import Foundation
import CoreBluetooth
import Observation
import RowivoCore

enum RowerConnectionState: String {
    case idle = "Connect your rower"
    case starting = "Starting Bluetooth…"
    case scanning = "Looking for rowing machines…"
    case connecting = "Connecting to your rower…"
    case connected = "Rower connected"
    case reconnecting = "Reconnecting to your rower…"
    case disconnected = "Rower disconnected"
    case poweredOff = "Bluetooth is off"
    case unauthorized = "Bluetooth access is off"
    case unsupported = "Bluetooth unavailable"
    case failed = "Could not connect to your rower"
    case notRower = "This device does not provide supported rowing data"
}

struct RowerDevice: Identifiable {
    var id: UUID
    var name: String
    var signal: Int
    var deviceProtocol: RowerProtocol = .concept2
}

/// CoreBluetooth delivers all delegates on the main queue. No Bluetooth permission is
/// requested until the user explicitly searches or reconnects.
@MainActor @Observable final class RowerConnection: NSObject {
    private(set) var state = RowerConnectionState.idle
    private(set) var devices: [RowerDevice] = []
    private(set) var selectedDevice: RowerDevice?
    private(set) var latest: RowerSnapshot?
    var lockedDeviceID: UUID?
    var onSnapshot: ((RowerSnapshot, RowerDevice) -> Void)?
    var onInterruption: (() -> Void)?

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var peripheral: CBPeripheral?
    private var telemetry = PM5Telemetry()
    private var ftmsTelemetry = FTMSTelemetry()
    private var subscribed: Set<CBUUID> = []
    private var wantsConnection = false
    private var scanRequested = false
    private var timeout: Task<Void, Never>?
    private static let fitness = CBUUID(string: "1826")
    private static let rowerData = CBUUID(string: "2AD1")
    private var requiredNotifications: [CBUUID] { selectedDevice?.deviceProtocol == .ftms ? [Self.rowerData] : [Self.general, Self.additional] }
    private static let rowing = uuid(0x0030)
    private static let general = uuid(0x0031)
    private static let additional = uuid(0x0032)
    private static let stroke = uuid(0x0036)
    private static let rate = uuid(0x0034)
    private static func uuid(_ short: UInt16) -> CBUUID {
        CBUUID(string: String(format: "CE06%04X-43E5-11E4-916C-0800200C9A66", short))
    }

    var isConnected: Bool { state == .connected }
    var isBusy: Bool { [.starting, .scanning, .connecting, .reconnecting].contains(state) }
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    func search() {
        guard !isConnected, ![.connecting, .reconnecting].contains(state) else { return }
        guard !isSimulator else { state = .unsupported; return }
        scanRequested = true
        if central == nil {
            state = .starting
            central = CBCentralManager(delegate: self, queue: .main,
                                       options: [CBCentralManagerOptionShowPowerAlertKey: false])
        } else if central?.state == .poweredOn { beginScan() }
        else { refreshBluetoothState() }
    }

    private func beginScan() {
        guard central?.state == .poweredOn else { return }
        timeout?.cancel(); devices = []; peripherals = [:]; state = .scanning
        // Scan in the foreground: PM5 names and advertised FTMS services are candidates.
        // Discover and verify the actual rowing characteristic before subscribing.
        central?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scheduleTimeout(seconds: 15) { connection in connection.stopSearch() }
    }

    func stopSearch() {
        scanRequested = false
        central?.stopScan()
        if state == .scanning { timeout?.cancel(); state = .idle }
    }

    func connect(_ device: RowerDevice) {
        guard lockedDeviceID == nil || lockedDeviceID == device.id,
              let candidate = peripherals[device.id], central?.state == .poweredOn else { return }
        stopSearch(); selectedDevice = device; peripheral = candidate; candidate.delegate = self
        wantsConnection = true; state = .connecting; subscribed = []; telemetry = PM5Telemetry(); ftmsTelemetry = FTMSTelemetry(); latest = nil
        central?.connect(candidate)
        connectionDeadline()
    }

    func disconnect() {
        wantsConnection = false; stopSearch(); timeout?.cancel()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil; latest = nil; subscribed = []; telemetry = PM5Telemetry(); ftmsTelemetry = FTMSTelemetry()
        state = .disconnected; onInterruption?()
    }

    func reset() {
        peripheral?.delegate = nil
        disconnect()
        central?.delegate = nil; central = nil
        peripherals = [:]; devices = []; selectedDevice = nil; lockedDeviceID = nil
        state = .idle
    }

    private func fail() {
        disconnect(); state = .failed
    }

    private func connectionDeadline() {
        scheduleTimeout(seconds: 20) { connection in
            if !connection.isConnected { connection.fail() }
        }
    }

    private func scheduleTimeout(seconds: Double, action: @escaping @MainActor (RowerConnection) -> Void) {
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self else { return }; action(self)
        }
    }

    private func refreshBluetoothState() {
        guard let central else { return }
        switch central.state {
        case .poweredOn:
            if wantsConnection, let peripheral {
                state = .reconnecting; central.connect(peripheral); connectionDeadline()
            } else if scanRequested { beginScan() }
            else { state = .idle }
        case .poweredOff: unavailable(.poweredOff)
        case .unauthorized: unavailable(.unauthorized)
        case .unsupported: unavailable(.unsupported)
        case .resetting, .unknown: unavailable(.starting)
        @unknown default: unavailable(.unsupported)
        }
    }

    private func unavailable(_ reason: RowerConnectionState) {
        timeout?.cancel(); latest = nil; subscribed = []; telemetry = PM5Telemetry(); ftmsTelemetry = FTMSTelemetry()
        state = reason; onInterruption?()
    }
}

extension RowerConnection: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) { refreshBluetoothState() }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard state == .scanning else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            + (advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
            + Array((advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]).keys)
        let concept2 = name.uppercased().hasPrefix("PM5") || services.contains(Self.rowing)
        guard concept2 || services.contains(Self.fitness), lockedDeviceID == nil || lockedDeviceID == peripheral.identifier else { return }
        peripherals[peripheral.identifier] = peripheral
        let device = RowerDevice(id: peripheral.identifier, name: name.isEmpty ? "FTMS" : name, signal: RSSI.intValue, deviceProtocol: concept2 ? .concept2 : .ftms)
        if let i = devices.firstIndex(where: { $0.id == device.id }) { devices[i] = device }
        else { devices.append(device) }
        devices.sort { $0.signal > $1.signal }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard wantsConnection, self.peripheral?.identifier == peripheral.identifier else {
            central.cancelPeripheralConnection(peripheral); return
        }
        subscribed = []; telemetry = PM5Telemetry(); ftmsTelemetry = FTMSTelemetry(); latest = nil
        peripheral.delegate = self
        peripheral.discoverServices([Self.rowing, Self.fitness])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        guard self.peripheral?.identifier == peripheral.identifier else { return }; fail()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        guard self.peripheral?.identifier == peripheral.identifier else { return }
        latest = nil; telemetry = PM5Telemetry(); ftmsTelemetry = FTMSTelemetry(); subscribed = []; onInterruption?()
        if wantsConnection && central.state == .poweredOn {
            state = .reconnecting
            central.connect(peripheral); connectionDeadline()
        } else if central.state == .poweredOn { state = .disconnected }
    }
}

extension RowerConnection: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        guard wantsConnection, self.peripheral?.identifier == peripheral.identifier else { return }
        guard error == nil else { fail(); return }
        if let service = peripheral.services?.first(where: { $0.uuid == Self.rowing }) {
            selectedDevice?.deviceProtocol = .concept2
            peripheral.discoverCharacteristics([Self.general, Self.additional, Self.stroke, Self.rate], for: service)
        } else if let service = peripheral.services?.first(where: { $0.uuid == Self.fitness }) {
            selectedDevice?.deviceProtocol = .ftms
            peripheral.discoverCharacteristics([Self.rowerData], for: service)
        } else { disconnect(); state = .notRower }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        guard wantsConnection, self.peripheral?.identifier == peripheral.identifier else { return }
        let characteristics = service.characteristics ?? []
        if service.uuid == Self.fitness {
            guard error == nil else { fail(); return }
            guard let characteristic = characteristics.first(where: { $0.uuid == Self.rowerData && $0.properties.contains(.notify) }) else {
                disconnect(); state = .notRower; return
            }
            // Receive telemetry only; no Fitness Machine Control Point writes.
            peripheral.setNotifyValue(true, for: characteristic)
            return
        }
        guard error == nil, [Self.general, Self.additional].allSatisfy({ id in
            characteristics.contains { $0.uuid == id && $0.properties.contains(.notify) }
        }) else { fail(); return }
        for characteristic in characteristics {
            if [Self.general, Self.additional, Self.stroke].contains(characteristic.uuid), characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == Self.rate, characteristic.properties.contains(.write) {
                peripheral.writeValue(Data([0]), for: characteristic, type: .withResponse) // 1 Hz
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard wantsConnection, self.peripheral?.identifier == peripheral.identifier else { return }
        let required = requiredNotifications
        guard error == nil, characteristic.isNotifying else {
            if required.contains(characteristic.uuid) { fail() }; return
        }
        subscribed.insert(characteristic.uuid)
        if required.allSatisfy(subscribed.contains) { timeout?.cancel(); state = .connected }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard wantsConnection, self.peripheral?.identifier == peripheral.identifier, error == nil,
              let data = characteristic.value, let device = selectedDevice else { return }
        if characteristic.uuid == Self.rowerData, device.deviceProtocol == .ftms {
            guard let snapshot = ftmsTelemetry.receive(data, at: Date()) else { return }
            latest = snapshot
            if isConnected { onSnapshot?(snapshot, device) }
            return
        }
        let short: UInt16
        switch characteristic.uuid {
        case Self.general: short = 0x0031
        case Self.additional: short = 0x0032
        case Self.stroke: short = 0x0036
        default: return
        }
        guard let packet = PM5Packet.decode(characteristic: short, data: data),
              let snapshot = telemetry.receive(packet, at: Date()) else { return }
        latest = RowerSnapshot(snapshot)
        if isConnected { onSnapshot?(RowerSnapshot(snapshot), device) }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard wantsConnection, self.peripheral?.identifier == peripheral.identifier,
              invalidatedServices.contains(where: { [Self.rowing, Self.fitness].contains($0.uuid) }) else { return }
        latest = nil; subscribed = []; telemetry = PM5Telemetry(); ftmsTelemetry = FTMSTelemetry(); onInterruption?()
        state = .connecting; connectionDeadline(); peripheral.discoverServices([Self.rowing, Self.fitness])
    }
}

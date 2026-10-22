import Foundation

/// Concept2 PM CSAFE Communication Definition, revision 0.34, pp. 17–22.
/// Dedicated GATT notifications (not the multiplexed characteristic).
public enum PM5Packet: Equatable, Sendable {
    case general(PM5GeneralStatus)
    case additional(PM5AdditionalStatus)
    case stroke(PM5StrokeStatus)

    public static func decode(characteristic: UInt16, data: Data) -> PM5Packet? {
        let b = Array(data)
        func u16(_ i: Int) -> Int { Int(b[i]) | Int(b[i + 1]) << 8 }
        func u24(_ i: Int) -> Int { u16(i) | Int(b[i + 2]) << 16 }
        switch characteristic {
        case 0x0031:
            guard b.count >= 19 else { return nil }
            return .general(.init(elapsed: Double(u24(0)) / 100, distance: Double(u24(3)) / 10,
                                  workoutType: b[6], workoutState: b[8], rowingState: b[9], dragFactor: Int(b[18])))
        case 0x0032:
            // Older firmware omits the trailing erg type byte.
            guard b.count >= 16 else { return nil }
            let pace = u16(7)
            return .additional(.init(elapsed: Double(u24(0)) / 100, strokeRate: Int(b[5]),
                                     heartRate: b[6] == 255 || b[6] == 0 ? nil : Int(b[6]),
                                     pace: pace == 0 || pace == 65535 ? nil : Double(pace) / 100))
        case 0x0036:
            // The 2025 firmware appends projected-work-other; the original packet is 15 bytes.
            guard b.count >= 15 else { return nil }
            return .stroke(.init(elapsed: Double(u24(0)) / 100, watts: u16(3), count: u16(7)))
        default: return nil
        }
    }
}

public struct PM5GeneralStatus: Equatable, Sendable {
    public var elapsed: Double
    public var distance: Double
    public var workoutType: UInt8
    public var workoutState: UInt8
    public var rowingState: UInt8
    public var dragFactor: Int
    public init(elapsed: Double, distance: Double, workoutType: UInt8 = 0, workoutState: UInt8 = 1,
                rowingState: UInt8 = 1, dragFactor: Int = 0) {
        self.elapsed = elapsed; self.distance = distance; self.workoutType = workoutType
        self.workoutState = workoutState; self.rowingState = rowingState; self.dragFactor = dragFactor
    }
}
public struct PM5AdditionalStatus: Equatable, Sendable {
    public var elapsed: Double
    public var strokeRate: Int
    public var heartRate: Int?
    public var pace: Double?
}
public struct PM5StrokeStatus: Equatable, Sendable {
    public var elapsed: Double
    public var watts: Int
    public var count: Int
}

public struct PM5Snapshot: Equatable, Sendable {
    public var date: Date
    public var general: PM5GeneralStatus
    public var pace: Double?
    public var strokeRate: Int?
    public var watts: Int?
    public var heartRate: Int?
    public init(date: Date, general: PM5GeneralStatus, pace: Double? = nil, strokeRate: Int? = nil,
                watts: Int? = nil, heartRate: Int? = nil) {
        self.date = date; self.general = general; self.pace = pace; self.strokeRate = strokeRate
        self.watts = watts; self.heartRate = heartRate
    }
}

/// Pairs independently delivered characteristics only while both their monitor and receipt times agree.
public struct PM5Telemetry: Sendable {
    private var additional: (PM5AdditionalStatus, Date)?
    private var stroke: (PM5StrokeStatus, Date)?
    private var previous: PM5GeneralStatus?
    public init() {}
    public mutating func receive(_ packet: PM5Packet, at date: Date) -> PM5Snapshot? {
        switch packet {
        case .additional(let value): additional = (value, date); return nil
        case .stroke(let value): stroke = (value, date); return nil
        case .general(let value):
            if let previous, value.elapsed < previous.elapsed || value.distance < previous.distance {
                additional = nil; stroke = nil
            }
            previous = value
            let a = additional.flatMap { abs($0.0.elapsed - value.elapsed) <= 2 && date.timeIntervalSince($0.1) <= 3 ? $0.0 : nil }
            let s = stroke.flatMap { abs($0.0.elapsed - value.elapsed) <= 10 && date.timeIntervalSince($0.1) <= 10 ? $0.0 : nil }
            return .init(date: date, general: value, pace: a?.pace, strokeRate: a?.strokeRate,
                         watts: s?.watts, heartRate: a?.heartRate)
        }
    }
}

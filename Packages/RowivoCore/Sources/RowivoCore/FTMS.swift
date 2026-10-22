import Foundation

/// Bluetooth Fitness Machine Service 1.0 §4.8/4.19; GATT Supplement (2026-02-05) §3.212.
/// Rower Data 0x2AD1, little endian. Other fitness-machine characteristics are not accepted.
public struct FTMSPacket: Equatable, Sendable {
    public var flags: UInt16
    public var values: RowerSnapshot
    public var moreData: Bool { flags & 1 != 0 }

    public static func decode(_ data: Data, at date: Date) -> Self? {
        let bytes = Array(data)
        guard bytes.count >= 2 else { return nil }
        let flags = UInt16(bytes[0]) | UInt16(bytes[1]) << 8
        guard flags & 0xE000 == 0 else { return nil }
        // Validate the entire payload before reading any optional field.
        let widths = [1, 3, 2, 2, 2, 2, 1, 5, 1, 1, 2, 2]
        var size = 2 + (flags & 1 == 0 ? 3 : 0)
        for bit in 1...12 where flags & (1 << bit) != 0 { size += widths[bit - 1] }
        guard bytes.count == size else { return nil }
        var offset = 2
        func read(_ width: Int) -> Int {
            defer { offset += width }
            return (0..<width).reduce(0) { $0 | Int(bytes[offset + $1]) << ($1 * 8) }
        }
        var values = RowerSnapshot(date: date)
        if flags & 1 == 0 {
            values.strokeRate = Double(read(1)) / 2
            values.strokeCount = read(2)
        }
        for bit in 1...12 where flags & (1 << bit) != 0 {
            switch bit {
            case 2: values.distance = Double(read(3))
            case 3:
                let raw = read(2); values.pace = raw == 0 ? nil : Double(raw)
            case 5: values.watts = Int(Int16(bitPattern: UInt16(read(2))))
            case 9:
                let raw = read(1); values.heartRate = raw == 0 ? nil : raw
            case 11: values.elapsed = Double(read(2))
            default: offset += widths[bit - 1]
            }
        }
        return .init(flags: flags, values: values)
    }
}

/// More Data = 1 precedes the final notification (More Data = 0). Publish complete
/// records only. Never carry optional metrics forward into the next record.
public struct FTMSTelemetry: Sendable {
    private var pending: FTMSPacket?
    public init() {}
    public mutating func receive(_ data: Data, at date: Date) -> RowerSnapshot? {
        guard var packet = FTMSPacket.decode(data, at: date) else { pending = nil; return nil }
        if let old = pending, (0...2).contains(date.timeIntervalSince(old.values.date)),
           // Repeated elapsed time is allowed, but must identify the same record.
           old.values.elapsed == nil || packet.values.elapsed == nil || old.values.elapsed == packet.values.elapsed,
           (old.flags & packet.flags & 0x17FE) == 0 {
            packet.values.distance = packet.values.distance ?? old.values.distance
            packet.values.elapsed = packet.values.elapsed ?? old.values.elapsed
            packet.values.pace = packet.values.pace ?? old.values.pace
            packet.values.watts = packet.values.watts ?? old.values.watts
            packet.values.heartRate = packet.values.heartRate ?? old.values.heartRate
            packet.flags |= old.flags & ~1
        }
        if packet.moreData { pending = packet; return nil }
        pending = nil
        return packet.values
    }
}

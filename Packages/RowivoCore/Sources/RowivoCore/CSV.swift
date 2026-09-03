import Foundation

public enum CSVValue: Sendable {
    case text(String), number(Double), integer(Int), boolean(Bool), empty

    fileprivate var encoded: String {
        let value: String
        switch self {
        case .text(let text):
            // Quoting alone does not stop spreadsheet formula execution. Guard text,
            // including leading whitespace, without changing numeric measurements.
            let first = text.trimmingCharacters(in: .whitespacesAndNewlines).first
            value = first.map { "=+-@".contains($0) } == true || text.first == "\t" || text.first == "\r" || text.first == "\n" ? "'" + text : text
        case .number(let number): value = number.isFinite ? String(number) : ""
        case .integer(let number): value = String(number)
        case .boolean(let flag): value = flag ? "true" : "false"
        case .empty: value = ""
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// RFC 4180 CSV, UTF-8 BOM for spreadsheet readers, locale-independent values.
public struct CSVTable: Sendable {
    public private(set) var data = Data([0xEF, 0xBB, 0xBF])
    private let columns: Int
    public init(headers: [String]) {
        columns = headers.count
        append(headers.map(CSVValue.text))
    }
    public mutating func append(_ row: [CSVValue]) {
        precondition(row.count == columns, "CSV row does not match schema")
        data.append(Data((row.map(\.encoded).joined(separator: ",") + "\r\n").utf8))
    }
}

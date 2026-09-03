import XCTest
@testable import RowivoCore

final class CSVTests: XCTestCase {
    func testUTF8CSVQuotesCommasNewlinesAndUnicode() {
        var csv = CSVTable(headers: ["note", "meters", "pain", "heart_rate"])
        csv.append([.text("Grüße,\n\"Rowivo\""), .number(12.5), .boolean(false), .empty])
        XCTAssertEqual(String(decoding: csv.data, as: UTF8.self), "\u{FEFF}\"note\",\"meters\",\"pain\",\"heart_rate\"\r\n\"Grüße,\n\"\"Rowivo\"\"\",\"12.5\",\"false\",\"\"\r\n")
    }
    func testUserTextCannotStartSpreadsheetFormulas() {
        for text in ["=1+1", "+SUM(A1)", "-1+2", "@SUM(A1)", "  =1+1", "\t=1+1", "\r=1+1", "\n=1+1"] {
            var csv = CSVTable(headers: ["note"])
            csv.append([.text(text)])
            XCTAssertTrue(String(decoding: csv.data, as: UTF8.self).contains("\"'" + text + "\""))
        }
        var csv = CSVTable(headers: ["signed_number", "missing"])
        csv.append([.number(-2.5), .number(.nan)])
        XCTAssertTrue(String(decoding: csv.data, as: UTF8.self).hasSuffix("\"-2.5\",\"\"\r\n"))
    }
}

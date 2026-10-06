import XCTest
@testable import StockTracker

final class StockSymbolTests: XCTestCase {
    func testSymbolsWithTheSameValueAreEqual() {
        XCTAssertEqual(StockSymbol(rawValue: "AAPL"), StockSymbol(rawValue: "AAPL"))
    }
}

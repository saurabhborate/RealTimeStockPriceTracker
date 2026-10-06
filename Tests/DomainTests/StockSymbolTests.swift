import XCTest
@testable import StockTracker

@MainActor
final class StockSymbolTests: XCTestCase {
    func testSymbolsWithTheSameValueAreEqual() {
        XCTAssertEqual(StockSymbol(rawValue: "AAPL"), StockSymbol(rawValue: "AAPL"))
    }
}

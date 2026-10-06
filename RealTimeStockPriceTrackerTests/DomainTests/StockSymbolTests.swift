import XCTest
@testable import RealTimeStockPriceTracker

@MainActor
final class StockSymbolTests: XCTestCase {
    func testSymbolsWithTheSameValueAreEqual() {
        XCTAssertEqual(StockSymbol(rawValue: "AAPL"), StockSymbol(rawValue: "AAPL"))
    }
}

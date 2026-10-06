import Foundation
import XCTest
@testable import StockTracker

@MainActor
final class StockCatalogAndGeneratorTests: XCTestCase {
    func testCatalogContainsTwentyFiveUniqueStocksWithDeterministicValidPrices() {
        let stocks = StockCatalog.initialStocks
        XCTAssertEqual(stocks.count, 25)
        XCTAssertEqual(Set(stocks.map(\.symbol)).count, 25)
        XCTAssertTrue(stocks.allSatisfy { $0.currentPrice.value > .zero })
        XCTAssertTrue(stocks.allSatisfy { $0.currentPrice.updatedAt == Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(stocks.first(where: { $0.symbol.rawValue == "AAPL" })?.currentPrice.value, 225)
    }

    func testRandomGeneratorKeepsMovesBoundedPositiveAndCorrectlyCalculated() async {
        let stock = Stock(
            symbol: StockSymbol(rawValue: "AAPL"),
            currentPrice: StockPrice(value: 225, updatedAt: Date(timeIntervalSince1970: 1)),
            description: "Apple Inc."
        )
        let generator = RandomStockPriceUpdateGenerator()
        let maxMove = Decimal(string: "1.13") ?? 1.13

        for index in 0..<100 {
            let update = await generator.generateUpdate(
                for: stock,
                at: Date(timeIntervalSince1970: TimeInterval(index + 2))
            )
            XCTAssertEqual(update.symbol, stock.symbol)
            XCTAssertEqual(update.previousPrice, stock.currentPrice)
            XCTAssertGreaterThan(update.currentPrice.value, .zero)
            let absoluteChange = update.priceChange < .zero ? -update.priceChange : update.priceChange
            XCTAssertLessThanOrEqual(absoluteChange, maxMove)
            XCTAssertEqual(update.priceChange, update.currentPrice.value - stock.currentPrice.value)
        }
    }
}

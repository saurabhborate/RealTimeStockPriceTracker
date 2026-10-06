import Foundation
import XCTest
@testable import RealTimeStockPriceTracker

@MainActor
final class StockModelTests: XCTestCase {
    func testStockRetainsCurrentAndPreviousPrices() {
        let current = StockPrice(value: 182.45, updatedAt: Date(timeIntervalSince1970: 20))
        let previous = StockPrice(value: 181.90, updatedAt: Date(timeIntervalSince1970: 10))
        let stock = Stock(
            symbol: StockSymbol(rawValue: "AAPL"),
            currentPrice: current,
            previousPrice: previous
        )

        XCTAssertEqual(stock.id, StockSymbol(rawValue: "AAPL"))
        XCTAssertEqual(stock.currentPrice, current)
        XCTAssertEqual(stock.previousPrice, previous)
    }

    func testStockPricePreservesDecimalValue() throws {
        let value = try XCTUnwrap(Decimal(string: "1234.56789"))
        let price = StockPrice(value: value, updatedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(price.value, value)
    }

    func testStockPriceChangeRepresentsPositiveNegativeAndZeroMoves() {
        let previous = StockPrice(value: 225, updatedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(stock(current: 226.2, previous: previous).priceChange, Decimal(string: "1.2"))
        XCTAssertEqual(stock(current: 223.8, previous: previous).priceChange, Decimal(string: "-1.2"))
        XCTAssertEqual(stock(current: 225, previous: previous).priceChange, .zero)
        XCTAssertEqual(stock(current: 225, previous: nil).priceChange, .zero)
    }

    private func stock(current: Decimal, previous: StockPrice?) -> Stock {
        Stock(
            symbol: StockSymbol(rawValue: "AAPL"),
            currentPrice: StockPrice(value: current, updatedAt: Date(timeIntervalSince1970: 2)),
            previousPrice: previous
        )
    }
}

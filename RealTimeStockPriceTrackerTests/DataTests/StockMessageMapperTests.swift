import Foundation
import XCTest
@testable import RealTimeStockPriceTracker

@MainActor
final class StockMessageMapperTests: XCTestCase {
    func testMapsTransportMessageToDomainStock() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let message = StockPriceMessage(symbol: " aapl ", price: 187.25, timestamp: timestamp)

        let stock = try StockMessageMapper().map(message)

        XCTAssertEqual(stock.symbol, StockSymbol(rawValue: "AAPL"))
        XCTAssertEqual(stock.currentPrice.value, 187.25)
        XCTAssertEqual(stock.currentPrice.updatedAt, timestamp)
    }

    func testRejectsEmptySymbol() {
        let message = StockPriceMessage(symbol: "  ", price: 10, timestamp: Date(timeIntervalSince1970: 1))

        XCTAssertThrowsError(try StockMessageMapper().map(message)) { error in
            XCTAssertEqual(error as? StockMessageMapperError, .invalidSymbol)
        }
    }

    func testRejectsNonpositivePrice() {
        let message = StockPriceMessage(symbol: "AAPL", price: 0, timestamp: Date(timeIntervalSince1970: 1))

        XCTAssertThrowsError(try StockMessageMapper().map(message)) { error in
            XCTAssertEqual(error as? StockMessageMapperError, .invalidPrice)
        }
    }
}

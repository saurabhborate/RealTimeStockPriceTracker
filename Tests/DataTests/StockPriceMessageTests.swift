import Foundation
import XCTest
@testable import StockTracker

@MainActor
final class StockPriceMessageTests: XCTestCase {
    func testMessageRoundTripsThroughCodable() throws {
        let message = StockPriceMessage(
            symbol: "TSLA",
            price: 250.75,
            change: 1.25,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(StockPriceMessage.self, from: data)

        XCTAssertEqual(decoded, message)
    }

    func testMalformedJSONCannotDecodeAsMessage() {
        XCTAssertThrowsError(try JSONDecoder().decode(StockPriceMessage.self, from: Data("{}".utf8)))
    }
}

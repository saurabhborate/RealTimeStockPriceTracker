import Foundation
import XCTest
@testable import StockTracker

@MainActor
final class StockWebSocketDataSourceTests: XCTestCase {
    func testEncodesStockUpdatesBeforeSending() async throws {
        let client = MockWebSocketClient()
        try await client.connect()
        let dataSource = StockWebSocketDataSource(client: client)
        let stock = Stock(
            symbol: StockSymbol(rawValue: "MSFT"),
            currentPrice: StockPrice(value: 420.15, updatedAt: Date(timeIntervalSince1970: 5)),
            previousPrice: StockPrice(value: 419, updatedAt: Date(timeIntervalSince1970: 4))
        )

        try await dataSource.send(stock)

        let sentMessages = await client.sentMessages()
        let message = try JSONDecoder().decode(StockPriceMessage.self, from: try XCTUnwrap(sentMessages.first))
        XCTAssertEqual(message.symbol, "MSFT")
        XCTAssertEqual(message.price, stock.currentPrice.value)
        XCTAssertEqual(message.change, Decimal(string: "1.15"))
        XCTAssertEqual(message.timestamp, stock.currentPrice.updatedAt)
    }

    func testDecodesIncomingStockUpdate() async throws {
        let client = MockWebSocketClient()
        try await client.connect()
        let dataSource = StockWebSocketDataSource(client: client)
        let updates = await dataSource.priceUpdates()
        _ = await dataSource.priceUpdates()
        let timestamp = Date(timeIntervalSince1970: 50)
        let message = StockPriceMessage(symbol: "NVDA", price: 900.50, timestamp: timestamp)
        await client.yield(try JSONEncoder().encode(message))

        var iterator = updates.makeAsyncIterator()
        let stock = try await iterator.next()

        XCTAssertEqual(stock?.symbol, StockSymbol(rawValue: "NVDA"))
        XCTAssertEqual(stock?.currentPrice.value, 900.50)
        XCTAssertEqual(stock?.currentPrice.updatedAt, timestamp)
        let counts = await client.counts()
        XCTAssertEqual(counts.incomingSubscriptions, 1)
    }

    func testFinishesWithDataErrorForMalformedPayload() async throws {
        let client = MockWebSocketClient()
        try await client.connect()
        let dataSource = StockWebSocketDataSource(client: client)
        let updates = await dataSource.priceUpdates()
        await client.yield(Data("not-json".utf8))

        var iterator = updates.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            XCTFail("Expected malformed payload to fail the update stream.")
        } catch StockDataError.decodingFailed(_) {
            return
        }
    }

    func testPropagatesSocketSendFailure() async throws {
        let client = MockWebSocketClient(sendFailure: .send)
        try await client.connect()
        let dataSource = StockWebSocketDataSource(client: client)
        let stock = Stock(
            symbol: StockSymbol(rawValue: "AAPL"),
            currentPrice: StockPrice(value: 180, updatedAt: Date(timeIntervalSince1970: 1))
        )

        do {
            try await dataSource.send(stock)
            XCTFail("Expected the socket send failure to be propagated.")
        } catch MockWebSocketClient.Failure.send {
            return
        }
    }

    func testPropagatesSocketConnectionFailure() async throws {
        let client = MockWebSocketClient(connectionFailure: .connection)
        let dataSource = StockWebSocketDataSource(client: client)

        do {
            try await dataSource.connect()
            XCTFail("Expected the socket connection failure to be propagated.")
        } catch MockWebSocketClient.Failure.connection {
            return
        }
    }

    func testPropagatesSocketReceiveFailure() async throws {
        let client = MockWebSocketClient()
        try await client.connect()
        let dataSource = StockWebSocketDataSource(client: client)
        let updates = await dataSource.priceUpdates()
        await client.finishIncoming(throwing: .receive)

        var iterator = updates.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            XCTFail("Expected the socket receive failure to be propagated.")
        } catch MockWebSocketClient.Failure.receive {
            return
        }
    }

    func testDisconnectFinishesUpdateStream() async throws {
        let client = MockWebSocketClient()
        try await client.connect()
        let dataSource = StockWebSocketDataSource(client: client)
        let updates = await dataSource.priceUpdates()

        await dataSource.disconnect()

        var iterator = updates.makeAsyncIterator()
        let nextUpdate = try await iterator.next()
        XCTAssertNil(nextUpdate)
    }
}

import Foundation
import XCTest
@testable import StockTracker

@MainActor
final class StockRepositoryTests: XCTestCase {
    func testSharesIncomingUpdatesAndPublishesConnectionState() async throws {
        let dataSource = MockStockDataSource()
        let repository = StockRepositoryImpl(dataSource: dataSource)
        let states = await repository.connectionStates()
        var stateIterator = states.makeAsyncIterator()
        let initialState = await stateIterator.next()
        XCTAssertEqual(initialState, .disconnected)

        try await repository.connect()
        let connectingState = await stateIterator.next()
        let connectedState = await stateIterator.next()
        XCTAssertEqual(connectingState, .connecting)
        XCTAssertEqual(connectedState, .connected)

        let firstSubscriber = await repository.priceUpdates()
        let secondSubscriber = await repository.priceUpdates()
        let stock = Stock(
            symbol: StockSymbol(rawValue: "AMD"),
            currentPrice: StockPrice(value: 150, updatedAt: Date(timeIntervalSince1970: 80))
        )
        await dataSource.yield(stock)

        var firstIterator = firstSubscriber.makeAsyncIterator()
        var secondIterator = secondSubscriber.makeAsyncIterator()
        let firstStock = try await firstIterator.next()
        let secondStock = try await secondIterator.next()
        XCTAssertEqual(firstStock, secondStock)
        XCTAssertEqual(firstStock?.symbol, StockSymbol(rawValue: "AMD"))

        try await repository.send(stock)
        await repository.disconnect()
        let isDisconnected = await dataSource.wasDisconnected()
        let sentStocks = await dataSource.sent()
        let disconnectedState = await stateIterator.next()
        XCTAssertTrue(isDisconnected)
        XCTAssertEqual(sentStocks, [stock])
        XCTAssertEqual(disconnectedState, .disconnected)
    }

    func testConnectionFailureIsPropagatedAndUpdatesState() async throws {
        let dataSource = MockStockDataSource(connectionFailure: .connection)
        let repository = StockRepositoryImpl(dataSource: dataSource)
        let states = await repository.connectionStates()
        var iterator = states.makeAsyncIterator()

        do {
            try await repository.connect()
            XCTFail("Expected the connection failure to be propagated.")
        } catch StockRepositoryError.connectionFailed {
            let initialState = await iterator.next()
            let connectingState = await iterator.next()
            let failedState = await iterator.next()
            XCTAssertEqual(initialState, .disconnected)
            XCTAssertEqual(connectingState, .connecting)
            XCTAssertEqual(failedState, .failed)
        }
    }

    func testUpdateFailureIsPropagatedToSubscribers() async throws {
        let dataSource = MockStockDataSource()
        let repository = StockRepositoryImpl(dataSource: dataSource)
        try await repository.connect()
        let updates = await repository.priceUpdates()
        await dataSource.finishUpdates(throwing: .updates)

        var iterator = updates.makeAsyncIterator()
        do {
            _ = try await iterator.next()
            XCTFail("Expected the source failure to reach repository subscribers.")
        } catch StockRepositoryError.updatesFailed {
            return
        }
    }

    func testSendFailureIsExposedAsRepositoryError() async throws {
        let dataSource = MockStockDataSource(sendFailure: .send)
        let repository = StockRepositoryImpl(dataSource: dataSource)
        let stock = Stock(
            symbol: StockSymbol(rawValue: "AAPL"),
            currentPrice: StockPrice(value: 180, updatedAt: Date(timeIntervalSince1970: 1))
        )
        try await repository.connect()

        do {
            try await repository.send(stock)
            XCTFail("Expected the source send failure to be translated.")
        } catch StockRepositoryError.sendFailed {
            return
        }
    }
}

import Foundation
import XCTest
@testable import RealTimeStockPriceTracker

@MainActor
final class StockRepositoryTests: XCTestCase {
    func testKeepsSeededStocksAndPublishesEchoedUpdatesToMultipleObservers() async throws {
        let seed = stock("AMD", price: 150)
        let dataSource = MockStockDataSource()
        let repository = StockRepositoryImpl(
            dataSource: dataSource,
            initialStocks: [seed],
            priceUpdateGenerator: MockStockPriceUpdateGenerator(nextPrice: 155),
            updateInterval: nil
        )
        let firstStocks = await repository.stocks()
        let secondStocks = await repository.stocks()
        var firstStockIterator = firstStocks.makeAsyncIterator()
        var secondStockIterator = secondStocks.makeAsyncIterator()
        let firstInitialSnapshot = await firstStockIterator.next()
        let secondInitialSnapshot = await secondStockIterator.next()
        XCTAssertEqual(firstInitialSnapshot, [seed])
        XCTAssertEqual(secondInitialSnapshot, [seed])

        let states = await repository.connectionStates()
        var stateIterator = states.makeAsyncIterator()
        let initialState = await stateIterator.next()
        XCTAssertEqual(initialState, .disconnected)

        try await repository.connect()
        let connectingState = await stateIterator.next()
        let connectedState = await stateIterator.next()
        XCTAssertEqual(connectingState, .connecting)
        XCTAssertEqual(connectedState, .connected)

        let updated = Stock(
            symbol: seed.symbol,
            currentPrice: StockPrice(value: 152, updatedAt: Date(timeIntervalSince1970: 80))
        )
        await dataSource.yield(updated)
        let firstSnapshot = await firstStockIterator.next()
        let secondSnapshot = await secondStockIterator.next()
        XCTAssertEqual(firstSnapshot, secondSnapshot)
        XCTAssertEqual(firstSnapshot?.first?.currentPrice.value, 152)
        XCTAssertEqual(firstSnapshot?.first?.previousPrice, seed.currentPrice)

        await repository.disconnect()
        let isDisconnected = await dataSource.wasDisconnected()
        let sentStocks = await dataSource.sentStocks()
        let disconnectedState = await stateIterator.next()
        XCTAssertTrue(isDisconnected)
        XCTAssertTrue(sentStocks.isEmpty)
        XCTAssertEqual(disconnectedState, .disconnected)
    }

    func testConnectionFailureIsPropagatedAndUpdatesState() async throws {
        let dataSource = MockStockDataSource(connectionFailure: .connection)
        let repository = StockRepositoryImpl(dataSource: dataSource, updateInterval: nil)
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

    func testUpdateFailureChangesConnectionStateToFailed() async throws {
        let dataSource = MockStockDataSource()
        let repository = StockRepositoryImpl(dataSource: dataSource, updateInterval: nil)
        let states = await repository.connectionStates()
        var iterator = states.makeAsyncIterator()
        _ = await iterator.next()
        try await repository.connect()
        await dataSource.finishUpdates(throwing: .updates)
        let connecting = await iterator.next()
        let connected = await iterator.next()
        let failed = await iterator.next()
        XCTAssertEqual(connecting, .connecting)
        XCTAssertEqual(connected, .connected)
        XCTAssertEqual(failed, .failed)
    }

    func testSendFailureIsExposedAsRepositoryError() async throws {
        let dataSource = MockStockDataSource(sendFailure: .send)
        let repository = StockRepositoryImpl(dataSource: dataSource, updateInterval: nil)
        let stock = Stock(
            symbol: StockSymbol(rawValue: "AAPL"),
            currentPrice: StockPrice(value: 180, updatedAt: Date(timeIntervalSince1970: 1))
        )
        let states = await repository.connectionStates()
        var iterator = states.makeAsyncIterator()
        _ = await iterator.next()
        try await repository.connect()
        _ = await iterator.next()
        _ = await iterator.next()

        do {
            try await repository.send(stock)
            XCTFail("Expected the source send failure to be translated.")
        } catch StockRepositoryError.sendFailed {
            let failedState = await iterator.next()
            let disconnected = await dataSource.wasDisconnected()
            XCTAssertEqual(failedState, .failed)
            XCTAssertTrue(disconnected)
        }
    }

    func testGeneratedUpdateIsSentEchoedAndAppliedThenFeedStops() async throws {
        let seed = stock("AAPL", price: 200)
        let webSocketClient = MockWebSocketClient(echoesSentMessages: true)
        let dataSource = StockWebSocketDataSource(client: webSocketClient)
        let generator = MockStockPriceUpdateGenerator(nextPrice: 201.25)
        let repository = StockRepositoryImpl(
            dataSource: dataSource,
            initialStocks: [seed],
            priceUpdateGenerator: generator,
            updateInterval: .seconds(3_600)
        )
        let generatedUpdates = await generator.generatedUpdates()
        var generatedIterator = generatedUpdates.makeAsyncIterator()
        let snapshots = await repository.stocks()
        var stockIterator = snapshots.makeAsyncIterator()
        _ = await stockIterator.next()

        try await repository.connect()

        let generated = await generatedIterator.next()
        let applied = await stockIterator.next()
        let sentData = await webSocketClient.sentMessages()
        let sentMessage = try XCTUnwrap(sentData.first)
        let decodedMessage = try JSONDecoder().decode(StockPriceMessage.self, from: sentMessage)
        XCTAssertEqual(generated?.currentPrice.value, 201.25)
        XCTAssertEqual(decodedMessage.symbol, seed.symbol.rawValue)
        XCTAssertEqual(decodedMessage.change, Decimal(string: "1.25"))
        XCTAssertEqual(applied?.first?.currentPrice.value, 201.25)
        XCTAssertEqual(applied?.first?.previousPrice, seed.currentPrice)

        await repository.disconnect()
        let sentCountAfterStop = await webSocketClient.sentMessages().count
        XCTAssertEqual(sentCountAfterStop, 1)
        let socketCounts = await webSocketClient.counts()
        XCTAssertEqual(socketCounts.connections, 1)
        XCTAssertEqual(socketCounts.disconnections, 1)
        XCTAssertEqual(socketCounts.incomingSubscriptions, 1)
    }

    func testConnectIsIdempotentStopIsSafeAndRestartCreatesANewConnection() async throws {
        let dataSource = MockStockDataSource()
        let repository = StockRepositoryImpl(dataSource: dataSource, updateInterval: nil)
        try await repository.connect()
        try await repository.connect()
        await repository.disconnect()
        await repository.disconnect()
        try await repository.connect()

        let counts = await dataSource.counts()
        XCTAssertEqual(counts.connections, 2)
        XCTAssertEqual(counts.disconnections, 1)
        await repository.disconnect()
    }

    private func stock(_ symbol: String, price: Decimal) -> Stock {
        Stock(
            symbol: StockSymbol(rawValue: symbol),
            currentPrice: StockPrice(value: price, updatedAt: Date(timeIntervalSince1970: 10)),
            description: "Test company"
        )
    }
}

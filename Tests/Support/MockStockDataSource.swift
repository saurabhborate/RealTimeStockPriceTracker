import Foundation
@testable import StockTracker

actor MockStockDataSource: StockDataSource {
    enum Failure: Error, Sendable {
        case connection
        case send
        case updates
    }

    private let connectionFailure: Failure?
    private let sendFailure: Failure?
    private var incomingStream: AsyncThrowingStream<Stock, any Error>?
    private var incomingContinuation: AsyncThrowingStream<Stock, any Error>.Continuation?
    private var sentStockHistory: [Stock] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    init(
        connectionFailure: Failure? = nil,
        sendFailure: Failure? = nil
    ) {
        self.connectionFailure = connectionFailure
        self.sendFailure = sendFailure
    }

    func connect() async throws {
        if let connectionFailure { throw connectionFailure }
        connectCount += 1
        let (stream, continuation) = AsyncThrowingStream<Stock, any Error>.makeStream()
        incomingStream = stream
        incomingContinuation = continuation
    }

    func send(_ stock: Stock) async throws {
        if let sendFailure { throw sendFailure }
        sentStockHistory.append(stock)
    }

    func priceUpdates() async -> AsyncThrowingStream<Stock, any Error> {
        incomingStream ?? AsyncThrowingStream { $0.finish(throwing: Failure.connection) }
    }

    func disconnect() async {
        disconnectCount += 1
        incomingContinuation?.finish()
        incomingContinuation = nil
        incomingStream = nil
    }

    func yield(_ stock: Stock) {
        incomingContinuation?.yield(stock)
    }

    func finishUpdates(throwing error: Failure) {
        incomingContinuation?.finish(throwing: error)
        incomingContinuation = nil
    }

    func sentStocks() -> [Stock] { sentStockHistory }
    func wasDisconnected() -> Bool { disconnectCount > 0 }
    func counts() -> (connections: Int, disconnections: Int) { (connectCount, disconnectCount) }

}

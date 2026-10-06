import Foundation
@testable import StockTracker

actor MockStockDataSource: StockDataSource {
    enum Failure: Error, Sendable {
        case connection
        case send
        case updates
    }

    private let stream: AsyncThrowingStream<Stock, any Error>
    private let continuation: AsyncThrowingStream<Stock, any Error>.Continuation
    private let connectionFailure: Failure?
    private let sendFailure: Failure?
    private var sentStocks: [Stock] = []
    private var disconnected = false

    init(connectionFailure: Failure? = nil, sendFailure: Failure? = nil) {
        let (stream, continuation) = AsyncThrowingStream<Stock, any Error>.makeStream()
        self.stream = stream
        self.continuation = continuation
        self.connectionFailure = connectionFailure
        self.sendFailure = sendFailure
    }

    func connect() async throws {
        if let connectionFailure { throw connectionFailure }
    }

    func send(_ stock: Stock) async throws {
        if let sendFailure { throw sendFailure }
        sentStocks.append(stock)
    }

    func priceUpdates() async -> AsyncThrowingStream<Stock, any Error> {
        stream
    }

    func disconnect() async {
        disconnected = true
        continuation.finish()
    }

    func yield(_ stock: Stock) {
        continuation.yield(stock)
    }

    func finishUpdates(throwing error: Failure) {
        continuation.finish(throwing: error)
    }

    func wasDisconnected() -> Bool { disconnected }
    func sent() -> [Stock] { sentStocks }
}

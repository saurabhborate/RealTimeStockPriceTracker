import Foundation
@testable import StockTracker

actor MockStockRepository: StockRepository {
    private var state: ConnectionState = .disconnected
    private var stateContinuations: [AsyncStream<ConnectionState>.Continuation] = []
    private var stockContinuations: [UUID: AsyncThrowingStream<Stock, any Error>.Continuation] = [:]
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0

    func connect() async throws {
        connectCount += 1
        publishState(.connecting)
        publishState(.connected)
    }

    func send(_ stock: Stock) async throws {}

    func priceUpdates() async -> AsyncThrowingStream<Stock, any Error> {
        let (stream, continuation) = AsyncThrowingStream<Stock, any Error>.makeStream()
        let id = UUID()
        stockContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStockObserver(id) }
        }
        return stream
    }

    func connectionStates() async -> AsyncStream<ConnectionState> {
        let (stream, continuation) = AsyncStream<ConnectionState>.makeStream()
        stateContinuations.append(continuation)
        continuation.yield(state)
        return stream
    }

    func disconnect() async {
        disconnectCount += 1
        publishState(.disconnected)
        for continuation in stockContinuations.values { continuation.finish() }
        stockContinuations.removeAll()
    }

    func activeStockObserverCount() -> Int {
        stockContinuations.count
    }

    func publish(_ stock: Stock) {
        for continuation in stockContinuations.values { continuation.yield(stock) }
    }

    func setState(_ state: ConnectionState) {
        publishState(state)
    }

    private func publishState(_ state: ConnectionState) {
        self.state = state
        for continuation in stateContinuations { continuation.yield(state) }
    }

    private func removeStockObserver(_ id: UUID) {
        stockContinuations[id] = nil
    }
}

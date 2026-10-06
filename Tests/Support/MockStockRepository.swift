import Foundation
@testable import StockTracker

actor MockStockRepository: StockRepository {
    private var state: ConnectionState = .disconnected
    private var stocks: [Stock]
    private var connectionError: StockRepositoryError?
    private var stateContinuations: [UUID: AsyncStream<ConnectionState>.Continuation] = [:]
    private var stockContinuations: [UUID: AsyncStream<[Stock]>.Continuation] = [:]
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var sentStocks: [Stock] = []

    init(
        stocks: [Stock] = StockCatalog.initialStocks,
        connectionError: StockRepositoryError? = nil
    ) {
        self.stocks = stocks
        self.connectionError = connectionError
    }

    func connect() async throws {
        connectCount += 1
        publishState(.connecting)
        if let connectionError {
            publishState(.failed)
            throw connectionError
        }
        publishState(.connected)
    }

    func send(_ stock: Stock) async throws {
        sentStocks.append(stock)
    }

    func currentStocks() async -> [Stock] {
        stocks
    }

    func stocks() async -> AsyncStream<[Stock]> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[Stock]>.makeStream()
        stockContinuations[id] = continuation
        continuation.yield(stocks)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStockObserver(id) }
        }
        return stream
    }

    func connectionStates() async -> AsyncStream<ConnectionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ConnectionState>.makeStream()
        stateContinuations[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStateObserver(id) }
        }
        return stream
    }

    func disconnect() async {
        disconnectCount += 1
        publishState(.disconnected)
    }

    func publish(_ stock: Stock) {
        guard let index = stocks.firstIndex(where: { $0.symbol == stock.symbol }) else { return }
        let previous = stocks[index]
        stocks[index] = Stock(
            symbol: stock.symbol,
            currentPrice: stock.currentPrice,
            previousPrice: previous.currentPrice,
            description: previous.description
        )
        publishStocks()
    }

    func activeStockObserverCount() -> Int {
        stockContinuations.count
    }

    func countConnections() -> Int { connectCount }
    func countDisconnections() -> Int { disconnectCount }

    private func publishState(_ state: ConnectionState) {
        self.state = state
        for continuation in stateContinuations.values { continuation.yield(state) }
    }

    private func publishStocks() {
        for continuation in stockContinuations.values { continuation.yield(stocks) }
    }

    private func removeStockObserver(_ id: UUID) {
        stockContinuations[id] = nil
    }

    private func removeStateObserver(_ id: UUID) {
        stateContinuations[id] = nil
    }
}

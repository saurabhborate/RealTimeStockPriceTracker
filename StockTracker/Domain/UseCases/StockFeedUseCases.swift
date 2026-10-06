public struct ObserveStockUpdatesUseCase: Sendable {
    private let repository: any StockRepository

    public init(repository: any StockRepository) {
        self.repository = repository
    }

    public func callAsFunction() async -> AsyncThrowingStream<Stock, any Error> {
        await repository.priceUpdates()
    }
}

public struct ObserveConnectionStateUseCase: Sendable {
    private let repository: any StockRepository

    public init(repository: any StockRepository) {
        self.repository = repository
    }

    public func callAsFunction() async -> AsyncStream<ConnectionState> {
        await repository.connectionStates()
    }
}

public struct StartStockFeedUseCase: Sendable {
    private let repository: any StockRepository

    public init(repository: any StockRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws {
        try await repository.connect()
    }
}

public struct StopStockFeedUseCase: Sendable {
    private let repository: any StockRepository

    public init(repository: any StockRepository) {
        self.repository = repository
    }

    public func callAsFunction() async {
        await repository.disconnect()
    }
}

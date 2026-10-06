public protocol StockDataSource: Sendable {
    func connect() async throws
    func send(_ stock: Stock) async throws
    func priceUpdates() async -> AsyncThrowingStream<Stock, any Error>
    func disconnect() async
}

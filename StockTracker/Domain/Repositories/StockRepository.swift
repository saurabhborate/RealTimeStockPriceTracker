/// Exposes stock data to application logic without coupling it to a data source.
public protocol StockRepository: Sendable {
    func connect() async throws
    func send(_ stock: Stock) async throws
    func priceUpdates() async -> AsyncThrowingStream<Stock, any Error>
    func connectionStates() async -> AsyncStream<ConnectionState>
    func disconnect() async
}

public enum StockRepositoryError: Error, Equatable, Sendable {
    case connectionFailed
    case sendFailed
    case updatesFailed
}

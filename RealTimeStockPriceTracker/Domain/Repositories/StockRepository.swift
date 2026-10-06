public protocol StockRepository: Sendable {
    func connect() async throws
    func send(_ stock: Stock) async throws
    func currentStocks() async -> [Stock]
    func stocks() async -> AsyncStream<[Stock]>
    func connectionStates() async -> AsyncStream<ConnectionState>
    func disconnect() async
}

public enum StockRepositoryError: Error, Equatable, Sendable {
    case connectionFailed
    case sendFailed
    case unknownStock
    case invalidPrice
}

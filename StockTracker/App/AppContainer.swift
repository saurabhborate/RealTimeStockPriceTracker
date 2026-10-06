/// Constructs and owns the shared data dependencies for the application.
public struct AppContainer: Sendable {
    public let stockRepository: any StockRepository

    public init(environment: AppEnvironment = AppEnvironment()) throws {
        let webSocketClient = try WebSocketClientImpl(endpoint: environment.webSocketEndpoint)
        let dataSource = StockWebSocketDataSource(client: webSocketClient)
        stockRepository = StockRepositoryImpl(dataSource: dataSource)
    }
}

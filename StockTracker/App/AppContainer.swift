/// Constructs and owns the shared data dependencies for the application.
public struct AppContainer: Sendable {
    public let stockRepository: any StockRepository

    public init(environment: AppEnvironment = AppEnvironment()) throws {
        let webSocketClient = try WebSocketClientImpl(endpoint: environment.webSocketEndpoint)
        let dataSource = StockWebSocketDataSource(client: webSocketClient)
        stockRepository = StockRepositoryImpl(dataSource: dataSource)
    }

    public init(stockRepository: any StockRepository) {
        self.stockRepository = stockRepository
    }

    @MainActor
    public func makeStockListViewModel() -> StockListViewModel {
        StockListViewModel(
            observeUpdates: ObserveStockUpdatesUseCase(repository: stockRepository),
            observeConnection: ObserveConnectionStateUseCase(repository: stockRepository),
            sortStocks: SortStocksUseCase()
        )
    }

    @MainActor
    public func makeStockDetailViewModel(for stock: Stock) -> StockDetailViewModel {
        StockDetailViewModel(
            stock: stock,
            observeUpdates: ObserveStockUpdatesUseCase(repository: stockRepository),
            observeConnection: ObserveConnectionStateUseCase(repository: stockRepository),
            startFeed: StartStockFeedUseCase(repository: stockRepository),
            stopFeed: StopStockFeedUseCase(repository: stockRepository)
        )
    }
}

public struct AppContainer: Sendable {
    public let stockRepository: any StockRepository

    public init(environment: AppEnvironment = AppEnvironment()) throws {
        let webSocketClient = try WebSocketClientImpl(endpoint: environment.webSocketEndpoint)
        let dataSource = StockWebSocketDataSource(client: webSocketClient)
        stockRepository = StockRepositoryImpl(
            dataSource: dataSource,
            initialStocks: StockCatalog.initialStocks,
            priceUpdateGenerator: RandomStockPriceUpdateGenerator()
        )
    }

    public init(stockRepository: any StockRepository) {
        self.stockRepository = stockRepository
    }

    @MainActor
    public func makeStockListViewModel() -> StockListViewModel {
        StockListViewModel(
            observeStocks: ObserveStocksUseCase(repository: stockRepository),
            observeConnection: ObserveConnectionStateUseCase(repository: stockRepository),
            sortStocks: SortStocksUseCase()
        )
    }

    @MainActor
    public func makeStockDetailViewModel(for stock: Stock) -> StockDetailViewModel {
        StockDetailViewModel(
            stock: stock,
            observeStocks: ObserveStocksUseCase(repository: stockRepository),
            observeConnection: ObserveConnectionStateUseCase(repository: stockRepository)
        )
    }

    public func stopStockFeed() async {
        await StopStockFeedUseCase(repository: stockRepository)()
    }

    public func startStockFeed() async throws {
        try await StartStockFeedUseCase(repository: stockRepository)()
    }
}

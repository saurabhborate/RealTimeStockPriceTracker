/// Exposes stock data to application logic without coupling it to a data source.
public protocol StockRepository: Sendable {
    func priceUpdates(for symbols: [StockSymbol]) -> AsyncThrowingStream<StockPrice, any Error>
}

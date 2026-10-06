/// A stock identity and its latest observed prices.
public struct Stock: Equatable, Identifiable, Sendable {
    public let symbol: StockSymbol
    public let currentPrice: StockPrice
    public let previousPrice: StockPrice?

    public var id: StockSymbol { symbol }

    public init(
        symbol: StockSymbol,
        currentPrice: StockPrice,
        previousPrice: StockPrice? = nil
    ) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
    }
}

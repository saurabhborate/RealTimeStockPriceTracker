import Foundation

/// A stock identity and its latest observed prices.
public struct Stock: Equatable, Identifiable, Sendable {
    public let symbol: StockSymbol
    public let currentPrice: StockPrice
    public let previousPrice: StockPrice?
    public let description: String?

    public var id: StockSymbol { symbol }
    public var priceChange: Decimal {
        currentPrice.value - (previousPrice?.value ?? currentPrice.value)
    }

    public init(
        symbol: StockSymbol,
        currentPrice: StockPrice,
        previousPrice: StockPrice? = nil,
        description: String? = nil
    ) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.previousPrice = previousPrice
        self.description = description
    }
}

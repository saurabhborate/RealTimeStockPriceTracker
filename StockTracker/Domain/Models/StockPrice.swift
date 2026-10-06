import Foundation

/// A stock price update represented independently of transport or storage.
public struct StockPrice: Equatable, Sendable {
    public let symbol: StockSymbol
    public let value: Decimal
    public let updatedAt: Date

    public init(symbol: StockSymbol, value: Decimal, updatedAt: Date) {
        self.symbol = symbol
        self.value = value
        self.updatedAt = updatedAt
    }
}

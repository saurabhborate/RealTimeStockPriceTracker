import Foundation

public struct StockPriceMessage: Codable, Equatable, Sendable {
    public let symbol: String
    public let price: Decimal
    public let change: Decimal?
    public let timestamp: Date

    public init(symbol: String, price: Decimal, change: Decimal? = nil, timestamp: Date) {
        self.symbol = symbol
        self.price = price
        self.change = change
        self.timestamp = timestamp
    }
}

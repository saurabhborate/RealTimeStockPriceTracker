import Foundation

/// The JSON representation exchanged with the stock feed.
public struct StockPriceMessage: Codable, Equatable, Sendable {
    public let symbol: String
    public let price: Decimal
    public let timestamp: Date

    public init(symbol: String, price: Decimal, timestamp: Date) {
        self.symbol = symbol
        self.price = price
        self.timestamp = timestamp
    }
}

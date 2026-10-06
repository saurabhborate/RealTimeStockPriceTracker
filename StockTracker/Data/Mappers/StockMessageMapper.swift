import Foundation

public enum StockMessageMapperError: Error, Equatable, Sendable {
    case invalidSymbol
    case invalidPrice
}

public struct StockMessageMapper: Sendable {
    public init() {}

    public func map(_ message: StockPriceMessage) throws -> Stock {
        let symbol = message.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !symbol.isEmpty else { throw StockMessageMapperError.invalidSymbol }
        guard message.price > 0 else { throw StockMessageMapperError.invalidPrice }

        return Stock(
            symbol: StockSymbol(rawValue: symbol.uppercased()),
            currentPrice: StockPrice(value: message.price, updatedAt: message.timestamp)
        )
    }

    public func map(_ stock: Stock) -> StockPriceMessage {
        StockPriceMessage(
            symbol: stock.symbol.rawValue,
            price: stock.currentPrice.value,
            change: stock.priceChange,
            timestamp: stock.currentPrice.updatedAt
        )
    }
}

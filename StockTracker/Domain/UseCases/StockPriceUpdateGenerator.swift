import Foundation

public protocol StockPriceUpdateGenerating: Sendable {
    func generateUpdate(for stock: Stock, at date: Date) async -> Stock
}

public struct RandomStockPriceUpdateGenerator: StockPriceUpdateGenerating {
    public init() {}

    public func generateUpdate(for stock: Stock, at date: Date = .now) async -> Stock {
        let movementBasisPoints = Int.random(in: -50...50)
        let movement = Decimal(movementBasisPoints) / Decimal(10_000)
        var calculatedPrice = stock.currentPrice.value * (Decimal(1) + movement)
        var roundedPrice = Decimal()
        NSDecimalRound(&roundedPrice, &calculatedPrice, 2, .plain)
        let minimumPrice = Decimal(string: "0.01") ?? Decimal(1) / 100
        let updatedPrice = max(minimumPrice, roundedPrice)

        return Stock(
            symbol: stock.symbol,
            currentPrice: StockPrice(value: updatedPrice, updatedAt: date),
            previousPrice: stock.currentPrice,
            description: stock.description
        )
    }
}

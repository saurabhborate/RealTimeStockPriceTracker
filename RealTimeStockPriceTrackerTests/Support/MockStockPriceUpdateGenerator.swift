import Foundation
@testable import RealTimeStockPriceTracker

actor MockStockPriceUpdateGenerator: StockPriceUpdateGenerating {
    private let nextPrice: Decimal
    private var generatedContinuations: [UUID: AsyncStream<Stock>.Continuation] = [:]

    init(nextPrice: Decimal) {
        self.nextPrice = nextPrice
    }

    func generateUpdate(for stock: Stock, at date: Date) async -> Stock {
        let update = Stock(
            symbol: stock.symbol,
            currentPrice: StockPrice(value: nextPrice, updatedAt: date),
            previousPrice: stock.currentPrice,
            description: stock.description
        )
        for continuation in generatedContinuations.values { continuation.yield(update) }
        return update
    }

    func generatedUpdates() -> AsyncStream<Stock> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<Stock>.makeStream()
        generatedContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeGeneratedObserver(id) }
        }
        return stream
    }

    private func removeGeneratedObserver(_ id: UUID) {
        generatedContinuations[id] = nil
    }
}

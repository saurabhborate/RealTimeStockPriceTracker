import SwiftUI

public struct StockRowView: View {
    public let stock: Stock

    public init(stock: Stock) {
        self.stock = stock
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(stock.symbol.rawValue)
                    .font(.headline)
                PriceChangeIndicatorView(change: stock.priceChange)
            }
            Spacer()
            Text(StockPriceFormatting.price(stock.currentPrice.value))
                .font(.body.monospacedDigit().weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stock.symbol.rawValue), \(StockPriceFormatting.price(stock.currentPrice.value)), change \(StockPriceFormatting.change(stock.priceChange))")
    }
}

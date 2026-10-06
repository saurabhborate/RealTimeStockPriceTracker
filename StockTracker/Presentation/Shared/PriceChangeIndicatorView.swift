import SwiftUI

struct PriceChangeIndicatorView: View {
    let change: Decimal

    private var color: Color {
        if change > 0 { .green }
        else if change < 0 { .red }
        else { .secondary }
    }

    private var symbol: String {
        if change > 0 { "arrow.up.right" }
        else if change < 0 { "arrow.down.right" }
        else { "minus" }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(StockPriceFormatting.change(change))
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Price change \(StockPriceFormatting.change(change))")
    }
}

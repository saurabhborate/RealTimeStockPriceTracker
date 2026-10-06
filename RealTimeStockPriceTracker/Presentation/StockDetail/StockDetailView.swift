import SwiftUI

public struct StockDetailView: View {
    @State private var viewModel: StockDetailViewModel

    public init(viewModel: StockDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.stock.symbol.rawValue)
                    .font(.largeTitle.bold())
                Text(StockPriceFormatting.price(viewModel.stock.currentPrice.value))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                PriceChangeIndicatorView(change: viewModel.stock.priceChange)
            }

            Text(viewModel.description)
                .font(.body)
                .foregroundStyle(.secondary)

            ConnectionStatusView(state: viewModel.connectionState)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(errorMessage)")
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationTitle(viewModel.stock.symbol.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.startObserving() }
        .onDisappear { viewModel.stopObserving() }
    }
}

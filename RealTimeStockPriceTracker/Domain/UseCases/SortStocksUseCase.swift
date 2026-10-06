import Foundation

public enum StockSortingOption: String, CaseIterable, Sendable, Identifiable {
    case priceAscending
    case priceChangeDescending

    public var id: Self { self }

    public var title: String {
        switch self {
        case .priceAscending: "Price: Low to High"
        case .priceChangeDescending: "Price Change: High to Low"
        }
    }
}

public struct SortStocksUseCase: Sendable {
    public init() {}

    public func callAsFunction(
        _ stocks: [Stock],
        by option: StockSortingOption
    ) -> [Stock] {
        stocks.sorted { lhs, rhs in
            let lhsValue = sortValue(for: lhs, option: option)
            let rhsValue = sortValue(for: rhs, option: option)
            if lhsValue != rhsValue {
                return option == .priceAscending ? lhsValue < rhsValue : lhsValue > rhsValue
            }
            return lhs.symbol.rawValue < rhs.symbol.rawValue
        }
    }

    private func sortValue(for stock: Stock, option: StockSortingOption) -> Decimal {
        switch option {
        case .priceAscending: stock.currentPrice.value
        case .priceChangeDescending: stock.priceChange
        }
    }
}

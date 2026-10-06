import Foundation

enum StockPriceFormatting {
    static func price(_ value: Decimal) -> String {
        value.formatted(.currency(code: "USD"))
    }

    static func change(_ value: Decimal) -> String {
        if value == .zero { return price(value) }
        return value.formatted(.currency(code: "USD").sign(strategy: .always()))
    }
}

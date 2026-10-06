/// A symbol identifying a stock in the domain layer.
public struct StockSymbol: Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

import Foundation

/// A monetary value and the time at which it was observed.
public struct StockPrice: Equatable, Sendable {
    public let value: Decimal
    public let updatedAt: Date

    public init(value: Decimal, updatedAt: Date) {
        self.value = value
        self.updatedAt = updatedAt
    }
}

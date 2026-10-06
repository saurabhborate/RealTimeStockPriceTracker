import Foundation

public struct StockPrice: Equatable, Sendable {
    public let value: Decimal
    public let updatedAt: Date

    public init(value: Decimal, updatedAt: Date) {
        self.value = value
        self.updatedAt = updatedAt
    }
}

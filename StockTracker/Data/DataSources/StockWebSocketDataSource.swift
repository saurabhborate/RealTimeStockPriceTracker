import Foundation

public enum StockDataError: Error, LocalizedError, Sendable {
    case encodingFailed(underlying: any Error)
    case decodingFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "The stock message could not be encoded."
        case .decodingFailed: return "The stock message could not be decoded."
        }
    }
}

public actor StockWebSocketDataSource: StockDataSource {
    private let client: any WebSocketClient
    private let mapper: StockMessageMapper
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(client: any WebSocketClient, mapper: StockMessageMapper = StockMessageMapper()) {
        self.client = client
        self.mapper = mapper
    }

    public func connect() async throws {
        try await client.connect()
    }

    public func send(_ stock: Stock) async throws {
        let message = mapper.map(stock)
        let data: Data

        do {
            data = try encoder.encode(message)
        } catch {
            throw StockDataError.encodingFailed(underlying: error)
        }

        try await client.send(data)
    }

    public func priceUpdates() async -> AsyncThrowingStream<Stock, any Error> {
        let incomingMessages = await client.incomingMessages()
        let (updates, continuation) = AsyncThrowingStream<Stock, any Error>.makeStream()
        let task = Task { [self] in
            do {
                for try await data in incomingMessages {
                    try Task.checkCancellation()
                    continuation.yield(try decode(data))
                }
                continuation.finish()
            } catch is CancellationError {
                await client.disconnect()
                continuation.finish()
            } catch {
                await client.disconnect()
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return updates
    }

    public func disconnect() async {
        await client.disconnect()
    }

    private func decode(_ data: Data) throws -> Stock {
        let message: StockPriceMessage
        do {
            message = try decoder.decode(StockPriceMessage.self, from: data)
        } catch {
            throw StockDataError.decodingFailed(underlying: error)
        }

        return try mapper.map(message)
    }
}

import Foundation

public enum StockDataError: Error, LocalizedError, Sendable {
    case encodingFailed(underlying: any Error)
    case decodingFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: "The stock message could not be encoded."
        case .decodingFailed: "The stock message could not be decoded."
        }
    }
}

public actor StockWebSocketDataSource: StockDataSource {
    private let client: any WebSocketClient
    private let mapper: StockMessageMapper
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var connectionID: UUID?
    private var bridgeConnectionID: UUID?
    private var updateStream: AsyncThrowingStream<Stock, any Error>?
    private var updateContinuation: AsyncThrowingStream<Stock, any Error>.Continuation?
    private var bridgeTask: Task<Void, Never>?

    public init(client: any WebSocketClient, mapper: StockMessageMapper = StockMessageMapper()) {
        self.client = client
        self.mapper = mapper
    }

    public func connect() async throws {
        guard connectionID == nil else { return }
        let connectionID = UUID()
        self.connectionID = connectionID
        do {
            try await client.connect()
            guard self.connectionID == connectionID else { throw CancellationError() }
        } catch {
            if self.connectionID == connectionID { self.connectionID = nil }
            throw error
        }
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
        guard let connectionID else {
            return AsyncThrowingStream { $0.finish(throwing: WebSocketError.connectionClosed) }
        }
        if bridgeConnectionID == connectionID, let updateStream { return updateStream }

        let incomingMessages = await client.incomingMessages()
        let (updates, continuation) = AsyncThrowingStream<Stock, any Error>.makeStream()
        guard self.connectionID == connectionID else {
            continuation.finish(throwing: CancellationError())
            return updates
        }

        bridgeConnectionID = connectionID
        updateStream = updates
        updateContinuation = continuation
        let task = Task { [weak self] in
            do {
                for try await data in incomingMessages {
                    try Task.checkCancellation()
                    do {
                        guard let stock = try await self?.decode(data, connectionID: connectionID) else {
                            continuation.finish()
                            return
                        }
                        continuation.yield(stock)
                    } catch is StockDataError {
                        continue
                    } catch is StockMessageMapperError {
                        continue
                    }
                }
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                continuation.finish(throwing: WebSocketError.connectionClosed)
                await self?.disconnectAfterFailure(connectionID: connectionID)
            } catch is CancellationError {
                continuation.finish()
            } catch {
                await self?.disconnectAfterFailure(connectionID: connectionID)
                continuation.finish(throwing: error)
            }
        }
        bridgeTask = task
        continuation.onTermination = { [weak self] _ in
            task.cancel()
            Task { await self?.updateStreamTerminated(connectionID: connectionID) }
        }
        return updates
    }

    public func disconnect() async {
        connectionID = nil
        bridgeConnectionID = nil
        let bridgeTask = self.bridgeTask
        self.bridgeTask = nil
        updateContinuation?.finish()
        updateContinuation = nil
        updateStream = nil
        bridgeTask?.cancel()
        await client.disconnect()
        await bridgeTask?.value
    }

    private func decode(_ data: Data, connectionID: UUID) throws -> Stock? {
        guard self.connectionID == connectionID else { return nil }
        let message: StockPriceMessage
        do {
            message = try decoder.decode(StockPriceMessage.self, from: data)
        } catch {
            throw StockDataError.decodingFailed(underlying: error)
        }

        return try mapper.map(message)
    }

    private func disconnectAfterFailure(connectionID: UUID) async {
        guard self.connectionID == connectionID else { return }
        self.connectionID = nil
        bridgeConnectionID = nil
        bridgeTask = nil
        updateContinuation = nil
        updateStream = nil
        await client.disconnect()
    }

    private func updateStreamTerminated(connectionID: UUID) async {
        guard self.connectionID == connectionID else { return }
        self.connectionID = nil
        bridgeConnectionID = nil
        let bridgeTask = self.bridgeTask
        self.bridgeTask = nil
        updateContinuation = nil
        updateStream = nil
        bridgeTask?.cancel()
        await client.disconnect()
    }
}

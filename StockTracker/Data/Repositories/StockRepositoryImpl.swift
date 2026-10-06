import Foundation

public actor StockRepositoryImpl: StockRepository {
    private let dataSource: any StockDataSource
    private var state: ConnectionState = .disconnected
    private var stateObservers: [UUID: AsyncStream<ConnectionState>.Continuation] = [:]
    private var updateObservers: [UUID: AsyncThrowingStream<Stock, any Error>.Continuation] = [:]
    private var updateTask: Task<Void, Never>?
    private var isStartingUpdates = false
    private var isDisconnecting = false
    private var lifecycleID = UUID()

    public init(dataSource: any StockDataSource) {
        self.dataSource = dataSource
    }

    public func connect() async throws {
        guard !isDisconnecting else { throw StockRepositoryError.connectionFailed }
        guard state != .connected, state != .connecting else { return }
        let lifecycleID = UUID()
        self.lifecycleID = lifecycleID
        setState(.connecting)

        do {
            try await dataSource.connect()
            try Task.checkCancellation()
            guard self.lifecycleID == lifecycleID else { throw CancellationError() }
            setState(.connected)
        } catch is CancellationError {
            guard self.lifecycleID == lifecycleID else { throw CancellationError() }
            setState(.disconnected)
            throw CancellationError()
        } catch {
            guard self.lifecycleID == lifecycleID else { throw CancellationError() }
            setState(.failed)
            throw StockRepositoryError.connectionFailed
        }
    }

    public func send(_ stock: Stock) async throws {
        guard state == .connected, !isDisconnecting else {
            throw StockRepositoryError.sendFailed
        }

        do {
            try await dataSource.send(stock)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw StockRepositoryError.sendFailed
        }
    }

    public func priceUpdates() async -> AsyncThrowingStream<Stock, any Error> {
        let (stream, continuation) = AsyncThrowingStream<Stock, any Error>.makeStream()
        guard state == .connected, !isDisconnecting else {
            continuation.finish(throwing: StockRepositoryError.connectionFailed)
            return stream
        }

        let id = UUID()
        updateObservers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeUpdateObserver(id) }
        }

        guard !isStartingUpdates, updateTask == nil else { return stream }
        isStartingUpdates = true
        let lifecycleID = self.lifecycleID
        let sourceUpdates = await dataSource.priceUpdates()
        guard self.lifecycleID == lifecycleID, state == .connected, !isDisconnecting else {
            continuation.finish(throwing: StockRepositoryError.connectionFailed)
            return stream
        }
        isStartingUpdates = false

        guard !updateObservers.isEmpty else { return stream }
        updateTask = Task { [weak self] in
            await self?.forwardUpdates(from: sourceUpdates)
        }
        return stream
    }

    public func connectionStates() async -> AsyncStream<ConnectionState> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ConnectionState>.makeStream()
        stateObservers[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStateObserver(id) }
        }
        return stream
    }

    public func disconnect() async {
        guard !isDisconnecting else { return }
        isDisconnecting = true
        let lifecycleID = UUID()
        self.lifecycleID = lifecycleID
        updateTask?.cancel()
        updateTask = nil
        isStartingUpdates = false
        finishUpdateObservers()
        await dataSource.disconnect()
        guard self.lifecycleID == lifecycleID else { return }
        isDisconnecting = false
        setState(.disconnected)
    }

    private func forwardUpdates(from updates: AsyncThrowingStream<Stock, any Error>) async {
        do {
            for try await stock in updates {
                try Task.checkCancellation()
                for observer in updateObservers.values {
                    observer.yield(stock)
                }
            }

            guard !Task.isCancelled else { return }
            updateTask = nil
            finishUpdateObservers()
            setState(.disconnected)
        } catch is CancellationError {
            guard !Task.isCancelled else { return }
            updateTask = nil
            finishUpdateObservers()
            setState(.disconnected)
        } catch {
            guard !Task.isCancelled else { return }
            updateTask = nil
            finishUpdateObservers(throwing: StockRepositoryError.updatesFailed)
            setState(.failed)
        }
    }

    private func setState(_ newState: ConnectionState) {
        guard state != newState else { return }
        state = newState
        for observer in stateObservers.values {
            observer.yield(newState)
        }
    }

    private func finishUpdateObservers(throwing error: (any Error)? = nil) {
        for observer in updateObservers.values {
            if let error {
                observer.finish(throwing: error)
            } else {
                observer.finish()
            }
        }
        updateObservers.removeAll()
    }

    private func removeUpdateObserver(_ id: UUID) {
        updateObservers[id] = nil
    }

    private func removeStateObserver(_ id: UUID) {
        stateObservers[id] = nil
    }
}

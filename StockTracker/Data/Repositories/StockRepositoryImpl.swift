import Foundation

public actor StockRepositoryImpl: StockRepository {
    private let dataSource: any StockDataSource
    private let priceUpdateGenerator: any StockPriceUpdateGenerating
    private let updateInterval: Duration?
    private let stockOrder: [StockSymbol]
    private var stocksBySymbol: [StockSymbol: Stock]
    private var state: ConnectionState = .disconnected
    private var stateObservers: [UUID: AsyncStream<ConnectionState>.Continuation] = [:]
    private var stockObservers: [UUID: AsyncStream<[Stock]>.Continuation] = [:]
    private var receiveTask: Task<Void, Never>?
    private var feedTask: Task<Void, Never>?
    private var isDisconnecting = false
    private var lifecycleID = UUID()

    public init(
        dataSource: any StockDataSource,
        initialStocks: [Stock] = StockCatalog.initialStocks,
        priceUpdateGenerator: any StockPriceUpdateGenerating = RandomStockPriceUpdateGenerator(),
        updateInterval: Duration? = .seconds(1)
    ) {
        self.dataSource = dataSource
        self.priceUpdateGenerator = priceUpdateGenerator
        self.updateInterval = updateInterval

        var orderedSymbols: [StockSymbol] = []
        var stocksBySymbol: [StockSymbol: Stock] = [:]
        for stock in initialStocks where stocksBySymbol[stock.symbol] == nil {
            orderedSymbols.append(stock.symbol)
            stocksBySymbol[stock.symbol] = stock
        }
        self.stockOrder = orderedSymbols
        self.stocksBySymbol = stocksBySymbol
    }

    public func connect() async throws {
        guard !isDisconnecting else { throw StockRepositoryError.connectionFailed }
        guard state != .connected, state != .connecting else { return }

        let connectionID = UUID()
        lifecycleID = connectionID
        setState(.connecting)

        do {
            try await dataSource.connect()
            try Task.checkCancellation()
            guard lifecycleID == connectionID, !isDisconnecting else { throw CancellationError() }

            let incomingUpdates = await dataSource.priceUpdates()
            try Task.checkCancellation()
            guard lifecycleID == connectionID, !isDisconnecting else { throw CancellationError() }

            receiveTask = Task { [weak self] in
                do {
                    for try await update in incomingUpdates {
                        try Task.checkCancellation()
                        guard let self else { return }
                        guard let wasApplied = await self.apply(update, connectionID: connectionID) else { return }
                        guard wasApplied else {
                            await self.failConnection(connectionID: connectionID)
                            return
                        }
                    }
                    guard !Task.isCancelled else { return }
                    await self?.failConnection(connectionID: connectionID)
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    await self?.failConnection(connectionID: connectionID)
                }
            }
            setState(.connected)
            startPriceFeed(connectionID: connectionID)
        } catch is CancellationError {
            guard lifecycleID == connectionID else { throw CancellationError() }
            await dataSource.disconnect()
            setState(.disconnected)
            throw CancellationError()
        } catch {
            guard lifecycleID == connectionID else { throw CancellationError() }
            await dataSource.disconnect()
            guard lifecycleID == connectionID, !isDisconnecting else { throw CancellationError() }
            setState(.failed)
            throw StockRepositoryError.connectionFailed
        }
    }

    public func send(_ stock: Stock) async throws {
        guard state == .connected, !isDisconnecting else {
            throw StockRepositoryError.sendFailed
        }
        guard stocksBySymbol[stock.symbol] != nil else {
            throw StockRepositoryError.unknownStock
        }
        guard stock.currentPrice.value > .zero else {
            throw StockRepositoryError.invalidPrice
        }

        let connectionID = lifecycleID
        do {
            try await dataSource.send(stock)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if lifecycleID == connectionID, !isDisconnecting {
                await failConnection(connectionID: connectionID)
            }
            throw StockRepositoryError.sendFailed
        }
    }

    public func currentStocks() -> [Stock] {
        stockOrder.compactMap { stocksBySymbol[$0] }
    }

    public func stocks() -> AsyncStream<[Stock]> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<[Stock]>.makeStream(bufferingPolicy: .bufferingNewest(1))
        stockObservers[id] = continuation
        continuation.yield(currentStocks())
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeStockObserver(id) }
        }
        return stream
    }

    public func connectionStates() -> AsyncStream<ConnectionState> {
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
        guard state != .disconnected || receiveTask != nil || feedTask != nil else { return }

        isDisconnecting = true
        lifecycleID = UUID()
        let receiveTask = self.receiveTask
        let feedTask = self.feedTask
        self.receiveTask = nil
        self.feedTask = nil
        receiveTask?.cancel()
        feedTask?.cancel()

        await dataSource.disconnect()
        await receiveTask?.value
        await feedTask?.value
        isDisconnecting = false
        setState(.disconnected)
    }

    private func startPriceFeed(connectionID: UUID) {
        guard feedTask == nil, let interval = updateInterval else { return }
        feedTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let shouldContinue = await self?.sendGeneratedUpdate(connectionID: connectionID),
                      shouldContinue
                else { return }
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    return
                }
            }
        }
    }

    private func sendGeneratedUpdate(connectionID: UUID) async -> Bool {
        guard lifecycleID == connectionID, state == .connected, !isDisconnecting,
              let sourceStock = currentStocks().randomElement()
        else { return false }

        let update = await priceUpdateGenerator.generateUpdate(for: sourceStock, at: .now)
        guard lifecycleID == connectionID, state == .connected, !isDisconnecting, !Task.isCancelled else {
            return false
        }
        do {
            try await send(update)
            return lifecycleID == connectionID && !Task.isCancelled
        } catch {
            guard lifecycleID == connectionID, !Task.isCancelled else { return false }
            await failConnection(connectionID: connectionID)
            return false
        }
    }

    private func apply(_ update: Stock, connectionID: UUID) -> Bool? {
        guard lifecycleID == connectionID else { return nil }
        guard let previous = stocksBySymbol[update.symbol], update.currentPrice.value > .zero else {
            return false
        }

        stocksBySymbol[update.symbol] = Stock(
            symbol: update.symbol,
            currentPrice: update.currentPrice,
            previousPrice: previous.currentPrice,
            description: previous.description
        )
        publishStocks()
        return true
    }

    private func failConnection(connectionID: UUID) async {
        guard lifecycleID == connectionID, !isDisconnecting else { return }
        lifecycleID = UUID()
        isDisconnecting = true
        let receiveTask = self.receiveTask
        let feedTask = self.feedTask
        self.receiveTask = nil
        self.feedTask = nil
        receiveTask?.cancel()
        feedTask?.cancel()
        setState(.failed)
        await dataSource.disconnect()
        isDisconnecting = false
    }

    private func publishStocks() {
        let snapshot = currentStocks()
        for observer in stockObservers.values {
            observer.yield(snapshot)
        }
    }

    private func setState(_ newState: ConnectionState) {
        guard state != newState else { return }
        state = newState
        for observer in stateObservers.values {
            observer.yield(newState)
        }
    }

    private func removeStockObserver(_ id: UUID) {
        stockObservers[id] = nil
    }

    private func removeStateObserver(_ id: UUID) {
        stateObservers[id] = nil
    }
}

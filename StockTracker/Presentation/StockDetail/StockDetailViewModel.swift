import Observation

@MainActor
@Observable
public final class StockDetailViewModel {
    public private(set) var stock: Stock
    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var errorMessage: String?
    public private(set) var isFeedActionInProgress = false

    @ObservationIgnored private let observeStocks: ObserveStocksUseCase
    @ObservationIgnored private let observeConnection: ObserveConnectionStateUseCase
    @ObservationIgnored private let startFeed: StartStockFeedUseCase
    @ObservationIgnored private let stopFeed: StopStockFeedUseCase
    @ObservationIgnored private var stocksTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var feedActionTask: Task<Void, Never>?

    public var feedIsActive: Bool {
        connectionState == .connecting || connectionState == .connected
    }

    public var description: String {
        stock.description ?? "No company description available."
    }

    public init(
        stock: Stock,
        observeStocks: ObserveStocksUseCase,
        observeConnection: ObserveConnectionStateUseCase,
        startFeed: StartStockFeedUseCase,
        stopFeed: StopStockFeedUseCase
    ) {
        self.stock = stock
        self.observeStocks = observeStocks
        self.observeConnection = observeConnection
        self.startFeed = startFeed
        self.stopFeed = stopFeed
    }

    deinit {
        stocksTask?.cancel()
        connectionTask?.cancel()
        feedActionTask?.cancel()
    }

    public func startObserving() {
        guard stocksTask == nil, connectionTask == nil else { return }

        let observeStocks = self.observeStocks
        let selectedSymbol = stock.symbol
        stocksTask = Task { [weak self] in
            let snapshots = await observeStocks()
            for await stocks in snapshots {
                guard !Task.isCancelled else { return }
                if let updatedStock = stocks.first(where: { $0.symbol == selectedSymbol }) {
                    self?.stock = updatedStock
                }
            }
            self?.stocksTask = nil
        }

        let observeConnection = self.observeConnection
        connectionTask = Task { [weak self] in
            let states = await observeConnection()
            for await state in states {
                guard !Task.isCancelled else { return }
                self?.connectionState = state
                switch state {
                case .failed:
                    self?.errorMessage = "The stock feed stopped unexpectedly. Try starting it again."
                case .connected:
                    self?.errorMessage = nil
                case .disconnected, .connecting:
                    break
                }
            }
            self?.connectionTask = nil
        }
    }

    public func stopObserving() {
        stocksTask?.cancel()
        connectionTask?.cancel()
        feedActionTask?.cancel()
        stocksTask = nil
        connectionTask = nil
        feedActionTask = nil
        isFeedActionInProgress = false
    }

    public func toggleFeed() {
        guard feedActionTask == nil else { return }
        isFeedActionInProgress = true
        feedActionTask = Task { [weak self] in
            guard let self else { return }
            if feedIsActive {
                await stopFeedAction()
            } else {
                await startFeedAction()
            }
            isFeedActionInProgress = false
            feedActionTask = nil
        }
    }

    public func startFeedAction() async {
        errorMessage = nil
        do {
            try await startFeed()
        } catch is CancellationError {
            return
        } catch StockRepositoryError.connectionFailed {
            errorMessage = "The stock feed could not connect. Check your connection and try again."
        } catch {
            errorMessage = "The stock feed could not be started."
        }
    }

    public func stopFeedAction() async {
        errorMessage = nil
        await stopFeed()
    }
}

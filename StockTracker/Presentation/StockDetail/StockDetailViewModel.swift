import Observation

@MainActor
@Observable
public final class StockDetailViewModel {
    public private(set) var stock: Stock
    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var errorMessage: String?

    @ObservationIgnored private let observeUpdates: ObserveStockUpdatesUseCase
    @ObservationIgnored private let observeConnection: ObserveConnectionStateUseCase
    @ObservationIgnored private let startFeed: StartStockFeedUseCase
    @ObservationIgnored private let stopFeed: StopStockFeedUseCase
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?

    public var feedIsActive: Bool {
        connectionState == .connecting || connectionState == .connected
    }

    public init(
        stock: Stock,
        observeUpdates: ObserveStockUpdatesUseCase,
        observeConnection: ObserveConnectionStateUseCase,
        startFeed: StartStockFeedUseCase,
        stopFeed: StopStockFeedUseCase
    ) {
        self.stock = stock
        self.observeUpdates = observeUpdates
        self.observeConnection = observeConnection
        self.startFeed = startFeed
        self.stopFeed = stopFeed
    }

    public var description: String {
        stock.description ?? "No company description available."
    }

    public func startObserving() {
        guard connectionTask == nil else { return }
        let observeConnection = self.observeConnection
        connectionTask = Task { [weak self] in
            let stream = await observeConnection()
            for await state in stream {
                guard !Task.isCancelled else { return }
                self?.connectionState = state
                if state == .connected {
                    self?.startPriceUpdates()
                } else {
                    self?.updatesTask?.cancel()
                    self?.updatesTask = nil
                }
            }
            self?.connectionTask = nil
        }
    }

    public func stopObserving() {
        updatesTask?.cancel()
        connectionTask?.cancel()
        updatesTask = nil
        connectionTask = nil
    }

    public func startFeedAction() async {
        errorMessage = nil
        do {
            try await startFeed()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "The stock feed could not be started."
        }
    }

    public func stopFeedAction() async {
        errorMessage = nil
        await stopFeed()
    }

    private func startPriceUpdates() {
        guard updatesTask == nil else { return }
        let observeUpdates = self.observeUpdates
        let selectedSymbol = stock.symbol
        updatesTask = Task { [weak self] in
            let stream = await observeUpdates()
            do {
                for try await updatedStock in stream {
                    guard !Task.isCancelled else { return }
                    if updatedStock.symbol == selectedSymbol { self?.stock = updatedStock }
                }
            } catch is CancellationError {
                return
            } catch {
                self?.errorMessage = "Stock updates could not be loaded."
            }
            self?.updatesTask = nil
        }
    }
}

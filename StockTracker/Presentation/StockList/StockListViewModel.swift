import Observation

@MainActor
@Observable
public final class StockListViewModel {
    public private(set) var stocks: [Stock] = []
    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var errorMessage: String?
    public var sortingOption: StockSortingOption = .priceAscending

    @ObservationIgnored private let observeStocks: ObserveStocksUseCase
    @ObservationIgnored private let observeConnection: ObserveConnectionStateUseCase
    @ObservationIgnored private let sortStocks: SortStocksUseCase
    @ObservationIgnored private var stocksTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?

    public var sortedStocks: [Stock] {
        sortStocks(stocks, by: sortingOption)
    }

    public init(
        observeStocks: ObserveStocksUseCase,
        observeConnection: ObserveConnectionStateUseCase,
        sortStocks: SortStocksUseCase
    ) {
        self.observeStocks = observeStocks
        self.observeConnection = observeConnection
        self.sortStocks = sortStocks
    }

    deinit {
        stocksTask?.cancel()
        connectionTask?.cancel()
    }

    public func startObserving() {
        guard stocksTask == nil, connectionTask == nil else { return }

        let observeStocks = self.observeStocks
        stocksTask = Task { [weak self] in
            let snapshots = await observeStocks()
            for await stocks in snapshots {
                guard !Task.isCancelled else { return }
                self?.stocks = stocks
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
        stocksTask = nil
        connectionTask = nil
    }

    public func selectSortingOption(_ option: StockSortingOption) {
        sortingOption = option
    }
}

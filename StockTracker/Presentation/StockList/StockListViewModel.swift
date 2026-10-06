import Observation

@MainActor
@Observable
public final class StockListViewModel {
    public private(set) var stocks: [Stock] = []
    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var errorMessage: String?
    public var sortingOption: StockSortingOption = .priceAscending

    @ObservationIgnored private let observeUpdates: ObserveStockUpdatesUseCase
    @ObservationIgnored private let observeConnection: ObserveConnectionStateUseCase
    @ObservationIgnored private let sortStocks: SortStocksUseCase
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?

    public var sortedStocks: [Stock] {
        sortStocks(stocks, by: sortingOption)
    }

    public init(
        observeUpdates: ObserveStockUpdatesUseCase,
        observeConnection: ObserveConnectionStateUseCase,
        sortStocks: SortStocksUseCase
    ) {
        self.observeUpdates = observeUpdates
        self.observeConnection = observeConnection
        self.sortStocks = sortStocks
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

    public func selectSortingOption(_ option: StockSortingOption) {
        sortingOption = option
    }

    func receive(_ stock: Stock) {
        if let index = stocks.firstIndex(where: { $0.symbol == stock.symbol }) {
            stocks[index] = stock
        } else {
            stocks.append(stock)
        }
    }

    private func startPriceUpdates() {
        guard updatesTask == nil else { return }
        let observeUpdates = self.observeUpdates
        updatesTask = Task { [weak self] in
            let stream = await observeUpdates()
            do {
                for try await stock in stream {
                    guard !Task.isCancelled else { return }
                    self?.receive(stock)
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

import Observation

@MainActor
@Observable
public final class StockDetailViewModel {
    public private(set) var stock: Stock
    public private(set) var connectionState: ConnectionState = .disconnected
    public private(set) var errorMessage: String?

    @ObservationIgnored private let observeStocks: ObserveStocksUseCase
    @ObservationIgnored private let observeConnection: ObserveConnectionStateUseCase
    @ObservationIgnored private var stocksTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?

    public var description: String {
        stock.description ?? "No company description available."
    }

    public init(
        stock: Stock,
        observeStocks: ObserveStocksUseCase,
        observeConnection: ObserveConnectionStateUseCase
    ) {
        self.stock = stock
        self.observeStocks = observeStocks
        self.observeConnection = observeConnection
    }

    deinit {
        stocksTask?.cancel()
        connectionTask?.cancel()
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
                    self?.errorMessage = "The stock feed stopped unexpectedly."
                case .connecting, .connected:
                    self?.errorMessage = nil
                case .disconnected:
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
}

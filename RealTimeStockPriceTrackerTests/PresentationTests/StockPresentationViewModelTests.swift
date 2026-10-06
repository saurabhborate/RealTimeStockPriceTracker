import Foundation
import XCTest
@testable import RealTimeStockPriceTracker

@MainActor
final class StockPresentationViewModelTests: XCTestCase {
    func testSortStocksUsesSelectedOptionAndStableSymbolTieBreak() {
        let sort = SortStocksUseCase()
        let stocks = [stock("ZZZ", current: 12, previous: 10), stock("AAA", current: 12, previous: 10), stock("BBB", current: 9, previous: 8)]

        XCTAssertEqual(sort(stocks, by: .priceAscending).map(\.symbol.rawValue), ["BBB", "AAA", "ZZZ"])
        XCTAssertEqual(sort(stocks, by: .priceChangeDescending).map(\.symbol.rawValue), ["AAA", "ZZZ", "BBB"])
    }

    func testStockListViewModelReceivesUpdatesAndChangesSorting() async {
        let repository = MockStockRepository()
        let viewModel = AppContainer(stockRepository: repository).makeStockListViewModel()
        viewModel.startObserving()
        let loadedCatalog = await waitUntil { viewModel.stocks.count == 25 }
        let isObservingStocks = await waitUntil { await repository.activeStockObserverCount() == 1 }
        XCTAssertTrue(loadedCatalog)
        XCTAssertTrue(isObservingStocks)

        let apple = stock("AAPL", current: 230, previous: 225)
        let amd = stock("AMD", current: 122, previous: 120)
        await repository.publish(apple)
        await repository.publish(amd)
        let receivedStocks = await waitUntil {
            viewModel.stocks.first(where: { $0.symbol.rawValue == "AMD" })?.currentPrice.value == 122
        }
        XCTAssertTrue(receivedStocks)
        XCTAssertEqual(viewModel.stocks.count, 25)

        viewModel.selectSortingOption(.priceChangeDescending)
        XCTAssertEqual(
            Array(viewModel.sortedStocks.prefix(2).map(\.symbol.rawValue)),
            ["AAPL", "AMD"]
        )
        viewModel.stopObserving()
    }

    func testDetailViewModelObservesSelectedStockAndReflectsConnectionState() async {
        let repository = MockStockRepository()
        let container = AppContainer(stockRepository: repository)
        let selected = stock("AAPL", current: 180, previous: 178)
        let viewModel = container.makeStockDetailViewModel(for: selected)
        viewModel.startObserving()
        let selectedStockLoaded = await waitUntil { viewModel.stock.currentPrice.value == 225 }
        let isObservingStocks = await waitUntil { await repository.activeStockObserverCount() == 1 }
        XCTAssertTrue(selectedStockLoaded)
        XCTAssertTrue(isObservingStocks)

        let update = stock("AAPL", current: 182, previous: 180)
        await repository.publish(update)
        let receivedUpdate = await waitUntil { viewModel.stock.currentPrice == update.currentPrice }
        XCTAssertTrue(receivedUpdate)

        XCTAssertEqual(viewModel.stock.symbol, selected.symbol)
        XCTAssertEqual(viewModel.stock.currentPrice, update.currentPrice)
        XCTAssertEqual(viewModel.stock.priceChange, Decimal(182) - Decimal(225))
        viewModel.stopObserving()
    }

    func testListAndDetailReceiveTheSameRepositoryPriceSnapshot() async {
        let repository = MockStockRepository()
        let container = AppContainer(stockRepository: repository)
        let listViewModel = container.makeStockListViewModel()
        let detailViewModel = container.makeStockDetailViewModel(for: StockCatalog.initialStocks[0])
        listViewModel.startObserving()
        detailViewModel.startObserving()
        let bothObserving = await waitUntil { await repository.activeStockObserverCount() == 2 }
        XCTAssertTrue(bothObserving)

        let update = stock("AAPL", current: 231, previous: 225)
        await repository.publish(update)
        let bothUpdated = await waitUntil {
            listViewModel.stocks.first(where: { $0.symbol == update.symbol })?.currentPrice == update.currentPrice
                && detailViewModel.stock.currentPrice == update.currentPrice
        }
        XCTAssertTrue(bothUpdated)
        XCTAssertEqual(
            listViewModel.stocks.first(where: { $0.symbol == update.symbol })?.priceChange,
            detailViewModel.stock.priceChange
        )

        listViewModel.stopObserving()
        detailViewModel.stopObserving()
    }

    func testAppContainerStartsStopsAndRestartsTheSharedFeed() async throws {
        let repository = MockStockRepository()
        let container = AppContainer(stockRepository: repository)

        try await container.startStockFeed()
        let initialConnectionState = await repository.currentConnectionState()
        XCTAssertEqual(initialConnectionState, .connected)

        await container.stopStockFeed()
        let stoppedConnectionState = await repository.currentConnectionState()
        XCTAssertEqual(stoppedConnectionState, .disconnected)

        try await container.startStockFeed()

        let connectionCount = await repository.countConnections()
        let connectionState = await repository.currentConnectionState()
        let disconnectionCount = await repository.countDisconnections()
        XCTAssertEqual(connectionCount, 2)
        XCTAssertEqual(disconnectionCount, 1)
        XCTAssertEqual(connectionState, .connected)
    }

    func testAppContainerPropagatesStartupFailure() async {
        let repository = MockStockRepository(connectionError: .connectionFailed)
        let container = AppContainer(stockRepository: repository)

        do {
            try await container.startStockFeed()
            XCTFail("Expected the feed startup failure to propagate.")
        } catch StockRepositoryError.connectionFailed {
            let connectionState = await repository.currentConnectionState()
            XCTAssertEqual(connectionState, .failed)
        } catch {
            XCTFail("Unexpected startup error: \(error)")
        }
    }

    func testDetailViewModelSurfacesRepositoryFailure() async {
        let repository = MockStockRepository()
        let viewModel = AppContainer(stockRepository: repository).makeStockDetailViewModel(
            for: StockCatalog.initialStocks[0]
        )
        viewModel.startObserving()
        await repository.publishConnectionState(.failed)

        let failed = await waitUntil { viewModel.connectionState == .failed }

        XCTAssertTrue(failed)
        XCTAssertNotNil(viewModel.errorMessage)
        await repository.publishConnectionState(.connecting)
        let errorClearedForRetry = await waitUntil { viewModel.errorMessage == nil }
        XCTAssertTrue(errorClearedForRetry)
        viewModel.stopObserving()
    }

    func testStoppingObservationCancelsFurtherStockUpdates() async {
        let repository = MockStockRepository()
        let viewModel = AppContainer(stockRepository: repository).makeStockListViewModel()
        viewModel.startObserving()
        let loadedCatalog = await waitUntil { viewModel.stocks.count == 25 }
        let isObservingStocks = await waitUntil { await repository.activeStockObserverCount() == 1 }
        XCTAssertTrue(loadedCatalog)
        XCTAssertTrue(isObservingStocks)
        await repository.publish(stock("AAPL", current: 230, previous: 225))
        let receivedStock = await waitUntil {
            viewModel.stocks.first(where: { $0.symbol.rawValue == "AAPL" })?.currentPrice.value == 230
        }
        XCTAssertTrue(receivedStock)
        viewModel.stopObserving()
        let observationStopped = await waitUntil { await repository.activeStockObserverCount() == 0 }
        XCTAssertTrue(observationStopped)

        await repository.publish(stock("AMD", current: 105, previous: 100))
        XCTAssertEqual(viewModel.stocks.first(where: { $0.symbol.rawValue == "AMD" })?.currentPrice.value, 120)
    }

    private func stock(_ symbol: String, current: Decimal, previous: Decimal) -> Stock {
        Stock(
            symbol: StockSymbol(rawValue: symbol),
            currentPrice: StockPrice(value: current, updatedAt: Date(timeIntervalSince1970: 2)),
            previousPrice: StockPrice(value: previous, updatedAt: Date(timeIntervalSince1970: 1))
        )
    }

    private func waitUntil(
        iterations: Int = 1_000,
        condition: @MainActor () async -> Bool
    ) async -> Bool {
        for _ in 0..<iterations {
            if await condition() { return true }
            await Task.yield()
        }
        return false
    }
}

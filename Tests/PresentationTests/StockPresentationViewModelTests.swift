import Foundation
import XCTest
@testable import StockTracker

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
        await repository.connect()
        let isConnected = await waitUntil { viewModel.connectionState == .connected }
        let isObservingStocks = await waitUntil { await repository.activeStockObserverCount() == 1 }
        XCTAssertTrue(isConnected)
        XCTAssertTrue(isObservingStocks)

        let apple = stock("AAPL", current: 180, previous: 175)
        let amd = stock("AMD", current: 100, previous: 99)
        await repository.publish(apple)
        await repository.publish(amd)
        let receivedStocks = await waitUntil { viewModel.stocks.count == 2 }
        XCTAssertTrue(receivedStocks)

        viewModel.selectSortingOption(.priceChangeDescending)
        XCTAssertEqual(viewModel.sortedStocks.map(\.symbol.rawValue), ["AAPL", "AMD"])
        viewModel.stopObserving()
    }

    func testDetailViewModelObservesSelectedStockAndReflectsConnectionState() async {
        let repository = MockStockRepository()
        let container = AppContainer(stockRepository: repository)
        let selected = stock("AAPL", current: 180, previous: 178)
        let viewModel = container.makeStockDetailViewModel(for: selected)
        viewModel.startObserving()
        await repository.connect()
        let isConnected = await waitUntil { viewModel.connectionState == .connected }
        let isObservingStocks = await waitUntil { await repository.activeStockObserverCount() == 1 }
        XCTAssertTrue(isConnected)
        XCTAssertTrue(isObservingStocks)

        let update = stock("AAPL", current: 182, previous: 180)
        await repository.publish(update)
        let receivedUpdate = await waitUntil { viewModel.stock.currentPrice == update.currentPrice }
        XCTAssertTrue(receivedUpdate)

        XCTAssertEqual(viewModel.stock.symbol, selected.symbol)
        XCTAssertEqual(viewModel.stock.currentPrice, update.currentPrice)
        XCTAssertEqual(viewModel.connectionState, .connected)
        viewModel.stopObserving()
    }

    func testDetailViewModelStartAndStopActionsCallRepository() async {
        let repository = MockStockRepository()
        let viewModel = AppContainer(stockRepository: repository).makeStockDetailViewModel(
            for: stock("AAPL", current: 180, previous: 179)
        )

        await viewModel.startFeedAction()
        await viewModel.stopFeedAction()

        let connectCount = await repository.connectCount
        let disconnectCount = await repository.disconnectCount
        XCTAssertEqual(connectCount, 1)
        XCTAssertEqual(disconnectCount, 1)
    }

    func testStoppingObservationCancelsFurtherStockUpdates() async {
        let repository = MockStockRepository()
        let viewModel = AppContainer(stockRepository: repository).makeStockListViewModel()
        viewModel.startObserving()
        await repository.connect()
        let isConnected = await waitUntil { viewModel.connectionState == .connected }
        let isObservingStocks = await waitUntil { await repository.activeStockObserverCount() == 1 }
        XCTAssertTrue(isConnected)
        XCTAssertTrue(isObservingStocks)
        await repository.publish(stock("AAPL", current: 180, previous: 179))
        let receivedStock = await waitUntil { viewModel.stocks.count == 1 }
        XCTAssertTrue(receivedStock)
        viewModel.stopObserving()
        let observationStopped = await waitUntil { await repository.activeStockObserverCount() == 0 }
        XCTAssertTrue(observationStopped)

        await repository.publish(stock("AMD", current: 100, previous: 99))
        XCTAssertEqual(viewModel.stocks.count, 1)
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

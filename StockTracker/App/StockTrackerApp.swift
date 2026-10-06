import SwiftUI

@MainActor
public struct StockTrackerApp: App {
    private let container: AppContainer
    @State private var listViewModel: StockListViewModel

    public init(container: AppContainer) {
        self.container = container
        _listViewModel = State(initialValue: container.makeStockListViewModel())
    }

    public var body: some Scene {
        WindowGroup {
            StockListView(
                viewModel: listViewModel,
                makeDetailViewModel: { container.makeStockDetailViewModel(for: $0) }
            )
        }
    }
}

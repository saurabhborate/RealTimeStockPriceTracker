import SwiftUI

#if !SWIFT_PACKAGE
@main
#endif
@MainActor
public struct StockTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: AppContainer?
    @State private var listViewModel: StockListViewModel?

    public init() {
        do {
            let container = try AppContainer()
            self.container = container
            _listViewModel = State(initialValue: container.makeStockListViewModel())
        } catch {
            self.container = nil
            _listViewModel = State(initialValue: nil)
        }
    }

    public init(container: AppContainer) {
        self.container = container
        _listViewModel = State(initialValue: container.makeStockListViewModel())
    }

    public var body: some Scene {
        WindowGroup {
            Group {
                if let container, let listViewModel {
                    StockListView(
                        viewModel: listViewModel,
                        makeDetailViewModel: { container.makeStockDetailViewModel(for: $0) }
                    )
                } else {
                    ContentUnavailableView(
                        "Stock Tracker Could Not Start",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The application could not configure its stock feed.")
                    )
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active, let container else { return }
                Task { await container.stopStockFeed() }
            }
        }
    }
}

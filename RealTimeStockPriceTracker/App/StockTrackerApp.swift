import SwiftUI

@main
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
            .task(id: scenePhase) {
                guard let container else { return }
                guard scenePhase == .active else {
                    await container.stopStockFeed()
                    return
                }
                try? await container.startStockFeed()
            }
        }
    }
}

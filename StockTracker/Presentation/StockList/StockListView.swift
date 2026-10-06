import SwiftUI

public struct StockListView: View {
    @State private var viewModel: StockListViewModel
    private let makeDetailViewModel: @MainActor (Stock) -> StockDetailViewModel

    public init(
        viewModel: StockListViewModel,
        makeDetailViewModel: @escaping @MainActor (Stock) -> StockDetailViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeDetailViewModel = makeDetailViewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.sortedStocks.isEmpty {
                    ContentUnavailableView(
                        "No stock updates",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Stock prices will appear when the feed provides updates.")
                    )
                } else {
                    List(viewModel.sortedStocks) { stock in
                        NavigationLink {
                            StockDetailView(viewModel: makeDetailViewModel(stock))
                        } label: {
                            StockRowView(stock: stock)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Stocks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(StockSortingOption.allCases) { option in
                            Button {
                                viewModel.selectSortingOption(option)
                            } label: {
                                if viewModel.sortingOption == option {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort stocks")
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    ConnectionStatusView(state: viewModel.connectionState)
                    Spacer()
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .task { viewModel.startObserving() }
        }
    }
}

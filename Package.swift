// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StockTracker",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "StockTracker", targets: ["StockTracker"])
    ],
    targets: [
        .target(
            name: "StockTracker",
            path: "StockTracker"
        ),
        .testTarget(
            name: "StockTrackerDomainTests",
            dependencies: ["StockTracker"],
            path: "Tests/DomainTests"
        )
    ]
)

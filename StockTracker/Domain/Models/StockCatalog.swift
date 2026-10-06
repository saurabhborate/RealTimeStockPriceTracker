import Foundation

public enum StockCatalog {
    public static let initialStocks: [Stock] = [
        stock("AAPL", 225.00, "Apple Inc."),
        stock("GOOG", 190.00, "Alphabet Inc. Class C"),
        stock("GOOGL", 188.00, "Alphabet Inc. Class A"),
        stock("MSFT", 425.00, "Microsoft Corporation"),
        stock("AMZN", 220.00, "Amazon.com, Inc."),
        stock("NVDA", 140.00, "NVIDIA Corporation"),
        stock("TSLA", 350.00, "Tesla, Inc."),
        stock("META", 600.00, "Meta Platforms, Inc."),
        stock("NFLX", 900.00, "Netflix, Inc."),
        stock("AMD", 120.00, "Advanced Micro Devices, Inc."),
        stock("INTC", 25.00, "Intel Corporation"),
        stock("ORCL", 180.00, "Oracle Corporation"),
        stock("IBM", 260.00, "International Business Machines"),
        stock("ADBE", 450.00, "Adobe Inc."),
        stock("CRM", 320.00, "Salesforce, Inc."),
        stock("AVGO", 180.00, "Broadcom Inc."),
        stock("QCOM", 160.00, "Qualcomm Incorporated"),
        stock("CSCO", 60.00, "Cisco Systems, Inc."),
        stock("UBER", 80.00, "Uber Technologies, Inc."),
        stock("SHOP", 110.00, "Shopify Inc."),
        stock("PYPL", 75.00, "PayPal Holdings, Inc."),
        stock("JPM", 240.00, "JPMorgan Chase & Co."),
        stock("V", 350.00, "Visa Inc."),
        stock("MA", 520.00, "Mastercard Incorporated"),
        stock("COST", 950.00, "Costco Wholesale Corporation")
    ]

    private static func stock(_ symbol: String, _ value: Decimal, _ description: String) -> Stock {
        Stock(
            symbol: StockSymbol(rawValue: symbol),
            currentPrice: StockPrice(value: value, updatedAt: Date(timeIntervalSince1970: 0)),
            description: description
        )
    }
}

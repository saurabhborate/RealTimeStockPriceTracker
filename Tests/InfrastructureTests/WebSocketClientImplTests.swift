import Foundation
import XCTest
@testable import StockTracker

@MainActor
final class WebSocketClientImplTests: XCTestCase {
    func testRejectsInvalidEndpoint() {
        XCTAssertThrowsError(try WebSocketClientImpl(endpoint: "https://example.com")) { error in
            guard case WebSocketError.invalidURL = error else {
                return XCTFail("Expected an invalid WebSocket URL error.")
            }
        }
    }

    func testSendingWithoutAConnectionFails() async throws {
        let client = try WebSocketClientImpl(endpoint: AppEnvironment.postmanEchoEndpoint)

        do {
            try await client.send(Data("message".utf8))
            XCTFail("Expected sending without a connection to fail.")
        } catch WebSocketError.connectionClosed {
            return
        }
    }
}

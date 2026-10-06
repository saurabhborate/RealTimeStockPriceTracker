public struct AppEnvironment: Sendable {
    public static let postmanEchoEndpoint = "wss://ws.postman-echo.com/raw"

    public let webSocketEndpoint: String

    public init(webSocketEndpoint: String = Self.postmanEchoEndpoint) {
        self.webSocketEndpoint = webSocketEndpoint
    }
}

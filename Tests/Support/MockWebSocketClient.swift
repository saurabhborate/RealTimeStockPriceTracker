import Foundation
@testable import StockTracker

actor MockWebSocketClient: WebSocketClient {
    enum Failure: Error, Sendable {
        case connection
        case send
        case receive
    }

    private let connectionFailure: Failure?
    private let sendFailure: Failure?
    private let echoesSentMessages: Bool
    private var stream: AsyncThrowingStream<Data, any Error>?
    private var continuation: AsyncThrowingStream<Data, any Error>.Continuation?
    private var connected = false
    private var sent: [Data] = []
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private(set) var incomingSubscriptionCount = 0

    init(
        connectionFailure: Failure? = nil,
        sendFailure: Failure? = nil,
        echoesSentMessages: Bool = false
    ) {
        self.connectionFailure = connectionFailure
        self.sendFailure = sendFailure
        self.echoesSentMessages = echoesSentMessages
    }

    func connect() async throws {
        if let connectionFailure { throw connectionFailure }
        guard !connected else { return }
        let (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
        self.stream = stream
        self.continuation = continuation
        connected = true
        connectCount += 1
    }

    func send(_ message: Data) async throws {
        guard connected else { throw WebSocketError.connectionClosed }
        if let sendFailure { throw sendFailure }
        sent.append(message)
        if echoesSentMessages { continuation?.yield(message) }
    }

    func incomingMessages() async -> AsyncThrowingStream<Data, any Error> {
        incomingSubscriptionCount += 1
        return stream ?? AsyncThrowingStream { $0.finish(throwing: WebSocketError.connectionClosed) }
    }

    func disconnect() async {
        disconnectCount += 1
        connected = false
        continuation?.finish()
        continuation = nil
        stream = nil
    }

    func yield(_ message: Data) {
        continuation?.yield(message)
    }

    func finishIncoming(throwing error: Failure) {
        continuation?.finish(throwing: error)
        continuation = nil
    }

    func sentMessages() -> [Data] { sent }
    func counts() -> (connections: Int, disconnections: Int, incomingSubscriptions: Int) {
        (connectCount, disconnectCount, incomingSubscriptionCount)
    }
}

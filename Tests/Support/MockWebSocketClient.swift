import Foundation
@testable import StockTracker

actor MockWebSocketClient: WebSocketClient {
    enum Failure: Error, Sendable {
        case connection
        case send
        case receive
    }

    private let stream: AsyncThrowingStream<Data, any Error>
    private let continuation: AsyncThrowingStream<Data, any Error>.Continuation
    private let connectionFailure: Failure?
    private let sendFailure: Failure?
    private var connected = false
    private var sent: [Data] = []
    private var didDisconnect = false

    init(connectionFailure: Failure? = nil, sendFailure: Failure? = nil) {
        let (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
        self.stream = stream
        self.continuation = continuation
        self.connectionFailure = connectionFailure
        self.sendFailure = sendFailure
    }

    func connect() async throws {
        if let connectionFailure { throw connectionFailure }
        connected = true
    }

    func send(_ message: Data) async throws {
        guard connected else { throw WebSocketError.connectionClosed }
        if let sendFailure { throw sendFailure }
        sent.append(message)
    }

    func incomingMessages() async -> AsyncThrowingStream<Data, any Error> {
        stream
    }

    func disconnect() async {
        connected = false
        didDisconnect = true
        continuation.finish()
    }

    func yield(_ message: Data) {
        continuation.yield(message)
    }

    func finishIncoming(throwing error: Failure) {
        continuation.finish(throwing: error)
    }

    func sentMessages() -> [Data] { sent }
    func isDisconnected() -> Bool { didDisconnect }
}

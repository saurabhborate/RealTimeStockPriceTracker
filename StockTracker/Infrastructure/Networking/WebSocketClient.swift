import Foundation

/// Defines the transport boundary for exchanging opaque WebSocket messages.
/// Implementations belong in the Infrastructure layer and can be replaced without
/// changing domain or presentation code.
public protocol WebSocketClient: Sendable {
    func connect() async throws
    func send(_ message: Data) async throws
    func incomingMessages() async -> AsyncThrowingStream<Data, any Error>
    func disconnect() async
}

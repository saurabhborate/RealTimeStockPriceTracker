import Foundation

public enum WebSocketError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case connectionFailed(underlying: any Error)
    case sendFailed(underlying: any Error)
    case receiveFailed(underlying: any Error)
    case invalidMessageEncoding
    case unsupportedMessage
    case connectionClosed

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let value): return "Invalid WebSocket URL: \(value)"
        case .connectionFailed: return "The WebSocket connection failed."
        case .sendFailed: return "The WebSocket message could not be sent."
        case .receiveFailed: return "A WebSocket message could not be received."
        case .invalidMessageEncoding: return "A WebSocket message must contain UTF-8 encoded text."
        case .unsupportedMessage: return "The WebSocket returned an unsupported message."
        case .connectionClosed: return "The WebSocket is not connected."
        }
    }
}

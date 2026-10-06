/// Application-level connection state without transport-specific details.
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed
}

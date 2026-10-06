public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case failed
}

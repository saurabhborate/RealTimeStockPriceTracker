import SwiftUI

struct ConnectionStatusView: View {
    let state: ConnectionState

    private var title: String {
        switch state {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .failed: "Connection failed"
        }
    }

    private var tint: Color {
        switch state {
        case .connected: .green
        case .connecting: .orange
        case .disconnected, .failed: .secondary
        }
    }

    var body: some View {
        Label(title, systemImage: "circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .accessibilityLabel("Connection status: \(title)")
    }
}

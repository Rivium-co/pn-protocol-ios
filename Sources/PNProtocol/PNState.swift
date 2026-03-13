import Foundation

/// Connection states for PNSocket
public enum PNState: String {
    /// Not connected to gateway
    case disconnected

    /// Establishing connection
    case connecting

    /// Connected and ready
    case connected

    /// Reconnecting after connection loss
    case reconnecting

    /// Gracefully disconnecting
    case disconnecting
}

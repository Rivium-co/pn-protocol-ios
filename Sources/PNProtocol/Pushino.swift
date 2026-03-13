import Foundation

/// PN Protocol SDK
///
/// Lightweight push notification protocol using MQTT as transport.
///
/// ## Quick Start
///
/// ```swift
/// // Initialize
/// let config = PNConfigBuilder()
///     .gateway("push.example.com")
///     .port(1883)
///     .clientId("user-12345")
///     .auth(.basic(username: "user", password: "pass"))
///     .build()
///
/// PNProtocolClient.initialize(config)
///
/// // Connect
/// PNProtocolClient.socket()
///     .addConnectionListener(myListener)
///     .open()
///
/// // Stream messages
/// PNProtocolClient.socket().stream("notifications/user-123") { message in
///     print("Received: \(message.payloadAsString())")
/// }
///
/// // Dispatch messages
/// PNProtocolClient.socket().dispatch(PNMessage.text("chat/room-1", "Hello!"))
/// ```
///
/// ## Terminology
///
/// | PN Protocol   | MQTT              | Description                    |
/// |---------------|-------------------|--------------------------------|
/// | gateway       | broker            | Server address                 |
/// | channel       | topic             | Message destination            |
/// | stream()      | subscribe()       | Listen to messages             |
/// | detach()      | unsubscribe()     | Stop listening                 |
/// | dispatch()    | publish()         | Send a message                 |
/// | exitSignal    | lastWill          | Message on disconnect          |
/// | freshStart    | cleanSession      | Ignore persisted state         |
/// | heartbeat     | keepAlive         | Connection keep-alive          |
public final class PNProtocolClient {

    /// SDK Version
    public static let VERSION = "1.0.0"

    /// Protocol identifier
    public static let PROTOCOL = "PN/1.0"

    private static var _socket: PNSocket?
    private static var _config: PNConfig?

    private init() {}

    /// Initialize PNProtocol with configuration
    @discardableResult
    public static func initialize(_ config: PNConfig) -> PNProtocolClient.Type {
        // Close existing socket to prevent orphaned MQTT connections
        // (orphaned connections cause EMQX session takeover loops)
        _socket?.close()
        _config = config
        _socket = PNSocket(config: config)
        return PNProtocolClient.self
    }

    /// Get the active socket connection
    public static func socket() -> PNSocket {
        guard let socket = _socket else {
            fatalError("PNProtocol not initialized. Call initialize() first.")
        }
        return socket
    }

    /// Check if PNProtocol is initialized
    public static func isInitialized() -> Bool {
        return _socket != nil
    }

    /// Shutdown PNProtocol and release resources
    public static func shutdown() {
        _socket?.close()
        _socket = nil
        _config = nil
    }

    /// Get current configuration
    public static func config() -> PNConfig? {
        return _config
    }
}

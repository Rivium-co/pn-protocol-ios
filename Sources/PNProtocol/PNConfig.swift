import Foundation

/// Configuration for PNSocket connection
///
/// | PN Protocol        | MQTT                  |
/// |--------------------|-----------------------|
/// | gateway            | broker host           |
/// | heartbeatInterval  | keepAliveInterval     |
/// | freshStart         | cleanSession          |
/// | exitSignal         | lastWillAndTestament  |
public struct PNConfig {
    /// Gateway server host (MQTT: broker)
    public let gateway: String

    /// Gateway server port
    public let port: UInt16

    /// Unique client identifier
    public let clientId: String

    /// Authentication credentials
    public let auth: PNAuth?

    /// Keep connection alive interval in seconds (MQTT: keepAliveInterval)
    public let heartbeatInterval: UInt16

    /// Connection timeout in seconds
    public let connectionTimeout: TimeInterval

    /// Start with fresh state, ignore persisted data (MQTT: cleanSession)
    public let freshStart: Bool

    /// Auto-reconnect on connection loss
    public let autoReconnect: Bool

    /// Maximum reconnect attempts (0 = infinite)
    public let maxReconnectAttempts: Int

    /// Initial reconnect delay in seconds
    public let reconnectDelay: TimeInterval

    /// Maximum reconnect delay in seconds
    public let maxReconnectDelay: TimeInterval

    /// Exit signal - message sent on unexpected disconnect (MQTT: Last Will)
    public let exitSignal: PNExitSignal?

    /// Enable secure connection (TLS/SSL)
    public let secure: Bool

    public init(
        gateway: String,
        port: UInt16 = 1883,
        clientId: String,
        auth: PNAuth? = nil,
        heartbeatInterval: UInt16 = 60,
        connectionTimeout: TimeInterval = 30,
        freshStart: Bool = true,
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 10,
        reconnectDelay: TimeInterval = 1.0,
        maxReconnectDelay: TimeInterval = 300.0,
        exitSignal: PNExitSignal? = nil,
        secure: Bool = false
    ) {
        self.gateway = gateway
        self.port = port
        self.clientId = clientId
        self.auth = auth
        self.heartbeatInterval = heartbeatInterval
        self.connectionTimeout = connectionTimeout
        self.freshStart = freshStart
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelay = reconnectDelay
        self.maxReconnectDelay = maxReconnectDelay
        self.exitSignal = exitSignal
        self.secure = secure
    }
}

/// Authentication options
public enum PNAuth {
    /// Username/password authentication
    case basic(username: String, password: String)

    /// Token-based authentication
    case token(String)
}

/// Exit signal sent when client disconnects unexpectedly (MQTT: Last Will and Testament)
public struct PNExitSignal {
    /// Channel to send exit signal to
    public let channel: String

    /// Payload to send
    public let payload: Data

    /// Delivery mode
    public let mode: PNDeliveryMode

    /// Persist the exit signal
    public let persist: Bool

    public init(
        channel: String,
        payload: Data,
        mode: PNDeliveryMode = .reliable,
        persist: Bool = false
    ) {
        self.channel = channel
        self.payload = payload
        self.mode = mode
        self.persist = persist
    }

    public static func create(channel: String, payload: String) -> PNExitSignal {
        return PNExitSignal(
            channel: channel,
            payload: payload.data(using: .utf8) ?? Data()
        )
    }
}

/// Builder for PNConfig
public class PNConfigBuilder {
    private var gateway: String = ""
    private var port: UInt16 = 1883
    private var clientId: String = ""
    private var auth: PNAuth?
    private var heartbeatInterval: UInt16 = 60
    private var connectionTimeout: TimeInterval = 30
    private var freshStart: Bool = true
    private var autoReconnect: Bool = true
    private var maxReconnectAttempts: Int = 10
    private var reconnectDelay: TimeInterval = 1.0
    private var maxReconnectDelay: TimeInterval = 300.0
    private var exitSignal: PNExitSignal?
    private var secure: Bool = false

    public init() {}

    @discardableResult
    public func gateway(_ gateway: String) -> PNConfigBuilder {
        self.gateway = gateway
        return self
    }

    @discardableResult
    public func port(_ port: UInt16) -> PNConfigBuilder {
        self.port = port
        return self
    }

    @discardableResult
    public func clientId(_ clientId: String) -> PNConfigBuilder {
        self.clientId = clientId
        return self
    }

    @discardableResult
    public func auth(_ auth: PNAuth) -> PNConfigBuilder {
        self.auth = auth
        return self
    }

    @discardableResult
    public func heartbeatInterval(_ seconds: UInt16) -> PNConfigBuilder {
        self.heartbeatInterval = seconds
        return self
    }

    @discardableResult
    public func connectionTimeout(_ seconds: TimeInterval) -> PNConfigBuilder {
        self.connectionTimeout = seconds
        return self
    }

    @discardableResult
    public func freshStart(_ fresh: Bool) -> PNConfigBuilder {
        self.freshStart = fresh
        return self
    }

    @discardableResult
    public func autoReconnect(_ auto: Bool) -> PNConfigBuilder {
        self.autoReconnect = auto
        return self
    }

    @discardableResult
    public func maxReconnectAttempts(_ max: Int) -> PNConfigBuilder {
        self.maxReconnectAttempts = max
        return self
    }

    @discardableResult
    public func reconnectDelay(_ delay: TimeInterval) -> PNConfigBuilder {
        self.reconnectDelay = delay
        return self
    }

    @discardableResult
    public func maxReconnectDelay(_ delay: TimeInterval) -> PNConfigBuilder {
        self.maxReconnectDelay = delay
        return self
    }

    @discardableResult
    public func exitSignal(_ signal: PNExitSignal) -> PNConfigBuilder {
        self.exitSignal = signal
        return self
    }

    @discardableResult
    public func secure(_ secure: Bool) -> PNConfigBuilder {
        self.secure = secure
        return self
    }

    public func build() -> PNConfig {
        precondition(!gateway.isEmpty, "Gateway is required")
        precondition(!clientId.isEmpty, "Client ID is required")

        return PNConfig(
            gateway: gateway,
            port: port,
            clientId: clientId,
            auth: auth,
            heartbeatInterval: heartbeatInterval,
            connectionTimeout: connectionTimeout,
            freshStart: freshStart,
            autoReconnect: autoReconnect,
            maxReconnectAttempts: maxReconnectAttempts,
            reconnectDelay: reconnectDelay,
            maxReconnectDelay: maxReconnectDelay,
            exitSignal: exitSignal,
            secure: secure
        )
    }
}

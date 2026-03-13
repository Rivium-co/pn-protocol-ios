import Foundation
import CocoaMQTT

/// PNSocket - Main connection handler for PN Protocol
///
/// Wraps MQTT client with PN Protocol branded API.
///
/// | PN Protocol   | MQTT              |
/// |---------------|-------------------|
/// | open()        | connect()         |
/// | close()       | disconnect()      |
/// | stream()      | subscribe()       |
/// | detach()      | unsubscribe()     |
/// | dispatch()    | publish()         |
/// | channel       | topic             |
public class PNSocket {
    private static let TAG = "PNSocket"
    private static let BACKOFF_MULTIPLIER = 2.0
    private static let JITTER_FACTOR = 0.2

    // MQTT client (internal implementation)
    private var mqttClient: CocoaMQTT?

    // Configuration
    private let config: PNConfig

    // State
    private(set) public var state: PNState = .disconnected
    private var activeChannels = Set<String>()

    // Listeners
    private var connectionListeners = [WeakRef<AnyObject>]()
    private var messageListeners = [String: [WeakRef<AnyObject>]]()
    private var errorListeners = [WeakRef<AnyObject>]()

    // Reconnection state
    private var retryAttempt = 0
    private var isRetrying = false
    private var isConnecting = false
    private var manualDisconnect = false
    private var retryTimer: Timer?

    public init(config: PNConfig) {
        self.config = config
    }

    // ========================================================================
    // Public API
    // ========================================================================

    /// Open connection to the gateway (MQTT: connect)
    @discardableResult
    public func open() -> PNSocket {
        if state == .connected || state == .connecting {
            return self
        }

        manualDisconnect = false
        resetRetryState()
        connectInternal()
        return self
    }

    /// Close connection gracefully (MQTT: disconnect)
    @discardableResult
    public func close() -> PNSocket {
        if state == .disconnected { return self }

        Log.d(PNSocket.TAG, "Closing connection")
        manualDisconnect = true
        cancelRetry()
        isConnecting = false

        state = .disconnecting
        notifyStateChange(.disconnecting)

        mqttClient?.disconnect()
        mqttClient = nil
        activeChannels.removeAll()

        state = .disconnected
        notifyStateChange(.disconnected)

        return self
    }

    /// Reconnect immediately without destroying the socket.
    /// Cancels any pending retry and triggers an immediate connection attempt.
    /// Unlike close()+open(), this preserves activeChannels so resubscription works.
    @discardableResult
    public func reconnectImmediately() -> PNSocket {
        if state == .connected || state == .connecting {
            Log.d(PNSocket.TAG, "reconnectImmediately() skipped - state is \(state)")
            return self
        }

        Log.d(PNSocket.TAG, "Reconnecting immediately")
        cancelRetry()
        isConnecting = false
        manualDisconnect = false
        connectInternal()
        return self
    }

    /// Stream messages from a channel (MQTT: subscribe)
    ///
    /// - Parameters:
    ///   - channel: Channel name to listen to (MQTT: topic)
    ///   - mode: Delivery guarantee mode (MQTT: QoS)
    ///   - listener: Message listener
    @discardableResult
    public func stream(
        _ channel: String,
        mode: PNDeliveryMode = .reliable,
        listener: PNMessageListener
    ) -> PNSocket {
        guard state == .connected else {
            let error = PNError.notConnected()
            notifyError(error)
            return self
        }

        // Add listener, deduplicating to prevent accumulation across reconnects
        if messageListeners[channel] == nil {
            messageListeners[channel] = []
        }
        // Check if this listener is already registered (by identity)
        let alreadyRegistered = messageListeners[channel]?.contains(where: { $0.value === listener }) ?? false
        if !alreadyRegistered {
            messageListeners[channel]?.append(WeakRef(listener))
        }

        if !activeChannels.contains(channel) {
            mqttClient?.subscribe(channel, qos: CocoaMQTTQoS(rawValue: UInt8(mode.qos)) ?? .qos1)
            activeChannels.insert(channel)
            Log.d(PNSocket.TAG, "Streaming from channel: \(channel)")
        }

        return self
    }

    /// Stream messages with closure
    @discardableResult
    public func stream(
        _ channel: String,
        mode: PNDeliveryMode = .reliable,
        handler: @escaping (PNMessage) -> Void
    ) -> PNSocket {
        return stream(channel, mode: mode, listener: PNMessageHandler(handler))
    }

    /// Stream with pattern matching (wildcard channels)
    @discardableResult
    public func streamPattern(
        _ pattern: String,
        mode: PNDeliveryMode = .reliable,
        listener: PNMessageListener
    ) -> PNSocket {
        return stream(pattern, mode: mode, listener: listener)
    }

    /// Stop streaming from a channel (MQTT: unsubscribe)
    @discardableResult
    public func detach(_ channel: String) -> PNSocket {
        guard activeChannels.contains(channel) else { return self }

        mqttClient?.unsubscribe(channel)
        activeChannels.remove(channel)
        messageListeners.removeValue(forKey: channel)
        Log.d(PNSocket.TAG, "Detached from channel: \(channel)")

        return self
    }

    /// Dispatch a message to a channel (MQTT: publish)
    @discardableResult
    public func dispatch(_ message: PNMessage) -> PNSocket {
        guard state == .connected else {
            let error = PNError.notConnected()
            notifyError(error)
            return self
        }

        let mqttMessage = CocoaMQTTMessage(
            topic: message.channel,
            payload: [UInt8](message.payload),
            qos: CocoaMQTTQoS(rawValue: UInt8(message.mode.qos)) ?? .qos1,
            retained: message.persist
        )
        mqttClient?.publish(mqttMessage)
        Log.d(PNSocket.TAG, "Dispatched message to \(message.channel)")

        return self
    }

    /// Check if connected
    public func isConnected() -> Bool {
        return state == .connected && (mqttClient?.connState == .connected)
    }

    /// Get active channels
    public func getActiveChannels() -> Set<String> {
        return activeChannels
    }

    // ========================================================================
    // Listeners
    // ========================================================================

    @discardableResult
    public func addConnectionListener(_ listener: PNConnectionListener) -> PNSocket {
        connectionListeners.append(WeakRef(listener))
        return self
    }

    @discardableResult
    public func removeConnectionListener(_ listener: PNConnectionListener) -> PNSocket {
        connectionListeners.removeAll { $0.value === listener }
        return self
    }

    @discardableResult
    public func addErrorListener(_ listener: PNErrorListener) -> PNSocket {
        errorListeners.append(WeakRef(listener))
        return self
    }

    @discardableResult
    public func removeErrorListener(_ listener: PNErrorListener) -> PNSocket {
        errorListeners.removeAll { $0.value === listener }
        return self
    }

    // ========================================================================
    // Internal MQTT Implementation
    // ========================================================================

    private func connectInternal() {
        // Prevent concurrent connection attempts that cause EMQX session takeover
        guard !isConnecting else {
            Log.d(PNSocket.TAG, "Connection already in progress - skipping")
            return
        }
        isConnecting = true

        state = .connecting
        notifyStateChange(.connecting)

        let clientId = config.clientId
        let host = config.gateway
        let port = config.port

        Log.d(PNSocket.TAG, "Connecting to gateway: \(host):\(port) (clientId: \(clientId))")

        // Create MQTT client
        mqttClient = CocoaMQTT(clientID: clientId, host: host, port: port)
        mqttClient?.cleanSession = config.freshStart
        mqttClient?.keepAlive = config.heartbeatInterval
        mqttClient?.enableSSL = config.secure
        mqttClient?.autoReconnect = false  // We handle reconnection ourselves

        // Authentication
        if let auth = config.auth {
            switch auth {
            case .basic(let username, let password):
                mqttClient?.username = username
                mqttClient?.password = password
            case .token(let token):
                mqttClient?.username = "token"
                mqttClient?.password = token
            }
        }

        // Exit signal (Last Will)
        if let exit = config.exitSignal {
            let will = CocoaMQTTMessage(
                topic: exit.channel,
                payload: [UInt8](exit.payload),
                qos: CocoaMQTTQoS(rawValue: UInt8(exit.mode.qos)) ?? .qos1,
                retained: exit.persist
            )
            mqttClient?.willMessage = will
        }

        // Set delegate
        mqttClient?.delegate = self

        // Connect
        let success = mqttClient?.connect() ?? false
        if !success {
            Log.e(PNSocket.TAG, "Failed to initiate connection")
            isConnecting = false
            state = .disconnected
            let error = PNError.connectionFailed("Failed to initiate connection")
            notifyError(error)

            if !manualDisconnect && config.autoReconnect {
                scheduleRetry()
            }
        }
    }

    private func resubscribeChannels() {
        guard !activeChannels.isEmpty else { return }

        for channel in activeChannels {
            mqttClient?.subscribe(channel, qos: .qos1)
        }
        Log.d(PNSocket.TAG, "Resubscribed to \(activeChannels.count) channels")
    }

    // ========================================================================
    // Reconnection with Exponential Backoff
    // ========================================================================

    private func calculateRetryDelay(_ attempt: Int) -> TimeInterval {
        let exponentialDelay = config.reconnectDelay * pow(PNSocket.BACKOFF_MULTIPLIER, Double(attempt))
        let cappedDelay = min(exponentialDelay, config.maxReconnectDelay)
        let jitter = cappedDelay * PNSocket.JITTER_FACTOR * (Double.random(in: 0...1) * 2 - 1)
        return cappedDelay + jitter
    }

    private func scheduleRetry() {
        guard !manualDisconnect else { return }

        if config.maxReconnectAttempts > 0 && retryAttempt >= config.maxReconnectAttempts {
            Log.e(PNSocket.TAG, "Max retry attempts (\(config.maxReconnectAttempts)) reached")
            let error = PNError(
                code: .connectionFailed,
                message: "Max retry attempts reached after \(retryAttempt) attempts"
            )
            notifyError(error)
            return
        }

        let delay = calculateRetryDelay(retryAttempt)
        Log.d(PNSocket.TAG, "Scheduling retry \(retryAttempt + 1) in \(delay)s")

        state = .reconnecting
        notifyStateChange(.reconnecting)
        notifyReconnecting(attempt: retryAttempt, nextRetryMs: Int(delay * 1000))

        isRetrying = true
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.retryAttempt += 1
            Log.d(PNSocket.TAG, "Executing retry attempt \(self.retryAttempt)")
            self.connectInternal()
        }
    }

    private func cancelRetry() {
        retryTimer?.invalidate()
        retryTimer = nil
        isRetrying = false
    }

    private func resetRetryState() {
        retryAttempt = 0
        isRetrying = false
        cancelRetry()
    }

    // ========================================================================
    // Notification Helpers
    // ========================================================================

    private func notifyStateChange(_ newState: PNState) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionListeners.compactMap { $0.value as? PNConnectionListener }.forEach {
                $0.onStateChanged(newState)
            }
        }
    }

    private func notifyConnected() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionListeners.compactMap { $0.value as? PNConnectionListener }.forEach {
                $0.onConnected()
            }
        }
    }

    private func notifyDisconnected(reason: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionListeners.compactMap { $0.value as? PNConnectionListener }.forEach {
                $0.onDisconnected(reason: reason)
            }
        }
    }

    private func notifyReconnecting(attempt: Int, nextRetryMs: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionListeners.compactMap { $0.value as? PNConnectionListener }.forEach {
                $0.onReconnecting(attempt: attempt, nextRetryMs: nextRetryMs)
            }
        }
    }

    private func notifyError(_ error: PNError) {
        DispatchQueue.main.async { [weak self] in
            self?.errorListeners.compactMap { $0.value as? PNErrorListener }.forEach {
                $0.onError(error)
            }
        }
    }

    private func notifyMessage(_ message: PNMessage) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Notify listeners for this channel
            self.messageListeners[message.channel]?.compactMap { $0.value as? PNMessageListener }.forEach {
                $0.onMessage(message)
            }

            // Also check pattern listeners
            for (pattern, listeners) in self.messageListeners {
                if self.matchesPattern(pattern, message.channel) && pattern != message.channel {
                    listeners.compactMap { $0.value as? PNMessageListener }.forEach {
                        $0.onMessage(message)
                    }
                }
            }
        }
    }

    private func matchesPattern(_ pattern: String, _ topic: String) -> Bool {
        if !pattern.contains("+") && !pattern.contains("#") {
            return pattern == topic
        }

        let patternParts = pattern.split(separator: "/", omittingEmptySubsequences: false)
        let topicParts = topic.split(separator: "/", omittingEmptySubsequences: false)

        var i = 0
        for part in patternParts {
            if part == "#" { return true }
            if part == "+" { i += 1; continue }
            if i >= topicParts.count || topicParts[i] != part { return false }
            i += 1
        }
        return i == topicParts.count
    }
}

// MARK: - CocoaMQTTDelegate

extension PNSocket: CocoaMQTTDelegate {
    public func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            Log.d(PNSocket.TAG, "Connected to gateway")
            isConnecting = false
            state = .connected
            resetRetryState()
            notifyStateChange(.connected)
            notifyConnected()
            resubscribeChannels()
        } else {
            Log.e(PNSocket.TAG, "Connection rejected: \(ack)")
            isConnecting = false
            state = .disconnected
            let error = PNError.connectionFailed("Connection rejected: \(ack)")
            notifyError(error)

            if !manualDisconnect && config.autoReconnect {
                scheduleRetry()
            }
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        Log.d(PNSocket.TAG, "MQTT state changed: \(state)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        Log.d(PNSocket.TAG, "Message published: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        Log.d(PNSocket.TAG, "Publish acknowledged: \(id)")
    }

    public func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let pnMessage = PNMessage.fromMqtt(
            topic: message.topic,
            payload: Data(message.payload),
            qos: Int(message.qos.rawValue),
            retained: message.retained
        )
        Log.d(PNSocket.TAG, "Message received on channel: \(message.topic)")
        notifyMessage(pnMessage)
    }

    public func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        Log.d(PNSocket.TAG, "Subscribed to topics: \(success.allKeys)")
        if !failed.isEmpty {
            Log.e(PNSocket.TAG, "Failed to subscribe: \(failed)")
        }
    }

    public func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
        Log.d(PNSocket.TAG, "Unsubscribed from topics: \(topics)")
    }

    public func mqttDidPing(_ mqtt: CocoaMQTT) {}

    public func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}

    public func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        Log.e(PNSocket.TAG, "Disconnected: \(err?.localizedDescription ?? "unknown")")

        isConnecting = false
        state = .disconnected
        // NOTE: activeChannels is intentionally NOT cleared here
        // so resubscribeChannels() can restore them after reconnect
        notifyDisconnected(reason: err?.localizedDescription)

        if let err = err {
            let error = PNError.connectionLost(err.localizedDescription, err)
            notifyError(error)
        }

        if !manualDisconnect && config.autoReconnect {
            scheduleRetry()
        }
    }
}

// MARK: - Helpers

private class WeakRef<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}

private enum Log {
    static func d(_ tag: String, _ message: String) {
        #if DEBUG
        print("[\(tag)] \(message)")
        #endif
    }

    static func e(_ tag: String, _ message: String) {
        print("[\(tag)] ERROR: \(message)")
    }
}

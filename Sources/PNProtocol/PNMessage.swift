import Foundation

/// Message in PN Protocol
///
/// Wraps MQTT message with PN Protocol terminology.
public struct PNMessage {
    /// Target channel (MQTT: topic)
    public let channel: String

    /// Message payload as bytes
    public let payload: Data

    /// Delivery guarantee mode (MQTT: QoS)
    public let mode: PNDeliveryMode

    /// Persist message for new subscribers (MQTT: retain)
    public let persist: Bool

    /// Message timestamp
    public let timestamp: Date

    /// Unique message ID
    public let id: String

    public init(
        channel: String,
        payload: Data,
        mode: PNDeliveryMode = .reliable,
        persist: Bool = false,
        timestamp: Date = Date(),
        id: String = UUID().uuidString
    ) {
        self.channel = channel
        self.payload = payload
        self.mode = mode
        self.persist = persist
        self.timestamp = timestamp
        self.id = id
    }

    /// Get payload as UTF-8 string
    public func payloadAsString() -> String {
        return String(data: payload, encoding: .utf8) ?? ""
    }

    /// Create a simple text message
    public static func text(_ channel: String, _ text: String) -> PNMessage {
        return PNMessage(
            channel: channel,
            payload: text.data(using: .utf8) ?? Data()
        )
    }

    /// Create from MQTT message
    internal static func fromMqtt(topic: String, payload: Data, qos: Int, retained: Bool) -> PNMessage {
        return PNMessage(
            channel: topic,
            payload: payload,
            mode: PNDeliveryMode.fromQos(qos),
            persist: retained
        )
    }
}

/// Builder for PNMessage
public class PNMessageBuilder {
    private var channel: String = ""
    private var payload: Data = Data()
    private var mode: PNDeliveryMode = .reliable
    private var persist: Bool = false

    public init() {}

    @discardableResult
    public func channel(_ channel: String) -> PNMessageBuilder {
        self.channel = channel
        return self
    }

    @discardableResult
    public func payload(_ payload: Data) -> PNMessageBuilder {
        self.payload = payload
        return self
    }

    @discardableResult
    public func payload(_ payload: String) -> PNMessageBuilder {
        self.payload = payload.data(using: .utf8) ?? Data()
        return self
    }

    @discardableResult
    public func mode(_ mode: PNDeliveryMode) -> PNMessageBuilder {
        self.mode = mode
        return self
    }

    @discardableResult
    public func persist(_ persist: Bool) -> PNMessageBuilder {
        self.persist = persist
        return self
    }

    public func build() -> PNMessage {
        precondition(!channel.isEmpty, "Channel is required")
        return PNMessage(channel: channel, payload: payload, mode: mode, persist: persist)
    }
}

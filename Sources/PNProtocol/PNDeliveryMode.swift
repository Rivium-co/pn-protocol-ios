import Foundation

/// Delivery guarantee modes for PN Protocol
///
/// | Mode       | MQTT QoS | Description                    |
/// |------------|----------|--------------------------------|
/// | fast       | QoS 0    | Fire and forget, no guarantee  |
/// | reliable   | QoS 1    | At least once delivery         |
/// | exactOnce  | QoS 2    | Exactly once delivery          |
public enum PNDeliveryMode: Int {
    /// Fire and forget - fastest, no guarantee (QoS 0)
    case fast = 0

    /// At least once delivery (QoS 1)
    case reliable = 1

    /// Exactly once delivery (QoS 2)
    case exactOnce = 2

    /// Get MQTT QoS value
    public var qos: Int { rawValue }

    /// Create from QoS value
    public static func fromQos(_ qos: Int) -> PNDeliveryMode {
        return PNDeliveryMode(rawValue: qos) ?? .reliable
    }
}

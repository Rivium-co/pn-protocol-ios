import Foundation

/// Listener for connection state changes
public protocol PNConnectionListener: AnyObject {
    /// Called when connection state changes
    func onStateChanged(_ state: PNState)

    /// Called when successfully connected
    func onConnected()

    /// Called when disconnected
    func onDisconnected(reason: String?)

    /// Called when reconnecting (with retry info)
    func onReconnecting(attempt: Int, nextRetryMs: Int)
}

/// Default implementations for PNConnectionListener
public extension PNConnectionListener {
    func onStateChanged(_ state: PNState) {}
    func onConnected() {}
    func onDisconnected(reason: String?) {}
    func onReconnecting(attempt: Int, nextRetryMs: Int) {}
}

/// Listener for incoming messages
public protocol PNMessageListener: AnyObject {
    func onMessage(_ message: PNMessage)
}

/// Listener for errors
public protocol PNErrorListener: AnyObject {
    func onError(_ error: PNError)
}

/// Callback for dispatch (publish) operations
public protocol PNDispatchCallback: AnyObject {
    func onSuccess(messageId: String)
    func onFailure(error: PNError)
}

/// Closure-based message listener
public class PNMessageHandler: PNMessageListener {
    private let handler: (PNMessage) -> Void

    public init(_ handler: @escaping (PNMessage) -> Void) {
        self.handler = handler
    }

    public func onMessage(_ message: PNMessage) {
        handler(message)
    }
}

/// Closure-based error listener
public class PNErrorHandler: PNErrorListener {
    private let handler: (PNError) -> Void

    public init(_ handler: @escaping (PNError) -> Void) {
        self.handler = handler
    }

    public func onError(_ error: PNError) {
        handler(error)
    }
}

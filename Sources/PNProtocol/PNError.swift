import Foundation

/// Error from PN Protocol operations
public struct PNError: Error {
    public let code: Code
    public let message: String
    public let underlyingError: Error?

    public enum Code: Int {
        case unknown = 0
        case connectionFailed = 100
        case connectionLost = 101
        case connectionTimeout = 102
        case authFailed = 200
        case authExpired = 201
        case streamFailed = 300
        case detachFailed = 301
        case dispatchFailed = 400
        case invalidConfig = 500
        case invalidMessage = 501
        case notConnected = 600
    }

    public init(code: Code, message: String, underlyingError: Error? = nil) {
        self.code = code
        self.message = message
        self.underlyingError = underlyingError
    }

    public static func connectionFailed(_ message: String, _ error: Error? = nil) -> PNError {
        return PNError(code: .connectionFailed, message: message, underlyingError: error)
    }

    public static func connectionLost(_ message: String, _ error: Error? = nil) -> PNError {
        return PNError(code: .connectionLost, message: message, underlyingError: error)
    }

    public static func authFailed(_ message: String, _ error: Error? = nil) -> PNError {
        return PNError(code: .authFailed, message: message, underlyingError: error)
    }

    public static func notConnected() -> PNError {
        return PNError(code: .notConnected, message: "Not connected. Call open() first.")
    }

    public static func from(_ error: Error, defaultMessage: String = "Unknown error") -> PNError {
        return PNError(code: .unknown, message: error.localizedDescription, underlyingError: error)
    }
}

extension PNError: LocalizedError {
    public var errorDescription: String? {
        return message
    }
}

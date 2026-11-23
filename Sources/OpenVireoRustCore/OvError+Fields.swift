// Field access for the single-variant `OvError` the binding generates (see src/error.rs), so
// callers write `error.code` / `error.wireCode` instead of pattern matching.
import Foundation

public extension OvError {
    /// An error with `code` and `message`, for Host implementations to throw.
    init(code: OvErrorCode, message: String) {
        self = makeOvError(code: code, message: message)
    }

    /// The typed code.
    var code: OvErrorCode {
        switch self { case let .Failure(code, _, _, _, _, _, _): return code }
    }

    /// The stable string the TS SDK's `err.code` holds (`"plan_limit"`, or the server's own code).
    var wireCode: String {
        switch self { case let .Failure(_, wireCode, _, _, _, _, _): return wireCode }
    }

    /// The message (English, for logs).
    var message: String {
        switch self { case let .Failure(_, _, message, _, _, _, _): return message }
    }

    /// The HTTP status, for server errors.
    var status: UInt16? {
        switch self { case let .Failure(_, _, _, status, _, _, _): return status }
    }

    /// `Retry-After` seconds, for `rateLimited`.
    var retryAfter: UInt32? {
        switch self { case let .Failure(_, _, _, _, retryAfter, _, _): return retryAfter }
    }

    /// Extra details as a JSON object string.
    var details: String? {
        switch self { case let .Failure(_, _, _, _, _, details, _): return details }
    }

    /// The server's code when it isn't an `OvErrorCode`.
    var serverCode: String? {
        switch self { case let .Failure(_, _, _, _, _, _, serverCode): return serverCode }
    }
}

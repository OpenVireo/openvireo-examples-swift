import Foundation
import OpenVireoRustCore

// The core does no I/O: the Host is the platform's part. This one is enough for a command-line program
// on macOS: URLSession for HTTP, and memory for the secure store and the offline cache (so every run is
// a new device). An app keeps the store in the Keychain and the cache on disk; the iOS app's Host does.

/// A Host for the examples.
func makeHost() -> OpenVireoRustCore.Host {   // qualified: Foundation has a Host class on macOS
    OpenVireoRustCore.Host(http: URLSessionTransport(), store: MemoryStore(), cache: MemoryCache(), clock: SystemClock(), log: StderrLog())
}

/// HTTP on URLSession. Two rules apply to every transport: it must not follow redirects, and it must
/// not send or store cookies. Every status is a response; only a request that got no answer at all is
/// a `TransportError`.
final class URLSessionTransport: NSObject, HttpTransport, URLSessionTaskDelegate, @unchecked Sendable {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    func send(req: HttpRequest) async throws -> HttpResponse {
        do {
            let (data, response) = try await session.data(for: try Self.urlRequest(req))
            guard let http = response as? HTTPURLResponse else { throw TransportError.Other(message: "not an HTTP response") }
            return HttpResponse(status: UInt16(clamping: http.statusCode), headers: Self.headers(http), body: data)
        } catch let e as TransportError {
            throw e
        } catch {
            throw Self.transportError(error)
        }
    }

    func openStream(req: HttpRequest) async throws -> OpenedStream {
        var request = try Self.urlRequest(req)
        request.timeoutInterval = .infinity   // the event stream stays open; it has its own keep-alive
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw TransportError.Other(message: "not an HTTP response") }
            return OpenedStream(stream: URLByteStream(bytes: bytes, status: UInt16(clamping: http.statusCode)))
        } catch let e as TransportError {
            throw e
        } catch {
            throw Self.transportError(error)
        }
    }

    // no redirects: a 3xx goes back to the core as a response
    func urlSession(_: URLSession, task _: URLSessionTask, willPerformHTTPRedirection _: HTTPURLResponse,
                    newRequest _: URLRequest) async -> URLRequest? {
        nil
    }

    static func urlRequest(_ req: HttpRequest) throws -> URLRequest {
        guard let url = URL(string: req.url) else { throw TransportError.Other(message: "invalid URL") }
        var r = URLRequest(url: url)
        r.httpMethod = switch req.method {
        case .get: "GET"
        case .head: "HEAD"
        case .post: "POST"
        case .put: "PUT"
        case .patch: "PATCH"
        case .delete: "DELETE"
        }
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.httpShouldHandleCookies = false
        for h in req.headers { r.addValue(h.value, forHTTPHeaderField: h.name) }
        r.httpBody = req.body
        return r
    }

    static func headers(_ http: HTTPURLResponse) -> [HttpHeader] {
        http.allHeaderFields.compactMap { k, v in (k as? String).map { HttpHeader(name: $0, value: "\(v)") } }
    }

    static func transportError(_ error: any Error) -> TransportError {
        if error is CancellationError { return .Cancelled }
        guard let e = error as? URLError else { return .Other(message: error.localizedDescription) }
        switch e.code {
        case .cancelled: return .Cancelled
        case .timedOut: return .Timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .Offline
        case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
            return .Tls(message: e.localizedDescription)
        default: return .Other(message: e.localizedDescription)
        }
    }
}

/// An open server-sent events response, handed to the core a line at a time.
final class URLByteStream: ByteStream, @unchecked Sendable {
    private let bytes: URLSession.AsyncBytes
    private var iterator: URLSession.AsyncBytes.AsyncIterator
    private let statusCode: UInt16
    private let lock = NSLock()
    private var closed = false

    init(bytes: URLSession.AsyncBytes, status: UInt16) {
        self.bytes = bytes
        iterator = bytes.makeAsyncIterator()
        statusCode = status
    }

    func status() -> UInt16 { statusCode }

    func nextChunk() async throws -> Data? {
        if lock.withLock({ closed }) { return nil }
        var chunk = Data()
        do {
            while let b = try await iterator.next() {
                chunk.append(b)
                if b == UInt8(ascii: "\n") || chunk.count >= 16 * 1024 { break }
            }
        } catch {
            if lock.withLock({ closed }) { return chunk.isEmpty ? nil : chunk }
            throw URLSessionTransport.transportError(error)
        }
        return chunk.isEmpty ? nil : chunk
    }

    func close() {
        lock.withLock { closed = true }
        bytes.task.cancel()
    }
}

/// Sessions and trusted-device keys, in memory. An app keeps them in the Keychain.
final class MemoryStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func get(key: String) async throws -> Data? { lock.withLock { values[key] } }
    func set(key: String, value: Data) async throws { lock.withLock { values[key] = value } }
    func delete(key: String) async throws { lock.withLock { _ = values.removeValue(forKey: key) } }
}

/// The offline copies, in memory. An app keeps them on disk so it can open vaults offline.
final class MemoryCache: BlobCache, @unchecked Sendable {
    private let lock = NSLock()
    private var vaults: [String: [String: CachedVault]] = [:]
    private var meta: [String: [String: Data]] = [:]

    func load(userId: String, vaultId: String) async throws -> CachedVault? { lock.withLock { vaults[userId]?[vaultId] } }
    func save(userId: String, vaultId: String, v: CachedVault) async throws { lock.withLock { vaults[userId, default: [:]][vaultId] = v } }
    func remove(userId: String, vaultId: String) async throws { lock.withLock { _ = vaults[userId]?.removeValue(forKey: vaultId) } }
    func list(userId: String) async throws -> [String] { lock.withLock { Array(vaults[userId, default: [:]].keys) } }
    func loadMeta(userId: String, name: String) async throws -> Data? { lock.withLock { meta[userId]?[name] } }
    func saveMeta(userId: String, name: String, value: Data) async throws { lock.withLock { meta[userId, default: [:]][name] = value } }
    func clearUser(userId: String) async throws {
        lock.withLock {
            vaults[userId] = nil
            meta[userId] = nil
        }
    }
}

final class SystemClock: Clock, @unchecked Sendable {
    func nowUnixMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}

/// Warnings and errors to stderr; set OV_LOG=debug for more.
final class StderrLog: LogSink, @unchecked Sendable {
    private let verbose = ProcessInfo.processInfo.environment["OV_LOG"] == "debug"

    func log(level: Level, target: String, msg: String) {
        switch level {
        case .error, .warn: break
        case .info, .debug, .trace: if !verbose { return }
        }
        FileHandle.standardError.write(Data("[\(level)] \(target): \(msg)\n".utf8))
    }
}

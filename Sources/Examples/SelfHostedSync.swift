import Foundation
import OpenVireoRustCore

/// A self-hosted sync server: pairing a device, syncing a .kdbx file, and the other calls.
///
/// Guide: https://developer.openvireo.com/sdk/guides/self-hosted-sync/
///
///     swift run Examples self-hosted-sync https://sync.example.org ABCD-EFGH personal Passwords.kdbx
///
/// Pairs with the server, syncs the file (password from KDBX_PASSWORD; the merged file is written back
/// to the same path) and shows the other calls. The examples' Host keeps the pairing in memory; with a
/// Keychain-backed SecureStore, restoreSelfHosted finds it again next launch.
enum SelfHostedSync {
    static let cancel = CancelToken()

    // Pairing
    static func pair(_ client: OvClient, url: String, code: String) async throws -> SelfHosted {
        try await SelfHosted.pair(client: client, serverUrl: url, code: code, deviceName: "Mac", cancel: cancel)
    }

    static func restore(_ client: OvClient, url: String) async throws -> SelfHosted? {
        try await restoreSelfHosted(client: client, serverUrl: url)   // next time, with the same persistent store
    }

    // Syncing a database
    static func syncFile(_ server: SelfHosted, databaseId: String, url: URL, password: Data) async throws {
        let creds = KdbxCredentials(password: password, keyFile: nil)
        let result = try await server.syncDatabase(databaseId: databaseId, kdbx: try Data(contentsOf: url), credentials: creds, cancel: cancel)
        // result.kdbx is the merged file: save it locally and reopen it (result.report says what changed)
        try result.kdbx.write(to: url)
        print(result.report)
    }

    // Other calls
    static func otherCalls(_ server: SelfHosted) async throws {
        print(try await server.health(cancel: cancel))   // '{"status":"ok"}'
        for db in try await server.listDatabases(cancel: cancel) { print(db.id, db.revision, db.size, db.updatedAt) }
        let first = try await server.download(databaseId: "personal", cancel: cancel)   // the .kdbx, or nil
        print("personal:", first.map { "\($0.count) bytes" } ?? "none")
        let code = try await server.createPairingCode(cancel: cancel).code   // for the next device
        print("pairing code for the next device:", code)
        let stream = try await server.events(cancel: cancel)   // next(cancel:) gives .databaseChanged
        try stream.close()
    }

    static func run(_ args: [String]) async throws {
        guard args.count == 4 else { usage("Usage: self-hosted-sync <server url> <pairing code> <database id> <file.kdbx>") }
        let client = makeClient(name: "Mac")
        let server = if let restored = try await restore(client, url: args[0]) { restored } else { try await pair(client, url: args[0], code: args[1]) }
        try await syncFile(server, databaseId: args[2], url: URL(fileURLWithPath: args[3]), password: Data(env("KDBX_PASSWORD").utf8))
        try await otherCalls(server)
    }
}

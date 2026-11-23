import Foundation
import OpenVireoRustCore

/// Account recovery: resetting with a recovery link, and restoring the old vaults afterwards.
///
/// Guide: https://developer.openvireo.com/sdk/guides/recovery/
///
///     swift run Examples recovery info <token>   # what a reset would do; works signed out
///     swift run Examples recovery status         # after a reset: is there an archive to restore?
///
/// reset() and restore() change the account, so they only run when you call them yourself.
enum Recovery {
    static let cancel = CancelToken()

    // Resetting
    static func info(_ account: Account, token: Data) async throws {
        let info = try await account.recoverInfo(token: token, cancel: cancel)   // works signed out
        print(info)
    }

    static func reset(_ account: Account, token: Data, newPassword: Data) async throws {
        let created = try await account.recover(token: token, password: newPassword, kdf: nil, trustDevice: true, cancel: cancel)
        print("Your new Secret Key (keep it safe):", text(created.secretKey))   // signed in and unlocked afterwards
    }

    // Restoring the old vaults
    static func restore(_ account: Account, oldPassword: Data, oldSecretKey: Data) async throws {
        let status = try await account.recoveryStatus(cancel: cancel)
        if status.archived && !status.locked {
            let restored = try await account.restoreFromArchive(oldPassword: oldPassword, oldSecretKey: oldSecretKey, cancel: cancel)
            print("restored", restored, "vault(s)")   // vault list reloaded
        }
    }

    static func run(_ args: [String]) async throws {
        let client = makeClient()
        if args.count == 2 && args[0] == "info" {
            try await info(try await client.connect(issuer: issuer, cancel: cancel), token: Data(args[1].utf8))
        } else if args == ["status"] {
            let account = try await signIn(client, cancel: cancel)
            print(try await account.recoveryStatus(cancel: cancel))
            try await account.signOut(forgetDevice: false, cancel: cancel)
        } else {
            usage("Usage: recovery info <token> | recovery status")
        }
    }
}

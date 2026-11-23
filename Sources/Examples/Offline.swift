import Foundation
import OpenVireoRustCore

/// Offline: edit from the cached copy while the servers can't be reached, and merge the edits in when
/// back online.
///
/// Guide: https://developer.openvireo.com/sdk/guides/offline/
///
/// To unlock offline after a relaunch, the Host needs a persistent SecureStore (the Keychain) and
/// BlobCache (files). The examples' Host keeps both in memory, so this program signs in (online) and
/// then edits, keeping the edit if the network drops.
///
///     swift run Examples offline "ov://Home/Wifi/password" "new value"
enum Offline {
    static func run(_ args: [String]) async throws {
        guard args.count == 2 else { usage("Usage: offline <ov://Vault/Entry/field> <value>") }
        let (reference, value) = (args[0], Data(args[1].utf8))
        let cancel = CancelToken()
        let client = makeClient(name: "Mac", offline: true)   // offline needs a Host with a persistent BlobCache
        let account = try await signIn(client, cancel: cancel)   // with one: client.connect, then account.unlock(password:secretKey:nil)
        let vaultName = reference.dropFirst("ov://".count).split(separator: "/").first.map(String.init) ?? ""
        guard let info = try await account.vaults(cancel: cancel).first(where: { $0.name == vaultName }) else {
            usage("No vault named \(vaultName)")
        }
        let vault = try await account.openVault(vaultId: info.id, cancel: cancel)   // offline: the local copy
        print("offline:", try account.isOffline())   // true while unreachable

        do {
            _ = try await vault.writeField(reference: reference, value: value, create: false, cancel: cancel)
        } catch let error as OvError where error.code == .networkError {
            print("Saved locally; it uploads when you're back online.")   // offline: the edit is kept and merges in later
        }

        if try account.isOffline() {
            let result = try await account.reconnect(cancel: cancel)   // back online; result.dropped: revoked vaults
            print("reconnected; dropped:", result.dropped)
            _ = try await vault.sync(options: SyncOptions(localChanged: true, acceptServerState: false), cancel: cancel)
        }
        try await account.signOut(forgetDevice: false, cancel: cancel)
    }
}

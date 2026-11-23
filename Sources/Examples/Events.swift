import Foundation
import OpenVireoRustCore

/// Live events: react when another device changes a vault, or when access changes.
///
/// Guide: https://developer.openvireo.com/sdk/guides/events/
///
/// Running it signs in, opens the first vault and prints events until the session ends (Ctrl-C to
/// stop). Edit something in another OpenVireo app to see one.
///
///     swift run Examples events
enum Events {
    static let cancel = CancelToken()

    static func render(_ vaults: [VaultInfo]) {
        print("Vaults now:", vaults.map(\.name).joined(separator: ", "))
    }

    static func watch(_ account: Account, vault: Vault) async throws {
        let stream = try await account.subscribe(cancel: cancel)
        defer { try? stream.close() }
        loop: while let event = try await stream.next(cancel: cancel) {
            switch event {
            case .vaultChanged(let vaultId, let etag, _, _):
                // another device uploaded (or deleted) a vault this account can open
                print("Vault changed:", vaultId)
                if try vaultId == vault.id() && etag != vault.etag() {
                    _ = try await vault.sync(options: SyncOptions(localChanged: false, acceptServerState: false), cancel: cancel)
                }
            case .vaultsChanged(let vaults): render(vaults)   // access changed
            case .sessionEnded: break loop
            default: break
            }
        }
    }

    static func run(_ args: [String]) async throws {
        let account = try await signIn(makeClient(), cancel: cancel)
        guard let first = try await account.vaults(cancel: cancel).first else {
            print("No vaults to watch.")
            return try await account.signOut(forgetDevice: false, cancel: cancel)
        }
        print("Watching for changes (Ctrl-C to stop)...")
        try await watch(account, vault: try await account.openVault(vaultId: first.id, cancel: cancel))
        try await account.signOut(forgetDevice: false, cancel: cancel)
    }
}

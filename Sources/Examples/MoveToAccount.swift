import Foundation
import OpenVireoRustCore

/// Moving a .kdbx file into an account: as a new vault, or merged into a vault you already have.
///
/// Guide: https://developer.openvireo.com/sdk/guides/move-to-account/
///
///     swift run Examples move-to-account Passwords.kdbx            # a new vault named after the file
///     swift run Examples move-to-account Passwords.kdbx Personal   # merge into the vault "Personal"
///
/// The file's password is read from KDBX_PASSWORD.
enum MoveToAccount {
    static let cancel = CancelToken()

    static func importAsNewVault(_ account: Account, fileBytes: Data, password: Data, name: String) async throws {
        let creds = KdbxCredentials(password: password, keyFile: nil)
        let outcome = try await account.importKdbx(kdbx: fileBytes, credentials: creds,
                                                   mode: .newVault(name: name, orgId: nil), cancel: cancel)
        if !outcome.uploaded {
            // the vault exists but its first upload failed (outcome.uploadError): retry it later
            _ = try await outcome.vault.sync(options: SyncOptions(localChanged: true, acceptServerState: false), cancel: cancel)
        }
        print("Imported into", try outcome.vault.name())
    }

    static func mergeInto(_ client: OvClient, vault: Vault, fileBytes: Data, password: Data) async throws {
        let file = try await client.openLocal(kdbx: fileBytes, credentials: KdbxCredentials(password: password, keyFile: nil), cancel: cancel)
        let summary = try vault.importFrom(source: file, mode: .merge)   // added, updated, unchanged
        // or: .copies(parentGroupId: groupId), with vault.importTargets() listing the groups to offer
        _ = try await vault.sync(options: SyncOptions(localChanged: true, acceptServerState: false), cancel: cancel)
        print(summary)
    }

    static func run(_ args: [String]) async throws {
        guard (1...2).contains(args.count) else { usage("Usage: move-to-account <file.kdbx> [vault name]") }
        let url = URL(fileURLWithPath: args[0])
        let fileBytes = try Data(contentsOf: url)
        let password = Data(env("KDBX_PASSWORD").utf8)
        let client = makeClient()
        let account = try await signIn(client, cancel: cancel)
        if args.count == 1 {
            try await importAsNewVault(account, fileBytes: fileBytes, password: password, name: url.deletingPathExtension().lastPathComponent)
        } else if let info = try await account.vaults(cancel: cancel).first(where: { $0.name == args[1] }) {
            try await mergeInto(client, vault: try await account.openVault(vaultId: info.id, cancel: cancel), fileBytes: fileBytes, password: password)
        } else {
            print("No vault named \(args[1])")
        }
        try await account.signOut(forgetDevice: false, cancel: cancel)
    }
}

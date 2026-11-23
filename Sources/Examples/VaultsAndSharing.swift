import Foundation
import OpenVireoRustCore

/// Vaults: listing and opening, reading and writing fields, editing entries, creating, sharing,
/// revoking and organisations.
///
/// Guide: https://developer.openvireo.com/sdk/guides/vaults-and-sharing/
///
/// Running it signs in, lists the vaults and the entries of the first one, and reads a field if you
/// pass an ov:// reference. Nothing is written unless you pass --write, which adds an "OpenVireo
/// example" entry to the first vault you can write to. The sharing and organisation functions are
/// here to read and copy; run() doesn't call them.
///
///     swift run Examples vaults-and-sharing ["ov://Vault/Entry/field"] [--write]
enum VaultsAndSharing {
    static let cancel = CancelToken()

    struct KeysDontVerify: Error {}
    struct NotConfirmed: Error {}

    // Listing and opening
    static func listAndOpen(_ account: Account) async throws -> Vault? {
        let vaults = try await account.vaults(cancel: cancel)   // VaultInfo: id, name, role (.read, .write, .manage), orgId
        for info in vaults { print(info.name, info.role, info.id) }
        guard let first = vaults.first else { return nil }

        let vault = try await account.openVault(vaultId: first.id, cancel: cancel)   // downloads and decrypts it
        print("Entries in \(try vault.name()) at \(try vault.etag() ?? "-")")   // the server version this copy is based on
        for e in try vault.entries(includeRecycleBin: false) { print(" ", e.title) }   // vault.entry(entryId:) the full record
        return vault
    }

    // Reading and writing fields
    static func readAndWrite(_ vault: Vault, key: Data) async throws {
        print(String(decoding: try vault.readField(reference: "ov://Team/GitHub/password"), as: UTF8.self))

        // edits and syncs; create: true creates the entry if needed
        _ = try await vault.writeField(reference: "ov://Team/GitHub/password", value: Data("new value".utf8), create: false, cancel: cancel)
        _ = try await vault.writeField(reference: "ov://Team/Apps/Stripe/api_key", value: key, create: true, cancel: cancel)
    }

    // Editing the database directly
    static func editEntries(_ vault: Vault) async throws {
        _ = try vault.addEntry(groupId: vault.rootGroupId(), input: EntryInput(
            fields: [
                FieldInput(name: "Title", value: Data("OpenVireo example".utf8), protected: nil),
                FieldInput(name: "UserName", value: Data("app".utf8), protected: nil),
                FieldInput(name: "Password", value: Data("s3cret".utf8), protected: nil),
            ],
            removeFields: [], tags: nil, iconId: nil, expiry: .keep,
            foregroundColor: nil, backgroundColor: nil, customIcon: nil, fieldOrder: nil))
        _ = try vault.setFields(reference: "ov://\(vault.name())/OpenVireo example", fields: [
            FieldInput(name: "UserName", value: Data("svc".utf8), protected: nil),
            FieldInput(name: "token", value: Data("...".utf8), protected: true),
        ], create: .createIfMissing)

        let result = try await vault.sync(options: SyncOptions(localChanged: true, acceptServerState: false), cancel: cancel)
        print(result.outcome)     // .uploaded, .pulled (only downloaded), .created or .unchanged
        print(result.conflicts)   // entries both sides changed
        print(result.changes)     // what the merge did, entry by entry
    }

    // Creating vaults
    static func createVaults(_ account: Account, orgId: String) async throws {
        _ = try await account.createVault(name: "Personal", orgId: nil, cancel: cancel)
        _ = try await account.createVault(name: "Team Infra", orgId: orgId, cancel: cancel)   // admins get manage
    }

    // Sharing
    static func shareByEmail(_ account: Account, vaultId: String) async throws {
        let grant = try await account.shareVault(vaultId: vaultId, grantee: .email("bob@example.com"), role: .write, cancel: cancel)
        try confirmWithBob(grant.fingerprint)   // compare it with what Bob's app shows, out of band

        try await account.changeRole(vaultId: vaultId, principal: grant.principal, role: .read, cancel: cancel)
    }

    static func shareWithVerifiedKeys(_ account: Account, vaultId: String) async throws {
        let bob = try await account.lookUp(email: "bob@example.com", cancel: cancel)
        guard try verifyPublicKeys(keys: bob.publicKeys) else { throw KeysDontVerify() }
        try confirmWithBob(bob.publicKeys.fingerprint)
        _ = try await account.shareVaultWithKeys(vaultId: vaultId, grantee: .principal(bob.principal), role: .write,
                                                 keys: bob.publicKeys, cancel: cancel)
    }

    static func confirmWithBob(_ fingerprint: String) throws {
        guard prompt("Does Bob's app show \(fingerprint)? [y/N] ").lowercased() == "y" else { throw NotConfirmed() }
    }

    // Revoking and rotating
    static func revokeAndRotate(_ account: Account, vaultId: String, bobPrincipal: String) async throws {
        _ = try await account.revoke(vaultId: vaultId, principals: [bobPrincipal], cancel: cancel)   // and rotates the key
        _ = try await account.rotateVaultKey(vaultId: vaultId, remove: [], cancel: cancel)          // a new key only
    }

    // Organisations
    static func organisations(_ account: Account, vaultId: String) async throws {
        let org = try await account.createOrg(name: "Acme", cancel: cancel)
        _ = try await account.invite(orgId: org.id, email: "carol@example.com", role: .member, cancel: cancel)
        // Carol gets an email, and her app calls account.acceptInvitation(token:cancel:)

        let members = try await account.orgMembers(orgId: org.id, cancel: cancel)
        guard let carol = members.first(where: { $0.email == "carol@example.com" && $0.status == .accepted }) else { return }
        _ = try await account.confirmMember(orgId: org.id, member: carol,
                                            vaults: [VaultGrantRequest(vaultId: vaultId, role: .read)], cancel: cancel)

        _ = try await account.setMemberRole(orgId: org.id, member: carol, role: .admin, cancel: cancel)   // manage everywhere
        let report = try await account.removeMember(orgId: org.id, userId: carol.userId, cancel: cancel)  // rotates her vaults
        print("rotated:", report.rotated, "failed:", report.failed)
    }

    static func run(_ args: [String]) async throws {
        let account = try await signIn(makeClient(), cancel: cancel)
        do {
            let vault = try await listAndOpen(account)
            if let vault, let ref = args.first(where: { $0.hasPrefix("ov://") }) {
                print(ref, "=", text(try vault.readField(reference: ref)))
            }
            if args.contains("--write"), let info = try await account.vaults(cancel: cancel).first(where: { $0.role != .read }) {
                try await editEntries(try await account.openVault(vaultId: info.id, cancel: cancel))
            }
        } catch {
            try? await account.signOut(forgetDevice: false, cancel: cancel)
            throw error
        }
        try await account.signOut(forgetDevice: false, cancel: cancel)
    }
}

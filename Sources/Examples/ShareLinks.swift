import Foundation
import OpenVireoRustCore

/// Share links: share one item, or some text, through a link that needs no account; list and revoke
/// links; open one.
///
/// Guide: https://developer.openvireo.com/sdk/guides/share-links/
///
///     swift run Examples share-links list
///     swift run Examples share-links text "The alarm code is 4321"
///     swift run Examples share-links open "https://share.openvireo.com/<id>#<key>"
enum ShareLinks {
    static let cancel = CancelToken()

    // Making a link
    static func shareEntry(_ account: Account, vault: Vault, entryId: String) async throws -> String {
        let entry = try vault.entry(entryId: entryId)
        let choices = try shareableFields(entry: entry)   // what can be shared, in display order
        print("can share:", choices.map(\.name))

        let payload = try itemSharePayload(entry: entry, names: try defaultShareFields(), sharedBy: "Sam")   // username, password, website
        let link = try await account.createShare(payload: payload, options: ShareOptions(
            expiresIn: 7 * 86400,   // seconds: 1 hour to 30 days (free plans: 7 days)
            maxOpens: 1,            // nil: until it expires
            passcode: nil, vaultId: vault.id(), entryId: entryId), cancel: cancel)
        return String(decoding: link.url, as: UTF8.self)   // https://share.openvireo.com/<id>#<key>
    }

    static func shareText(_ account: Account, _ message: String) async throws -> String {
        let link = try await account.createShare(
            payload: try textSharePayload(text: Data(message.utf8), title: "From the examples", sharedBy: nil),
            options: ShareOptions(expiresIn: 3600, maxOpens: nil, passcode: Data("tiger lily 42".utf8), vaultId: nil, entryId: nil),
            cancel: cancel)
        return text(link.url)
    }

    // Listing and revoking
    static func listShares(_ account: Account) async throws {
        for s in try await account.listShares(cancel: cancel) {
            // s.reference has vault, entry, title, readable only by this account
            print(s.id, s.reference?.title ?? "", s.status, s.opens, s.maxOpens ?? 0, s.expiresAt, s.endReason ?? "")
        }
    }

    static func revoke(_ account: Account, shareId: String) async throws {
        try await account.revokeShare(shareId: shareId, cancel: cancel)
    }

    static func orgPolicy(_ account: Account, orgId: String) async throws {
        _ = try await account.setOrgShareLinks(orgId: orgId, policy: .managers, cancel: cancel)   // .on (default), .managers, .off
    }

    // Opening a link
    static func openLink(_ client: OvClient, api: String, link: String) async throws {
        let info = try await client.shareInfo(api: api, shareId: try parseShareLink(link: link).id, cancel: cancel)
        // Show a "Reveal" button and open only when it's pressed: link previews then can't use up a one-time link.
        _ = prompt("Press Enter to reveal... ")
        let passcode = info.kdf != nil ? Data(prompt("Passcode: ").utf8) : nil
        let opened = try await client.openShare(api: api, link: Data(link.utf8), passcode: passcode, info: info, cancel: cancel)

        for f in opened.payload.fields {
            let shown = f.k == "totp"
                ? try totpCode(params: try parseTotpUri(uri: f.value), nowMs: Int64(Date().timeIntervalSince1970 * 1000)).code
                : f.value
            // render as plain text; hide f.protected values until shown
            print("\(f.label): \(shown)")
        }
    }

    static func run(_ args: [String]) async throws {
        let client = makeClient()
        let account = try await signIn(client, cancel: cancel)
        switch (args.first, args.count) {
        case ("list", 1): try await listShares(account)
        case ("text", 2): print(try await shareText(account, args[1]) + "\npasscode: tiger lily 42")
        case ("open", 2): try await openLink(client, api: account.serverConfig().api, link: args[1])   // or the share host's API
        default: usage("Usage: share-links list | text <text> | open <link>")
        }
        try await account.signOut(forgetDevice: false, cancel: cancel)
    }
}

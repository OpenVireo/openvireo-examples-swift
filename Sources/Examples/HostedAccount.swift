import Foundation
import OpenVireoRustCore

/// Hosted accounts: connecting, signing up and in, locking, the account itself, devices and deletion.
///
/// Guide: https://developer.openvireo.com/sdk/guides/hosted-account/
///
/// Running it signs in, prints the account and its devices, locks and unlocks, and signs out. The
/// functions that change the account (signUp, changePassword, deleteAccount, ...) are here to read and
/// copy; run() doesn't call them.
///
///     swift run Examples hosted-account
enum HostedAccount {
    static let cancel = CancelToken()

    // Connecting
    static func connect() async throws -> (OvClient, Account) {
        // host: your Host (HTTP, a Keychain-backed SecureStore, a cache, a clock, a log sink)
        let client = OvClient(
            config: ClientConfig(device: DeviceInfo(id: nil, name: "Mac", platform: .cli), offline: false, server: nil),
            host: makeHost())
        return (client, try await client.connect(issuer: issuer, cancel: cancel))
    }

    // Signing up
    static func signUp(_ account: Account, email: String, password: Data) async throws {
        let created = try await account.register(
            input: RegisterInput(email: email, password: password, kdf: nil, trustDevice: true), cancel: cancel)
        showEmergencyKit(created.secretKey)   // the only time the Secret Key is shown; the user must keep it
    }

    static func showEmergencyKit(_ secretKey: Data) {
        print("Your Secret Key (keep it safe):", text(secretKey))
    }

    // Signing in
    static func signIn(_ account: Account, email: String, password: Data, secretKey: Data?) async throws {
        // secretKey: only needed the first time on this device (else nil)
        var step = try await account.login(
            input: LoginInput(email: email, password: password, secretKey: secretKey, totp: nil, trustDevice: true),
            cancel: cancel)
        while case .needsTotp(let challenge) = step {   // two-factor authentication is on
            step = try await account.submitTotp(challenge: challenge, code: askForCode(), cancel: cancel)
        }
    }

    // Unlocking and locking
    static func lockAndUnlock(_ account: Account, password: Data) async throws {
        try account.lock()   // wipes the keys from memory; the session stays
        if try account.isSignedIn(), try !account.isUnlocked() {
            _ = try await account.unlock(password: password, secretKey: nil, cancel: cancel)
        }
    }

    static func signOut(_ account: Account, forgetDevice: Bool) async throws {
        // false ends the session and forgets it here; true also forgets the trusted Secret Key
        try await account.signOut(forgetDevice: forgetDevice, cancel: cancel)
    }

    // Staying unlocked across a relaunch
    static func stayUnlocked(_ account: Account, reloaded: Account) async throws {
        let secret = try account.unlockedKeysetSecret()   // keep it in the Keychain
        // after a relaunch, on a connected (signed-in, locked) account
        try await reloaded.resumeUnlocked(keysetSecret: secret, cancel: cancel)
    }

    static func watchForSignOut(_ account: Account) async throws {
        let reason = try await account.signedOut(cancel: cancel)   // .sessionExpired, .tokenReused, .unauthorized, .logout, ...
        print("Signed out:", reason)
    }

    // The account itself
    static func showAccount(_ account: Account) throws {
        print("email:", try account.email() ?? "")
        print("user id:", try account.userId() ?? "")
        print("fingerprint:", try account.fingerprint())   // this account's public key fingerprint, for others to compare
    }

    static func changePassword(_ account: Account, current: Data, next: Data) async throws {
        _ = try await account.changePassword(current: current, next: next, kdf: nil, cancel: cancel)   // signs others out
    }

    static func changeEmail(_ account: Account, to newEmail: String, password: Data) async throws {
        try await account.requestEmailChange(email: newEmail, cancel: cancel)   // mails a code
        let code = prompt("Code sent to \(newEmail): ")
        try await account.changeEmail(email: newEmail, code: code, password: password, cancel: cancel)
    }

    static func accountWebsiteLink(_ account: Account) async throws -> String {
        String(decoding: try await account.webSessionUrl(next: "/settings", cancel: cancel), as: UTF8.self)   // one-time (60 s)
    }

    // Devices
    static func listDevices(_ account: Account) async throws {
        for d in try await account.devices(cancel: cancel) {   // name, platform, lastSeenAt, current, ...
            print(d.name, d.platform, d.lastSeenAt, d.current ? "(this device)" : "")
        }
    }

    static func revokeDevice(_ account: Account, named name: String) async throws {
        let devices = try await account.devices(cancel: cancel)
        if let old = devices.first(where: { !$0.current && $0.name == name }) {
            try await account.revokeDevice(deviceId: old.id, cancel: cancel)
        }
    }

    // Deleting the account
    static func deleteAccount(_ account: Account, password: Data, typedEmail: String, heir: String?) async throws {
        let preview = try await account.deletionPreview(cancel: cancel)
        print("would be erased on", preview.eraseOn)
        print("vaults:", preview.vaults.map { ($0.name, $0.sharedWith) })   // shared vaults can be given away first
        print("orgs:", preview.orgs.map { ($0.name, $0.outcome) })          // leave, delete or blocked
        if let heir, let vault = preview.vaults.first, !vault.sharedWith.isEmpty {
            try await account.transferVault(vaultId: vault.id, to: heir, cancel: cancel)
        }

        let scheduledFor = try await account.deleteAccount(password: password, confirm: typedEmail, cancel: cancel)
        print("scheduled for", scheduledFor)
        // This device is signed out and its offline cache is gone. The Secret Key stays, so after signing in again:
        if try account.deletionScheduledFor() != nil {
            try await account.restoreAccount(password: password, cancel: cancel)
        }
    }

    static func run(_ args: [String]) async throws {
        let password = Data(env("OV_PASSWORD").utf8)
        let (_, account) = try await connect()
        try await signIn(account, email: env("OV_EMAIL"), password: password, secretKey: Data(env("OV_SECRET_KEY").utf8))
        try showAccount(account)
        try await listDevices(account)
        try await lockAndUnlock(account, password: password)
        try await signOut(account, forgetDevice: false)
    }
}

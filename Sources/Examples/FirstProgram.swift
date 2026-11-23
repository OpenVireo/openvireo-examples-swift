import Foundation
import OpenVireoRustCore

/// A first program: sign in, list the vaults, read one field and sign out.
///
/// Guide: https://developer.openvireo.com/sdk/#a-first-program
///
///     swift run Examples first-program "ov://Personal/GitHub/username"
enum FirstProgram {
    static func firstProgram(email: String, password: Data, secretKey: Data, reference: String?) async throws {
        // The Host is the platform's part: HTTP, a secure store, a cache, a clock and a log sink (Host.swift)
        let host = makeHost()
        let client = OvClient(
            config: ClientConfig(device: DeviceInfo(id: nil, name: "My script", platform: .cli), offline: false, server: nil),
            host: host)
        let cancel = CancelToken()
        let account = try await client.connect(issuer: issuer, cancel: cancel)
        // The LoginStep asks for a TOTP code when two-step sign-in is on: see HostedAccount
        _ = try await account.login(
            input: LoginInput(email: email, password: password, secretKey: secretKey, totp: nil, trustDevice: true),
            cancel: cancel)

        let vaults = try await account.vaults(cancel: cancel)
        for info in vaults { print(info.name, info.role) }
        if let first = vaults.first, let reference {
            let vault = try await account.openVault(vaultId: first.id, cancel: cancel)
            print(String(decoding: try vault.readField(reference: reference), as: UTF8.self))
        }
        try await account.signOut(forgetDevice: false, cancel: cancel)
    }

    static func run(_ args: [String]) async throws {
        try await firstProgram(email: env("OV_EMAIL"), password: Data(env("OV_PASSWORD").utf8),
                               secretKey: Data(env("OV_SECRET_KEY").utf8), reference: args.first)
    }
}

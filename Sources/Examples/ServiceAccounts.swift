import Foundation
import OpenVireoRustCore

/// Service accounts: create one for CI, then read, inject and write secrets with its token.
///
/// Guide: https://developer.openvireo.com/sdk/guides/service-accounts/
///
///     OPENVIREO_SERVICE_ACCOUNT_TOKEN=... swift run Examples service-accounts "ov://Team Infra/CI/token"
///
/// create() needs an organisation owner or admin signed in, so run() doesn't call it. Set ROTATE to a
/// new value to also write it (needs the write role).
enum ServiceAccounts {
    static let cancel = CancelToken()

    // Creating one
    static func create(_ account: Account, orgId: String, vaultId: String) async throws {
        let created = try await account.createServiceAccount(orgId: orgId, input: NewServiceAccount(
            name: "ci", vaults: [VaultGrantRequest(vaultId: vaultId, role: .read)],
            expiresAt: "2027-01-01T00:00:00Z", secretName: nil), cancel: cancel)
        print(text(created.token))   // show it once; store it as a CI secret

        _ = try await account.issueServiceAccountSecret(saId: created.serviceAccount.id, name: "staging", expiresAt: nil, cancel: cancel)
    }

    // Reading and writing
    static func run(_ args: [String]) async throws {
        guard let reference = args.first, args.count == 1 else { usage("Usage: service-accounts <ov://Vault/Entry/field>") }
        let client = makeClient(name: "CI")
        let token = Data(env("OPENVIREO_SERVICE_ACCOUNT_TOKEN").utf8)
        let sa = try await ServiceAccount.fromToken(client: client, token: token, cancel: cancel)
        defer { try? sa.close() }   // wipes the keys from memory
        let password = try await sa.read(reference: reference, cancel: cancel)
        print("\(reference): \(password.count) bytes")

        let template = "TOKEN=\(reference.replacingOccurrences(of: " ", with: "%20"))\n"
        let injected = try await sa.inject(template: Data(template.utf8), cancel: cancel)   // mask injected.secrets in logs
        print("injected \(injected.secrets.count) secret(s)")

        if let rotated = ProcessInfo.processInfo.environment["ROTATE"] {
            try await sa.write(reference: reference, value: Data(rotated.utf8), create: false, cancel: cancel)   // needs the write role
        }
    }
}

import Foundation
import OpenVireoRustCore

/// The account server: OV_ISSUER, or the hosted one.
let issuer = ProcessInfo.processInfo.environment["OV_ISSUER"] ?? "https://accounts.openvireo.com"

func env(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        FileHandle.standardError.write(Data("Set \(name) to run this example.\n".utf8))
        exit(1)
    }
    return value
}

func usage(_ text: String) -> Never {
    FileHandle.standardError.write(Data((text + "\n").utf8))
    exit(2)
}

func prompt(_ text: String) -> String {
    print(text, terminator: "")
    return readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
}

func askForCode() -> String { prompt("Authenticator code: ") }

func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

func makeClient(name: String = "OpenVireo examples", offline: Bool = false) -> OvClient {
    OvClient(
        config: ClientConfig(device: DeviceInfo(id: nil, name: name, platform: .cli), offline: offline, server: nil),
        host: makeHost())
}

/// Connects and signs in from OV_EMAIL, OV_PASSWORD and OV_SECRET_KEY, asking for a TOTP code when needed.
func signIn(_ client: OvClient, cancel: CancelToken) async throws -> Account {
    let account = try await client.connect(issuer: issuer, cancel: cancel)
    let secretKey = ProcessInfo.processInfo.environment["OV_SECRET_KEY"].map { Data($0.utf8) }
    var step = try await account.login(
        input: LoginInput(email: env("OV_EMAIL"), password: Data(env("OV_PASSWORD").utf8), secretKey: secretKey,
                          totp: nil, trustDevice: true),
        cancel: cancel)
    while case .needsTotp(let challenge) = step {
        step = try await account.submitTotp(challenge: challenge, code: askForCode(), cancel: cancel)
    }
    return account
}

/// Loads the core and reaches the account server, without signing in.
func check(_ args: [String]) async throws {
    let account = try await makeClient().connect(issuer: issuer, cancel: CancelToken())
    print("Connected to \(issuer) (API \(try account.serverConfig().api)); signed in: \(try account.isSignedIn())")
}

import Foundation

/// The examples, by the name you pass to `swift run Examples <name> ...`.
let examples: [(String, ([String]) async throws -> Void)] = [
    ("first-program", FirstProgram.run),
    ("hosted-account", HostedAccount.run),
    ("vaults-and-sharing", VaultsAndSharing.run),
    ("events", Events.run),
    ("offline", Offline.run),
    ("move-to-account", MoveToAccount.run),
    ("recovery", Recovery.run),
    ("self-hosted-sync", SelfHostedSync.run),
    ("service-accounts", ServiceAccounts.run),
    ("share-links", ShareLinks.run),
    ("check", check),
]

@main
struct Main {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let name = args.first, let run = examples.first(where: { $0.0 == name })?.1 else {
            usage("Usage: swift run Examples <example> [args]\nExamples: \(examples.map(\.0).joined(separator: ", "))")
        }
        do {
            try await run(Array(args.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }
}

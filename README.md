# OpenVireo examples: Swift

Runnable examples for the [OpenVireo](https://openvireo.com) Swift binding (`OpenVireoRustCore`), one
file per guide on [developer.openvireo.com](https://developer.openvireo.com). Each file holds the code from
its guide's **Swift** tab, wrapped in a command-line program for macOS.

Examples in other languages: [TypeScript](https://github.com/openvireo/openvireo-examples-typescript) · [Rust](https://github.com/openvireo/openvireo-examples-rust) · [Python](https://github.com/openvireo/openvireo-examples-python) · [Kotlin](https://github.com/openvireo/openvireo-examples-kotlin) · [Java](https://github.com/openvireo/openvireo-examples-java) · [C++](https://github.com/openvireo/openvireo-examples-cpp) · [ov CLI](https://github.com/openvireo/openvireo-examples-cli)

## Run them

You need macOS 13 or newer and Xcode 16 (Swift 6). The package depends on the core's
Swift package [openvireo-swift](https://github.com/openvireo/openvireo-swift): the core's
`OpenVireoCore.xcframework` (iOS, iOS simulator, macOS) with the UniFFI Swift API over it.

```sh
git clone https://github.com/openvireo/openvireo-examples-swift
cd openvireo-examples-swift
swift run Examples check
```

Set your account in the environment. `OV_SECRET_KEY` is only needed the first time on a device;
`OV_ISSUER` picks an account server other than `https://accounts.openvireo.com`.

```sh
export OV_EMAIL=you@example.com OV_PASSWORD='...' OV_SECRET_KEY='A3-...'
```

```sh
swift run Examples first-program "ov://Personal/GitHub/username"
swift run Examples vaults-and-sharing
```

### The Host

The core does no I/O: every program passes it a Host for HTTP, a secure store, an offline cache, a
clock and logging. [`Host.swift`](Sources/Examples/Host.swift) is a small one on Foundation: URLSession
with no redirects and no cookies, and memory for the store and the cache. An app keeps the store in the
Keychain and the cache on disk so it can open vaults offline.

### Using the core in your own package

Add the package, as [`Package.swift`](Package.swift) does, or in Xcode with **File → Add Package
Dependencies…** and `https://github.com/openvireo/openvireo-swift`:

```swift
.package(url: "https://github.com/openvireo/openvireo-swift", from: "1.2.0"),
// in the target:
.product(name: "OpenVireoRustCore", package: "openvireo-swift"),
```

## The examples

| Example | What it does | Guide |
|---|---|---|
| [`FirstProgram.swift`](Sources/Examples/FirstProgram.swift) | Sign in, list the vaults, read one field, sign out | [A first program](https://developer.openvireo.com/sdk/#a-first-program) |
| [`HostedAccount.swift`](Sources/Examples/HostedAccount.swift) | Connect, sign up, sign in with two-step codes, lock, devices, account deletion | [Hosted accounts](https://developer.openvireo.com/sdk/guides/hosted-account/) |
| [`VaultsAndSharing.swift`](Sources/Examples/VaultsAndSharing.swift) | List, open, read, write and edit vaults; share, revoke, organisations | [Vaults and sharing](https://developer.openvireo.com/sdk/guides/vaults-and-sharing/) |
| [`Events.swift`](Sources/Examples/Events.swift) | Follow live changes from other devices | [Events](https://developer.openvireo.com/sdk/guides/events/) |
| [`Offline.swift`](Sources/Examples/Offline.swift) | Edit offline, merge when back online | [Offline](https://developer.openvireo.com/sdk/guides/offline/) |
| [`MoveToAccount.swift`](Sources/Examples/MoveToAccount.swift) | Import a `.kdbx` file as a new vault or merge it into one | [Moving to an account](https://developer.openvireo.com/sdk/guides/move-to-account/) |
| [`Recovery.swift`](Sources/Examples/Recovery.swift) | Inspect a recovery link, reset, restore the old vaults | [Recovery](https://developer.openvireo.com/sdk/guides/recovery/) |
| [`SelfHostedSync.swift`](Sources/Examples/SelfHostedSync.swift) | Pair with a self-hosted sync server and sync a `.kdbx` file | [Self-hosted sync](https://developer.openvireo.com/sdk/guides/self-hosted-sync/) |
| [`ServiceAccounts.swift`](Sources/Examples/ServiceAccounts.swift) | Create a service account; read, inject and write with its token | [Service accounts](https://developer.openvireo.com/sdk/guides/service-accounts/) |
| [`ShareLinks.swift`](Sources/Examples/ShareLinks.swift) | Share an item or text by link, list and revoke links, open one | [Share links](https://developer.openvireo.com/sdk/guides/share-links/) |

Each file has one function per section of its guide. Running an example does something safe and
mostly read-only; the functions that change an account for good (deleting it, revoking access,
rotating keys) are there to read and copy, and the programs don't call them. Try the rest on a test
account. `check` reaches the account server without signing in, to test the setup.

## Checks

CI builds the package and runs `check` on macOS, on every push and weekly:

```sh
swift build
```

## License

MIT. Copy the code into your own programs.

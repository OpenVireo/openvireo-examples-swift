#!/bin/sh
# Points the package at another core release: the xcframework URL and checksum in Package.swift, and
# the UniFFI Swift source that matches it, with the OvError field extension from the same tag.
#   scripts/update-core.sh 1.0.1
set -eu
version=${1:?usage: scripts/update-core.sh <version>}
base="https://github.com/openvireo/openvireo-core/releases/download/v$version"
cd "$(dirname "$0")/.."
checksum=$(curl -fsSL "$base/OpenVireoCore.xcframework.zip.checksum" | tr -d '[:space:]')
curl -fsSL "$base/OpenVireoRustCore.swift" -o Sources/OpenVireoRustCore/OpenVireoRustCore.swift
# error.code, error.wireCode, ...: a small hand-written extension the release doesn't attach
curl -fsSL "https://raw.githubusercontent.com/openvireo/openvireo-core/v$version/bindings/ov-ffi/Sources/OpenVireoRustCore/OvError%2BFields.swift" \
  -o "Sources/OpenVireoRustCore/OvError+Fields.swift"
sed -i.bak -e "s/^let coreVersion = .*/let coreVersion = \"$version\"/" \
           -e "s/^let coreChecksum = .*/let coreChecksum = \"$checksum\"/" Package.swift
rm Package.swift.bak
echo "OpenVireo core $version ($checksum)"

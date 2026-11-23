#!/bin/sh
# Points the package at another core release: the xcframework URL and checksum in Package.swift, and
# the Swift source that matches it (with the OvError field extension).
#   scripts/update-core.sh 1.0.1
set -eu
version=${1:?usage: scripts/update-core.sh <version>}
base="https://github.com/openvireo/openvireo-core/releases/download/v$version"
cd "$(dirname "$0")/.."
checksum=$(curl -fsSL "$base/OpenVireoCore.xcframework.zip.checksum" | tr -d '[:space:]')
curl -fsSL "$base/OpenVireoRustCore.swift" -o Sources/OpenVireoRustCore/OpenVireoRustCore.swift
# error.code, error.wireCode, ...: releases after 1.0.0 append the extension to the source; 1.0.0
# didn't, so take it from the tag then
if grep -q 'OvError+Fields.swift (hand-written' Sources/OpenVireoRustCore/OpenVireoRustCore.swift; then
  rm -f "Sources/OpenVireoRustCore/OvError+Fields.swift"
else
  curl -fsSL "https://raw.githubusercontent.com/openvireo/openvireo-core/v$version/bindings/ov-ffi/Sources/OpenVireoRustCore/OvError%2BFields.swift" \
    -o "Sources/OpenVireoRustCore/OvError+Fields.swift"
fi
sed -i.bak -e "s/^let coreVersion = .*/let coreVersion = \"$version\"/" \
           -e "s/^let coreChecksum = .*/let coreChecksum = \"$checksum\"/" Package.swift
rm Package.swift.bak
echo "OpenVireo core $version ($checksum)"

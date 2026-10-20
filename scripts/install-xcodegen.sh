#!/bin/bash
# Installs a pinned XcodeGen release after checking its SHA-256, instead of
# whatever version Homebrew serves on the day. Adds it to the job's PATH.
set -euo pipefail

VERSION="2.46.0"
SHA256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"

dest="${RUNNER_TEMP:?}/xcodegen-$VERSION"
curl -fsSL -o "$dest.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/$VERSION/xcodegen.zip"
echo "$SHA256  $dest.zip" | shasum -a 256 -c -
unzip -q "$dest.zip" -d "$dest"
echo "$dest/xcodegen/bin" >> "$GITHUB_PATH"

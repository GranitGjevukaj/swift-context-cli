#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <version> <sha256> <github-repo>" >&2
  exit 1
fi

VERSION="$1"
SHA256="$2"
REPO="$3"
FORMULA_FILE="Formula/swiftcontext.rb"

if [[ ! -f "$FORMULA_FILE" ]]; then
  echo "Formula file not found: $FORMULA_FILE" >&2
  exit 1
fi

if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "sha256 must be 64 lowercase hex characters" >&2
  exit 1
fi

URL="https://github.com/${REPO}/releases/download/v#{version}/swiftcontext-macos-universal.tar.gz"

perl -0pi -e "s/version \"[^\"]+\"/version \"$VERSION\"/g" "$FORMULA_FILE"
perl -0pi -e "s|url \"[^\"]+\"|url \"$URL\"|g" "$FORMULA_FILE"
perl -0pi -e "s/sha256 \"[0-9a-f]{64}\"/sha256 \"$SHA256\"/g" "$FORMULA_FILE"

echo "Updated $FORMULA_FILE to version $VERSION"

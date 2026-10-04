#!/usr/bin/env bash
# shellcheck source=/dev/null
# Usage: ./bootstrap.sh
# This script will:
#   - install the gems and link git hooks, when not running on CI
#   - install SwiftLint and SwiftFormat, unless `SKIP_SWIFT_BOOTSTRAP` is `true`

function puts {
  echo
  echo -e "👉 ${1}"
}

# Set bash to Strict Mode (http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -Eeuo pipefail

trap "echo ; echo ❌ The Bootstrap script failed to finish without error. See the log above to debug. ; echo" ERR

source ./Githubfile

if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
  puts "Set up git hooks"
  bundle install
  bundle exec lefthook install
fi

if [ "${SKIP_SWIFT_BOOTSTRAP:-}" != true ]; then
  puts "Install SwiftLint v${SWIFT_LINT_VERSION}"
  DOWNLOAD_URL="https://github.com/realm/SwiftLint/releases/download/${SWIFT_LINT_VERSION}/SwiftLint.pkg"
  DOWNLOAD_PATH="/tmp/SwiftLint-${SWIFT_LINT_VERSION}.pkg"
  wget "$DOWNLOAD_URL" -O "$DOWNLOAD_PATH"
  sudo installer -pkg "$DOWNLOAD_PATH" -target /
  swiftlint version

  puts "Install SwiftFormat v${SWIFT_FORMAT_VERSION}"
  DOWNLOAD_URL="https://github.com/nicklockwood/SwiftFormat/releases/download/${SWIFT_FORMAT_VERSION}/swiftformat.zip"
  DOWNLOAD_PATH="/tmp/swiftformat-${SWIFT_FORMAT_VERSION}.zip"
  BIN_PATH="/usr/local/bin/swiftformat"
  brew uninstall swiftformat || true
  wget "$DOWNLOAD_URL" -O "$DOWNLOAD_PATH"
  unzip -o "$DOWNLOAD_PATH" -d /tmp/swiftformat-${SWIFT_FORMAT_VERSION}
  sudo mv /tmp/swiftformat-${SWIFT_FORMAT_VERSION}/swiftformat "$BIN_PATH"
  sudo chmod +x "$BIN_PATH"
  swiftformat --version
fi

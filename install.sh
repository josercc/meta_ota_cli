#!/usr/bin/env bash
# Install meta_ota from the latest GitHub Release.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/josercc/meta_ota_cli/main/install.sh | bash
#   META_OTA_VERSION=v0.1.0 bash install.sh   # pin a tag
#   PREFIX=$HOME/.local bash install.sh       # install without sudo
set -euo pipefail

REPO="josercc/meta_ota_cli"
PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"
VERSION="${META_OTA_VERSION:-latest}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd uname
need_cmd mktemp

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

case "$os" in
  darwin)
    case "$arch" in
      arm64|aarch64) asset="meta_ota-macos-arm64" ;;
      x86_64)
        echo "error: macOS Intel (x86_64) binary is not published yet." >&2
        echo "       Build from source: dart compile exe bin/meta_ota.dart -o meta_ota" >&2
        exit 1
        ;;
      *) echo "error: unsupported macOS arch: $arch" >&2; exit 1 ;;
    esac
    ;;
  linux)
    case "$arch" in
      x86_64|amd64) asset="meta_ota-linux-x64" ;;
      *) echo "error: unsupported Linux arch: $arch (need x86_64)" >&2; exit 1 ;;
    esac
    ;;
  mingw*|msys*|cygwin*)
    echo "error: use PowerShell install.ps1 on Windows" >&2
    exit 1
    ;;
  *)
    echo "error: unsupported OS: $os" >&2
    exit 1
    ;;
esac

if [[ "$VERSION" == "latest" ]]; then
  api_url="https://api.github.com/repos/${REPO}/releases/latest"
else
  api_url="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
fi

echo "==> Resolving release (${VERSION})…"
json="$(curl -fsSL -H 'User-Agent: meta_ota-install' "$api_url")"
tag="$(printf '%s' "$json" | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | cut -d'"' -f4)"
download_url="$(printf '%s' "$json" | grep -oE "https://[^\"]+/${asset}" | head -n1)"

if [[ -z "$tag" || -z "$download_url" ]]; then
  echo "error: could not find asset '${asset}' in ${VERSION} release." >&2
  echo "       Check https://github.com/${REPO}/releases" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
tmpfile="${tmpdir}/meta_ota"

echo "==> Downloading ${asset} (${tag})…"
curl -fsSL "$download_url" -o "$tmpfile"
chmod +x "$tmpfile"

dest="${BIN_DIR}/meta_ota"
echo "==> Installing to ${dest}…"
mkdir -p "$BIN_DIR"
if [[ -w "$BIN_DIR" ]]; then
  mv "$tmpfile" "$dest"
else
  need_cmd sudo
  sudo mv "$tmpfile" "$dest"
fi

if [[ "$os" == "darwin" ]] && command -v xattr >/dev/null 2>&1; then
  xattr -d com.apple.quarantine "$dest" 2>/dev/null || true
fi

echo "==> Installed: $(command -v meta_ota 2>/dev/null || echo "$dest")"
"$dest" 2>/dev/null || true
echo "Done. Try: meta_ota --help"
if ! command -v meta_ota >/dev/null 2>&1; then
  echo "Note: add ${BIN_DIR} to your PATH if 'meta_ota' is not found."
fi

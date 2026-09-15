#!/usr/bin/env bash
#
# Builds privacyfox_<version>_all.deb from the repo's real source files
# (PrivacyFox.js, distribution/policies.json, etc.) -- nothing here is a
# duplicated copy that could drift from the repo root; this script pulls
# from there every time it runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="$(awk -F': ' '/^Version:/{print $2; exit}' "$SCRIPT_DIR/control")"
PKG_NAME="privacyfox"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

PKG_ROOT="$BUILD_DIR/${PKG_NAME}_${VERSION}_all"

echo "Building ${PKG_NAME} ${VERSION}..."

umask 022

mkdir -p "$PKG_ROOT/DEBIAN"
mkdir -p "$PKG_ROOT/usr/share/privacyfox/distribution"
mkdir -p "$PKG_ROOT/usr/share/doc/privacyfox"
mkdir -p "$PKG_ROOT/usr/bin"

# --- payload, pulled straight from the repo root (single source of truth) --
cp "$REPO_ROOT/PrivacyFox.js" "$PKG_ROOT/usr/share/privacyfox/PrivacyFox.js"
cp "$REPO_ROOT/distribution/policies.json" "$PKG_ROOT/usr/share/privacyfox/distribution/policies.json"
if [[ -f "$REPO_ROOT/userContent.css" ]]; then
  cp "$REPO_ROOT/userContent.css" "$PKG_ROOT/usr/share/privacyfox/userContent.css"
fi

# --- the per-user command ----------------------------------------------------
install -m 0755 "$SCRIPT_DIR/privacyfox-apply" "$PKG_ROOT/usr/bin/privacyfox-apply"

# --- doc: copyright + changelog (required for a native package) -------------
install -m 0644 "$SCRIPT_DIR/copyright" "$PKG_ROOT/usr/share/doc/privacyfox/copyright"
gzip -9n -c "$SCRIPT_DIR/changelog" > "$PKG_ROOT/usr/share/doc/privacyfox/changelog.gz"
chmod 0644 "$PKG_ROOT/usr/share/doc/privacyfox/changelog.gz"

# --- DEBIAN control files -----------------------------------------------------
install -m 0644 "$SCRIPT_DIR/control" "$PKG_ROOT/DEBIAN/control"
install -m 0755 "$SCRIPT_DIR/postinst" "$PKG_ROOT/DEBIAN/postinst"

# Normalize perms across the whole tree -- umask above covers files created
# from here on, but PrivacyFox.js/policies.json were cp'd before it took
# effect at the point this script is read, so enforce explicitly too.
find "$PKG_ROOT" -mindepth 1 -type d -exec chmod 0755 {} +
find "$PKG_ROOT" -mindepth 1 -type f -not -path "*/DEBIAN/*" -exec chmod 0644 {} +
chmod 0755 "$PKG_ROOT/usr/bin/privacyfox-apply" "$PKG_ROOT/DEBIAN/postinst"

# Installed-Size is a real, expected control field (kB, best-effort estimate)
size_kb="$(du -sk "$PKG_ROOT" | cut -f1)"
echo "Installed-Size: ${size_kb}" >> "$PKG_ROOT/DEBIAN/control"

OUT="$REPO_ROOT/${PKG_NAME}_${VERSION}_all.deb"
dpkg-deb --build --root-owner-group "$PKG_ROOT" "$OUT"

echo
echo "Built: $OUT"
if command -v dpkg-deb >/dev/null 2>&1; then
  echo
  echo "=== dpkg-deb --info ==="
  dpkg-deb --info "$OUT"
  echo
  echo "=== dpkg-deb --contents ==="
  dpkg-deb --contents "$OUT"
fi

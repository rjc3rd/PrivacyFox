#!/usr/bin/env bash
#
# PrivacyFox installer
#
# Layers PrivacyFox's config on top of an existing, real, unmodified
# Waterfox install:
#   - distribution/policies.json  -> <waterfox install dir>/distribution/
#   - PrivacyFox.js                -> <profile>/user.js
#   - (userContent.css, when it exists -> <profile>/chrome/userContent.css)
#
# Doesn't touch Waterfox's own binary, doesn't recompile or repackage
# anything. See README.md for what each piece actually does.
#
# Requires: Waterfox already installed, launched at least once (so a real
# profile exists to write user.js into).

set -uo pipefail
# Deliberately NOT using -e: this script's own history (see PrivacyOS's
# CLAUDE.md, the "set -e + bare [[ ]] && action" saga) shows how easily
# set -e turns a normal, correct "nothing to do here" branch into a silent
# early exit. Every step below checks its own exit status explicitly
# instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

warn() { echo "[privacyfox] WARNING: $*" >&2; }
die()  { echo "[privacyfox] ERROR: $*" >&2; exit 1; }
info() { echo "[privacyfox] $*"; }

# ---- 1. Find the Waterfox install directory -------------------------------
resolve_waterfox_install_dir() {
  local candidates=(/usr/lib/waterfox /opt/waterfox)
  local d
  for d in "${candidates[@]}"; do
    if [[ -x "$d/waterfox" || -x "$d/waterfox-bin" ]]; then
      echo "$d"
      return 0
    fi
  done
  if command -v waterfox >/dev/null 2>&1; then
    local bin_path
    bin_path="$(readlink -f "$(command -v waterfox)")" || return 1
    echo "$(dirname "$bin_path")"
    return 0
  fi
  return 1
}

# ---- 2. Find the default profile directory ---------------------------------
# Waterfox still uses the legacy ~/.waterfox path (not XDG) as of this
# writing -- unlike LibreWolf/Firefox 147+, which fall back to
# ~/.config/... only when ~/.waterfox doesn't already exist. No verified
# evidence Waterfox does the same (this exact caveat is carried over from
# PrivacyOS's own real-hardware findings) -- if that ever changes, this
# needs a resolve_profile_root()-style fallback added, not a silent guess.
resolve_default_profile_dir() {
  local profiles_ini="$HOME/.waterfox/profiles.ini"
  [[ -f "$profiles_ini" ]] || return 1

  local profile_name
  profile_name="$(awk '
    /^\[Install/ { in_install=1; next }
    /^\[/        { in_install=0 }
    in_install && /^Default=/ { sub(/^Default=/, ""); print; exit }
  ' "$profiles_ini")"

  [[ -n "$profile_name" ]] || return 1
  local dir="$HOME/.waterfox/$profile_name"
  [[ -d "$dir" ]] || return 1
  echo "$dir"
}

# ---- 3. policies.json (system-wide, needs sudo) ----------------------------
install_policies() {
  local install_dir="$1"
  local dist_dir="$install_dir/distribution"
  local target="$dist_dir/policies.json"
  local source="$SCRIPT_DIR/distribution/policies.json"

  [[ -f "$source" ]] || { warn "distribution/policies.json not found next to this script, skipping"; return 1; }

  info "Installing policies.json to $target (needs sudo -- system path)"
  if [[ ! -d "$dist_dir" ]]; then
    sudo mkdir -p "$dist_dir" || { warn "couldn't create $dist_dir"; return 1; }
  fi
  if [[ -f "$target" ]]; then
    sudo cp "$target" "$target.bak.$(date +%Y%m%d%H%M%S)" || warn "couldn't back up existing policies.json"
  fi
  sudo cp "$source" "$target" || { warn "couldn't copy policies.json"; return 1; }
  info "policies.json installed."
  return 0
}

# ---- 4. PrivacyFox.js -> profile's user.js ---------------------------------
install_userjs() {
  local profile_dir="$1"
  local source="$SCRIPT_DIR/PrivacyFox.js"
  local target="$profile_dir/user.js"

  [[ -f "$source" ]] || { warn "PrivacyFox.js not found next to this script, skipping"; return 1; }

  if [[ -f "$target" ]]; then
    cp "$target" "$target.bak.$(date +%Y%m%d%H%M%S)" || warn "couldn't back up existing user.js"
  fi
  cp "$source" "$target" || { warn "couldn't copy PrivacyFox.js to $target"; return 1; }
  info "user.js installed to $target"
  return 0
}

# ---- 5. userContent.css (cosmetic vendor-UI cleanup) -----------------------
install_usercontent_css() {
  local profile_dir="$1"
  local source="$SCRIPT_DIR/userContent.css"
  [[ -f "$source" ]] || return 0   # not an error -- harmless if it's ever removed

  local chrome_dir="$profile_dir/chrome"
  mkdir -p "$chrome_dir" || { warn "couldn't create $chrome_dir"; return 1; }
  cp "$source" "$chrome_dir/userContent.css" || { warn "couldn't copy userContent.css"; return 1; }
  info "userContent.css installed to $chrome_dir/userContent.css"
  return 0
}

main() {
  if pgrep -x waterfox >/dev/null 2>&1 || pgrep -f '/waterfox$' >/dev/null 2>&1; then
    die "Waterfox is currently running. Close it first -- it rewrites user.js/prefs.js on exit and would overwrite what this installer writes."
  fi

  local install_dir
  install_dir="$(resolve_waterfox_install_dir)"
  if [[ -z "$install_dir" ]]; then
    die "Couldn't find a Waterfox install. Install Waterfox first (waterfox.net), launch it once, then re-run this script."
  fi
  info "Found Waterfox install at $install_dir"

  local profile_dir
  profile_dir="$(resolve_default_profile_dir)"
  if [[ -z "$profile_dir" ]]; then
    die "Couldn't find a Waterfox profile under ~/.waterfox. Launch Waterfox at least once first, then re-run this script."
  fi
  info "Found default profile at $profile_dir"

  local ok=1
  install_policies "$install_dir" || ok=0
  install_userjs "$profile_dir" || ok=0
  install_usercontent_css "$profile_dir" || ok=0

  echo
  if [[ "$ok" -eq 1 ]]; then
    info "Done. Start Waterfox to see it take effect."
    info "Check about:policies to confirm the policy took, about:addons for the six extensions, about:config for the hardened prefs."
  else
    warn "Finished with at least one step skipped or failed -- see warnings above."
  fi
}

main "$@"

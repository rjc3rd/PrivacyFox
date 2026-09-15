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
# Requires: Waterfox already installed -- nothing else. If you've never
# launched it before, this script does that bootstrap step itself (a brief
# headless launch just long enough to create a profile, then closes it
# again) -- no manual "open it once yourself" step needed. On success, this
# script launches Waterfox for real at the end, hardened, so you see the
# result immediately.

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

# ---- 1b. Offer to install Waterfox itself, if it's missing -----------------
# Only offers for OS/version combinations verified against Waterfox's own
# real repo listing (waterfox.com/download) -- Debian 13 confirmed directly
# against this machine's own working /etc/apt/sources.list.d/waterfox.list,
# Ubuntu's xUbuntu_<version> naming confirmed from their docs. Notably,
# Debian 12 is NOT in Waterfox's own supported list at all -- don't guess a
# path for it or any other unlisted combination, just tell the user to
# install it themselves rather than risk adding a wrong/broken repo.
detect_waterfox_repo_path() {
  [[ -f /etc/os-release ]] || return 1
  local os_id="" codename="" version_id=""
  # shellcheck disable=SC1091
  . /etc/os-release
  os_id="$ID"
  codename="$VERSION_CODENAME"
  version_id="$VERSION_ID"

  case "$os_id" in
    debian)
      case "$codename" in
        trixie) echo "Debian_13"; return 0 ;;
        sid|unstable) echo "Debian_Unstable"; return 0 ;;
      esac
      ;;
    ubuntu)
      case "$version_id" in
        22.04|24.04|24.10|25.04|25.10|26.04) echo "xUbuntu_${version_id}"; return 0 ;;
      esac
      ;;
  esac
  return 1
}

offer_install_waterfox() {
  local repo_path
  repo_path="$(detect_waterfox_repo_path)"
  if [[ -z "$repo_path" ]]; then
    warn "Waterfox isn't installed, and I don't have a verified repo path for"
    warn "your specific OS/version. Install it yourself: https://www.waterfox.com/download/"
    return 1
  fi

  echo
  echo "Waterfox isn't installed. PrivacyFox can add Waterfox's own official"
  echo "APT repo (download.opensuse.org/repositories/isv:/BrowserWorks/$repo_path/)"
  echo "and install it for you -- needs sudo."
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    warn "Skipped. Install Waterfox yourself, then re-run this script."
    return 1
  fi

  local key_url="https://download.opensuse.org/repositories/isv:/BrowserWorks/${repo_path}/Release.key"
  curl -fsSL "$key_url" | gpg --dearmor | sudo tee /usr/share/keyrings/waterfox.gpg > /dev/null
  if [[ ! -s /usr/share/keyrings/waterfox.gpg ]]; then
    warn "Couldn't fetch/import Waterfox's signing key."
    return 1
  fi

  echo "deb [signed-by=/usr/share/keyrings/waterfox.gpg] https://download.opensuse.org/repositories/isv:/BrowserWorks/${repo_path}/ /" \
    | sudo tee /etc/apt/sources.list.d/waterfox.list > /dev/null
  if [[ ! -f /etc/apt/sources.list.d/waterfox.list ]]; then
    warn "Couldn't write /etc/apt/sources.list.d/waterfox.list."
    return 1
  fi

  sudo apt-get update || { warn "apt update failed"; return 1; }
  sudo apt-get install -y waterfox || { warn "waterfox install failed"; return 1; }

  info "Waterfox installed."
  return 0
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

# ---- 2b. Bootstrap a profile if none exists yet ----------------------------
# Real Gecko headless launch, no display server needed. Same mechanism
# PrivacyOS proved out on real hardware (see its CLAUDE.md) -- launch, give
# it a few seconds to actually write profiles.ini + the profile folder,
# kill it, done. Only runs when resolve_default_profile_dir() found nothing;
# an existing profile (the already-using-Waterfox case) is never touched by
# this function at all.
bootstrap_profile() {
  info "No existing profile found -- launching Waterfox briefly to create one..."
  waterfox --headless >/dev/null 2>&1 &
  local pid=$!
  sleep 6
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" 2>/dev/null || true
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
    if offer_install_waterfox; then
      install_dir="$(resolve_waterfox_install_dir)"
    fi
  fi
  if [[ -z "$install_dir" ]]; then
    die "Couldn't find a Waterfox install."
  fi
  info "Found Waterfox install at $install_dir"

  local profile_dir
  profile_dir="$(resolve_default_profile_dir)"
  if [[ -z "$profile_dir" ]]; then
    bootstrap_profile
    profile_dir="$(resolve_default_profile_dir)"
  fi
  if [[ -z "$profile_dir" ]]; then
    die "Couldn't create or find a Waterfox profile under ~/.waterfox. Something's wrong with the Waterfox install itself -- try launching it manually once to see what happens."
  fi
  info "Found default profile at $profile_dir"

  local ok=1
  install_policies "$install_dir" || ok=0
  install_userjs "$profile_dir" || ok=0
  install_usercontent_css "$profile_dir" || ok=0

  echo
  if [[ "$ok" -eq 1 ]]; then
    info "Done. Launching Waterfox..."
    info "Check about:policies to confirm the policy took, about:addons for the seven extensions, about:config for the hardened prefs."
    setsid waterfox >/dev/null 2>&1 &
  else
    warn "Finished with at least one step skipped or failed -- see warnings above."
  fi
}

main "$@"

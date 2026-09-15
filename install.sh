#!/usr/bin/env bash
#
# PrivacyFox installer
#
# Layers PrivacyFox's config on top of an existing, real, unmodified
# LibreWolf install:
#   - distribution/policies.json  -> <librewolf install dir>/distribution/
#   - PrivacyFox.js                 -> <profile>/user.js
#   - (userContent.css, when it exists -> <profile>/chrome/userContent.css)
#
# Doesn't touch LibreWolf's own binary, doesn't recompile or repackage
# anything. See README.md for what each piece actually does.
#
# Requires: LibreWolf already installed -- nothing else. If it's missing,
# this script offers to add LibreWolf's own official APT repo (via extrepo,
# Debian's own trusted-repo tool) and install it for you. If you've never
# launched it before, this script also bootstraps a profile itself (a brief
# headless launch just long enough to create one, then closes it again) --
# no manual "open it once yourself" step needed. This script never launches
# LibreWolf for real, before or after -- you're in charge of opening and
# closing your own browser.

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

# ---- 1. Find the LibreWolf install directory -------------------------------
resolve_librewolf_install_dir() {
  local candidates=(/usr/share/librewolf /usr/lib/librewolf /opt/librewolf)
  local d
  for d in "${candidates[@]}"; do
    if [[ -x "$d/librewolf" || -x "$d/librewolf-bin" ]]; then
      echo "$d"
      return 0
    fi
  done
  if command -v librewolf >/dev/null 2>&1; then
    local bin_path
    bin_path="$(readlink -f "$(command -v librewolf)")" || return 1
    echo "$(dirname "$bin_path")"
    return 0
  fi
  return 1
}

# ---- 1b. Offer to install LibreWolf itself, if it's missing ----------------
# LibreWolf's own real install docs (librewolf.net/installation/debian)
# use extrepo -- Debian's own trusted-repo-enabler tool -- and the exact
# same three commands apply universally across Debian-based distros
# (Debian, Ubuntu, Mint, etc.), no per-OS-version branching needed. Much
# simpler than Waterfox's raw curl+gpg+sources.list approach, and nothing
# here is guessed -- confirmed directly from their current install page.
offer_install_librewolf() {
  echo
  echo "LibreWolf isn't installed. PrivacyFox can add LibreWolf's own"
  echo "official APT repo (via extrepo, Debian's own trusted-repo tool)"
  echo "and install it for you -- needs sudo."
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    warn "Skipped. Install LibreWolf yourself (librewolf.net), then re-run this script."
    return 1
  fi

  sudo apt-get -qq update || { warn "apt update failed"; return 1; }
  sudo apt-get -qq install -y extrepo || { warn "couldn't install extrepo"; return 1; }
  sudo extrepo enable librewolf || { warn "couldn't enable LibreWolf's repo via extrepo"; return 1; }
  sudo extrepo update librewolf || { warn "couldn't update LibreWolf's repo via extrepo"; return 1; }
  sudo apt-get -qq update || { warn "apt update failed"; return 1; }
  sudo apt-get -qq install -y librewolf || { warn "librewolf install failed"; return 1; }

  info "LibreWolf installed."
  return 0
}

# ---- 2. Find the default profile directory ---------------------------------
# LibreWolf (Firefox 147+ base) falls back to ~/.config/librewolf/librewolf
# via XDG Base Directory support, but ONLY when the legacy ~/.librewolf
# doesn't already exist -- confirmed directly on real hardware by PrivacyOS
# (see its CLAUDE.md, "the big one" real finding). Check legacy first,
# matching the browser's own real compatibility rule exactly, not guessing.
resolve_librewolf_profile_root() {
  if [[ -d "$HOME/.librewolf" ]]; then
    echo "$HOME/.librewolf"
  else
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/librewolf/librewolf"
  fi
}

resolve_default_profile_dir() {
  local profile_root
  profile_root="$(resolve_librewolf_profile_root)"
  local profiles_ini="$profile_root/profiles.ini"
  [[ -f "$profiles_ini" ]] || return 1

  local profile_name
  profile_name="$(awk '
    /^\[Install/ { in_install=1; next }
    /^\[/        { in_install=0 }
    in_install && /^Default=/ { sub(/^Default=/, ""); print; exit }
  ' "$profiles_ini")"

  [[ -n "$profile_name" ]] || return 1
  local dir="$profile_root/$profile_name"
  [[ -d "$dir" ]] || return 1
  echo "$dir"
}

# ---- 2b. Bootstrap a profile if none exists yet ----------------------------
# Real Gecko headless launch, no display server needed. Same mechanism
# PrivacyOS proved out on real hardware (see its CLAUDE.md) -- launch, give
# it a few seconds to actually write profiles.ini + the profile folder,
# kill it, done. Only runs when resolve_default_profile_dir() found nothing;
# an existing profile (the already-using-LibreWolf case) is never touched by
# this function at all.
bootstrap_profile() {
  info "No existing profile found -- launching LibreWolf briefly to create one..."
  librewolf --headless >/dev/null 2>&1 &
  local pid=$!
  sleep 6
  kill "$pid" >/dev/null 2>&1 || true
  wait "$pid" 2>/dev/null || true
}

# ---- 3. policies.json (system-wide, needs sudo) ----------------------------
# Deliberately NOT <install dir>/distribution/policies.json -- that path is
# real package content the `librewolf` .deb itself ships (confirmed via
# `dpkg -S`), and it isn't a registered conffile (confirmed via
# `dpkg-query -W -f='${Conffiles}' librewolf` -- doesn't list it), so dpkg
# has no reason to preserve our edit to it: the next `librewolf` package
# upgrade would silently overwrite it back to their stock file, quietly
# undoing everything PrivacyFox set. /etc/librewolf/policies/policies.json
# is the OTHER real location Firefox's policy engine reads (confirmed from
# Mozilla's own docs) -- genuinely unclaimed, no package owns anything
# there, so nothing else can ever silently clobber it, and removing it
# later is unambiguous (it's 100% ours, nothing to restore).
install_policies() {
  local target="/etc/librewolf/policies/policies.json"
  local target_dir="/etc/librewolf/policies"
  local source="$SCRIPT_DIR/distribution/policies.json"

  [[ -f "$source" ]] || { warn "distribution/policies.json not found next to this script, skipping"; return 1; }

  info "Installing policies.json to $target (needs sudo -- system path)"
  if [[ ! -d "$target_dir" ]]; then
    sudo mkdir -p "$target_dir" || { warn "couldn't create $target_dir"; return 1; }
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
  if pgrep -x librewolf >/dev/null 2>&1 || pgrep -f '/librewolf$' >/dev/null 2>&1; then
    die "LibreWolf is currently running. Close it first -- it writes prefs.js on exit, and won't actually load what this installer writes until the next full restart anyway."
  fi

  local install_dir
  install_dir="$(resolve_librewolf_install_dir)"
  if [[ -z "$install_dir" ]]; then
    if offer_install_librewolf; then
      install_dir="$(resolve_librewolf_install_dir)"
    fi
  fi
  if [[ -z "$install_dir" ]]; then
    die "Couldn't find a LibreWolf install."
  fi
  info "Found LibreWolf install at $install_dir"

  local profile_dir
  profile_dir="$(resolve_default_profile_dir)"
  if [[ -z "$profile_dir" ]]; then
    bootstrap_profile
    profile_dir="$(resolve_default_profile_dir)"
  fi
  if [[ -z "$profile_dir" ]]; then
    die "Couldn't create or find a LibreWolf profile. Something's wrong with the LibreWolf install itself -- try launching it manually once to see what happens."
  fi
  info "Found default profile at $profile_dir"

  local ok=1
  install_policies || ok=0
  install_userjs "$profile_dir" || ok=0
  install_usercontent_css "$profile_dir" || ok=0

  echo
  if [[ "$ok" -eq 1 ]]; then
    info "Done -- open LibreWolf yourself to see the hardened result."
    info "Check about:policies to confirm the policy took, about:addons for the seven extensions, about:config for the hardened prefs."
  else
    warn "Finished with at least one step skipped or failed -- see warnings above."
  fi
}

main "$@"

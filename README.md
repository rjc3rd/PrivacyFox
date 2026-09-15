# PrivacyFox

LibreWolf is great. PrivacyFox makes it even better.

PrivacyFox doesn't touch a single line of LibreWolf's code, and it isn't a fork of
the browser itself. It's a small, transparent config layer you drop on top of a
real, official, unmodified LibreWolf install — the same binary everyone else gets,
properly diffed against LibreWolf's own real hardening rather than blindly layered
on top of it.

> **Status: rebuilt for LibreWolf, not yet re-tested end to end.** This project
> originally targeted Waterfox; that had a real, structural bug (a startup-timing
> conflict in Waterfox's own native ad-blocker detection) that three separate fix
> attempts couldn't resolve, so the target was switched to LibreWolf entirely,
> which has no native ad-blocker to conflict with in the first place. Everything
> below reflects the LibreWolf version — rebuilt, `lintian`-clean, and internally
> validated, but the real-world install/apply flow hasn't been walked through
> fresh on LibreWolf yet the way the Waterfox version was.

## What it actually changes

- **No Account & Sync nagging.** Disabled at the policy level
  (`DisableFirefoxAccounts`) — the one thing LibreWolf's own hardening doesn't
  already set that this project cares about.
- **A curated set of privacy extensions alongside LibreWolf's own uBlock Origin.**
  LibreWolf already ships uBlock Origin by default — left exactly as they have it,
  not force-installed or duplicated. Six more, force-installed via policy:
  ClearURLs, LocalCDN, CanvasBlocker, Don't Track Me Google, Port Authority,
  Privacy Badger — each audited for being real, maintained, and doing what it
  claims, not just popular.
- **A real, properly-diffed hardening `user.js`** — not Arkenfox + Betterfox
  layered blindly on top of LibreWolf's own settings. Every pref was checked
  against LibreWolf's actual current defaults first; only genuine additions made
  it in. See "How PrivacyFox.js was actually built" below.
- **A small cosmetic cleanup**: hides the dead Account & Sync menu entry that
  `DisableFirefoxAccounts` disables the function of but doesn't remove from the
  Settings sidebar on its own.

## How PrivacyFox.js was actually built

Not assumed, not layered on blind — diffed for real. Every one of Arkenfox's and
Betterfox's 207 unique prefs was checked against LibreWolf's own actual compiled-in
defaults (extracted from their real `librewolf.cfg`, version-matched against their
live upstream repo):

- **118 prefs already overlap** with LibreWolf's own hardening. 115 of those
  already agree outright — kept as LibreWolf's own, not restated here.
- **3 are genuine, deliberate disagreements**, where LibreWolf's own choice is
  treated as intentional and *not* overridden:
  - `media.peerconnection.ice.default_address_only` — LibreWolf likely relies on
    the newer mDNS-obfuscation mechanism instead; forcing this on can break WebRTC
    video calls.
  - `privacy.trackingprotection.allow_list.convenience.enabled` — LibreWolf is
    actually *stricter* here than Arkenfox, deliberately rejecting Mozilla's
    tracker "convenience" allowlist exceptions.
  - `signon.formlessCapture.enabled` — a login-manager UX-vs-privacy tradeoff
    LibreWolf resolved differently than Arkenfox.
- **The remaining 89**, found nowhere in LibreWolf's own file at all, are
  `PrivacyFox.js`'s actual content — documented in full in the file's own header
  comment.

## What it deliberately doesn't do

- Doesn't recompile, repackage, or redistribute LibreWolf itself. You install real
  LibreWolf from their own repo, same as anyone else.
- Doesn't replace LibreWolf's own security updates, release cadence, or engine —
  none of that is ours to maintain, and it shouldn't be.
- Doesn't hide or distance itself from LibreWolf's own identity. LibreWolf's own
  About page, support links, and branding stay exactly as LibreWolf built them —
  this project builds on LibreWolf, it doesn't hide it.

## Platform support

**Right now: Debian/Ubuntu-family Linux, any desktop environment.** Nothing here
is tied to Cinnamon, GTK, or any specific desktop/toolkit — the `.deb` installs
fine under GNOME, KDE, XFCE, Cinnamon, whatever, since none of this touches the
desktop environment at all. That's a real difference from this project's sibling,
[PrivacyOS](https://privacyos.dev), which does have genuine Cinnamon-only pieces.

What "Debian/Ubuntu-family" actually means here: the `.deb` package and
`install.sh` both assume `apt`/`dpkg` and Linux filesystem paths
(`/usr/share/librewolf`, `~/.librewolf`). Other Linux families (Fedora, Arch,
openSUSE, etc.) aren't supported yet — no RPM or equivalent exists — though
nothing about the underlying approach rules it out, it just hasn't been built.

**The config itself isn't actually Linux-specific.** `policies.json`,
`PrivacyFox.js`, and `userContent.css` are all standard Gecko/LibreWolf
mechanisms that work identically on Windows and macOS — arkenfox and betterfox
are themselves cross-platform projects, and LibreWolf ships on all three.
Someone on Windows or Mac could place these three files in their OS's equivalent
locations by hand and get the same hardening; there's just no automated installer
for those platforms yet.

## How it works

Three files, none of which require touching LibreWolf's own installation:

| file | goes in | does what |
|---|---|---|
| `policies.json` | `/etc/librewolf/policies/policies.json` | App-level toggles: Firefox Accounts off, force-installed extensions |
| `PrivacyFox.js` | your profile's `user.js` | The diffed hardening prefs (see above) |
| `userContent.css` | your profile's `chrome/userContent.css` | Cosmetic cleanup: the dead Account & Sync menu entry |

`policies.json` deliberately does *not* go in `<LibreWolf install dir>/distribution/` — that path is real content the `librewolf` package itself ships (confirmed via `dpkg -S`) and isn't a registered conffile, so a routine `apt upgrade` of LibreWolf would silently overwrite it back to their stock file, quietly undoing this project's hardening with no warning. `/etc/librewolf/policies/` is the other real location Firefox's policy engine reads (confirmed from Mozilla's own docs) and is genuinely unclaimed by any package — nothing can silently clobber it, and removing it later (`apt purge privacyfox`) is completely unambiguous.

Two real ways to install this automatically, both in this repo:

- **`.deb`**: grab one from [Releases](https://github.com/rjc3rd/PrivacyFox/releases),
  or build it yourself with `packaging/build-deb.sh`, then
  `sudo apt install ./privacyfox_*.deb` and run `privacyfox --apply` once
  as yourself (no sudo — it only touches your own profile). The split exists
  because Debian packaging rules don't let a package's install step write
  into your home directory. This path assumes LibreWolf (and its APT repo)
  is already set up, since it's a declared package dependency.
- **`install.sh`**: `./install.sh` layers all three files directly onto an
  existing LibreWolf install/profile in one step, no packaging involved. If
  LibreWolf itself isn't installed yet, it offers to add LibreWolf's own
  official APT repo (via `extrepo`, Debian's own trusted-repo tool) and install
  it for you — the same three commands work universally across Debian-based
  distros, no per-OS-version branching needed.

Either way, once LibreWolf is present, no other manual step is needed. If
you've never launched it before, both paths bootstrap a profile for you
automatically (a brief headless launch just long enough to create one, then
closed again). Neither path launches LibreWolf for real when it's done —
open it yourself, whenever you're ready, to see the hardened result.

**One thing to expect the first time you open it afterward, completely
normal:** the seven policy-managed extensions take a couple of minutes to
actually finish
installing in the background — give it a moment.

**Already using LibreWolf and want to try this risk-free first?** Since
`user.js` lives entirely inside your profile folder:
```
mv ~/.librewolf ~/.librewolf.bak    # close LibreWolf first
```
(If your install already uses the newer XDG path instead — check for
`~/.config/librewolf/librewolf` — back that up instead.)
Launch LibreWolf once (creates a fresh, empty profile) and close it again,
then run either install path above against that fresh profile. Like it?
Delete `~/.librewolf.bak`. Don't like it? Delete the new `~/.librewolf`, rename
`~/.librewolf.bak` back, restart LibreWolf — everything is exactly as it was.
One caveat: `policies.json` is system-wide, not per-profile, so installing
the package affects every profile on the machine immediately, including your
real one, regardless of which profile you're actively testing against.

**Changed your mind? Uninstall cleanly:**
```
privacyfox --revert
sudo apt purge privacyfox
```
Order matters — run `--revert` first. `sudo apt purge` only undoes the
system-wide side (deletes `policies.json` and any backups — Accounts is no
longer disabled by policy, and the extensions stop being centrally managed),
since a root-run maintainer script can't reach into your `$HOME` any more
than `postinst` could when installing it. `--revert` is the profile-side
counterpart: it restores the newest pre-PrivacyFox backup of `user.js` and
`userContent.css` (made automatically on every `privacyfox --apply` run), or
removes the file outright if no backup exists — i.e. that profile had
neither file before PrivacyFox touched it. Run it *before* purging, not
after: purge removes the `privacyfox` command itself along with the
rest of the package.

## Credits & license

PrivacyFox is built on, and grateful for, the real work of:

- **[LibreWolf](https://librewolf.net/)** — the browser itself, and the baseline
  `PrivacyFox.js` is diffed against. PrivacyFox configures it; LibreWolf builds,
  hardens, and maintains it. Not affiliated with or endorsed by the LibreWolf
  project.
- **[arkenfox/user.js](https://github.com/arkenfox/user.js)** — the hardening
  baseline this project's `user.js` additions are drawn from.
- **[Betterfox](https://github.com/yokoffing/Betterfox)** — the other half of
  that baseline.

PrivacyFox itself is MIT licensed — see [LICENSE](LICENSE).

Part of the same project family as [PrivacyOS](https://privacyos.dev).

---

**privacyfox.dev** · [GitHub](https://github.com/rjc3rd/PrivacyFox)

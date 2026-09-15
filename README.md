# PrivacyFox

Waterfox is pretty good. We made it better.

PrivacyFox doesn't touch a single line of Waterfox's code, and it isn't a fork of
the browser itself. It's a small, transparent config layer you drop on top of a
real, official, unmodified Waterfox install — the same binary everyone else gets,
just configured the way it should have shipped in the first place.

> **Status: early, but real.** The merged hardening file, extension policy,
> cosmetic cleanup layer, installer script, and a real `.deb` are all built and
> committed. What's still missing: an actual APT repo to host it in (for now it's
> a downloadable `.deb`, not yet `apt upgrade`-able) and real-world soak time —
> this hasn't been used as a daily driver long enough yet to call it done.

## What it actually changes

- **No Account & Sync nagging.** Disabled at the policy level
  (`DisableFirefoxAccounts`), not just hidden — the feature is off, not painted over.
- **No unsolicited default-browser nagging.** `DontCheckDefaultBrowser` stops
  Waterfox from checking and prompting on every startup — it doesn't remove your
  ability to actually set it as your default. That button stays right where it is
  in Settings for anyone who wants to use it; we just don't nag you about it.
- **No partner-ad carve-out in the built-in blocker.** Waterfox's own blocker ships
  with an option to let *paid search partners* through even while blocking
  everything else — the exact thing an ad blocker shouldn't offer. Off by default,
  full stop.
- **A real, merged Arkenfox + Betterfox hardening `user.js`** — both projects'
  prefs combined into one conflict-free file, so there's no "which file loads last
  wins" ambiguity the way layering their two files separately would leave you with.
- **A curated set of privacy extensions**, force-installed via policy so you get a
  sane baseline out of the box: uBlock Origin, ClearURLs, LocalCDN, CanvasBlocker,
  Don't Track Me Google, Port Authority, Privacy Badger — each audited for being real, maintained,
  and doing what it claims, not just popular.
- **A small cosmetic cleanup layer** for the vendor UI clutter that doesn't have a
  policy key to turn off cleanly (About page, support links, etc.) — least critical
  part of this, purely tidiness.

## What it deliberately doesn't do

- Doesn't recompile, repackage, or redistribute Waterfox itself. You install real
  Waterfox from their own repo, same as anyone else.
- Doesn't replace Waterfox's own security updates, release cadence, or engine —
  none of that is ours to maintain, and it shouldn't be.
- Doesn't rename or rebrand anything *inside* the running browser. Open the About
  page after installing PrivacyFox and it will honestly say Waterfox, because it
  honestly still is — that's not a gap, it's the proof nothing was disguised.

## Platform support

**Right now: Debian/Ubuntu-family Linux, any desktop environment.** Nothing here
is tied to Cinnamon, GTK, or any specific desktop/toolkit — the `.deb` installs
fine under GNOME, KDE, XFCE, Cinnamon, whatever, since none of this touches the
desktop environment at all. That's a real difference from this project's sibling,
[PrivacyOS](https://privacyos.dev), which does have genuine Cinnamon-only pieces.

What "Debian/Ubuntu-family" actually means here: the `.deb` package and
`install.sh` both assume `apt`/`dpkg` and Linux filesystem paths
(`/usr/lib/waterfox`, `~/.waterfox`). Other Linux families (Fedora, Arch,
openSUSE, etc.) aren't supported yet — no RPM or equivalent exists — though
nothing about the underlying approach rules it out, it just hasn't been built.

**The config itself isn't actually Linux-specific.** `policies.json`,
`PrivacyFox.js`, and `userContent.css` are all standard Gecko/Waterfox
mechanisms that work identically on Windows and macOS — arkenfox and betterfox
are themselves cross-platform projects. Someone on Windows or Mac could place
these three files in their OS's equivalent locations by hand and get the same
hardening; there's just no automated installer for those platforms yet.

## How it works

Three files, none of which require touching Waterfox's own installation:

| file | goes in | does what |
|---|---|---|
| `policies.json` | `/usr/lib/waterfox/distribution/policies.json` | App-level toggles: accounts/sync, default-browser check, force-installed extensions |
| `PrivacyFox.js` | your profile's `user.js` | The merged Arkenfox + Betterfox hardening prefs |
| `userContent.css` | your profile's `chrome/userContent.css` | Cosmetic vendor-UI cleanup |

Two real ways to install this automatically, both in this repo:

- **`.deb`**: grab one from [Releases](https://github.com/rjc3rd/PrivacyFox/releases),
  or build it yourself with `packaging/build-deb.sh`, then
  `sudo apt install ./privacyfox_*.deb` and run `privacyfox-apply` once as
  yourself (no sudo — it only touches your own profile). The split exists
  because Debian packaging rules don't let a package's install step write
  into your home directory. This path assumes Waterfox (and its APT repo)
  is already set up, since it's a declared package dependency.
- **`install.sh`**: `./install.sh` layers all three files directly onto an
  existing Waterfox install/profile in one step, no packaging involved. If
  Waterfox itself isn't installed yet, it offers to add Waterfox's own
  official APT repo and install it for you (only for OS/version
  combinations verified against Waterfox's real repo listing — currently
  Debian 13/sid and Ubuntu 22.04 through 26.04; anything else, it tells you
  to install Waterfox yourself rather than guess a repo path that might be
  wrong).

Either way, once Waterfox is present, no other manual step is needed. If
you've never launched it before, both paths bootstrap a profile for you
automatically (a brief headless launch just long enough to create one), and
both launch Waterfox for real once done, hardened, so you see the result
immediately.

## Credits & license

PrivacyFox is built on, and grateful for, the real work of:

- **[Waterfox](https://www.waterfox.net/)** — the browser itself. PrivacyFox
  configures it; Waterfox builds and maintains it. Not affiliated with or endorsed
  by BrowserWorks.
- **[arkenfox/user.js](https://github.com/arkenfox/user.js)** — the hardening
  baseline this project's `user.js` is merged from.
- **[Betterfox](https://github.com/yokoffing/Betterfox)** — the second half of that
  merge.

PrivacyFox itself is MIT licensed — see [LICENSE](LICENSE). "Waterfox" is a
trademark of BrowserWorks; this project is independent and uses the name only to
accurately describe what it configures.

Part of the same project family as [PrivacyOS](https://privacyos.dev).

---

**privacyfox.dev** · [GitHub](https://github.com/rjc3rd/PrivacyFox)

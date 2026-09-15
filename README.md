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
  Don't Track Me Google, Port Authority — each audited for being real, maintained,
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

## How it works

Three files, none of which require touching Waterfox's own installation:

| file | goes in | does what |
|---|---|---|
| `policies.json` | `/usr/lib/waterfox/distribution/policies.json` | App-level toggles: accounts/sync, default-browser check, force-installed extensions |
| `PrivacyFox.js` | your profile's `user.js` | The merged Arkenfox + Betterfox hardening prefs |
| `userContent.css` | your profile's `chrome/userContent.css` | Cosmetic vendor-UI cleanup |

Two real ways to install this automatically, both in this repo:

- **`.deb`**: `sudo apt install ./privacyfox_*.deb` (build it yourself with
  `packaging/build-deb.sh`, or grab one from Releases once published), then run
  `privacyfox-apply` once as yourself (no sudo — it only touches your own profile).
  The split exists because Debian packaging rules don't let a package's install
  step write into your home directory.
- **`install.sh`**: `./install.sh` layers all three files directly onto an
  existing Waterfox install/profile in one step, no packaging involved.

Either way, Waterfox needs to already be installed and launched at least once
(so a real profile exists) before running either of these.

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

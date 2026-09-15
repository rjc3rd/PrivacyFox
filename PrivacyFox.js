/*******************************************************************************
 * PrivacyFox.js
 *
 * A curated set of Arkenfox + Betterfox hardening prefs, properly diffed
 * against LibreWolf's own real, current hardening baseline (librewolf.cfg
 * 8.6) -- not blindly layered on top of it. LibreWolf already hardens a lot
 * of the same ground itself; this file adds only what LibreWolf genuinely
 * doesn't already cover, rather than restating or fighting its own choices.
 *
 * How this was built: every pref in Arkenfox+Betterfox (207 unique) was
 * compared against LibreWolf's actual compiled-in defaults (extracted from
 * their real librewolf.cfg, version-matched against their live upstream
 * repo). 118 already overlap -- 115 of those already agree outright (kept
 * as LibreWolf's own, not restated here). The remaining 89, found nowhere
 * in LibreWolf's own file, are the real, additive content of this file.
 *
 * Three prefs are DELIBERATELY excluded, not overlooked -- Arkenfox and
 * LibreWolf genuinely disagree on these, and LibreWolf's own choice is
 * treated as intentional, not something to override:
 *   - media.peerconnection.ice.default_address_only (Arkenfox: true,
 *     LibreWolf: false) -- LibreWolf relies on the newer mDNS-obfuscation
 *     mechanism instead; forcing this on can break WebRTC video calls.
 *   - privacy.trackingprotection.allow_list.convenience.enabled (Arkenfox:
 *     true, LibreWolf: false) -- LibreWolf is actually STRICTER here,
 *     deliberately rejecting Mozilla's tracker "convenience" allowlist.
 *   - signon.formlessCapture.enabled (Arkenfox: false, LibreWolf: true) --
 *     a login-manager UX-vs-privacy tradeoff LibreWolf resolved differently.
 *
 * Credit and thanks to the real upstream projects this is built from:
 *   - Arkenfox   https://github.com/arkenfox/user.js   (MIT)
 *   - Betterfox  https://github.com/yokoffing/Betterfox (MIT)
 *   - LibreWolf  https://codeberg.org/librewolf/settings (MIT) -- not
 *     bundled here, just diffed against; LibreWolf's own settings are
 *     applied by LibreWolf itself, untouched.
 *
 * Part of https://privacyfox.dev -- https://github.com/rjc3rd/PrivacyFox
 ******************************************************************************/


user_pref("_user.js.parrot", "SUCCESS: No no he's not dead, he's, he's restin'!");
user_pref("browser.startup.page", 0);
user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.amp.featureGate", false);
user_pref("browser.urlbar.wikipedia.featureGate", false);
user_pref("security.webauthn.always_allow_direct_attestation", false);
user_pref("toolkit.winRegisterApplicationRestart", false);
user_pref("dom.security.https_only_mode", true);
user_pref("dom.security.https_only_mode_send_http_background_request", false);
user_pref("pdfjs.disabled", false);
user_pref("browser.contentanalysis.enabled", false);
user_pref("browser.contentanalysis.default_result", 0);
user_pref("browser.download.always_ask_before_handling_new_types", true);
user_pref("privacy.clearOnShutdown_v2.cache", true);
user_pref("privacy.clearOnShutdown_v2.downloads", false);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
user_pref("privacy.clearSiteData.cache", true);
user_pref("privacy.clearSiteData.cookiesAndStorage", false);
user_pref("privacy.clearSiteData.historyFormDataAndDownloads", false);
user_pref("privacy.clearSiteData.browsingHistoryAndDownloads", false);
user_pref("privacy.clearSiteData.formdata", true);
user_pref("privacy.clearHistory.cache", true);
user_pref("privacy.clearHistory.cookiesAndStorage", false);
user_pref("privacy.clearHistory.historyFormDataAndDownloads", false);
user_pref("privacy.clearHistory.browsingHistoryAndDownloads", false);
user_pref("privacy.clearHistory.formdata", true);
user_pref("privacy.spoof_english", 1);
user_pref("widget.non-native-theme.use-theme-accent", false);
user_pref("extensions.blocklist.enabled", true);
user_pref("network.http.referer.spoofSource", false);
user_pref("security.dialog_enable_delay", 1000);
user_pref("privacy.firstparty.isolate", false);
user_pref("extensions.webcompat.enable_shims", true);
user_pref("extensions.quarantinedDomains.enabled", true);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);
user_pref("browser.urlbar.showSearchTerms.enabled", false);
user_pref("network.predictor.enabled", false);
user_pref("network.predictor.enable-prefetch", false);
user_pref("gfx.content.skia-font-cache-size", 20);
user_pref("content.notify.interval", 100000);
user_pref("gfx.canvas.accelerated.cache-size", 512);
user_pref("media.cache_readahead_limit", 3600);
user_pref("media.cache_resume_threshold", 1800);
user_pref("image.mem.decode_bytes_at_a_time", 32768);
user_pref("network.buffer.cache.size", 65535);
user_pref("network.buffer.cache.count", 48);
user_pref("network.http.max-connections", 1800);
user_pref("network.http.max-persistent-connections-per-server", 10);
user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
user_pref("network.http.request.max-start-delay", 5);
user_pref("network.dnsCacheExpiration", 3600);
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.urlbar.trimHttps", true);
user_pref("browser.urlbar.untrimOnUserInteraction.featureGate", true);
user_pref("browser.urlbar.groupLabels.enabled", false);
user_pref("signon.privateBrowsingCapture.enabled", false);
user_pref("editor.truncate_user_pastes", false);
user_pref("permissions.default.desktop-notification", 2);
user_pref("permissions.default.geo", 2);
user_pref("geo.provider.network.url", "https://beacondb.net/v1/geolocate");
user_pref("extensions.getAddons.cache.enabled", false);
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.preferences.moreFromMozilla", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.profiles.enabled", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.compactmode.show", true);
user_pref("browser.privateWindowSeparation.enabled", false);
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("full-screen-api.transition-duration.enter", "0 0");
user_pref("full-screen-api.transition-duration.leave", "0 0");
user_pref("full-screen-api.warning.timeout", 0);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.download.open_pdf_attachments_inline", true);
user_pref("browser.bookmarks.openInTabClosesMenu", false);
user_pref("findbar.highlightAll", true);
user_pref("extensions.pocket.enabled", false);

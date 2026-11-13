# Đá Banh (iOS)

The iPhone twin of the Android **Đá Banh TV** app: a small, single-playlist
football player. Same playlist, same league tabs, same ordering rules —
re-implemented natively in SwiftUI + AVPlayer. No accounts, no server, no
special entitlements, no CarPlay. The only network traffic is the playlist
itself, its channel logos, and the streams.

- Playlist (hardcoded, as on Android): `https://thtt.pages.dev/tttt.m3u`
- Bundle id: `com.luun.nguyen.dabanh` · Display name: **Đá Banh**
- Version 1.0 (build 1) · Swift 5 · iOS 17+

## Structure

| File | Role |
| --- | --- |
| `project.yml` | XcodeGen project definition (house style). Run `xcodegen generate`. |
| `.github/workflows/build-dabanh.yml` | Cloud build: XcodeGen → unsigned xcodebuild → unsigned `.ipa` artifact `DaBanh-ipa-run<N>-<date>`. The owner signs the IPA himself. |
| `DaBanh/DaBanhApp.swift` | `@main` entry, dark colour scheme. |
| `DaBanh/Channel.swift` | `Channel` model + the `League` tab enum (1 Anh, 2 Tây Ban Nha, 3 Ý, 4 Pháp, 9 Khác). |
| `DaBanh/M3UParser.swift` | M3U parser + kickoff parser, ported from Android `parse` / `titleOf` / `kickoffOf`. |
| `DaBanh/LeagueClassifier.swift` | League classification + sort, ported from Android `leagueOf` / `bucketOf` / `sportOf` / `sortChannels`. |
| `DaBanh/PlaylistStore.swift` | Fetch + disk cache + refresh logic (see below). |
| `DaBanh/ContentView.swift` | Header (title, count, Làm mới) + 5 league tabs; rows show logo, title, source brand, kickoff, ĐANG ĐÁ badge. Pull-to-refresh. |
| `DaBanh/PlayerView.swift` | `AVPlayerViewController` (autoplay, external playback on) + an `AVRoutePickerView` AirPlay button that prefers video routes. |

## Loading behaviour (mirrors Android)

- Launch: load `playlist.m3u` from the caches directory first (only if
  > 100 bytes), then fetch remote. A good fetch rewrites the cache.
- Fetch failure with a list already on screen keeps the old list and shows
  "Chưa làm mới được — đang dùng danh sách cũ."
- Manual refresh: the **Làm mới** button and pull-to-refresh.
- Auto-refresh every 15 minutes: a foreground timer, plus a
  refresh-on-foreground whenever the data is older than 15 minutes
  (Android does the staleness check in `onResume`).
- First load picks the tab of the highest-priority league that has a live
  match at that moment; otherwise Ngoại Hạng Anh (Android `setData`).

## Classifier rules (ported from the Android source)

Source of truth: `tv-build/dabanh-src/.../com/gathin/dabanh/MainActivity.java`.

1. **Parsing.** `#EXTINF` sets a pending entry: logo from `tvg-logo="…"`,
   group from `group-title="…"`; the title is the text after the first
   comma *outside* quotes (fallback `Kênh`). The next line starting with
   `http` completes the entry. Empty group → `Kênh`.
2. **Kickoff.** First `HH:MM DD/MM` match in the title, read as
   Asia/Ho_Chi_Minh in the current year; a result > 30 days in the past
   rolls forward 365 days. No match → no kickoff.
3. **League.** Lowercase the title; substring-match keyword lists in the
   fixed order **Anh (1) → Tây Ban Nha (2) → Ý (3) → Pháp (4)**; no match
   → **Khác (9)**. The group-title / source brand is *not* used. Keyword
   lists are copied verbatim from the Android arrays `LG_ENG`, `LG_SPAIN`,
   `LG_ITA`, `LG_FRA` (including quirks like the trailing space in
   `"lille "`).
4. **Sort buckets** (against "now"): kickoff in [−10 min, +140 min] →
   bucket 0 (live); kickoff in the future beyond that → bucket 1 if the
   league is a priority league, else bucket 2; everything else (no
   kickoff, or finished > 140 min ago) → bucket 3.
5. **Ordering**: bucket ↑, then football before other sports (⚽ or no
   sport emoji = football; 🏐🏀🎾🏸🏒🥊 = other), then — bucket 1 only —
   league order ↑, then — buckets 0–2 — kickoff ↑ (no kickoff sorts
   last). Stable sort, like Java's `Collections.sort`.

Checked against a real playlist snapshot (314 `#EXTINF` entries): entries
parse as expected, including `🟢`-prefixed live titles (the kickoff regex
searches anywhere in the title, as on Android), the `Updated …`
pseudo-channel (lands in Khác / bucket 3, exactly as on Android), and the
many entries carrying `#EXTVLCOPT` option lines between the `#EXTINF` and
the stream URL — the pending entry persists across those lines until the
`http` line arrives, again exactly as the Android parser behaves. (Those
per-stream VLC options, e.g. `http-referrer`, are ignored by both parsers;
the Android player does not apply them from the playlist either.)

## Uncertainties / deliberate deviations

- **Dead keyword lists on Android:** the Java source defines `LG_GER`
  (Bundesliga) and `LG_VIE` (V.League / Vietnam) arrays but `leagueOf`
  never uses them, so German and Vietnamese matches fall into **Khác** on
  Android. The port preserves that behaviour; the unused lists were not
  ported. If the owner ever wants a Đức/Việt tab, that is an Android-side
  change first.
- **Lowercasing:** Android lowercases with `Locale.ROOT`; Swift uses
  `String.lowercased()`. Equivalent for every keyword in the lists.
- **Not ported (TV-only concerns):** the Android player's same-fixture
  fallback across CDNs (`FixtureKey` / PlayerActivity), DPAD/grid UI, and
  the dormant WireGuard tunnel code (`OWN_TUNNEL = false` on Android; the
  iOS app has no tunnel at all, per spec).
- **Kickoff label:** row times are formatted in Asia/Ho_Chi_Minh
  (`HH:mm dd/MM`), matching the times written in the playlist titles.
- This scaffold has **not been compiled** (no Xcode on the build VM); the
  first cloud workflow run is the first real compile check.

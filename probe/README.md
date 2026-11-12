# CarProbe — CarPlay entitlement probe

A one-purpose test app. It answers exactly one question:

> Can an IPA signed with the owner's own signing app carry the managed
> CarPlay entitlements (`com.apple.developer.carplay-video` +
> `com.apple.developer.carplay-audio`) and open a CarPlay **window scene**
> on his BMW (iOS 27.2)?

Nothing else about this app matters. It is a probe, not a product.

## Based on Cafari Lite (MIT)

The scene recipe, the per-window `WKWebView` pattern and the file-logging
idea come from [Cafari Lite](https://github.com/rplayai/cafari-lite) by
rPlay AI, MIT licensed — see `LICENSE` in this repo (their copyright notice,
kept verbatim) and the attribution headers in each source file.

### What was changed vs Cafari Lite

- **Entitlements always on.** Cafari Lite ships with
  `CAFARI_LITE_ENTITLEMENTS` empty (phone-only) because the entitlement is
  Apple-granted per account. The probe hard-wires
  `CODE_SIGN_ENTITLEMENTS = CarPlay.entitlements` (both keys) — carrying
  them is the thing being tested.
- **Bundle / name:** `com.luun.nguyen.cardashprobe`, display name
  **CarProbe**, manual signing style, no team.
- **Test page:** desktop YouTube (`https://www.youtube.com/?app=desktop`,
  desktop user-agent) — the same evidence page as the owner's CarDash
  recordings. Cafari Lite loads mobile YouTube.
- **Logging:** Cafari Lite writes `Documents/lite.log` and *truncates it on
  every launch*. The probe writes **`Documents/probe.log`, append-only
  across launches**, and mirrors every line on the phone screen (the owner
  screenshots the phone; the sandbox cannot easily be pulled from his
  phone).
- **Phone screen:** a probe dashboard instead of a browser — app name, big
  version/build string read from Info.plist, purpose text, live
  car-scene CONNECTED / NOT CONNECTED status with timestamp, the full
  event log, and a button that opens the test page on the phone.
- **Dropped for minimality:** the settings sheet, the parked/moving gate
  (`CarGate`, CoreLocation), the send-to-car handoff, the car native-
  resolution layout trick, and the location usage description.

## How it works

Two scenes in `Info.plist`: the ordinary phone `UIWindowScene`, and a plain
`UIWindowScene` under the session role `UIWindowSceneSessionRoleCarPlay`.
Because it is a window scene rather than a CarPlay template scene, a
`WKWebView` can draw on the head unit. iOS only creates the car scene when
the build's signing carries the CarPlay video entitlement — and per
Cafari Lite, video alone is not enough: without the audio entitlement next
to it the app never appears on the head unit, with no error anywhere.

## Build (cloud)

`.github/workflows/build-ipa.yml` (GitHub Actions, `macos-latest`):

- `xcodebuild` for a generic iOS device, **ad-hoc signing**
  (`CODE_SIGNING_ALLOWED=YES`, `CODE_SIGN_IDENTITY="-"`, manual style,
  **no provisioning profile**) so the entitlements blob is embedded in the
  `.app`. The workflow run number is stamped in as the app's build number.
- Extracts the entitlements **actually embedded** in the built app
  (`codesign -d --entitlements :-`) into `entitlements-built.txt` and
  **fails the run loudly** if either CarPlay key is missing.
- Packages `Payload/` into an IPA and uploads one artifact named
  `CarProbe-probe-run<run_number>-<YYYYMMDD>` containing the IPA (same
  unique name), `entitlements-built.txt` and the built app's `Info.plist`.

## The car test (3 checks)

Sign the IPA with the owner's usual signing app, install, connect to the
BMW's CarPlay, then screenshot the phone screen:

1. **Installs?**
2. **Appears on the CarPlay home screen?**
3. **Car scene connects?** — the phone screen status flips to
   `CAR SCENE: CONNECTED` and the log shows
   `*** CAR scene willConnect role=UIWindowSceneSessionRoleCarPlay ***`.

Three yeses = the full CarDash-style architecture is open. A working phone
app with "no" at 2/3 is the documented signature of the entitlement not
surviving the owner's signing path — no code change fixes that.

## Limitations

- CarPlay cannot be tested in the Simulator (entitlements cannot be
  embedded in Simulator builds). Real car, parked, only.
- Playback is whatever the site does in a web view. No DRM services.
- Apple can withdraw or change this scene role in any iOS release.

## Licence

MIT, see LICENSE (Cafari Lite, © 2026 rPlay AI). Not affiliated with,
endorsed by, or connected to Apple or YouTube. CarPlay is a trademark of
Apple Inc.

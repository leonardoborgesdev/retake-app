# retake.

A native iOS app that compresses video on-device and cuts silence/retakes automatically — built for content creators who record on their iPhone and want to skip the desktop edit entirely.

## What it's for

Two problems, one app:

1. **Video compression** — iPhone video eats storage fast. `retake.` re-encodes to H.265/HEVC using the iPhone's own hardware encoder, entirely on-device. No upload, no server, no account required to use this part.
2. **Silence & retake removal** — if you record yourself talking (tutorials, vlogs, Reels), you almost always stumble a line and say it twice, or leave dead air between sentences. `retake.` transcribes the audio, finds those gaps and repeated phrases, and lets you pick which take to keep — the kind of edit that normally means importing into a desktop NLE.

## Who it's for

Solo creators, podcasters, and anyone who films on an iPhone and edits nowhere — the target is "record → open retake. → post," no computer step in between.

## Why it exists (market gap)

- Video compressor apps on the App Store are common and undifferentiated (Video Compress, Panda Video Compressor, AniSmall, etc).
- Silence-remover apps also exist on iOS (BlitzCut AI, AutoCut AI, Jumpcut).
- **Retake detection** (catching a repeated/re-recorded line, not just silence) exists, but only as desktop plugins or web SaaS (AutoCut's Repeat feature, TimeBolt, Vizard, Cutback) — nothing native on iPhone.

`retake.` is the first of those three to run natively on-device, with no upload step.

## Features

- **Compress video** — HEVC re-encode via `hevc_videotoolbox` (hardware), with an optional "Enhance quality" toggle that raises the target bitrate for a visibly sharper result. Shows a before/after size comparison. Never modifies the original video.
- **Cut silence & retakes** — pipeline: transcribe (AssemblyAI) → detect silence (ffmpeg `silencedetect`) → render cuts → re-transcribe the edit to catch repeated phrases → if a retake is found, the user picks which occurrence to keep in a dedicated review screen (waveform-style take comparison, "keep" vs "REMOVED ↩").
- **Delete original from Photos** (optional, opt-in) — after compressing, offers to delete the source video to actually reclaim space. Works even under limited Photos access, using the identifier `PHPickerViewController` hands back for the item the user just picked.
- **History** — every compress/cut run is logged locally (filename, date, result).
- **Account** — local-only today (Keychain-backed email/password, no server). Structured so it can be swapped for a real backend later without changing the UI contract.
- **Onboarding** — two-page demo (waveform with silence highlighted → trimmed result) shown once before the first login.

## Screens

Real screenshots, iPhone 17 Simulator, iOS 26.5:

| Onboarding | Login | Home | Account |
|---|---|---|---|
| ![onboarding](docs/screenshots/onboarding.png) | ![login](docs/screenshots/login.png) | ![home](docs/screenshots/home.png) | ![account](docs/screenshots/account.png) |

Full visual identity reference (logo, palette, type, and every screen mocked up before implementation, including Compress and the retake picker): see `docs/design-mockup.md`.

## Tech stack

- **SwiftUI**, iOS 16.0+, single Xcode project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml` (never edit `.xcodeproj` directly — edit `project.yml` and run `xcodegen generate`).
- **[ffmpeg-kit-spm](https://github.com/tylerjonesio/ffmpeg-kit-spm)** (Swift Package, pinned `5.1.2`) — the GPL-free "min" build. It has no `libx264`/`libx265` (hence hardware `hevc_videotoolbox` for encoding) and **no libavfilter modules** (no `-vf` filters work on device — learned this the hard way, see `VideoCompressor/FFmpegCommandBuilder.swift`).
- **AssemblyAI** (cloud) — transcription only, for the silence/retake feature. The user pastes their own API key in Account settings; it's stored in the iOS Keychain and never leaves the device except in the direct API call.
- **PHPickerViewController** (not SwiftUI's `PhotosPicker`) — more reliable for large video files; also the only way to get `assetIdentifier` under limited library access for the delete-original feature.
- No backend. Accounts, history, and settings are all local to the device today.

## Compatible devices

- iPhone only (`TARGETED_DEVICE_FAMILY = "1"`), iOS 16.0+.
- Tested end-to-end on an iPhone 13 (physical device) and iPhone 17 Simulator.
- Not tested on iPad; not tested on iOS versions below 16.

## Project structure

```
VideoCompressor/
  Theme.swift              Design tokens, Wordmark, AppMark
  RootView.swift            Splash -> Onboarding -> Auth -> RootTabView
  RootTabView.swift          Home / History / Account tabs
  SplashView.swift / OnboardingView.swift / AuthView.swift
  HomeView.swift
  CompressOnlyView.swift + VideoCompressionService.swift + FFmpegCommandBuilder.swift
  CutOnlyView.swift + EditingPipeline.swift + RetakeReviewView.swift
  SilenceCutPlanner.swift / SilenceDetector.swift / CutRenderer.swift / CutMapper.swift
  TranscriptQA.swift / RetakeCandidate.swift / AssemblyAIClient.swift
  AccountStore.swift / AccountView.swift / HistoryStore.swift / HistoryView.swift
  VideoPicker.swift / PhotoLibrarySaver.swift / APIKeyStore.swift
VideoCompressorTests/       28 XCTest cases covering the pure-logic pipeline
docs/
  design-mockup.md          Full visual identity + screen-by-screen spec
  screenshots/               Real on-device/simulator screenshots
STATUS.md                    Chronological engineering log (build issues, fixes, decisions)
```

## Building

```bash
xcodegen generate
xcodebuild -project VideoCompressor.xcodeproj -scheme VideoCompressor \
  -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

To run on a physical device, open `VideoCompressor.xcodeproj` in Xcode, pick the device, and hit Run — the first run on a new Apple ID needs Xcode's own GUI to create the signing certificate (this cannot be done from the command line; a headless `xcodebuild` will fail with "No signing certificate ... found" even after the cert exists, because `codesign` needs an interactive Keychain access session to read the private key).

## Known limitations / next steps

- **No backend** — login/signup work but are local-only. Needed before this can be a real SaaS.
- **Delete-original-from-Photos** and the **full cut/retake pipeline** haven't been verified end-to-end on a physical device with a real AssemblyAI key yet.
- Compression presets and language settings are currently display-only (no real options behind them).
- Not on the App Store — sideloaded via Xcode, free-tier provisioning profile expires after 7 days.

## Credits

Silence/retake detection pipeline ported from [Morfeu333/silence-retake-editing](https://github.com/Morfeu333/silence-retake-editing) (Python → Swift).

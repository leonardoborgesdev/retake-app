# retake.

**On-device video compression with AI-powered retake detection.**

## Why this exists

Filming yourself on an iPhone means you almost always stumble a line, say it twice, or leave dead air between sentences — and finding the "good take" in a pile of raw footage afterward is tedious. Most video compressor apps on the App Store are undifferentiated, and the tools that actually catch repeated/re-recorded lines (not just silence) only exist as desktop plugins or web SaaS. `retake.` does both on-device: it shrinks the file and picks out the awkward parts, natively, with no upload step.

## Features

- **On-device video compression** — re-encodes to H.265/HEVC using the iPhone's hardware encoder (`hevc_videotoolbox`), with real-time VideoToolbox mode for faster exports. No upload, no server, no account required.
- **Silence & retake detection** *(bonus, not in-app)* — transcribes the audio, finds silence gaps and repeated phrases, and surfaces a review screen where you pick which take to keep. Fully implemented and tested in isolation, but not linked from Home — see Status.
- **Record with teleprompter** *(bonus, not in-app)* — native camera capture with an auto-scrolling script overlay, chained into Compress/Cut. Also implemented and not linked from Home.
- **Delete original from Photos** (opt-in) — reclaim storage after compressing, without losing the source unless you choose to.
- **Local run history** — every compress/cut session is logged on-device.
- **Nine implemented screens** — splash, onboarding, auth, home, compress, processing, retake review, history, and account.
- **Local-only auth** — the account flow runs entirely against the Keychain out of the box; no backend is required to build and run the app.

## Tech stack

- **Swift / SwiftUI**, iOS 16.0+, single Xcode project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.
- **[ffmpeg-kit-spm](https://github.com/tylerjonesio/ffmpeg-kit-spm)** (pinned `5.1.2`) for on-device encoding and silence detection — the GPL-free build, so hardware `hevc_videotoolbox` is used for encoding rather than `libx264`/`libx265`.
- **AssemblyAI** (optional, bring-your-own-key) for transcription that powers the silence/retake pipeline. The key is pasted by the user in Account settings and stored in the Keychain; it never leaves the device except in the direct API call.
- **PHPickerViewController** for video import — more reliable for large files, and the only way to get an `assetIdentifier` under limited library access.
- No cloud dependency is required for the core features (compression, silence/retake detection, history). Supabase is wired up for auth but the app runs fully without it configured.

## Setup

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open VideoCompressor.xcodeproj
```

Auth is optional and only needed if you want to wire up a real Supabase backend for the account screen:

```bash
cp VideoCompressor/Secrets.swift.example VideoCompressor/Secrets.swift
# then fill in your own Supabase project URL and anon key
```

`Secrets.swift` is gitignored. Without it configured, the app still builds and runs — compression, history, and the silence/retake pipeline don't touch it.

To build from the command line:

```bash
xcodebuild -project VideoCompressor.xcodeproj -scheme VideoCompressor \
  -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

To run on a physical device, open the project in Xcode, pick the device, and hit Run — first-run signing needs Xcode's own GUI to create the certificate.

## Screens

Real screenshots, iPhone 17 Simulator, iOS 26.5:

| Onboarding | Login | Home | Account |
|---|---|---|---|
| ![onboarding](docs/screenshots/onboarding.png) | ![login](docs/screenshots/login.png) | ![home](docs/screenshots/home.png) | ![account](docs/screenshots/account.png) |

Full visual identity reference (logo, palette, type, and every screen mocked up before implementation) is in `docs/design-mockup.md`.

## Project structure

```
VideoCompressor/
  Theme.swift                Design tokens, wordmark, app mark
  RootView.swift              Splash -> Onboarding -> Auth -> RootTabView
  RootTabView.swift            Home / History / Account tabs
  SplashView.swift / OnboardingView.swift / AuthView.swift
  HomeView.swift
  CompressOnlyView.swift + VideoCompressionService.swift + FFmpegCommandBuilder.swift
  CutOnlyView.swift + EditingPipeline.swift + RetakeReviewView.swift
  SilenceCutPlanner.swift / SilenceDetector.swift / CutRenderer.swift / CutMapper.swift
  TranscriptQA.swift / RetakeCandidate.swift / AssemblyAIClient.swift
  AccountStore.swift / AccountView.swift / HistoryStore.swift / HistoryView.swift
  VideoPicker.swift / PhotoLibrarySaver.swift / APIKeyStore.swift
  SupabaseAuthClient.swift / Secrets.swift.example
VideoCompressorTests/         30 XCTest cases covering the pure-logic pipeline
docs/
  design-mockup.md             Visual identity + screen-by-screen spec
  screenshots/                  Simulator screenshots
```

## Status

All 9 mockup screens are implemented and match the design spec. The build compiles cleanly and all 30 tests pass. It's been run and tested end-to-end in the iPhone 17 Simulator. Physical-device testing is still pending.

**The app's focus is Compress.** Home only surfaces the compression flow — the one that's been exercised end-to-end and is closest to production-ready. Record (native camera + teleprompter) and Cut (silence/retake review) are real, working features with their own views and pipelines, but they're intentionally kept out of the app's navigation and documented here as bonus/optional rather than presented as equally core. They're a one-line change away from being wired back into Home if that becomes the priority.

Known limitations:

- Compression presets and language settings in Account are currently display-only.
- The delete-original-from-Photos flow and the full cut/retake pipeline haven't been verified end-to-end on a physical device with a real AssemblyAI key yet.
- Not distributed on the App Store — sideloaded via Xcode.

## Credits

Silence/retake detection pipeline ported from [Morfeu333/silence-retake-editing](https://github.com/Morfeu333/silence-retake-editing) (Python → Swift).

## License

Todos os direitos reservados — uso e redistribuição não autorizados.

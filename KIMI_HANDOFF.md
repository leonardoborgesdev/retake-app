# Kimi/OpenCode Handoff

Project: `/Users/caiosantos/Developer/VideoCompressor`

Use this context before making changes. The goal is to continue the native iOS app so Caio can plug in the iPhone and test with minimal friction.

## Current User Goal

Build and finish a personal iPhone app for video compression and optional speech cleanup:

- Import a video from Photos.
- Compress locally on the iPhone with FFmpeg embedded in the app through `ffmpeg-kit-spm`.
- Save the compressed result back to Photos.
- Do not use a server for compression.
- Handle picker, ffmpeg, and Photos save failures with simple user-facing errors.
- Cancel FFmpeg work if the user leaves the relevant screen during processing.
- Manual validation is acceptable: real iPhone video, compare original vs compressed in Photos.

The user also wants to continue implementation through OpenCode using TokenRouter's free Kimi K3 route.

Latest validation by Codex on 2026-08-03:

- Generic iOS device build succeeded with `CODE_SIGNING_ALLOWED=NO`.
- Simulator test build compiled and installed artifacts, but `xcodebuild test` was interrupted after the simulator launch/test runner hung for about two minutes. Treat this as a simulator/test-runner issue first, not a Swift compile failure.
- OpenCode history is local at `/Users/caiosantos/.local/share/opencode/opencode.db`.

## Agent/Model Setup

OpenCode is configured in `opencode.json`.

- Default model: `tokenrouter/moonshotai/kimi-k3-free`
- Provider: TokenRouter, OpenAI-compatible endpoint `https://api.tokenrouter.com/v1`
- Free route: `moonshotai/kimi-k3-free`, currently $0 input and $0 output while the provider keeps that offer active.
- Paid route also configured: `moonshotai/kimi-k3`, pay-as-you-go. Do not switch to it unless Caio explicitly asks.
- Conserve free quota: keep reasoning/output modest. Prefer focused reads and focused edits.

Secret handling:

- TokenRouter key is in `.env.opencode`.
- `.env.opencode` is gitignored.
- Do not print, copy, commit, or move the key.

Start command:

```bash
cd /Users/caiosantos/Developer/VideoCompressor
./run-kimi-opencode.sh
```

## Project State

The repo is clean except for OpenCode setup files added by Codex:

- `.gitignore` updated to ignore `.env.opencode`
- `opencode.json` added
- `run-kimi-opencode.sh` added

The app itself already exists and has many Swift files. Important files:

- `VideoCompressor/VideoCompressorApp.swift`
- `VideoCompressor/HomeView.swift`
- `VideoCompressor/CompressOnlyView.swift`
- `VideoCompressor/CutOnlyView.swift`
- `VideoCompressor/VideoCompressionService.swift`
- `VideoCompressor/CutRenderExecutor.swift`
- `VideoCompressor/EditingPipeline.swift`
- `VideoCompressor/PhotoLibrarySaver.swift`
- `VideoCompressor/VideoPicker.swift`
- `VideoCompressor/SettingsView.swift`
- `VideoCompressor/APIKeyStore.swift`
- tests under `VideoCompressorTests/`

`STATUS.md` contains the broader previous implementation summary. Read it first.

## Xcode/Device State Checked On 2026-08-03

Earlier blocker about missing iOS platform is resolved.

Verified commands:

```bash
xcodebuild -version
xcodebuild -showsdks
xcodebuild -showdestinations -project VideoCompressor.xcodeproj -scheme VideoCompressor
```

Observed state:

- Xcode `26.5`, build `17F42`
- iOS SDK `26.5` exists
- iOS Simulator SDK `26.5` exists
- Destination `Any iOS Device` exists
- Connected physical destination exists: `iPhone de Kaio`
- Several iOS 26.5 simulators are available

## Immediate Next Step

The generic iOS build already passed:

```bash
xcodebuild -project VideoCompressor.xcodeproj -scheme VideoCompressor -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```

If you need to re-check, run it again. If it fails:

1. Read the compiler errors carefully.
2. Patch only the needed Swift/project files.
3. Re-run the same build.
4. Keep iterating until it builds.

Then optionally run tests:

```bash
xcodebuild test -project VideoCompressor.xcodeproj -scheme VideoCompressor -destination "platform=iOS Simulator,name=iPhone 17,OS=26.5"
```

Note: the last test attempt hung during simulator launch and was interrupted. If debugging tests, start by booting/erasing the simulator or using a different simulator destination, then rerun.

Then for physical iPhone:

1. Open `VideoCompressor.xcodeproj`.
2. Pick `iPhone de Kaio`.
3. Ensure Signing & Capabilities uses Caio's Apple team.
4. Run from Xcode.

## Implementation Constraints

- Keep the app native SwiftUI.
- Keep ffmpeg local through `ffmpeg-kit-spm`.
- Do not add cloud upload for compression.
- AssemblyAI is only for the silence/retake transcription feature and requires the user to paste their own key in settings.
- Prefer narrow fixes over refactors.
- Do not remove existing features unless required to compile.
- Do not commit secrets.
- If changing project structure, regenerate with `xcodegen generate`.

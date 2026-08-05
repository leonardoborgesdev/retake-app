Read `KIMI_HANDOFF.md` and `STATUS.md` first.

Continue this iOS project from the current state. Use only the configured free model `tokenrouter/moonshotai/kimi-k3-free`; do not switch to paid models.

Current verified state:

- Generic iOS device build already succeeds:
  `xcodebuild -project VideoCompressor.xcodeproj -scheme VideoCompressor -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build`
- Simulator tests compiled but the simulator launch/test runner hung and were interrupted.
- The next practical goal is making the app easy to run on the physical device `iPhone de Kaio` and fixing any runtime/signing/manual-test issues that appear there.

Work rules:

- Keep changes narrow.
- Do not print or commit `.env.opencode`.
- Do not remove local FFmpeg compression.
- AssemblyAI is only for transcription in the silence/retake feature.
- Prefer short responses and small tool calls to conserve free quota.

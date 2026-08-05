# Visual identity

The concept comes from film-set vernacular — "retake" is literally what a clapperboard exists to mark. The app icon is a claquette stripe over a waveform, cut in the middle by a grease-pencil mark (the way editors used to physically mark a cut point on tape).

## Palette

Black and white as the base, one accent — the grease-pencil color.

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink` | `#0B0B0C` | `#F2F2F3` | primary text |
| `paper` | `#FFFFFF` | `#111113` | background |
| `surface2` | `#F4F4F5` | `#1B1B1E` | cards, rows |
| `line` | `#DCDCE0` | `#2D2D32` | borders |
| `inkSoft` | `#77777C` | `#94949A` | secondary text |
| `accent` | `#E0982C` | `#F0AB42` | the grease-pencil mark — CTAs, highlights |
| `discard` | `#C65B42` | `#C65B42` | semantic "removed/discard" state only |
| `board` | `#0A0A0B` | `#000000` | the claquette black — splash, onboarding, app icon |

## Type

- Display: Avenir Next / Helvetica Neue, heavy weight — the wordmark "retake." with the trailing dot always in `accent`.
- Body: system font (San Francisco).
- Data/timecode: SF Mono / `ui-monospace`.

## Screen-by-screen spec

1. **Splash** — claquette mark, loading ring, "warming up ffmpeg…"
2. **Onboarding (2 pages)** — dark. Page 1: waveform with silence segments in `discard`, "Hear the problem." Page 2: trimmed waveform, "−1.7s saved" chip in `accent`.
3. **Log in / Sign up** — segmented tabs, email/password fields, "Continue with Apple" (required by App Store guidelines once any third-party sign-in exists).
4. **Home** — two feature cards (Compress video, Cut silence & retakes), wordmark as the nav title.
5. **Compress** — video preview, source size, "Enhance quality" toggle, before/after size bars (proportional to actual bytes), optional "Delete original from Photos."
6. **Processing** — step list (Transcribing → Detecting silence → Cutting scenes → Finding retakes → Rendering) with done/active/pending states and a live percentage.
7. **Pick a take** — two waveform-style rows per candidate phrase, "keep" vs a `discard`-colored "REMOVED ↩" badge, a segmented control to flip the choice.
8. **History** — list of past compress/cut runs with a result chip (`-77%`, `3 cuts`).
9. **Account** — profile, plan, stats, AssemblyAI API key, language, compression preset, enhance-quality default, about, sign out. (Settings live here — there is no separate Settings screen.)

## Competitive reference

Screenshots pulled from the App Store (via the public iTunes lookup API, `https://itunes.apple.com/lookup?id=<appId>`) informed four concrete decisions:

- **Onboarding with a live before/after demo** before asking for an account — pattern from *Silence Remover – Auto Cut*.
- **Persistent bottom tab bar** instead of a Settings modal — pattern from *AutoCut AI*.
- **Color-coded removed state with an undo affordance** in the take picker — pattern from *Jumpcut*.
- **Optional delete-original-after-compress** — pattern from *Video Compressor & Reduce size*.

None of `retake.`'s core differentiator — on-device retake detection with a manual review step — exists in a native iPhone app among competitors; the closest equivalents (AutoCut's Repeat, TimeBolt, Vizard, Cutback) are desktop plugins or web SaaS.

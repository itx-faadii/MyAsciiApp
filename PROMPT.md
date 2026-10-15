# SketchGlyph - Master Prompt (for an AI coding agent in GitHub Codespaces)

## ROLE
You are a senior Flutter/Dart engineer, UI/UX designer and release engineer working fully autonomously inside this repository, in a GitHub Codespaces Linux x86_64 machine with terminal access. Build and ship a production-ready, fully offline (serverless) Android app called **SketchGlyph** with Flutter (stable) and Dart 3+. The user is non-technical and only wants the final working result. Create every file, folder, asset, test and config yourself. Work through ALL phases (0-10) in order without waiting for approval. Stop only if something is impossible without the user; then state the one exact action needed in one short message and continue with everything that is not blocked.

## ENVIRONMENT (READ FIRST)
- The devcontainer has already installed Flutter (`~/flutter`), Android SDK (`~/android-sdk`), JDK 17 and Node 20. First run: `flutter --version`, `flutter doctor -v`. If something is missing, install or fix it yourself (for example `flutter doctor --android-licenses`, `sdkmanager` packages). If PATH is missing, export `~/flutter/bin`, `~/android-sdk/cmdline-tools/latest/bin` and `~/android-sdk/platform-tools`.
- There is NO emulator and NO physical device here. You can build APKs but cannot run the UI. So: do not try to launch emulators. Verify with analyze, unit tests, widget tests, golden tests, and pure-Dart sample generators.
- Gradle is heavy: run long commands (`flutter build apk`) in the background with output redirected to `./.logs/<name>.log` (git-ignored) and poll the log with short reads. Use `--no-daemon` if memory is tight. Never paste long logs into chat.
- Keep chat output very short to save credits and context. No code dumps.
- Codespaces storage is ephemeral if deleted: commit often, and tell the user to push to GitHub.

## AUTONOMOUS WORKFLOW
1. After each meaningful change loop until green: `dart format .` -> `flutter analyze` (0 issues) -> `flutter test` -> (at the end of each phase) `flutter build apk --debug`. If anything fails, read the error, fix the code, re-run. Never leave the repo broken.
2. A phase is DONE only when analyze shows 0 issues, tests pass, the debug APK builds, and its Exit Criteria are verified. Then `git add -A && git commit -m "Phase N: <name>"` and continue.
3. Maintain `PROGRESS.md` at the repo root: each phase with status (TODO / IN PROGRESS / DONE), last commit, known issues, next step. If restarted or the context resets, read `PROMPT.md` and `PROGRESS.md` and resume from the first unfinished phase.
4. Never fake results. Do not weaken or delete tests to make them pass. Incomplete things go into PROGRESS.md and get fixed.
5. Visual proof without a device: write `tool/generate_samples.dart` (pure Dart, `image` package) that renders ASCII and sketch outputs for 3 reference images (portrait, landscape, object; generate them procedurally or keep small test assets) for every ASCII mode and every sketch style into `docs/samples/`, plus contact sheets (before/after). Re-run after engine changes, inspect the images yourself (view them if your tool can), and tune until they look right. Also produce Flutter golden images for key screens in Light, Dark and AMOLED into `docs/screenshots/` (`flutter test --update-goldens` works on Linux).
6. After each phase print only: PASS/FAIL for analyze, tests and build, plus a 2-line summary.

## GLOBAL PRODUCT RULES
- 100% serverless and offline: no backend, API calls, Firebase, analytics, or remote fonts/assets. The release AndroidManifest must NOT declare the INTERNET permission. Privacy statement in the app: "All processing happens on your device."
- Android primary (min SDK 24). Prepare iOS 13+ config (privacy manifest, usage descriptions) but note that building iOS needs a Mac.
- Icons: real vector icons only (phosphor_flutter or lucide_icons_flutter). NEVER emoji anywhere in the UI.
- Architecture: monorepo.
  - `packages/sketchglyph_engine`: PURE DART package (no Flutter imports) with the ASCII engine and sketch engine, tested with `dart test`.
  - Flutter app, feature-first: `core/`, `features/{home, ascii, sketch, create, export, gallery, settings, onboarding}`, `shared/`, with presentation / domain / data separation.
  - State: Riverpod. Navigation: go_router. Strict lints (flutter_lints), null-safe, zero warnings.
- Heavy image work runs in background isolates (`Isolate.run` / `compute`) with progress and cancellation; the UI must never jank.
- All algorithms are deterministic (same input + settings + seed = identical output).
- Write unit, widget and golden tests while building each phase, not at the end.
- Packages (resolve latest stable via `flutter pub add`): flutter_riverpod, go_router, image, image_picker, file_picker, path_provider, hive or isar (or sqflite), share_plus, gal, pdf, printing, permission_handler, phosphor_flutter, flutter_launcher_icons, flutter_native_splash, intl, vector_math, mocktail. Bundle fonts (JetBrains Mono, Courier Prime, IBM Plex Mono, Inter) as local assets (download once at build time of the repo, commit them; the app itself never fetches fonts). If you need another package, choose a well-maintained one and note it in PROGRESS.md.
- THEMING: Dark theme is first-class. Modes: System, Light, Dark, AMOLED. Every screen, sheet and dialog is designed and tested in all modes. Theme persists locally and is applied before the first frame (no white flash) with an animated cross-fade on switch.

## PHASE 0 - FOUNDATION
Environment check, project creation, app id `com.sketchglyph.app`, monorepo structure, flavors (dev/prod), analysis options, `scripts/check.sh` (format + analyze + test), README, `.gitignore` (exclude keystores, key.properties, `.logs/`, `build/`), git init, PROGRESS.md, bundled fonts. Create the GitHub Actions workflow now (see Phase 10).
Exit: analyze + tests pass, debug APK builds, first commit done.

## PHASE 1 - DESIGN SYSTEM, DARK THEME, UI SHELL
Tokens via ThemeExtension on Material 3 ColorScheme: color (Light, Dark, AMOLED), typography, 4/8 spacing, radius, elevation, motion. Look: clean "artist studio", large tap targets (48dp), generous whitespace.

DARK ("midnight studio"):
- background `#0E1116`, surface `#151A21`, surfaceHigh `#1C232C`, surfaceTop `#242D38`, outline `#2E3944` (thin 1px borders instead of heavy shadows).
- AMOLED: background `#000000`, surface `#0A0C0F`, slightly brighter borders.
- One vivid primary (electric violet `#8B7CFF` or cyan `#4CC9F0`) plus a secondary accent; soft primary-to-secondary gradient ONLY on hero elements (main CTA, selected style card, slider thumbs, progress rings).
- Text: primary `#E8ECF1`, secondary `#9AA7B5`, disabled `#5C6773`. All text pairs >= 4.5:1 contrast. Never pure white on pure black.
- Dark elevation = lighter surface tone + thin outline + faint accent glow on focus/selection.
- Glass (blurred translucent bottom sheets and nav bar, sigma 12-20, 1px light border) used sparingly, with a no-blur fallback.
- Selected style cards get a glowing gradient border; sliders show a live value pill; chips/toggles have clear on/off contrast.
- Status/navigation bar icons adapt to the theme. Previews are never color-inverted. ASCII preview defaults to dark bg + light text in dark mode (overridable). Sketch preview always shows the real paper color on a dark "desk" with soft vignette and paper shadow.
- Themed shimmer skeleton loaders. Icons: duotone/fill for active, regular/light for inactive.

Widgets: primary/secondary/ghost buttons, icon buttons, chips, segmented control, labeled sliders, bottom sheets, cards, toasts, empty states, theme toggle (System/Light/Dark/AMOLED with sun, moon, circle-half, device icons).
Shell: bottom navigation (Home, Create, Gallery, Settings) with animated indicator; responsive for phones and tablets; safe areas; text scaling up to 200%.
Exit: golden tests for core screens in Light/Dark/AMOLED; automated contrast test passes for all token pairs in all modes; no emoji icons.

## PHASE 2 - IMAGE INPUT PIPELINE
Sources: gallery, camera, file picker, clipboard where supported. Graceful permission flows (explain, request, denied, open settings). Safe decode, EXIF orientation fix, downscale to a working size (default 2048px long edge, configurable) while keeping the original for export. Crop/rotate/flip with aspect presets. Handle corrupted, huge and unsupported files and out-of-memory.
Exit: JPG/PNG/WEBP load with correct orientation (tested); failure paths tested.

## PHASE 3 - ASCII ENGINE (PURE DART, MUST BE ACCURATE)
Pipeline: decode -> preprocessing -> grayscale with Rec.709 luminance in linear light (gamma-correct) -> contrast/brightness/gamma/sharpen/invert/dither -> area-average (box/Lanczos) resample to grid -> map cells to characters -> output.
1. Cell aspect ratio is configurable, derived from the selected font's real metrics (store measured metrics per bundled font; do not hard-code one ratio).
2. Area-averaging per cell, never nearest-neighbor.
3. Character ramps sorted by MEASURED glyph ink density. For pure Dart, precompute density tables per bundled font with a build-time tool script (parse the TTF and rasterize glyphs) and ship them as a JSON asset; also add a Flutter-side runtime measurement (TextPainter/Canvas) used in an app test to verify the table. Cache per font.
4. Grid size by columns (40-400), by font size, or fit-to-page.
5. Optional Sobel edge mode choosing directional characters (`/ \ | - _`).
6. Optional Floyd-Steinberg / Bayer dithering.
Outputs: plain text, colored text (per-char RGB), HTML, and a PNG rasterized with the same font metrics as the preview.
Exit: dart tests for luminance, ramp ordering, aspect correction, determinism; reference tests (gradient, checkerboard, synthetic face) assert dark-to-light mapping numerically; 100% public API coverage in the engine package.

## PHASE 4 - ASCII MODES AND UX
Segmented control with three modes:
- A) DEFAULT: tuned built-in ramp, works in one tap.
- B) ART BY CHARACTER SET: presets (Classic ".:-=+*#%@", Blocks, Minimal, Dense 70-level, Binary "01", Braille, Letters, Numbers) or a custom set via a drag-to-reorder chip editor with an "auto-sort by density" button.
- C) ART BY USER STRING: (1) Text-flow: the string repeats in order across the grid and each character's size/weight/opacity is modulated by pixel brightness; (2) Ramp: unique characters of the string sorted by density become the tone ramp. Validate empty, emoji, unsupported glyphs and very long strings with clear messages.
Controls: columns/detail, contrast, brightness, gamma, invert, font, font size, line height, letter spacing, foreground/background color, color mode (mono / original / gradient), dithering. Color presets: Terminal Green, Amber Monitor, Paper Ink, Neon, Matrix (independent of the app theme).
UX: debounced (~150ms) low-res live preview while dragging, full-res on release; pinch-zoom and pan; draggable before/after compare slider; named presets; reset button.
Exit: all three modes tested; identical settings give identical output; samples in `docs/samples/ascii/`.

## PHASE 5 - REALISTIC SKETCH ENGINE
Pure Dart engine, in isolates with a progress callback. Goal: output that looks hand-drawn on paper, NOT a filter.
Techniques: grayscale -> invert -> Gaussian blur -> color-dodge (classic pencil), refined with XDoG for line work; hatching along local contour direction (structure tensor); cross-hatching in darks (0, 45, 90, 135 degrees); stroke realism with pressure taper, Perlin/simplex wobble, SEEDED jitter, overlapping translucent strokes, graphite grain; procedural paper grain with multiply blending (tooth effect); paper options: white cartridge, cream, grey, kraft, lined, grid. Seed for reproducibility.
Styles (preset + tunable): 1) Graphite Pencil (HB, 2B, 6B) 2) Mechanical Pencil 3) Charcoal with smudge 4) Blue Ballpoint Pen (thin blue cross-hatching, uneven ink flow, tiny ink blobs) 5) Black Fineliner/Ink (clean lines, stippled shadows) 6) Colored Pencil (waxy, source colors) 7) Contour Line Art 8) Stipple/Dotwork.
Controls: detail, line weight, hatching density, shading, edge strength, paper type, ink/pencil color, grain, smudge, background transparency, seed with re-roll. Optional draw-in animation replaying the recorded stroke list.
Generate before/after sheets for every style on the 3 reference images into `docs/samples/sketch/`, inspect them critically and iterate on tuning until they look convincingly hand-drawn: no banding, no visible tiling, strokes follow form.
Exit: determinism tests (same seed = same bytes); performance test (1080px image in a few seconds; O(n) algorithms, no per-pixel allocations); samples generated.

## PHASE 6 - CREATE FLOW AND EDITOR
Single Create flow: source -> type (ASCII/Sketch) -> style carousel -> fine-tune glass bottom sheet -> preview -> export. Undo/redo for settings, compare with original, randomize seed, favorite presets, batch mode (same settings on multiple images with queue and progress). Output canvas presets (1:1, 4:5, 9:16, A4, custom). Optional text caption and watermark overlays (off by default). Fully styled for dark mode.
Exit: end-to-end flow widget tests (fake picker/engine); no dead ends; back navigation preserves state.

## PHASE 7 - EXPORT, SAVE, SHARE
Formats: PNG (1x/2x/4x), JPG (quality slider), transparent PNG, PDF (A4/Letter, fit/fill), SVG, TXT and HTML for ASCII. Actions: save to gallery, system share, copy ASCII text, copy image where supported, print. Correct scoped storage (Android 10+) and iOS Photos permissions. Large exports in an isolate with progress and cancel. File naming `sketchglyph_YYYYMMDD_HHmmss`.
Exit: export logic unit-tested (names, formats, scaling); ASCII PNG matches the engine preview bytes.

## PHASE 8 - LIBRARY, SETTINGS, POLISH, ACCESSIBILITY
- Gallery: local DB with projects (source ref, settings JSON, thumbnail, result); grid/list toggle, search, sort, multi-select delete, rename, duplicate, re-edit, favorites.
- Settings: Appearance (System/Light/Dark/AMOLED, 4-6 curated accents, reduce transparency/blur toggle, live theme preview), default export format/quality, default font, language, haptics, clear cache, storage usage, about, licenses, privacy statement.
- Onboarding: 3 skippable screens with real vector illustrations (dark variants), shown once.
- Polish: haptics, Hero and shared-axis transitions, skeletons, meaningful empty/error states, undo snackbars, keyboard-safe forms, tooltips.
- Accessibility: semantic labels, 4.5:1 contrast in all modes, screen-reader support, reduced-motion respect. Localization scaffold with intl (English complete). No hard-coded strings.
Exit: widget tests for gallery and settings; grep proves no HTTP client is used.

## PHASE 9 - STABILITY AND TESTING
Size-capped LRU cache, tiled processing for very large images, graceful degradation on low-RAM devices, blur/glow fallback for low-end devices, dithering/noise on large dark gradients to avoid banding. Global error handling with a local-only log viewer (no remote reporting) and recovery of in-progress projects after an app kill. Add an `integration_test/` folder with flows (import -> ASCII -> export; import -> sketch -> save); keep them compile-checked locally. Coverage: engine 95%+, overall as high as practical. Write `docs/PERFORMANCE.md` with measured engine timings.
Exit: all runnable tests green; coverage numbers in PROGRESS.md.

## PHASE 10 - PRODUCTION RELEASE AND CI
- `.github/workflows/build.yml`: triggers push, pull_request, workflow_dispatch, tags `v*`. Steps: checkout, Java 17 (temurin), subosito/flutter-action (stable, cache), pub get, `dart format --set-exit-if-changed .`, `flutter analyze`, `dart test` (engine), `flutter test --coverage`. Build `flutter build apk --debug` on every push and upload artifact `sketchglyph-debug-apk`. On tags `v*`: `flutter build apk --release --split-per-abi` and `flutter build appbundle --release`, upload both and attach to a GitHub Release. Release signing reads secrets ANDROID_KEYSTORE_BASE64, KEY_ALIAS, KEY_PASSWORD, STORE_PASSWORD, decodes the keystore in CI only and writes key.properties in CI only; if secrets are missing, build with debug signing and log a clear note. Never commit keystores or passwords. Also upload `docs/samples` as an artifact.
- Locally in this Codespace: create an upload keystore with `keytool` (outside git, document how to download and back it up), configure `key.properties`-based signing, run `flutter build apk --release --split-per-abi` and `flutter build appbundle --release`, and report the output paths.
- App icon + adaptive icon (with monochrome layer for Android 13+) and native splash, with light/dark variants (flutter_launcher_icons, flutter_native_splash). Generate the icon artwork yourself as vector/PNG files.
- R8/ProGuard shrinking, split ABIs. The release manifest must have NO INTERNET permission (debug/profile manifests may have it for tooling). iOS: privacy manifest and usage descriptions, release config documented.
- Verify no analytics SDKs, no INTERNET permission in the merged release manifest, and no secrets in the repo (grep scan).
- Docs: `README.md`, `PRIVACY_POLICY.md` (no data collected), `STORE_LISTING.md`, `SCREENSHOTS_CHECKLIST.md`, `CHANGELOG.md`, `RELEASE_CHECKLIST.md`, `docs/CI_GUIDE.md` (simple steps: push to GitHub, open Actions, download the APK artifact, create signing secrets, tag v1.0.0).
- Final: run format, analyze, all tests and release builds again, update PROGRESS.md, commit, `git tag v1.0.0`.
Exit: release APKs and AAB build successfully; workflow YAML is valid; all docs exist.

## FINAL OUTPUT (print at the very end, short)
- Status of each phase (from PROGRESS.md)
- Paths: debug APK, release APKs, AAB, docs/samples, docs/screenshots, docs/
- Exact git commands for the user to push (`git push -u origin main --tags`) and how to download the APK file from the Codespaces file explorer
- What was verified locally and what still needs a real device
- Known limitations and manual steps for the user (signing key backup, store accounts, iOS build on a Mac)

## DEFINITION OF DONE
Every feature works offline; no emoji icons; ASCII output is deterministic and verified by tests; sketch styles look convincingly hand-drawn in the samples; dark/AMOLED/light themes are polished; export and share work; the debug and release APKs build; the app is release-ready with documentation.

**START NOW**: brief environment check, then Phase 0, and continue automatically through Phase 10.

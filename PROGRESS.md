# SketchGlyph — PROGRESS

Source of truth: `PROMPT.md`. Resume from the first unfinished phase.

| Phase | Status | Last commit | Notes / next step |
|---|---|---|---|
| 0 — Foundation | DONE | pending | Flutter 3.47.7 stable + Android SDK installed in sandbox (`/opt/tools/flutter`, `/opt/android-sdk`); env helper `/tmp/env.sh`. App id `com.sketchglyph.app`, minSdk 24. Monorepo, strict analysis options, `scripts/check.sh`, CI workflow, fonts + `assets/font_metrics.json` committed. README still stub — expanded in Phase 10. |
| 1 — Design system, dark theme, shell | DONE | pending | Tokens + SurfaceTokens/AccentTokens extensions; Light/Dark/AMOLED themes with 5 accent presets; contrast test enforces ≥4.5:1 for all text pairs and onPrimary in all modes and accents (all pass). Riverpod settings + SharedPreferences persistence applied before first frame; animated theme cross-fade; go_router 4-tab shell with glass nav; onboarding redirect; widget tests pass. Goldens for core screens still to add (Phase 9 sweep). |
| 2 — Image input pipeline | TODO | — | Sources, EXIF, downscale, crop/rotate. |
| 3 — ASCII engine (pure Dart) | DONE | pending | `packages/sketchglyph_engine`: gamma-correct Rec.709, measured-font cell aspect, area-average resample, ramps sorted by measured glyph density (TTF parse + rasterise via `tool/measure_fonts.dart` → `assets/font_metrics.json`), edge mode, FS/Bayer dither, text/plain+color+HTML+PNG outputs. 36 tests green. Runtime TextPainter verification test pending (Phase 4). |
| 4 — ASCII modes and UX | TODO | — | Segmented modes A/B/C, controls, presets, debounced live preview. |
| 5 — Realistic sketch engine | DONE | pending | 10 styles × 6 papers, XDoG + structure-tensor hatching, seeded determinism, stroke recording, samples in `packages/sketchglyph_engine/docs/samples/sketch/`. 15 tests green. |
| 6 — Create flow and editor | TODO | — | |
| 7 — Export, save, share | TODO | — | |
| 8 — Library, settings polish, a11y | TODO | — | Settings exists in skeleton; DB gallery pending. |
| 9 — Stability and testing | TODO | — | |
| 10 — Production release and CI | IN PROGRESS | pending | `build.yml` written (format/analyze/engine+app tests/debug APK/coverage/samples artifacts; tag → signed release APKs+AAB+GitHub Release, secrets-gated). Keystore + docs + icon/splash pending. |

## Known issues / deviations
- **phosphor_flutter 2.1.0 is incompatible with Flutter 3.47** (`IconData` is `final`, cannot be extended). Switched to `lucide_icons_flutter ^3.1.25` (explicitly allowed by PROMPT.md). Vector icons only; no emoji anywhere.
- `linearToGray` LUT is indexed by linear level quantised to /255, so it cannot be a perfect byte inverse; round-trip tested in linear space (≤1.5/255) and via the exact float pair.
- Engine samples for ASCII (`tool/generate_samples.dart` at app root) still pending — Phase 4 deliverable.

## Next step
Phase 2: image input pipeline (pickers, decode safety, EXIF, isolate processing).

# SketchGlyph — PROGRESS

Source of truth: `PROMPT.md`. Resume from the first unfinished phase.

| Phase | Status | Last commit | Notes / next step |
|---|---|---|---|
| 0 — Foundation | DONE | 1d8a57e | Flutter 3.47.7 stable + Android SDK installed in sandbox (`/opt/tools/flutter`, `/opt/android-sdk`); env helper `/tmp/env.sh`. App id `com.sketchglyph.app`, minSdk 24. Monorepo, strict analysis options, `scripts/check.sh`, CI workflow, fonts + `assets/font_metrics.json` committed. README still stub — expanded in Phase 10. |
| 1 — Design system, dark theme, shell | DONE | e11a49d | Tokens + SurfaceTokens/AccentTokens extensions; Light/Dark/AMOLED themes with 5 accent presets; contrast test enforces ≥4.5:1 for all text pairs and onPrimary in all modes and accents (all pass). Riverpod settings + SharedPreferences persistence applied before first frame; animated theme cross-fade; go_router 4-tab shell with glass nav; onboarding redirect; widget tests pass. Goldens for core screens still to add (Phase 9 sweep). |
| 2 — Image input pipeline | DONE | ec2dc9a | `lib/core/image/image_pipeline.dart`: isolate decode, EXIF orientation baked (image 4.12 JPEG decoder pre-bakes; PNG/WEBP via `bakeOrientation`), 48MP cap, OOM-safe, 2048 default working long edge (configurable), original bytes kept for export. rotate/flip/crop + `RectInt` clamping. `SourcePicker` (gallery/camera/file). 15 tests incl. truncation (EOI check), unsupported, downscale. Permission-request UX + clipboard source deferred to Phase 6 create flow. |
| 3 — ASCII engine (pure Dart) | DONE | 855cade | `packages/sketchglyph_engine`: gamma-correct Rec.709, measured-font cell aspect, area-average resample, ramps sorted by measured glyph density (TTF parse + rasterise via `tool/measure_fonts.dart` → `assets/font_metrics.json`), edge mode, FS/Bayer dither, text/plain+color+HTML+PNG outputs. 51 tests green. Line coverage 72% — raise toward 95% in Phase 9. Runtime TextPainter verification test pending (Phase 4). |
| 4 — ASCII modes and UX | DONE | 4bb95e4 | Domain: presets (6 render, 8 char sets, 5 palettes, 3 fonts), string validation, isolate preview renderer with cached metrics, debounced `AsciiEditorController`. UI: `/create/ascii` editor with Mode A/B/C selector, drag-reorder chip editor + auto-sort by density, user-string panel, controls sheet (all sliders/pills), InteractiveViewer zoom, long-press before/after compare, braille-style unsupported-set warning. 94 samples + contact sheets in `docs/samples/ascii/`; runtime TextPainter density verification test (Spearman ρ>0.75 per font) in `test/font_density_runtime_test.dart`. |
| 5 — Realistic sketch engine | DONE | aa32328 | 10 styles × 6 papers, XDoG + structure-tensor hatching, seeded determinism, stroke recording, samples in `packages/sketchglyph_engine/docs/samples/sketch/`. 15 tests green. |
| 6 — Create flow and editor | TODO | — | |
| 7 — Export, save, share | TODO | — | |
| 8 — Library, settings polish, a11y | TODO | — | Settings exists in skeleton; DB gallery pending. |
| 9 — Stability and testing | TODO | — | |
| 10 — Production release and CI | IN PROGRESS | pending | `build.yml` written (format/analyze/engine+app tests/debug APK/coverage/samples artifacts; tag → signed release APKs+AAB+GitHub Release, secrets-gated). Keystore + docs + icon/splash pending. |

## Known issues / deviations
- **phosphor_flutter 2.1.0 is incompatible with Flutter 3.47** (`IconData` is `final`, cannot be extended). Switched to `lucide_icons_flutter ^3.1.25` (explicitly allowed by PROMPT.md). Vector icons only; no emoji anywhere.
- `linearToGray` LUT is indexed by linear level quantised to /255, so it cannot be a perfect byte inverse; round-trip tested in linear space (≤1.5/255) and via the exact float pair.
- **Braille glyphs (U+2800–U+28FF) are missing from all three bundled monospace fonts**; the Mode B panel warns when <50% of a set's characters are unsupported, and the sample tool skips such sets. Consider bundling a braille-capable mono font in a later phase if desired.
- ASCII editor screen is reachable at `/create/ascii` but the full create flow (pick source → transform → choose ASCII vs sketch) is Phase 6.

## Next step
Phase 6: create flow and editor — pick source (gallery/camera/file) → transform step → choose ASCII vs sketch → `/create/ascii` editor; permission flows (explain/request/denied/open settings).

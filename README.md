# SketchGlyph

Turn photos into ASCII art and hand-drawn sketches — 100% offline, on your device.

- **No account, no servers, no analytics.** The release APK does not even request
  the INTERNET permission. All processing happens on your device.
- **ASCII engine**: gamma-correct Rec.709 luminance, character ramps sorted by
  *measured* glyph ink density of the bundled fonts, area-average resampling,
  dithering, edge mode, colored HTML/PNG output. Deterministic.
- **Sketch engine**: 10 hand-drawn styles (graphite HB/2B/6B, mechanical pencil,
  charcoal, ballpoint, fineliner, colored pencil, contour, stipple), 6 paper
  types, seeded reproducibility, stroke recording for draw-in replay.

## Repository layout

```
lib/                       Flutter app (feature-first: core/, features/, shared/)
packages/sketchglyph_engine/  Pure-Dart engines (no Flutter imports)
assets/fonts/                   Bundled fonts (committed; app never fetches)
assets/font_metrics.json          Measured glyph densities (build-time tool output)
tool/                         Sample generation
scripts/check.sh                  format -> analyze -> engine tests -> app tests
.github/workflows/build.yml       CI: tests, debug APK, release builds on tags
```

## Development

Requires Flutter stable (3.47+) and an Android SDK.

```sh
flutter pub get
dart pub get                       # in packages/sketchglyph_engine
bash scripts/check.sh              # full quality gate
flutter run                          # debug on a device
```

Regenerate the measured font tables after changing fonts or ramps:

```sh
cd packages/sketchglyph_engine && dart tool/measure_fonts.dart
```

## Tests

- `cd packages/sketchglyph_engine && dart test` — pure-Dart engine tests.
- `flutter test` — widget/contrast/serialization tests (runs on Linux, no device).

## Building

```sh
flutter build apk --debug
flutter build apk --release --split-per-abi
flutter build appbundle --release
```

Release signing reads `android/key.properties` (git-ignored). See
`docs/CI_GUIDE.md` for the GitHub Actions path.

## Privacy

See [PRIVACY_POLICY.md](PRIVACY_POLICY.md). Short version: no data leaves the
device, nothing is collected.

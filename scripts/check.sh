#!/usr/bin/env bash
# SketchGlyph quality gate: format -> analyze -> engine tests -> app tests.
# Usage: scripts/check.sh [--ci]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> dart format"
if [[ "${1:-}" == "--ci" ]]; then
  dart format --set-exit-if-changed .
else
  dart format .
fi

echo "==> flutter analyze"
flutter analyze

echo "==> engine tests (pure Dart)"
(cd packages/sketchglyph_engine && dart test --reporter compact)

echo "==> app tests"
flutter test --reporter compact

echo "ALL GREEN"

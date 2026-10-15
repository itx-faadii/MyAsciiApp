import 'dart:io';

import 'package:sketchglyph_engine/sketchglyph_engine.dart';

void main() {
  print('Generating sketch samples...');

  final outputDir = Directory('docs/samples/sketch');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Generate 3 synthetic source images
  final portrait = syntheticPortrait(width: 480, height: 600);
  final landscape = syntheticLandscape(width: 800, height: 500);
  final object = syntheticObject(width: 600, height: 600);

  final sources = <String, RgbImage>{
    'portrait': portrait,
    'landscape': landscape,
    'object': object,
  };

  // Render all 10 styles for each source
  for (final entry in sources.entries) {
    final sourceName = entry.key;
    final source = entry.value;

    for (final style in SketchStyle.values) {
      final settings = SketchSettings(style: style, longEdge: 1024, seed: 42);

      final result = SketchEngine.render(source, settings);

      final filename = '${sourceName}_${style.id}.png';
      final file = File('${outputDir.path}/$filename');
      file.writeAsBytesSync(result.pngBytes);

      print('Generated: $filename (${result.strokes.length} strokes)');
    }
  }

  print('All samples generated in ${outputDir.path}');
}

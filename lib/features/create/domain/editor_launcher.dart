/// Editor launcher abstraction — isolates sketch imports.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image/image_pipeline.dart';

/// Abstracts navigation to the ASCII and sketch editors so the create flow
/// does not import sketch files directly (another agent owns those).
abstract class EditorLauncher {
  /// Opens the ASCII editor with [source] seeded into its controller.
  Future<void> openAscii(WidgetRef ref, SourceImage source);

  /// Opens the sketch editor with [source] seeded into its controller.
  Future<void> openSketch(WidgetRef ref, SourceImage source);
}

/// Default editor launcher — the ONLY file that imports sketch controllers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image/image_pipeline.dart';
import '../../../features/ascii/domain/ascii_session_controller.dart';
import '../../../features/sketch/domain/sketch_session_controller.dart';
import '../domain/editor_launcher.dart';

/// Production launcher that seeds the real controllers and navigates.
class DefaultEditorLauncher implements EditorLauncher {
  /// Creates a launcher with an optional route callback.
  DefaultEditorLauncher({
    required this.onNavigateAscii,
    required this.onNavigateSketch,
  });

  /// Callback to navigate to the ASCII editor.
  final void Function() onNavigateAscii;

  /// Callback to navigate to the sketch editor.
  final void Function() onNavigateSketch;

  @override
  Future<void> openAscii(WidgetRef ref, SourceImage source) async {
    ref.read(asciiEditorControllerProvider.notifier).setSource(source);
    onNavigateAscii();
  }

  @override
  Future<void> openSketch(WidgetRef ref, SourceImage source) async {
    ref.read(sketchEditorControllerProvider.notifier).setSource(source);
    onNavigateSketch();
  }
}

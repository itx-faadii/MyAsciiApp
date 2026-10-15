/// Sketch editor screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/sketch_session_controller.dart';
import 'controls/sketch_fine_tune_sheet.dart';

/// Labels used in this screen (migrated to l10n later).
class _Labels {
  static const String title = 'Sketch';
  static const String export = 'Export';
  static const String fineTune = 'Fine-tune';
  static const String reset = 'Reset';
  static const String emptyTitle = 'No sketch yet';
  static const String emptyBody = 'Import an image to start sketching';
  static const String rendering = 'Rendering...';
}

/// Sketch editor screen.
class SketchEditorScreen extends ConsumerWidget {
  /// Creates the screen.
  const SketchEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SketchEditorState state = ref.watch(sketchEditorControllerProvider);
    final SketchEditorController controller = ref.read(
      sketchEditorControllerProvider.notifier,
    );
    final SurfaceTokens surface = Theme.of(context).extension<SurfaceTokens>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(_Labels.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: _Labels.export,
            onPressed: () {},
          ),
        ],
      ),
      body: state.source == null
          ? const EmptyState(
              icon: LucideIcons.palette,
              title: _Labels.emptyTitle,
              body: _Labels.emptyBody,
            )
          : Container(
              color: surface.paperDesk,
              child: Center(
                child: state.rendering
                    ? const _ShimmerIndicator()
                    : state.render == null
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.all(Spacing.xl),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: Radii.card,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: Radii.card,
                          child: InteractiveViewer(
                            child: Image.memory(
                              state.render!.pngBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
      bottomNavigationBar: state.source == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(Spacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(LucideIcons.sliders),
                      label: const Text(_Labels.fineTune),
                      onPressed: () => showSketchFineTuneSheet(
                        context,
                        state.settings,
                        controller.update,
                        controller.reset,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Flexible(
                    child: FilledButton.tonal(
                      onPressed: controller.reset,
                      child: const Text(_Labels.reset),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ShimmerIndicator extends StatefulWidget {
  const _ShimmerIndicator();

  @override
  State<_ShimmerIndicator> createState() => _ShimmerIndicatorState();
}

class _ShimmerIndicatorState extends State<_ShimmerIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1200),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double opacity = 0.3 + 0.7 * _controller.value;
        return Opacity(
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: Spacing.lg),
              Text(
                _Labels.rendering,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
    );
  }
}

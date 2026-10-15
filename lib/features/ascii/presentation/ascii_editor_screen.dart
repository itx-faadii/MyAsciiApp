/// ASCII editor screen: top bar, preview with before/after compare slider,
/// bottom control bar. Wires to the domain layer's [AsciiEditorController].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../../core/image/image_pipeline.dart';
import '../../../../core/theme/tokens.dart';
import '../domain/ascii_job.dart' show PreviewResult, loadMetricsFromAssetJson;
import '../domain/ascii_presets.dart';
import '../domain/ascii_session_controller.dart';
import 'ascii_preview.dart';
import 'controls/ascii_controls_sheet.dart';
import 'controls/mode_selector.dart';
import 'controls/user_string_panel.dart';

/// ASCII editor screen.
class AsciiEditorScreen extends ConsumerWidget {
  /// Creates the screen.
  const AsciiEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EditorState editorState = ref.watch(asciiEditorControllerProvider);
    final AsciiEditorController controller = ref.read(
      asciiEditorControllerProvider.notifier,
    );
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;

    // Surface validation failures as a themed snack bar.
    ref.listen<EditorState>(asciiEditorControllerProvider, (
      EditorState? previous,
      EditorState next,
    ) {
      final String? message = next.error;
      if (message != null && message != previous?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASCII Editor'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export',
            onPressed: () {
              // Phase 7: export handler.
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              0,
            ),
            child: _ModePanel(controller: controller, state: editorState),
          ),
          Expanded(
            child: _PreviewArea(
              editorState: editorState,
              controller: controller,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: tokens.surfaceTop,
            border: Border(top: BorderSide(color: tokens.outline)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showControlsSheet(context, ref),
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                  label: const Text('Controls'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: controller.reset,
                  icon: const Icon(LucideIcons.rotateCcw, size: 18),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showControlsSheet(BuildContext context, WidgetRef ref) {
    final EditorState editorState = ref.read(asciiEditorControllerProvider);
    final AsciiEditorController controller = ref.read(
      asciiEditorControllerProvider.notifier,
    );

    showModalBottomSheet<AsciiSettings>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return AsciiControlsSheet(
              settings: editorState.settings,
              onApply: (AsciiSettings Function(AsciiSettings) transform) {
                controller.update(transform);
              },
              onReset: controller.reset,
              palettes: PalettePreset.palettes
                  .map(
                    (PalettePreset p) => (
                      id: p.id,
                      label: p.label,
                      fg: p.foreground,
                      bg: p.background,
                      gStart: p.gradientStart,
                      gEnd: p.gradientEnd,
                    ),
                  )
                  .toList(),
              fonts: FontOption.bundled
                  .map(
                    (FontOption f) => (id: f.id, engineFamily: f.engineFamily),
                  )
                  .toList(),
              presets: AsciiPreset.all
                  .map(
                    (AsciiPreset p) =>
                        (id: p.id, label: p.label, build: p.build),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}

class _ModePanel extends ConsumerWidget {
  const _ModePanel({required this.controller, required this.state});

  final AsciiEditorController controller;
  final EditorState state;

  Future<void> _autoSortByDensity(BuildContext context) async {
    final Map<String, FontMetrics> metrics = await loadMetricsFromAssetJson();
    final FontMetrics? m = metrics[state.settings.font];
    if (m == null) return;
    final List<String> sorted = buildRamp(
      state.settings.characterSet.runes.map(String.fromCharCode),
      (String c) => m.densities[c] ?? 0.5,
    );
    final String joined = sorted.join();
    if (joined == state.settings.characterSet) return;
    controller.update((AsciiSettings s) => s.copyWith(characterSet: joined));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Characters sorted by ink density.')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsciiSettings settings = state.settings;
    if (settings.mode == AsciiMode.userString) {
      return UserStringPanel(
        userString: settings.userString,
        userStringMode: settings.userStringMode,
        onStringChanged: (String value) => controller.update(
          (AsciiSettings s) => s.copyWith(userString: value),
        ),
        onModeChanged: (UserStringMode value) => controller.update(
          (AsciiSettings s) => s.copyWith(userStringMode: value),
        ),
      );
    }
    // The metrics table is cached after the first preview render.
    return FutureBuilder<Map<String, FontMetrics>>(
      future: loadMetricsFromAssetJson(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, FontMetrics>> snapshot,
          ) {
            final FontMetrics? metrics = snapshot.data?[settings.font];
            return ModeSelector(
              mode: settings.mode,
              onModeChanged: (AsciiMode value) => controller.update(
                (AsciiSettings s) => s.copyWith(mode: value),
              ),
              characterSet: settings.characterSet,
              onCharacterSetChanged: (String value) => controller.update(
                (AsciiSettings s) => s.copyWith(characterSet: value),
              ),
              charSets: CharSetPreset.charSets
                  .map(
                    (CharSetPreset p) =>
                        (id: p.id, label: p.label, characters: p.characters),
                  )
                  .toList(),
              onAutoSortDensity: () => _autoSortByDensity(context),
              supportedCharacters: metrics?.densities.keys.toSet(),
              rampPreview: settings.characterSet,
            );
          },
    );
  }
}

class _PreviewArea extends StatefulWidget {
  const _PreviewArea({required this.editorState, required this.controller});

  final EditorState editorState;
  final AsciiEditorController controller;

  @override
  State<_PreviewArea> createState() => _PreviewAreaState();
}

class _PreviewAreaState extends State<_PreviewArea> {
  double _comparePosition = 0.5;
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;
    final PreviewResult? preview = widget.editorState.preview;

    // Shimmer while rendering with no preview.
    if (widget.editorState.rendering && preview == null) {
      return const Center(child: ShimmerSkeleton(height: 300));
    }

    // No preview yet.
    if (preview == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(LucideIcons.image, size: 64, color: tokens.outline),
            const SizedBox(height: Spacing.lg),
            Text(
              'No preview yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Load an image to begin',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Preview with optional before/after compare.
    return GestureDetector(
      onLongPressStart: (_) => setState(() => _showOriginal = true),
      onLongPressEnd: (_) => setState(() => _showOriginal = false),
      child: Stack(
        children: <Widget>[
          // ASCII preview.
          Positioned.fill(
            child: AsciiPreview(
              preview: preview,
              fontSizePx: widget.editorState.settings.fontSize,
              lineHeight: widget.editorState.settings.lineHeight,
              letterSpacing: widget.editorState.settings.letterSpacing,
              fontFamily: widget.editorState.settings.font,
            ),
          ),

          // Compare slider overlay.
          if (_showOriginal && widget.editorState.source != null)
            Positioned.fill(
              child: _CompareSlider(
                position: _comparePosition,
                onChanged: (double p) {
                  setState(() => _comparePosition = p);
                  widget.controller.finishPreview();
                },
                source: widget.editorState.source!,
                preview: preview,
              ),
            ),
        ],
      ),
    );
  }
}

class _CompareSlider extends StatelessWidget {
  const _CompareSlider({
    required this.position,
    required this.onChanged,
    required this.source,
    required this.preview,
  });

  final double position;
  final ValueChanged<double> onChanged;
  final SourceImage source;
  final PreviewResult preview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double splitX = constraints.maxWidth * position;
        return Stack(
          children: <Widget>[
            // Original image (left side).
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: splitX,
              child: ClipRect(
                child: OverflowBox(
                  maxWidth: constraints.maxWidth,
                  child: SourceImageView(source: source),
                ),
              ),
            ),

            // Drag handle.
            Positioned(
              left: splitX - 2,
              top: 0,
              bottom: 0,
              width: 4,
              child: GestureDetector(
                onHorizontalDragUpdate: (DragUpdateDetails details) {
                  final double newPos =
                      (splitX + details.delta.dx) / constraints.maxWidth;
                  onChanged(newPos.clamp(0.0, 1.0));
                },
                child: Container(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}

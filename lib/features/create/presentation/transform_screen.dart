/// Transform step screen — rotate, flip, crop with aspect presets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/image/image_pipeline.dart';
import '../../../core/theme/tokens.dart';
import '../../ascii/presentation/ascii_preview.dart';
import '../domain/canvas_format.dart';
import '../domain/create_session_controller.dart';

/// Transform step: rotate, flip, crop.
class TransformScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const TransformScreen({super.key});

  @override
  ConsumerState<TransformScreen> createState() => _TransformScreenState();
}

class _TransformScreenState extends ConsumerState<TransformScreen> {
  bool _busy = false;
  AspectRatioPreset _preset = kCropPresets.first;
  RectInt? _cropRect;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(createSessionProvider);
    final source = session.source;
    if (source == null) {
      return const Scaffold(body: Center(child: Text('No image')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transform'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw),
            tooltip: 'Reset',
            onPressed: () {
              setState(() {
                _preset = kCropPresets.first;
                _cropRect = null;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _ImagePreview(
              source: source,
              cropRect: _cropRect,
              onCropChanged: (RectInt? rect) =>
                  setState(() => _cropRect = rect),
            ),
          ),
          _PresetBar(
            selected: _preset,
            onChanged: (AspectRatioPreset p) {
              setState(() {
                _preset = p;
                if (p.id == 'free') {
                  _cropRect = null;
                } else {
                  _cropRect = cropRectFor(
                    p,
                    imageWidth: source.width,
                    imageHeight: source.height,
                  );
                }
              });
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: <Widget>[
                  _TransformButton(
                    icon: LucideIcons.rotateCw,
                    label: 'CW',
                    onPressed: _busy ? null : () => _rotate(90),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _TransformButton(
                    icon: LucideIcons.rotateCcw,
                    label: 'CCW',
                    onPressed: _busy ? null : () => _rotate(-90),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _TransformButton(
                    icon: LucideIcons.flipHorizontal,
                    label: 'Flip H',
                    onPressed: _busy ? null : () => _flip(true),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _TransformButton(
                    icon: LucideIcons.flipVertical,
                    label: 'Flip V',
                    onPressed: _busy ? null : () => _flip(false),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // The app theme's button minimumSize uses an infinite
                  // minimum width; non-flex Row children would get
                  // tight-infinite constraints and crash layout, so Apply
                  // takes a flex slot like the other buttons.
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _applyCrop(source),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rotate(int angle) async {
    final session = ref.read(createSessionProvider);
    final source = session.source;
    if (source == null) return;
    setState(() => _busy = true);
    final transform = switch (angle) {
      90 => ImageTransform.rotate90,
      -90 => ImageTransform.rotate270,
      _ => ImageTransform.rotate180,
    };
    final result = await applyTransform(source, transform);
    if (mounted) {
      ref.read(createSessionProvider.notifier).updateSource(result);
      setState(() {
        _busy = false;
        _cropRect = null;
      });
    }
  }

  Future<void> _flip(bool horizontal) async {
    final session = ref.read(createSessionProvider);
    final source = session.source;
    if (source == null) return;
    setState(() => _busy = true);
    final transform = horizontal
        ? ImageTransform.flipHorizontal
        : ImageTransform.flipVertical;
    final result = await applyTransform(source, transform);
    if (mounted) {
      ref.read(createSessionProvider.notifier).updateSource(result);
      setState(() {
        _busy = false;
        _cropRect = null;
      });
    }
  }

  Future<void> _applyCrop(SourceImage source) async {
    final rect = _cropRect;
    if (rect == null) return;
    setState(() => _busy = true);
    final result = await cropImage(source, rect);
    if (mounted) {
      ref.read(createSessionProvider.notifier).updateSource(result);
      setState(() {
        _busy = false;
        _cropRect = null;
      });
    }
  }
}

class _TransformButton extends StatelessWidget {
  const _TransformButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _PresetBar extends StatelessWidget {
  const _PresetBar({required this.selected, required this.onChanged});

  final AspectRatioPreset selected;
  final ValueChanged<AspectRatioPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        itemCount: kCropPresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, i) {
          final p = kCropPresets[i];
          final isSelected = p.id == selected.id;
          return ChoiceChip(
            label: Text(p.label),
            selected: isSelected,
            onSelected: (_) => onChanged(p),
          );
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.source,
    required this.cropRect,
    required this.onCropChanged,
  });

  final SourceImage source;
  final RectInt? cropRect;
  final ValueChanged<RectInt?> onCropChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / source.width;
        final scaleY = constraints.maxHeight / source.height;
        final scale = scaleX < scaleY ? scaleX : scaleY;
        final displayW = (source.width * scale).round();
        final displayH = (source.height * scale).round();

        return Center(
          child: SizedBox(
            width: displayW.toDouble(),
            height: displayH.toDouble(),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: SourceImageView(source: source)),
                if (cropRect != null)
                  Positioned(
                    left: cropRect!.left * scale,
                    top: cropRect!.top * scale,
                    width: cropRect!.width * scale,
                    height: cropRect!.height * scale,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

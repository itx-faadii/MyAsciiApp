import 'package:flutter/material.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/sketch_presets.dart';
import '../controls/style_carousel.dart';

/// Shows the sketch fine-tune bottom sheet.
Future<void> showSketchFineTuneSheet(
  BuildContext context,
  SketchSettings settings,
  void Function(SketchSettings Function(SketchSettings)) onApply,
  VoidCallback onReset,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        _FineTuneSheet(initial: settings, onApply: onApply, onReset: onReset),
  );
}

class _FineTuneSheet extends StatefulWidget {
  const _FineTuneSheet({
    required this.initial,
    required this.onApply,
    required this.onReset,
  });

  final SketchSettings initial;
  final void Function(SketchSettings Function(SketchSettings)) onApply;
  final VoidCallback onReset;

  @override
  State<_FineTuneSheet> createState() => _FineTuneSheetState();
}

class _FineTuneSheetState extends State<_FineTuneSheet> {
  late SketchSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
  }

  void _update(SketchSettings Function(SketchSettings) fn) {
    setState(() => _settings = fn(_settings));
    widget.onApply((_) => _settings);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SurfaceTokens surface = theme.extension<SurfaceTokens>()!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surface.surfaceHigh,
            borderRadius: Radii.sheet,
            border: Border(top: BorderSide(color: surface.outline)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(Spacing.lg),
              children: <Widget>[
                const _SectionHeader(title: 'Style'),
                const SizedBox(height: Spacing.sm),
                StyleCarousel(
                  selected: _settings.style,
                  onChanged: (SketchStyle style) =>
                      _update((SketchSettings s) => s.copyWith(style: style)),
                ),
                const SizedBox(height: Spacing.xl),
                const _SectionHeader(title: 'Paper'),
                const SizedBox(height: Spacing.sm),
                _PaperSelector(
                  selected: _settings.paper,
                  onChanged: (PaperType paper) =>
                      _update((SketchSettings s) => s.copyWith(paper: paper)),
                ),
                const SizedBox(height: Spacing.xl),
                const _SectionHeader(title: 'Ink'),
                const SizedBox(height: Spacing.sm),
                _InkSelector(
                  selectedArgb: _settings.inkArgb,
                  onChanged: (int argb) =>
                      _update((SketchSettings s) => s.copyWith(inkArgb: argb)),
                ),
                const SizedBox(height: Spacing.xl),
                const _SectionHeader(title: 'Parameters'),
                const SizedBox(height: Spacing.sm),
                _SliderTile(
                  label: 'Detail',
                  value: _settings.detail,
                  min: 0.3,
                  max: 3.0,
                  onChanged: (double v) =>
                      _update((SketchSettings s) => s.copyWith(detail: v)),
                ),
                _SliderTile(
                  label: 'Line Weight',
                  value: _settings.lineWeight,
                  min: 0.3,
                  max: 3.0,
                  onChanged: (double v) =>
                      _update((SketchSettings s) => s.copyWith(lineWeight: v)),
                ),
                _SliderTile(
                  label: 'Hatch Density',
                  value: _settings.hatchDensity,
                  min: 0.3,
                  max: 2.5,
                  onChanged: (double v) => _update(
                    (SketchSettings s) => s.copyWith(hatchDensity: v),
                  ),
                ),
                _SliderTile(
                  label: 'Shading',
                  value: _settings.shading,
                  min: 0.0,
                  max: 2.0,
                  onChanged: (double v) =>
                      _update((SketchSettings s) => s.copyWith(shading: v)),
                ),
                _SliderTile(
                  label: 'Edge Strength',
                  value: _settings.edgeStrength,
                  min: 0.0,
                  max: 3.0,
                  onChanged: (double v) => _update(
                    (SketchSettings s) => s.copyWith(edgeStrength: v),
                  ),
                ),
                _SliderTile(
                  label: 'Grain',
                  value: _settings.grain,
                  min: 0.0,
                  max: 2.0,
                  onChanged: (double v) =>
                      _update((SketchSettings s) => s.copyWith(grain: v)),
                ),
                _SliderTile(
                  label: 'Smudge',
                  value: _settings.smudge,
                  min: 0.0,
                  max: 2.0,
                  onChanged: (double v) =>
                      _update((SketchSettings s) => s.copyWith(smudge: v)),
                ),
                _SliderTile(
                  label: 'Ink Flow',
                  value: _settings.inkFlow,
                  min: 0.0,
                  max: 2.0,
                  onChanged: (double v) =>
                      _update((SketchSettings s) => s.copyWith(inkFlow: v)),
                ),
                const SizedBox(height: Spacing.lg),
                SwitchListTile(
                  title: const Text('Transparent Background'),
                  value: _settings.transparentBackground,
                  onChanged: (bool v) => _update(
                    (SketchSettings s) => s.copyWith(transparentBackground: v),
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                const _SectionHeader(title: 'Seed'),
                const SizedBox(height: Spacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Seed: ${_settings.seed}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Randomize',
                      onPressed: () {
                        final int newSeed =
                            DateTime.now().millisecondsSinceEpoch;
                        _update(
                          (SketchSettings s) => s.copyWith(seed: newSeed),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          widget.onReset();
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _PaperSelector extends StatelessWidget {
  const _PaperSelector({required this.selected, required this.onChanged});

  final PaperType selected;
  final ValueChanged<PaperType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final PaperType paper in PaperType.values)
          _PaperChip(
            paper: paper,
            selected: paper == selected,
            onTap: () => onChanged(paper),
          ),
      ],
    );
  }
}

class _PaperChip extends StatelessWidget {
  const _PaperChip({
    required this.paper,
    required this.selected,
    required this.onTap,
  });

  final PaperType paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SurfaceTokens surface = theme.extension<SurfaceTokens>()!;
    final Color paperColor = Color(paper.baseArgb);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: Radii.chip,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : surface.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          paper.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: _contrastColor(paperColor),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _contrastColor(Color bg) {
    final double luminance = bg.computeLuminance();
    return luminance > 0.5 ? const Color(0xFF111111) : const Color(0xFFF5F5F5);
  }
}

class _InkSelector extends StatelessWidget {
  const _InkSelector({required this.selectedArgb, required this.onChanged});

  final int selectedArgb;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final InkColorPreset preset in InkColorPreset.all)
          _InkSwatch(
            preset: preset,
            selected: preset.argb == selectedArgb,
            onTap: () => onChanged(preset.argb),
          ),
      ],
    );
  }
}

class _InkSwatch extends StatelessWidget {
  const _InkSwatch({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final InkColorPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SurfaceTokens surface = theme.extension<SurfaceTokens>()!;
    final Color inkColor = Color(preset.argb);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: inkColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? theme.colorScheme.primary : surface.outline,
                width: selected ? 3 : 1,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(preset.label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: Radii.chip,
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

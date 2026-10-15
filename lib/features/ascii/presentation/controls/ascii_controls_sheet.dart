/// ASCII controls bottom sheet: labeled sliders for all ASCII settings,
/// dither selector, color mode, palette presets, font dropdown, sizing.
library;

import 'package:flutter/material.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../../core/theme/tokens.dart';

/// Descriptor for a palette preset, injected from the screen.
typedef PaletteDescriptor = ({
  /// Stable id.
  String id,

  /// Display label.
  String label,

  /// Foreground ARGB.
  int fg,

  /// Background ARGB.
  int bg,

  /// Gradient start ARGB.
  int gStart,

  /// Gradient end ARGB.
  int gEnd,
});

/// Descriptor for a font option, injected from the screen.
typedef FontDescriptor = ({
  /// Stable id.
  String id,

  /// Flutter font family name.
  String engineFamily,
});

/// Descriptor for a named preset, injected from the screen.
typedef PresetDescriptor = ({
  /// Stable id.
  String id,

  /// Display label.
  String label,

  /// Build function returning settings.
  AsciiSettings Function() build,
});

/// Bottom sheet containing all ASCII controls.
class AsciiControlsSheet extends StatelessWidget {
  /// Creates a controls sheet.
  const AsciiControlsSheet({
    super.key,
    required this.settings,
    required this.onApply,
    required this.onReset,
    required this.palettes,
    required this.fonts,
    required this.presets,
  });

  /// Current settings.
  final AsciiSettings settings;

  /// Apply callback with transform function.
  final void Function(AsciiSettings Function(AsciiSettings) transform) onApply;

  /// Reset callback.
  final VoidCallback onReset;

  /// Available palette presets.
  final List<PaletteDescriptor> palettes;

  /// Available fonts.
  final List<FontDescriptor> fonts;

  /// Named presets.
  final List<PresetDescriptor> presets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          // Columns slider.
          _ValueSlider(
            title: 'Columns',
            value: settings.columns.toDouble(),
            min: AsciiSettings.minColumns.toDouble(),
            max: AsciiSettings.maxColumns.toDouble(),
            divisions: 36,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(columns: v.toInt())),
          ),
          const SizedBox(height: Spacing.md),

          // Contrast slider.
          _ValueSlider(
            title: 'Contrast',
            value: settings.contrast,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(contrast: v)),
          ),
          const SizedBox(height: Spacing.md),

          // Brightness slider.
          _ValueSlider(
            title: 'Brightness',
            value: settings.brightness,
            min: -0.5,
            max: 0.5,
            divisions: 20,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(brightness: v)),
          ),
          const SizedBox(height: Spacing.md),

          // Gamma slider.
          _ValueSlider(
            title: 'Gamma',
            value: settings.gamma,
            min: 0.2,
            max: 3.0,
            divisions: 28,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(gamma: v)),
          ),
          const SizedBox(height: Spacing.md),

          // Sharpen slider.
          _ValueSlider(
            title: 'Sharpen',
            value: settings.sharpen,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(sharpen: v)),
          ),
          const SizedBox(height: Spacing.md),

          // Line height slider.
          _ValueSlider(
            title: 'Line Height',
            value: settings.lineHeight,
            min: 0.5,
            max: 4.0,
            divisions: 35,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(lineHeight: v)),
          ),
          const SizedBox(height: Spacing.md),

          // Letter spacing slider.
          _ValueSlider(
            title: 'Letter Spacing',
            value: settings.letterSpacing,
            min: -0.1,
            max: 0.5,
            divisions: 60,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(letterSpacing: v)),
          ),
          const SizedBox(height: Spacing.md),

          // Font size slider.
          _ValueSlider(
            title: 'Font Size',
            value: settings.fontSize,
            min: 4.0,
            max: 24.0,
            divisions: 20,
            onChanged: (double v) =>
                onApply((AsciiSettings s) => s.copyWith(fontSize: v)),
          ),
          const SizedBox(height: Spacing.lg),

          // Dither selector.
          _DitherSelector(
            dither: settings.dither,
            strength: settings.ditherStrength,
            onDitherChanged: (DitherKind d) =>
                onApply((AsciiSettings s) => s.copyWith(dither: d)),
            onStrengthChanged: (double s) =>
                onApply((AsciiSettings st) => st.copyWith(ditherStrength: s)),
          ),
          const SizedBox(height: Spacing.lg),

          // Invert switch.
          SwitchListTile(
            title: const Text('Invert'),
            value: settings.invert,
            onChanged: (bool v) =>
                onApply((AsciiSettings s) => s.copyWith(invert: v)),
          ),

          // Edge mode switch.
          SwitchListTile(
            title: const Text('Edge Mode'),
            value: settings.edgeMode,
            onChanged: (bool v) =>
                onApply((AsciiSettings s) => s.copyWith(edgeMode: v)),
          ),
          const SizedBox(height: Spacing.lg),

          // Color mode selector.
          _ColorModeSelector(
            colorMode: settings.colorMode,
            onChanged: (ColorMode m) =>
                onApply((AsciiSettings s) => s.copyWith(colorMode: m)),
          ),
          const SizedBox(height: Spacing.lg),

          // Palette presets.
          if (palettes.isNotEmpty) ...<Widget>[
            Text('Palette', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: palettes.length,
                separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final PaletteDescriptor p = palettes[index];
                  return _PaletteChip(
                    label: p.label,
                    fg: p.fg,
                    bg: p.bg,
                    selected:
                        settings.foreground == p.fg &&
                        settings.background == p.bg,
                    onTap: () => onApply(
                      (AsciiSettings s) => s.copyWith(
                        foreground: p.fg,
                        background: p.bg,
                        gradientStart: p.gStart,
                        gradientEnd: p.gEnd,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // Font dropdown.
          if (fonts.isNotEmpty) ...<Widget>[
            DropdownButtonFormField<String>(
              initialValue: settings.font,
              decoration: const InputDecoration(labelText: 'Font'),
              items: fonts
                  .map(
                    (FontDescriptor f) => DropdownMenuItem<String>(
                      value: f.engineFamily,
                      child: Text(f.engineFamily),
                    ),
                  )
                  .toList(),
              onChanged: (String? v) {
                if (v != null) {
                  onApply((AsciiSettings s) => s.copyWith(font: v));
                }
              },
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // Sizing selector.
          _SizingSelector(
            sizing: settings.sizing,
            pageSize: settings.pageSize,
            onChanged: (GridSizing s, PageBox? p) => onApply(
              (AsciiSettings st) =>
                  st.copyWith(sizing: s, pageSize: p ?? st.pageSize),
            ),
          ),
          const SizedBox(height: Spacing.xl),

          // Named presets.
          if (presets.isNotEmpty) ...<Widget>[
            Text('Presets', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: presets
                  .map(
                    (PresetDescriptor p) => ActionChip(
                      label: Text(p.label),
                      onPressed: () {
                        final AsciiSettings built = p.build();
                        onApply((AsciiSettings _) => built);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // Reset button.
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.18),
                borderRadius: Radii.chip,
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DitherSelector extends StatelessWidget {
  const _DitherSelector({
    required this.dither,
    required this.strength,
    required this.onDitherChanged,
    required this.onStrengthChanged,
  });

  final DitherKind dither;
  final double strength;
  final ValueChanged<DitherKind> onDitherChanged;
  final ValueChanged<double> onStrengthChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Dithering', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.sm),
        SegmentedButton<DitherKind>(
          selected: <DitherKind>{dither},
          onSelectionChanged: (Set<DitherKind> s) {
            if (s.isNotEmpty) onDitherChanged(s.first);
          },
          segments: const <ButtonSegment<DitherKind>>[
            ButtonSegment<DitherKind>(
              value: DitherKind.none,
              label: Text('None'),
            ),
            ButtonSegment<DitherKind>(
              value: DitherKind.floydSteinberg,
              label: Text('Floyd'),
            ),
            ButtonSegment<DitherKind>(
              value: DitherKind.bayer4,
              label: Text('Bayer'),
            ),
          ],
        ),
        if (dither != DitherKind.none) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          _ValueSlider(
            title: 'Strength',
            value: strength,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            onChanged: onStrengthChanged,
          ),
        ],
      ],
    );
  }
}

class _ColorModeSelector extends StatelessWidget {
  const _ColorModeSelector({required this.colorMode, required this.onChanged});

  final ColorMode colorMode;
  final ValueChanged<ColorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Color Mode', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.sm),
        SegmentedButton<ColorMode>(
          selected: <ColorMode>{colorMode},
          onSelectionChanged: (Set<ColorMode> s) {
            if (s.isNotEmpty) onChanged(s.first);
          },
          segments: const <ButtonSegment<ColorMode>>[
            ButtonSegment<ColorMode>(
              value: ColorMode.mono,
              label: Text('Mono'),
            ),
            ButtonSegment<ColorMode>(
              value: ColorMode.original,
              label: Text('Original'),
            ),
            ButtonSegment<ColorMode>(
              value: ColorMode.gradient,
              label: Text('Gradient'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.label,
    required this.fg,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int fg;
  final int bg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.chip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          borderRadius: Radii.chip,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(fg),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Color(bg),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _SizingSelector extends StatelessWidget {
  const _SizingSelector({
    required this.sizing,
    required this.pageSize,
    required this.onChanged,
  });

  final GridSizing sizing;
  final PageBox pageSize;
  final void Function(GridSizing, PageBox?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Sizing', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: Spacing.sm),
        SegmentedButton<GridSizing>(
          selected: <GridSizing>{sizing},
          onSelectionChanged: (Set<GridSizing> s) {
            if (s.isNotEmpty) onChanged(s.first, null);
          },
          segments: const <ButtonSegment<GridSizing>>[
            ButtonSegment<GridSizing>(
              value: GridSizing.columns,
              label: Text('Columns'),
            ),
            ButtonSegment<GridSizing>(
              value: GridSizing.fitToPage,
              label: Text('Fit to Page'),
            ),
          ],
        ),
        if (sizing == GridSizing.fitToPage) ...<Widget>[
          const SizedBox(height: Spacing.md),
          SegmentedButton<PageBox>(
            selected: <PageBox>{pageSize},
            onSelectionChanged: (Set<PageBox> s) {
              if (s.isNotEmpty) onChanged(GridSizing.fitToPage, s.first);
            },
            segments: const <ButtonSegment<PageBox>>[
              ButtonSegment<PageBox>(value: PageBox.a4, label: Text('A4')),
              ButtonSegment<PageBox>(
                value: PageBox.letter,
                label: Text('Letter'),
              ),
              ButtonSegment<PageBox>(
                value: PageBox.square,
                label: Text('Square'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

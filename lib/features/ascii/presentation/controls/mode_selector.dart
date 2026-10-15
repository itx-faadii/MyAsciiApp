/// Mode selector: segmented control for the three ASCII modes plus
/// mode-specific panels (ramp preview, character set editor, user string).
///
/// Accepts preset lists via record-based dependency injection so it compiles
/// independently of the domain layer.
library;

import 'package:flutter/material.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../../core/theme/tokens.dart';

/// Descriptor for a character-set preset, injected from the screen.
typedef CharSetDescriptor = ({
  /// Stable id.
  String id,

  /// Display label.
  String label,

  /// Characters in the preset.
  String characters,
});

/// Mode selector with three-way segmented control and mode-specific panel.
class ModeSelector extends StatelessWidget {
  /// Creates a mode selector.
  const ModeSelector({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.characterSet,
    required this.onCharacterSetChanged,
    required this.charSets,
    required this.onAutoSortDensity,
    this.supportedCharacters,
    this.rampPreview = kDefaultRamp,
  });

  /// Current mode.
  final AsciiMode mode;

  /// Mode change callback.
  final ValueChanged<AsciiMode> onModeChanged;

  /// Current character set string (Mode B).
  final String characterSet;

  /// Character set change callback.
  final ValueChanged<String> onCharacterSetChanged;

  /// Available character-set presets.
  final List<CharSetDescriptor> charSets;

  /// Called when the user requests auto-sort by density.
  final VoidCallback onAutoSortDensity;

  /// Set of characters supported by the current font (from FontMetrics.densities keys).
  final Set<String>? supportedCharacters;

  /// The ramp string to show in the Mode A preview strip.
  final String rampPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<AsciiMode>(
          selected: <AsciiMode>{mode},
          onSelectionChanged: (Set<AsciiMode> s) {
            if (s.isNotEmpty) onModeChanged(s.first);
          },
          segments: const <ButtonSegment<AsciiMode>>[
            ButtonSegment<AsciiMode>(
              value: AsciiMode.defaultRamp,
              label: Text('Default'),
            ),
            ButtonSegment<AsciiMode>(
              value: AsciiMode.characterSet,
              label: Text('Character Set'),
            ),
            ButtonSegment<AsciiMode>(
              value: AsciiMode.userString,
              label: Text('User String'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        switch (mode) {
          AsciiMode.defaultRamp => _RampPreviewStrip(ramp: rampPreview),
          AsciiMode.characterSet => _CharSetPanel(
            characterSet: characterSet,
            onChanged: onCharacterSetChanged,
            charSets: charSets,
            onAutoSortDensity: onAutoSortDensity,
            supportedCharacters: supportedCharacters,
          ),
          AsciiMode.userString => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _RampPreviewStrip extends StatelessWidget {
  const _RampPreviewStrip({required this.ramp});

  final String ramp;

  @override
  Widget build(BuildContext context) {
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: Radii.control,
        border: Border.all(color: tokens.outline),
      ),
      child: Text(
        ramp,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 16,
          letterSpacing: 2,
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CharSetPanel extends StatefulWidget {
  const _CharSetPanel({
    required this.characterSet,
    required this.onChanged,
    required this.charSets,
    required this.onAutoSortDensity,
    this.supportedCharacters,
  });

  final String characterSet;
  final ValueChanged<String> onChanged;
  final List<CharSetDescriptor> charSets;
  final VoidCallback onAutoSortDensity;
  final Set<String>? supportedCharacters;

  @override
  State<_CharSetPanel> createState() => _CharSetPanelState();
}

class _CharSetPanelState extends State<_CharSetPanel> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.characterSet);
  }

  @override
  void didUpdateWidget(_CharSetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.characterSet != oldWidget.characterSet &&
        widget.characterSet != _controller.text) {
      _controller.text = widget.characterSet;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate character support warning
    String? warningText;
    if (widget.supportedCharacters != null && widget.characterSet.isNotEmpty) {
      final Set<String> uniqueChars = widget.characterSet.split('').toSet();
      final int supportedCount = uniqueChars
          .where((String char) => widget.supportedCharacters!.contains(char))
          .length;
      final double supportRatio = supportedCount / uniqueChars.length;

      if (supportRatio < 0.5) {
        warningText = 'This font is missing most of these characters';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Preset chips.
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.charSets.length,
            separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final CharSetDescriptor preset = widget.charSets[index];
              final bool selected = preset.characters == widget.characterSet;
              return ChoiceChip(
                label: Text(preset.label),
                selected: selected,
                onSelected: (_) => widget.onChanged(preset.characters),
              );
            },
          ),
        ),
        const SizedBox(height: Spacing.md),

        // Horizontal reorderable chip editor.
        SizedBox(
          height: 48,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            header: const SizedBox(width: 0),
            onReorderItem: (int oldIndex, int newIndex) {
              final List<String> chars = widget.characterSet.split('');
              final String item = chars.removeAt(oldIndex);
              chars.insert(newIndex, item);
              widget.onChanged(chars.join());
            },
            children: <Widget>[
              for (int i = 0; i < widget.characterSet.length && i < 30; i++)
                Padding(
                  key: ValueKey<int>(i),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Chip(
                    label: Text(
                      widget.characterSet[i],
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 14,
                      ),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),

        // Character support warning
        if (warningText != null) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: Radii.control,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    warningText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],

        // Custom set text field.
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Custom character set',
            helperText: '${widget.characterSet.length} characters',
          ),
          maxLines: 1,
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: Spacing.sm),

        // Auto-sort button.
        OutlinedButton.icon(
          onPressed: widget.onAutoSortDensity,
          icon: const Icon(Icons.sort, size: 18),
          label: const Text('Auto-sort by density'),
        ),
      ],
    );
  }
}

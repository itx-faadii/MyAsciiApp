/// Overlay editor sheet — caption and watermark.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../domain/overlay_spec.dart';

/// Bottom sheet for editing overlay (caption/watermark) settings.
class OverlaySheet extends StatefulWidget {
  /// Creates the sheet.
  const OverlaySheet({super.key, required this.initial, required this.onApply});

  /// Initial spec.
  final OverlaySpec initial;

  /// Callback when the user taps Apply.
  final ValueChanged<OverlaySpec> onApply;

  @override
  State<OverlaySheet> createState() => _OverlaySheetState();
}

class _OverlaySheetState extends State<OverlaySheet> {
  late TextEditingController _captionController;
  late TextEditingController _watermarkController;
  late OverlayPosition _position;
  late double _opacity;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initial.caption);
    _watermarkController = TextEditingController(
      text: widget.initial.watermark,
    );
    _position = widget.initial.position;
    _opacity = widget.initial.opacity;
    _enabled = widget.initial.enabled;
  }

  @override
  void dispose() {
    _captionController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.lg,
        Spacing.lg,
        MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Overlay', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Spacing.lg),
          SwitchListTile(
            title: const Text('Enable overlay'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          TextField(
            controller: _captionController,
            decoration: const InputDecoration(labelText: 'Caption'),
            enabled: _enabled,
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _watermarkController,
            decoration: const InputDecoration(labelText: 'Watermark'),
            enabled: _enabled,
          ),
          const SizedBox(height: Spacing.lg),
          const Text('Position'),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            children: OverlayPosition.values.map((p) {
              return ChoiceChip(
                label: Text(p.name),
                selected: p == _position,
                onSelected: _enabled
                    ? (_) => setState(() => _position = p)
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: <Widget>[
              const Text('Opacity'),
              Expanded(
                child: Slider(
                  value: _opacity,
                  onChanged: _enabled
                      ? (v) => setState(() => _opacity = v)
                      : null,
                ),
              ),
              Text('${(_opacity * 100).round()}%'),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton(
            onPressed: () {
              final spec = OverlaySpec(
                caption: _captionController.text.isEmpty
                    ? null
                    : _captionController.text,
                watermark: _watermarkController.text.isEmpty
                    ? null
                    : _watermarkController.text,
                position: _position,
                opacity: _opacity,
                enabled: _enabled,
              );
              widget.onApply(spec);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

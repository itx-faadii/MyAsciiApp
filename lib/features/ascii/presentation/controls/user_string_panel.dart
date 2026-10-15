/// Mode C user string panel: text field(s) with sub-mode selector and
/// live validation.
library;

import 'package:flutter/material.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/ascii_string_validation.dart';

/// Panel for Mode C: user string input with sub-mode and validation.
class UserStringPanel extends StatefulWidget {
  /// Creates a user string panel.
  const UserStringPanel({
    super.key,
    required this.userString,
    required this.userStringMode,
    required this.onStringChanged,
    required this.onModeChanged,
  });

  /// Current user string.
  final String userString;

  /// Current sub-mode.
  final UserStringMode userStringMode;

  /// String change callback.
  final ValueChanged<String> onStringChanged;

  /// Sub-mode change callback.
  final ValueChanged<UserStringMode> onModeChanged;

  @override
  State<UserStringPanel> createState() => _UserStringPanelState();
}

class _UserStringPanelState extends State<UserStringPanel> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.userString);
  }

  @override
  void didUpdateWidget(UserStringPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userString != oldWidget.userString &&
        widget.userString != _controller.text) {
      _controller.text = widget.userString;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? error = validateUserString(widget.userString);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Sub-mode selector.
        SegmentedButton<UserStringMode>(
          selected: <UserStringMode>{widget.userStringMode},
          onSelectionChanged: (Set<UserStringMode> s) {
            if (s.isNotEmpty) widget.onModeChanged(s.first);
          },
          segments: const <ButtonSegment<UserStringMode>>[
            ButtonSegment<UserStringMode>(
              value: UserStringMode.textFlow,
              label: Text('Text Flow'),
            ),
            ButtonSegment<UserStringMode>(
              value: UserStringMode.ramp,
              label: Text('Ramp'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),

        // User string text field.
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Your text',
            helperText: error,
            errorText: error,
          ),
          maxLines: 3,
          onChanged: widget.onStringChanged,
        ),
      ],
    );
  }
}

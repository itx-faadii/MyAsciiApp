/// Create tab — Phase 6 builds the full flow; this shell keeps navigation real.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Placeholder create screen with a source picker button.
class CreateScreen extends StatelessWidget {
  /// Creates the screen.
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTitle)),
      body: SafeArea(
        child: EmptyState(
          icon: LucideIcons.camera,
          title: l10n.createPickSource,
          body: l10n.privacyOnDevice,
          action: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.image),
            label: Text(l10n.createPickSource),
          ),
        ),
      ),
    );
  }
}

/// Recent-projects strip; Phase 8 replaces the placeholder with the gallery
/// provider once the project database exists.
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty-state placeholder until projects exist.
class RecentPlaceholder extends StatelessWidget {
  /// Creates the placeholder.
  const RecentPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.lg),
      child: EmptyState(
        icon: kEmptyStateIcon,
        title: l10n.homeEmptyTitle,
        body: l10n.homeEmptyBody,
      ),
    );
  }
}

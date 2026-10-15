/// Gallery tab — Phase 8 wires this to the local project database.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// Empty gallery screen.
class GalleryScreen extends StatelessWidget {
  /// Creates the screen.
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryTitle)),
      body: SafeArea(
        child: EmptyState(
          icon: LucideIcons.images,
          title: l10n.galleryEmptyTitle,
          body: l10n.galleryEmptyBody,
        ),
      ),
    );
  }
}

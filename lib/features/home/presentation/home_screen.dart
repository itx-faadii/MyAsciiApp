/// Home tab: hero CTA + quick entry points.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import 'recent_placeholder.dart';

/// Landing screen with the hero create card and a recent-projects strip.
class HomeScreen extends ConsumerWidget {
  /// Creates the screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AccentTokens accents = theme.extension<AccentTokens>()!;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          MediaQuery.viewPaddingOf(context).top + Spacing.lg,
          Spacing.lg,
          Spacing.xxl * 3,
        ),
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(LucideIcons.brush600, color: theme.colorScheme.primary),
              const SizedBox(width: Spacing.sm),
              Text(l10n.appName, style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: Spacing.xl),
          _HeroCard(
            title: l10n.homeHeroTitle,
            subtitle: l10n.homeHeroSubtitle,
            gradient: accents.heroGradient,
            onTap: () => context.go(AppRoutes.create),
          ),
          const SizedBox(height: Spacing.xl),
          Text(l10n.homeRecentHeading, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          const RecentPlaceholder(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.card,
      child: Ink(
        decoration: BoxDecoration(gradient: gradient, borderRadius: Radii.card),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                LucideIcons.image,
                color: Colors.white.withValues(alpha: 0.92),
                size: 32,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

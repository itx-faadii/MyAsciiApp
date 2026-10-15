/// The four-tab shell: glass bottom nav over the indexed router stack.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/tokens.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/settings/app_settings.dart';
import 'glass_surface.dart';

/// Bottom-navigation shell hosting the four tabs.
class AppShell extends ConsumerWidget {
  /// Creates the shell.
  const AppShell({super.key, required this.navigationShell});

  /// The router shell to present.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;

    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.md,
          0,
          Spacing.md,
          Spacing.md,
        ),
        child: GlassSurface(
          padding: EdgeInsets.zero,
          borderRadius: tokens.useGlass ? Radii.chip : Radii.control,
          child: Theme(
            // The nav bar sits on glass; keep Material ink calm.
            data: Theme.of(context).copyWith(
              splashFactory: settings.reduceBlur
                  ? NoSplash.splashFactory
                  : Theme.of(context).splashFactory,
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              indicatorColor: null,
              elevation: 0,
              height: 64,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (int index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              destinations: <Widget>[
                NavigationDestination(
                  label: l10n.navHome,
                  icon: const Icon(LucideIcons.home),
                  selectedIcon: const Icon(LucideIcons.home600),
                ),
                NavigationDestination(
                  label: l10n.navCreate,
                  icon: const Icon(LucideIcons.sparkles),
                  selectedIcon: const Icon(LucideIcons.sparkles600),
                ),
                NavigationDestination(
                  label: l10n.navGallery,
                  icon: const Icon(LucideIcons.images),
                  selectedIcon: const Icon(LucideIcons.images600),
                ),
                NavigationDestination(
                  label: l10n.navSettings,
                  icon: const Icon(LucideIcons.settings),
                  selectedIcon: const Icon(LucideIcons.settings600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared theme-mode toggle (System / Light / Dark / AMOLED) with a live
/// preview swatch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Row of four icon+label choice chips that write through to
/// [SettingsController]. [compact] renders a slim preview card with the four
/// modes as colour dots, for embedding inside a screen.
class ThemeModeToggle extends ConsumerWidget {
  /// Creates the toggle.
  const ThemeModeToggle({super.key, this.compact = false});

  /// Slim preview variant.
  final bool compact;

  static const Map<AppThemeMode, IconData> _icons = <AppThemeMode, IconData>{
    AppThemeMode.system: LucideIcons.smartphone,
    AppThemeMode.light: LucideIcons.sun,
    AppThemeMode.dark: LucideIcons.moon,
    AppThemeMode.amoled: LucideIcons.contrast,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );

    if (compact) {
      return _LivePreview(
        selected: settings.themeMode,
        labelOf: (AppThemeMode mode) => _label(l10n, mode),
        onSelect: controller.setThemeMode,
      );
    }

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        for (final AppThemeMode mode in AppThemeMode.values)
          ChoiceChip(
            avatar: Icon(
              _icons[mode],
              size: 18,
              color: mode == settings.themeMode
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(_label(l10n, mode)),
            selected: mode == settings.themeMode,
            onSelected: (_) => controller.setThemeMode(mode),
          ),
      ],
    );
  }

  static String _label(AppLocalizations l10n, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return l10n.themeModeSystem;
      case AppThemeMode.light:
        return l10n.themeModeLight;
      case AppThemeMode.dark:
        return l10n.themeModeDark;
      case AppThemeMode.amoled:
        return l10n.themeModeAmoled;
    }
  }
}

/// Four mini theme cards; tapping one switches the whole app live.
class _LivePreview extends StatelessWidget {
  const _LivePreview({
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final AppThemeMode selected;
  final String Function(AppThemeMode) labelOf;
  final ValueChanged<AppThemeMode> onSelect;

  static final Map<AppThemeMode, _ModeColors> _colors =
      <AppThemeMode, _ModeColors>{
        AppThemeMode.system: const _ModeColors(
          Color(0xFFF6F8FB),
          Color(0xFF8B7CFF),
          Color(0xFF12161B),
        ),
        AppThemeMode.light: const _ModeColors(
          Color(0xFFFFFFFF),
          Color(0xFF6C5CE7),
          Color(0xFF12161B),
        ),
        AppThemeMode.dark: const _ModeColors(
          Color(0xFF151A21),
          Color(0xFF8B7CFF),
          Color(0xFFE8ECF1),
        ),
        AppThemeMode.amoled: const _ModeColors(
          Color(0xFF000000),
          Color(0xFF4CC9F0),
          Color(0xFFE8ECF1),
        ),
      };

  @override
  Widget build(BuildContext context) {
    final SurfaceTokens tokens = Theme.of(context).extension<SurfaceTokens>()!;
    final List<Widget> cards = <Widget>[];
    for (final MapEntry<AppThemeMode, _ModeColors> entry in _colors.entries) {
      final bool isSelected = entry.key == selected;
      cards.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
            child: Semantics(
              selected: isSelected,
              button: true,
              label: labelOf(entry.key),
              child: InkWell(
                onTap: () => onSelect(entry.key),
                borderRadius: Radii.control,
                child: AnimatedContainer(
                  duration: Motion.normal,
                  curve: Motion.curve,
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: entry.value.background,
                    borderRadius: Radii.control,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : tokens.outline,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: 6,
                        width: 28,
                        decoration: BoxDecoration(
                          color: entry.value.text,
                          borderRadius: Radii.chip,
                        ),
                      ),
                      const SizedBox(height: Spacing.xs),
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              entry.value.accent,
                              entry.value.accent.withValues(alpha: 0.55),
                            ],
                          ),
                          borderRadius: Radii.chip,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: cards);
  }
}

class _ModeColors {
  const _ModeColors(this.background, this.accent, this.text);

  final Color background;
  final Color accent;
  final Color text;
}

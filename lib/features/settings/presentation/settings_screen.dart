/// Settings tab: appearance controls, privacy statement, about.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/theme_mode_toggle.dart';

/// Appearance + privacy + about.
class SettingsScreen extends ConsumerWidget {
  /// Creates the screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final SettingsController controller = ref.read(
      settingsControllerProvider.notifier,
    );
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.sm,
          Spacing.lg,
          Spacing.xxl,
        ),
        children: <Widget>[
          Text(l10n.settingsAppearance, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          const ThemeModeToggle(compact: true),
          const SizedBox(height: Spacing.xl),
          Text(l10n.settingsAccent, style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          _AccentRow(
            selectedId: settings.accentId,
            onSelect: controller.setAccent,
          ),
          const SizedBox(height: Spacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsReduceBlur),
            secondary: const Icon(LucideIcons.droplet),
            value: settings.reduceBlur,
            onChanged: controller.setReduceBlur,
          ),
          const SizedBox(height: Spacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.shieldCheck),
            title: Text(l10n.settingsPrivacy),
            subtitle: Text(l10n.privacyOnDevice),
          ),
          const SizedBox(height: Spacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.info),
            title: Text(l10n.settingsAbout),
            subtitle: Text(l10n.settingsVersion),
            trailing: const Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.selectedId, required this.onSelect});

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.md,
      runSpacing: Spacing.md,
      children: <Widget>[
        for (final AccentPreset preset in AccentPreset.all)
          Semantics(
            button: true,
            selected: preset.id == selectedId,
            label: preset.id,
            child: InkWell(
              onTap: () => onSelect(preset.id),
              borderRadius: Radii.chip,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[preset.primary, preset.secondary],
                  ),
                  border: Border.all(
                    color: preset.id == selectedId
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: preset.id == selectedId
                    ? const Icon(
                        LucideIcons.check600,
                        size: 20,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

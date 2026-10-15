/// Type step screen — choose ASCII or Sketch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/tokens.dart';
import '../domain/create_session_controller.dart';
import '../domain/create_types.dart';
import '../domain/editor_launcher.dart';

/// Type step: choose ASCII or Sketch editor.
class TypeScreen extends ConsumerWidget {
  /// Creates the screen.
  const TypeScreen({super.key, required this.launcher});

  /// The editor launcher to invoke.
  final EditorLauncher launcher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(createSessionProvider);
    final source = session.source;
    if (source == null) {
      return const Scaffold(body: Center(child: Text('No image')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Editor')),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _EditorCard(
                icon: LucideIcons.type,
                title: 'ASCII',
                subtitle: 'Character-based art',
                onTap: () async {
                  ref
                      .read(createSessionProvider.notifier)
                      .chooseTarget(CreateTarget.ascii);
                  await launcher.openAscii(ref, source);
                },
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: _EditorCard(
                icon: LucideIcons.pencil,
                title: 'Sketch',
                subtitle: 'Hand-drawn style',
                onTap: () async {
                  ref
                      .read(createSessionProvider.notifier)
                      .chooseTarget(CreateTarget.sketch);
                  await launcher.openSketch(ref, source);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: Spacing.lg),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: Spacing.sm),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

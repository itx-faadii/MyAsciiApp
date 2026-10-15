/// First-run onboarding: three skippable pages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/settings_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';

/// Page model for the three intro slides.
class _Slide {
  const _Slide(this.icon, this.titleKey, this.bodyKey);

  final IconData icon;
  final String Function(AppLocalizations) titleKey;
  final String Function(AppLocalizations) bodyKey;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(LucideIcons.image, _t1, _b1),
  _Slide(LucideIcons.brush, _t2, _b2),
  _Slide(LucideIcons.shieldCheck, _t3, _b3),
];

String _t1(AppLocalizations l) => l.onboardingTitle1;
String _b1(AppLocalizations l) => l.onboardingBody1;
String _t2(AppLocalizations l) => l.onboardingTitle2;
String _b2(AppLocalizations l) => l.onboardingBody2;
String _t3(AppLocalizations l) => l.onboardingTitle3;
String _b3(AppLocalizations l) => l.onboardingBody3;

/// Three-page intro with skip + get-started; completes by setting
/// [AppSettings.onboardingSeen].
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(settingsControllerProvider.notifier).setOnboardingSeen(true);
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final bool last = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.actionSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) {
                  final _Slide slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _OnboardingArt(icon: slide.icon),
                        const SizedBox(height: Spacing.xxl),
                        Text(
                          slide.titleKey(l10n),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: Spacing.md),
                        Text(
                          slide.bodyKey(l10n),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme
                                .extension<AccentTokens>()!
                                .textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: Motion.normal,
                    curve: Motion.curve,
                    margin: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? theme.colorScheme.primary
                          : theme.extension<SurfaceTokens>()!.outline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: Motion.normal,
                      curve: Motion.curve,
                    );
                  }
                },
                child: Text(last ? l10n.actionGetStarted : l10n.actionNext),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple vector composition for a slide (no raster images, no emoji).
class _OnboardingArt extends StatelessWidget {
  /// Creates the artwork.
  const _OnboardingArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AccentTokens accents = theme.extension<AccentTokens>()!;
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: <Color>[
            accents.heroGradient.colors.first.withValues(alpha: 0.28),
            accents.heroGradient.colors.last.withValues(alpha: 0.18),
          ],
        ),
        border: Border.all(color: accents.heroGradient.colors.first, width: 2),
      ),
      child: Icon(icon, size: 64, color: theme.colorScheme.primary),
    );
  }
}

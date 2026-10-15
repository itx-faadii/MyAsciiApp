/// go_router configuration: a four-tab shell plus onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ascii/presentation/ascii_editor_screen.dart';
import '../../features/create/presentation/create_screen.dart';
import '../../features/gallery/presentation/gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../providers/settings_providers.dart';
import '../../shared/widgets/app_shell.dart';
import '../settings/app_settings.dart';

/// Route paths kept in one place so screens never type raw strings.
class AppRoutes {
  const AppRoutes._();

  /// Home tab.
  static const String home = '/';

  /// Create tab.
  static const String create = '/create';

  /// Gallery tab.
  static const String gallery = '/gallery';

  /// Settings tab.
  static const String settings = '/settings';

  /// First-run onboarding.
  static const String onboarding = '/onboarding';

  /// ASCII editor.
  static const String asciiEditor = '/create/ascii';
}

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// The app router. Rebuilt only when the Provider container changes; the
/// refresh listenable re-runs redirects when settings update.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _SettingsRefresh refresh = _SettingsRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(settingsControllerProvider, (_, AppSettings next) {
    refresh.update(next.onboardingSeen);
  });
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool onboardingDone = ref
          .read(settingsControllerProvider)
          .onboardingSeen;
      final bool atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!onboardingDone && !atOnboarding) return AppRoutes.onboarding;
      if (onboardingDone && atOnboarding) return AppRoutes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(
              key: state.pageKey,
              child: const OnboardingScreen(),
            ),
      ),
      GoRoute(
        path: AppRoutes.asciiEditor,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(
              key: state.pageKey,
              child: const AsciiEditorScreen(),
            ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.create,
                builder: (BuildContext context, GoRouterState state) =>
                    const CreateScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.gallery,
                builder: (BuildContext context, GoRouterState state) =>
                    const GalleryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.settings,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _SettingsRefresh extends ChangeNotifier {
  void update(bool onboardingSeen) {
    if (this.onboardingSeen == onboardingSeen) return;
    this.onboardingSeen = onboardingSeen;
    notifyListeners();
  }

  bool onboardingSeen = false;
}

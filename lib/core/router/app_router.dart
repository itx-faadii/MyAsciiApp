/// go_router configuration: a four-tab shell plus onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ascii/presentation/ascii_editor_screen.dart';
import '../../features/create/data/default_editor_launcher.dart';
import '../../features/create/data/source_picker.dart';
import '../../features/create/domain/editor_launcher.dart';
import '../../features/create/presentation/batch_screen.dart';
import '../../features/create/presentation/create_screen.dart';
import '../../features/create/presentation/transform_screen.dart';
import '../../features/create/presentation/type_screen.dart';
import '../../features/gallery/presentation/gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sketch/presentation/sketch_editor_screen.dart';
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

  /// Create transform step.
  static const String createTransform = '/create/transform';

  /// Create type step.
  static const String createType = '/create/type';

  /// Create batch mode.
  static const String createBatch = '/create/batch';

  /// Gallery tab.
  static const String gallery = '/gallery';

  /// Settings tab.
  static const String settings = '/settings';

  /// First-run onboarding.
  static const String onboarding = '/onboarding';

  /// ASCII editor.
  static const String asciiEditor = '/create/ascii';

  /// Sketch editor.
  static const String sketchEditor = '/create/sketch';
}

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Shared source picker (image_picker + file_picker backed).
final Provider<SourcePicker> sourcePickerProvider = Provider<SourcePicker>(
  (Ref ref) => PluginSourcePicker(),
);

/// The app router. Rebuilt only when the Provider container changes; the
/// refresh listenable re-runs redirects when settings update.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _SettingsRefresh refresh = _SettingsRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(settingsControllerProvider, (_, AppSettings next) {
    refresh.update(next.onboardingSeen);
  });
  late final GoRouter router;
  final SourcePicker picker = ref.read(sourcePickerProvider);
  final EditorLauncher launcher = DefaultEditorLauncher(
    onNavigateAscii: () => router.push(AppRoutes.asciiEditor),
    onNavigateSketch: () => router.push(AppRoutes.sketchEditor),
  );
  router = GoRouter(
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
      GoRoute(
        path: AppRoutes.sketchEditor,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(
              key: state.pageKey,
              child: const SketchEditorScreen(),
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
                    CreateScreen(picker: picker, launcher: launcher),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'transform',
                    builder: (BuildContext context, GoRouterState state) =>
                        const TransformScreen(),
                  ),
                  GoRoute(
                    path: 'type',
                    builder: (BuildContext context, GoRouterState state) =>
                        TypeScreen(launcher: launcher),
                  ),
                  GoRoute(
                    path: 'batch',
                    builder: (BuildContext context, GoRouterState state) =>
                        BatchScreen(picker: picker),
                  ),
                ],
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
  return router;
});

class _SettingsRefresh extends ChangeNotifier {
  void update(bool onboardingSeen) {
    if (this.onboardingSeen == onboardingSeen) return;
    this.onboardingSeen = onboardingSeen;
    notifyListeners();
  }

  bool onboardingSeen = false;
}

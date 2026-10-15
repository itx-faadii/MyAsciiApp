// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SketchGlyph';

  @override
  String get navHome => 'Home';

  @override
  String get navCreate => 'Create';

  @override
  String get navGallery => 'Gallery';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeHeroTitle => 'Turn photos into art';

  @override
  String get homeHeroSubtitle =>
      'ASCII art and hand-drawn sketches — every pixel processed on your device.';

  @override
  String get homeActionAscii => 'ASCII art';

  @override
  String get homeActionSketch => 'Sketch';

  @override
  String get homeRecentHeading => 'Recent';

  @override
  String get homeEmptyTitle => 'Nothing here yet';

  @override
  String get homeEmptyBody =>
      'Your creations will appear here. Tap Create to make your first one.';

  @override
  String get privacyOnDevice => 'All processing happens on your device.';

  @override
  String get createTitle => 'Create';

  @override
  String get createPickSource => 'Choose an image';

  @override
  String get createPickFromGallery => 'Gallery';

  @override
  String get createPickFromCamera => 'Camera';

  @override
  String get createPickFromFile => 'File';

  @override
  String get createBatchMode => 'Batch Mode';

  @override
  String get actionRetry => 'Retry';

  @override
  String get createAccessBlocked =>
      'Access was blocked. You can allow it in system settings and try again.';

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get galleryEmptyTitle => 'No projects yet';

  @override
  String get galleryEmptyBody =>
      'Exported sketches and ASCII art are saved here.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeAmoled => 'AMOLED';

  @override
  String get settingsAccent => 'Accent';

  @override
  String get settingsReduceBlur => 'Reduce transparency and blur';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDone => 'Done';

  @override
  String get actionNext => 'Next';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionGetStarted => 'Get started';

  @override
  String get onboardingTitle1 => 'One tap art';

  @override
  String get onboardingBody1 =>
      'Pick any photo and choose ASCII or sketch — results appear instantly.';

  @override
  String get onboardingTitle2 => 'Real character';

  @override
  String get onboardingBody2 =>
      'Ten drawing styles, measured font ramps and real paper textures.';

  @override
  String get onboardingTitle3 => 'Totally private';

  @override
  String get onboardingBody3 =>
      'No account, no internet. Your images never leave this device.';

  @override
  String get contrastLowWarning =>
      'This colour pair falls below 4.5:1 contrast.';

  @override
  String get emptyStateDefaultTitle => 'Nothing to show';

  @override
  String get emptyStateDefaultBody => 'Check back after you create something.';
}

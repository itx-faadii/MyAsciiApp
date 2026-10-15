/// Riverpod controller for the ASCII editor state.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../core/image/image_pipeline.dart';
import 'ascii_job.dart';
import 'ascii_renderer_service.dart';

/// Default font family name as keyed in `assets/font_metrics.json`.
///
/// The engine's own `AsciiSettings` default is `'JetBrains Mono'` (with a
/// space), but the measured metrics table uses the TTF internal name
/// `'JetBrainsMono-Regular'`. We always pass the metrics key explicitly so
/// the engine uses real measured densities instead of synthetic fallbacks.
const String kDefaultFontFamily = 'JetBrainsMono-Regular';

/// Builds an [AsciiSettings] with the correct default font family.
AsciiSettings _defaultSettings() => AsciiSettings(font: kDefaultFontFamily);

/// State of the ASCII editor.
class EditorState {
  /// Creates a state.
  EditorState({
    this.source,
    AsciiSettings? settings,
    this.preview,
    this.rendering = false,
    this.error,
    this.lowResPreview = true,
  }) : settings = settings ?? _defaultSettings();

  /// Current source image.
  final SourceImage? source;

  /// Current ASCII settings.
  final AsciiSettings settings;

  /// Current preview result.
  final PreviewResult? preview;

  /// Whether rendering is in progress.
  final bool rendering;

  /// Current error message, if any.
  final String? error;

  /// Whether the preview is low-resolution.
  final bool lowResPreview;

  /// Copy with replacements.
  EditorState copyWith({
    SourceImage? source,
    AsciiSettings? settings,
    PreviewResult? preview,
    bool? rendering,
    String? error,
    bool? lowResPreview,
    bool clearPreview = false,
    bool clearError = false,
  }) => EditorState(
    source: source ?? this.source,
    settings: settings ?? this.settings,
    preview: clearPreview ? null : (preview ?? this.preview),
    rendering: rendering ?? this.rendering,
    error: clearError ? null : (error ?? this.error),
    lowResPreview: lowResPreview ?? this.lowResPreview,
  );
}

/// Simple notifier for ASCII settings.
class AsciiSettingsNotifier extends Notifier<AsciiSettings> {
  @override
  AsciiSettings build() => _defaultSettings();

  /// Updates settings with [fn].
  void update(AsciiSettings Function(AsciiSettings) fn) {
    state = fn(state);
  }
}

/// Public provider for ASCII settings, so tests can seed directly.
final NotifierProvider<AsciiSettingsNotifier, AsciiSettings>
asciiSettingsProvider = NotifierProvider<AsciiSettingsNotifier, AsciiSettings>(
  AsciiSettingsNotifier.new,
);

/// Controller for the ASCII editor domain layer.
class AsciiEditorController extends Notifier<EditorState> {
  Timer? _debounceTimer;
  int _requestSeq = 0;
  final AsciiRendererService _renderer = const AsciiRendererService();

  @override
  EditorState build() => EditorState();

  /// Sets the source image.
  void setSource(SourceImage? source) {
    state = state.copyWith(source: source, clearPreview: true);
    if (source != null) {
      refreshPreview();
    }
  }

  /// Updates settings with [fn], validates, and triggers a debounced preview.
  void update(AsciiSettings Function(AsciiSettings) fn) {
    try {
      final AsciiSettings next = fn(state.settings);
      state = state.copyWith(settings: next, clearError: true);
      ref.read(asciiSettingsProvider.notifier).update((_) => next);
      refreshPreview();
    } on AsciiSettingsException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Resets settings to defaults.
  void reset() {
    final AsciiSettings defaults = _defaultSettings();
    state = state.copyWith(settings: defaults, clearError: true);
    ref.read(asciiSettingsProvider.notifier).update((_) => defaults);
    refreshPreview();
  }

  /// Refreshes the preview with debouncing (~150ms).
  Future<void> refreshPreview({bool fullRes = false}) async {
    _debounceTimer?.cancel();
    if (state.source == null) return;

    _debounceTimer = Timer(const Duration(milliseconds: 150), () async {
      final int seq = ++_requestSeq;
      state = state.copyWith(rendering: true, lowResPreview: !fullRes);

      try {
        final SourceImage source = state.source!;
        final PreviewResult result = await _renderer.renderPreview(
          source.rgba,
          source.width,
          source.height,
          state.settings,
          lowRes: !fullRes,
        );

        // Ignore stale results.
        if (seq != _requestSeq) return;

        state = state.copyWith(
          preview: result,
          rendering: false,
          clearError: true,
        );
      } on AsciiPreviewException catch (e) {
        if (seq != _requestSeq) return;
        state = state.copyWith(
          rendering: false,
          error: e.message,
          clearPreview: true,
        );
      } on Object catch (e) {
        if (seq != _requestSeq) return;
        state = state.copyWith(
          rendering: false,
          error: 'Rendering failed: $e',
          clearPreview: true,
        );
      }
    });
  }

  /// Renders a full-resolution preview (no debounce).
  Future<void> finishPreview() async {
    if (state.source == null) return;
    final int seq = ++_requestSeq;
    state = state.copyWith(rendering: true, lowResPreview: false);

    try {
      final SourceImage source = state.source!;
      final PreviewResult result = await _renderer.renderPreview(
        source.rgba,
        source.width,
        source.height,
        state.settings,
        lowRes: false,
      );

      if (seq != _requestSeq) return;

      state = state.copyWith(
        preview: result,
        rendering: false,
        clearError: true,
      );
    } on AsciiPreviewException catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
        rendering: false,
        error: e.message,
        clearPreview: true,
      );
    } on Object catch (e) {
      if (seq != _requestSeq) return;
      state = state.copyWith(
        rendering: false,
        error: 'Rendering failed: $e',
        clearPreview: true,
      );
    }
  }
}

/// Provider for the ASCII editor domain controller.
final NotifierProvider<AsciiEditorController, EditorState>
asciiEditorControllerProvider =
    NotifierProvider<AsciiEditorController, EditorState>(
      AsciiEditorController.new,
    );

/// Riverpod controller for the sketch editor state.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sketchglyph_engine/sketchglyph_engine.dart';

import '../../../core/image/image_pipeline.dart';
import 'sketch_job.dart';

/// State of the sketch editor.
class SketchEditorState {
  /// Creates a state.
  SketchEditorState({
    this.source,
    SketchSettings? settings,
    this.render,
    this.rendering = false,
    this.error,
    int? seed,
  }) : settings = settings ?? SketchSettings(),
       seed = seed ?? 1;

  /// Current source image.
  final SourceImage? source;

  /// Current sketch settings.
  final SketchSettings settings;

  /// Current render result.
  final SketchRender? render;

  /// Whether rendering is in progress.
  final bool rendering;

  /// Current error message, if any.
  final String? error;

  /// Current random seed.
  final int seed;

  /// Copy with replacements.
  SketchEditorState copyWith({
    SourceImage? source,
    SketchSettings? settings,
    SketchRender? render,
    bool? rendering,
    String? error,
    int? seed,
    bool clearRender = false,
    bool clearError = false,
  }) => SketchEditorState(
    source: source ?? this.source,
    settings: settings ?? this.settings,
    render: clearRender ? null : (render ?? this.render),
    rendering: rendering ?? this.rendering,
    error: clearError ? null : (error ?? this.error),
    seed: seed ?? this.seed,
  );
}

/// Controller for the sketch editor domain layer.
class SketchEditorController extends Notifier<SketchEditorState> {
  Timer? _debounceTimer;
  int _requestSeq = 0;
  final math.Random _rng = math.Random();

  @override
  SketchEditorState build() => SketchEditorState();

  /// Sets the source image.
  void setSource(SourceImage? source) {
    state = state.copyWith(source: source, clearRender: true);
    if (source != null) {
      refresh(lowRes: true);
    }
  }

  /// Updates settings with [fn], keeping the seed in sync with settings.
  void update(SketchSettings Function(SketchSettings) fn) {
    final SketchSettings next = fn(state.settings);
    state = state.copyWith(
      settings: next,
      seed: next.seed,
      clearError: true,
      clearRender: true,
    );
    if (state.source != null) {
      refresh(lowRes: true);
    }
  }

  /// Sets the seed explicitly.
  void setSeed(int seed) {
    update((SketchSettings s) => s.copyWith(seed: seed));
  }

  /// Randomises the seed.
  void randomizeSeed() {
    final int newSeed = _rng.nextInt(1 << 30) + 1;
    setSeed(newSeed);
  }

  /// Resets everything to defaults.
  void reset() {
    _debounceTimer?.cancel();
    _requestSeq++;
    state = SketchEditorState(source: state.source);
    if (state.source != null) {
      refresh(lowRes: true);
    }
  }

  /// Refreshes the render with debouncing (~180ms).
  Future<void> refresh({bool lowRes = false}) async {
    _debounceTimer?.cancel();
    if (state.source == null) return;

    _debounceTimer = Timer(const Duration(milliseconds: 180), () async {
      final int seq = ++_requestSeq;
      state = state.copyWith(rendering: true, clearError: true);

      try {
        final SourceImage source = state.source!;
        final SketchSettings settings = state.settings.copyWith(
          seed: state.seed,
          longEdge: lowRes ? 640 : 1400,
        );
        final SketchRequest request = SketchRequest(
          source: source,
          settings: settings,
        );
        final SketchRender result = await renderSketch(request);

        if (seq != _requestSeq) return;

        state = state.copyWith(
          render: result,
          rendering: false,
          clearError: true,
        );
      } on SketchRenderException catch (e) {
        if (seq != _requestSeq) return;
        state = state.copyWith(rendering: false, error: e.message);
      } on Object catch (e) {
        if (seq != _requestSeq) return;
        state = state.copyWith(rendering: false, error: 'Rendering failed: $e');
      }
    });
  }
}

/// Provider for the sketch editor domain controller.
final NotifierProvider<SketchEditorController, SketchEditorState>
sketchEditorControllerProvider =
    NotifierProvider<SketchEditorController, SketchEditorState>(
      SketchEditorController.new,
    );

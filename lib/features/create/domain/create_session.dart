/// Immutable create session state with undo/redo history.
library;

import '../../../core/image/image_pipeline.dart';
import '../data/source_picker.dart';
import 'create_types.dart';
import 'overlay_spec.dart';

/// Immutable snapshot of the create session.
class CreateSession {
  /// Creates a session.
  const CreateSession({
    this.picked,
    this.source,
    this.target,
    this.history = const <CreateStep>[],
    this.historyIndex = -1,
    this.overlay = const OverlaySpec(),
  });

  /// The raw picked image bytes.
  final PickedImage? picked;

  /// The decoded (and possibly transformed) source.
  final SourceImage? source;

  /// The chosen editor target.
  final CreateTarget? target;

  /// Ordered list of steps the user has walked through.
  final List<CreateStep> history;

  /// Index into [history] for the current position.
  final int historyIndex;

  /// Caption / watermark overlay spec.
  final OverlaySpec overlay;

  /// Current step, or null if the session is empty.
  CreateStep? get currentStep =>
      (historyIndex >= 0 && historyIndex < history.length)
      ? history[historyIndex]
      : null;

  /// Copy with replacements.
  CreateSession copyWith({
    PickedImage? picked,
    SourceImage? source,
    CreateTarget? target,
    List<CreateStep>? history,
    int? historyIndex,
    OverlaySpec? overlay,
    bool clearPicked = false,
    bool clearSource = false,
    bool clearTarget = false,
  }) => CreateSession(
    picked: clearPicked ? null : (picked ?? this.picked),
    source: clearSource ? null : (source ?? this.source),
    target: clearTarget ? null : (target ?? this.target),
    history: history ?? this.history,
    historyIndex: historyIndex ?? this.historyIndex,
    overlay: overlay ?? this.overlay,
  );

  /// An empty session.
  static const CreateSession empty = CreateSession();
}

/// Create session controller — Phase 6.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image/image_pipeline.dart';
import '../data/source_picker.dart';
import 'create_session.dart';
import 'create_types.dart';
import 'overlay_spec.dart';

/// Riverpod notifier managing the create flow session.
///
/// Back navigation preserves state because the session lives in the provider,
/// not the widget. Re-entering Create with an active session resumes at the
/// last step.
class CreateSessionController extends Notifier<CreateSession> {
  // Classic two-stack model: the live state lives outside the stacks, so a
  // single undo moves back exactly one step.
  final List<CreateSession> _undo = <CreateSession>[];
  final List<CreateSession> _redo = <CreateSession>[];

  @override
  CreateSession build() => CreateSession.empty;

  void _push(CreateSession next) {
    _undo.add(state);
    _redo.clear();
    state = next;
  }

  /// Records a picked image and advances to the decode step.
  void setPicked(PickedImage picked) {
    _push(
      state.copyWith(
        picked: picked,
        history: <CreateStep>[CreateStep.pickSource],
        historyIndex: 0,
      ),
    );
  }

  /// Records a decoded source and advances to the transform step.
  void setSource(SourceImage source) {
    _push(
      state.copyWith(
        source: source,
        history: <CreateStep>[...state.history, CreateStep.decode],
        historyIndex: state.history.length,
      ),
    );
  }

  /// Updates the source after a transform (rotate/flip/crop).
  ///
  /// This replaces the current source without adding a new step — transforms
  /// are settings-level changes, not navigation steps.
  void updateSource(SourceImage source) {
    state = state.copyWith(source: source);
  }

  /// Records the chosen target (ASCII or sketch).
  void chooseTarget(CreateTarget target) {
    _push(
      state.copyWith(
        target: target,
        history: <CreateStep>[...state.history, CreateStep.chooseTarget],
        historyIndex: state.history.length,
      ),
    );
  }

  /// Updates the overlay spec.
  void setOverlay(OverlaySpec overlay) {
    state = state.copyWith(overlay: overlay);
  }

  /// Undoes the last step.
  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(state);
    state = _undo.removeLast();
  }

  /// Redoes the last undone step.
  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(state);
    state = _redo.removeLast();
  }

  /// Whether undo is possible.
  bool get canUndo => _undo.isNotEmpty;

  /// Whether redo is possible.
  bool get canRedo => _redo.isNotEmpty;

  /// Clears the session and history.
  void clear() {
    _undo.clear();
    _redo.clear();
    state = CreateSession.empty;
  }
}

/// Public provider for the create session.
final NotifierProvider<CreateSessionController, CreateSession>
createSessionProvider =
    NotifierProvider<CreateSessionController, CreateSession>(
      CreateSessionController.new,
    );

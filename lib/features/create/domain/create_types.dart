/// Create flow types shared across the feature.
library;

/// Which editor the user picked in the type step.
enum CreateTarget {
  /// ASCII editor.
  ascii,

  /// Sketch editor.
  sketch,
}

/// Steps in the create flow that participate in undo/redo.
enum CreateStep {
  /// Picking a source image.
  pickSource,

  /// Decoding the image.
  decode,

  /// Transforming (rotate/flip/crop).
  transform,

  /// Choosing ASCII or sketch.
  chooseTarget,
}

/// Batch queue — pure Dart, testable with fake async processors.
library;

import 'dart:async';

import '../../../core/image/image_pipeline.dart';
import '../data/source_picker.dart';

/// Status of a single batch item.
enum BatchItemStatus {
  /// Waiting to be processed.
  pending,

  /// Currently being processed.
  processing,

  /// Finished successfully.
  done,

  /// Failed with an error.
  failed,

  /// Cancelled by the user.
  cancelled,
}

/// A single item in the batch queue.
class BatchItem {
  /// Creates an item.
  const BatchItem({
    required this.id,
    required this.picked,
    this.status = BatchItemStatus.pending,
    this.progress = 0.0,
    this.source,
    this.error,
  });

  /// Stable identifier.
  final String id;

  /// The picked image.
  final PickedImage picked;

  /// Current status.
  final BatchItemStatus status;

  /// Progress in 0..1.
  final double progress;

  /// The decoded source, if successful.
  final SourceImage? source;

  /// Error message, if failed.
  final String? error;

  /// Copy with replacements.
  BatchItem copyWith({
    BatchItemStatus? status,
    double? progress,
    SourceImage? source,
    String? error,
  }) => BatchItem(
    id: id,
    picked: picked,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    source: source ?? this.source,
    error: error ?? this.error,
  );
}

/// Callback signature for the batch processor.
typedef BatchProcessor = Future<SourceImage> Function(
  PickedImage picked,
  void Function(double progress) onProgress,
);

/// A queue of images to be processed with identical settings.
class BatchQueue {
  /// Creates an empty queue.
  BatchQueue();

  final List<BatchItem> _items = <BatchItem>[];
  bool _cancelled = false;
  int _nextId = 0;

  /// All items.
  List<BatchItem> get items => List<BatchItem>.unmodifiable(_items);

  /// Whether the queue is currently running.
  bool get isRunning => _items.any(
    (BatchItem i) =>
        i.status == BatchItemStatus.processing ||
        i.status == BatchItemStatus.pending,
  );

  /// Adds a picked image to the queue.
  void add(PickedImage picked) {
    _items.add(BatchItem(id: 'batch_${_nextId++}', picked: picked));
  }

  /// Runs the queue with [processor], calling [onUpdate] after each item.
  ///
  /// Returns when all items are done, failed, or cancelled.
  Future<void> run(
    BatchProcessor processor, {
    void Function(List<BatchItem> items)? onUpdate,
  }) async {
    _cancelled = false;
    for (int i = 0; i < _items.length; i++) {
      if (_cancelled) {
        // Mark remaining as cancelled.
        for (int j = i; j < _items.length; j++) {
          _items[j] = _items[j].copyWith(status: BatchItemStatus.cancelled);
        }
        onUpdate?.call(items);
        return;
      }
      final BatchItem item = _items[i];
      if (item.status != BatchItemStatus.pending) continue;

      _items[i] = item.copyWith(status: BatchItemStatus.processing);
      onUpdate?.call(items);

      try {
        final SourceImage source = await processor(item.picked, (
          double progress,
        ) {
          _items[i] = _items[i].copyWith(progress: progress);
          onUpdate?.call(items);
        });
        _items[i] = _items[i].copyWith(
          status: BatchItemStatus.done,
          progress: 1.0,
          source: source,
        );
      } on ImagePipelineException catch (e) {
        _items[i] = _items[i].copyWith(
          status: BatchItemStatus.failed,
          error: e.message,
        );
      } on Object catch (e) {
        _items[i] = _items[i].copyWith(
          status: BatchItemStatus.failed,
          error: 'Processing failed: $e',
        );
      }
      onUpdate?.call(items);
    }
  }

  /// Cancels the queue. Items not yet started are marked cancelled.
  void cancel() {
    _cancelled = true;
  }

  /// Clears all items.
  void clear() {
    _items.clear();
    _nextId = 0;
  }
}

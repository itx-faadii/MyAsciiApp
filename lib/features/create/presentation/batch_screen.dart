/// Batch mode screen — process multiple images with identical settings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/image/image_pipeline.dart';
import '../../../core/theme/tokens.dart';
import '../data/source_picker.dart';
import '../domain/batch_queue.dart';

/// Batch mode screen.
class BatchScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const BatchScreen({super.key, required this.picker});

  /// Source picker for adding images.
  final SourcePicker picker;

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  final BatchQueue _queue = BatchQueue();
  bool _running = false;

  @override
  void dispose() {
    _queue.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Mode'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Add image',
            onPressed: _running ? null : _addImage,
          ),
          if (_running)
            IconButton(
              icon: const Icon(LucideIcons.x),
              tooltip: 'Cancel',
              onPressed: () {
                _queue.cancel();
                setState(() => _running = false);
              },
            ),
        ],
      ),
      body: _queue.items.isEmpty
          ? const Center(child: Text('No images in queue'))
          : ListView.builder(
              itemCount: _queue.items.length,
              itemBuilder: (context, i) {
                final item = _queue.items[i];
                return _BatchItemTile(item: item);
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: FilledButton.icon(
            onPressed: _running || _queue.items.isEmpty ? null : _run,
            icon: const Icon(LucideIcons.play),
            label: const Text('Process All'),
          ),
        ),
      ),
    );
  }

  Future<void> _addImage() async {
    final picked = await widget.picker.pickFromGallery();
    if (picked != null) {
      _queue.add(picked);
      setState(() {});
    }
  }

  Future<void> _run() async {
    setState(() => _running = true);
    await _queue.run((picked, onProgress) async {
      // Simulate progress.
      for (int i = 0; i <= 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        onProgress(i / 10);
      }
      return decodeAndPrepare(picked.bytes);
    }, onUpdate: (_) => setState(() {}));
    if (mounted) {
      setState(() => _running = false);
    }
  }
}

class _BatchItemTile extends StatelessWidget {
  const _BatchItemTile({required this.item});

  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (item.status) {
      BatchItemStatus.pending => 'Pending',
      BatchItemStatus.processing => 'Processing...',
      BatchItemStatus.done => 'Done',
      BatchItemStatus.failed => 'Failed: ${item.error}',
      BatchItemStatus.cancelled => 'Cancelled',
    };
    return ListTile(
      leading: Icon(
        switch (item.status) {
          BatchItemStatus.pending => LucideIcons.clock,
          BatchItemStatus.processing => LucideIcons.loader,
          BatchItemStatus.done => LucideIcons.checkCircle,
          BatchItemStatus.failed => LucideIcons.xCircle,
          BatchItemStatus.cancelled => LucideIcons.x,
        },
        color: switch (item.status) {
          BatchItemStatus.done => Colors.green,
          BatchItemStatus.failed => Colors.red,
          _ => null,
        },
      ),
      title: Text(item.picked.name ?? 'Image ${item.id}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(statusText),
          if (item.status == BatchItemStatus.processing)
            LinearProgressIndicator(value: item.progress),
        ],
      ),
    );
  }
}

/// Create flow entry — source picker, decode, transform, type.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/image/image_pipeline.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/source_picker.dart';
import '../domain/create_session_controller.dart';
import '../domain/editor_launcher.dart';
import 'type_screen.dart';

/// Create flow entry screen.
///
/// Shows a source picker sheet (Gallery / Camera / File) with graceful
/// permission handling, then navigates through decode -> transform -> type.
///
/// Permission handling strategy: we detect picker exceptions (cancelled,
/// permission denied) and show a clear message with retry. We do NOT add
/// permission_handler as a dependency — instead we rely on the plugin's
/// exception messages and provide a "Retry" action. If the user denies
/// permission at the OS level, the picker returns null or throws; we show
/// a snackbar explaining the issue and offering to retry.
class CreateScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CreateScreen({super.key, required this.picker, required this.launcher});

  /// Source picker (injectable for tests).
  final SourcePicker picker;

  /// Editor launcher (injectable for tests).
  final EditorLauncher launcher;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  bool _decoding = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(createSessionProvider);
    final l10n = AppLocalizations.of(context);

    // Resume an in-progress session at the type step instead of restarting.
    if (session.source != null && session.target == null) {
      return TypeScreen(launcher: widget.launcher);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTitle)),
      body: SafeArea(
        child: _decoding
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: LucideIcons.camera,
                title: l10n.createPickSource,
                body: l10n.privacyOnDevice,
                action: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _pickAndDecode,
                      icon: const Icon(LucideIcons.image),
                      label: Text(l10n.createPickSource),
                    ),
                    const SizedBox(height: Spacing.md),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push(AppRoutes.createBatch);
                      },
                      icon: const Icon(LucideIcons.layers),
                      label: Text(l10n.createBatchMode),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: Spacing.lg),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.sm),
                      TextButton(
                        onPressed: _pickAndDecode,
                        child: Text(l10n.actionRetry),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickAndDecode() async {
    setState(() {
      _decoding = true;
      _error = null;
    });

    try {
      // Show a bottom sheet with source options.
      final origin = await _showSourcePickerSheet();
      if (origin == null) {
        if (mounted) {
          setState(() => _decoding = false);
        }
        return;
      }
      final picked = await _pickByOrigin(origin);
      if (picked == null) {
        // User cancelled or pick failed (error already shown).
        if (mounted) {
          setState(() => _decoding = false);
        }
        return;
      }

      // Record the pick.
      ref.read(createSessionProvider.notifier).setPicked(picked);

      // Decode.
      final source = await decodeAndPrepare(picked.bytes);
      ref.read(createSessionProvider.notifier).setSource(source);

      // Navigate to transform.
      if (mounted) {
        setState(() => _decoding = false);
        context.push(AppRoutes.createTransform);
      }
    } on ImagePipelineException catch (e) {
      if (mounted) {
        setState(() {
          _decoding = false;
          _error = e.message;
        });
      }
    } on SourcePickException catch (e) {
      if (mounted) {
        setState(() {
          _decoding = false;
          _error = e.message;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _decoding = false;
          _error = 'Failed to load image: $e';
        });
      }
    }
  }

  Future<PickedImage?> _pickByOrigin(SourceOrigin origin) async {
    final l10n = AppLocalizations.of(context);
    try {
      return switch (origin) {
        SourceOrigin.gallery => await widget.picker.pickFromGallery(),
        SourceOrigin.camera => await widget.picker.pickFromCamera(),
        SourceOrigin.file => await widget.picker.pickFromFile(),
      };
    } on Object catch (e) {
      final String message = e is SourcePickException
          ? e.message
          : l10n.createAccessBlocked;
      if (mounted) {
        setState(() {
          _decoding = false;
          _error = message;
        });
      }
      return null;
    }
  }

  Future<SourceOrigin?> _showSourcePickerSheet() async {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<SourceOrigin>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(LucideIcons.image),
                title: Text(l10n.createPickFromGallery),
                onTap: () => Navigator.pop(sheetContext, SourceOrigin.gallery),
              ),
              ListTile(
                leading: const Icon(LucideIcons.camera),
                title: Text(l10n.createPickFromCamera),
                onTap: () => Navigator.pop(sheetContext, SourceOrigin.camera),
              ),
              ListTile(
                leading: const Icon(LucideIcons.file),
                title: Text(l10n.createPickFromFile),
                onTap: () => Navigator.pop(sheetContext, SourceOrigin.file),
              ),
            ],
          ),
        );
      },
    );
  }
}

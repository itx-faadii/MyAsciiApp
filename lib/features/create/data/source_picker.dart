/// Source picking for the create flow, behind an injectable interface so
/// tests can fake the pickers.
library;

import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Where an imported image came from.
enum SourceOrigin {
  /// Device gallery (photo library).
  gallery,

  /// Camera capture.
  camera,

  /// File system via the system picker.
  file,
}

/// A picked image: raw bytes plus display metadata.
@immutable
class PickedImage {
  /// Creates a picked image.
  const PickedImage({required this.bytes, required this.origin, this.name});

  /// Encoded file bytes (JPG/PNG/WEBP...).
  final Uint8List bytes;

  /// How it was obtained.
  final SourceOrigin origin;

  /// Optional display name from the picker.
  final String? name;
}

/// Thrown when a pick is cancelled or fails before any bytes exist.
class SourcePickException implements Exception {
  /// Creates the exception.
  const SourcePickException(this.message);

  /// User-facing message.
  final String message;

  @override
  String toString() => 'SourcePickException: $message';
}

/// Abstraction over gallery/camera/file picking.
abstract class SourcePicker {
  /// Pick from the gallery; returns `null` when the user cancels.
  Future<PickedImage?> pickFromGallery();

  /// Capture with the camera; returns `null` when the user cancels.
  Future<PickedImage?> pickFromCamera();

  /// Pick an arbitrary file; returns `null` when the user cancels.
  Future<PickedImage?> pickFromFile();
}

/// Real implementation backed by image_picker + file_picker.
class PluginSourcePicker implements SourcePicker {
  /// Creates with an optional injected [ImagePicker] (for tests).
  PluginSourcePicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  static const List<String> _allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'gif',
  ];

  @override
  Future<PickedImage?> pickFromGallery() =>
      _pick(_imagePicker.pickImage(source: ImageSource.gallery));

  @override
  Future<PickedImage?> pickFromCamera() =>
      _pick(_imagePicker.pickImage(source: ImageSource.camera));

  @override
  Future<PickedImage?> pickFromFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final PlatformFile file = result.files.first;
    final Uint8List? bytes =
        file.bytes ?? (file.path == null ? null : await _readFile(file.path!));
    if (bytes == null) {
      throw const SourcePickException('The selected file could not be read.');
    }
    return PickedImage(
      bytes: bytes,
      origin: SourceOrigin.file,
      name: file.name,
    );
  }

  Future<PickedImage?> _pick(Future<XFile?> future) async {
    final XFile? file = await future;
    if (file == null) return null;
    final Uint8List bytes = await file.readAsBytes();
    return PickedImage(
      bytes: bytes,
      origin: SourceOrigin.gallery,
      name: file.name,
    );
  }

  Future<Uint8List?> _readFile(String path) async {
    final File file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}

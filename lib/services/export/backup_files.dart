import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Lets the user choose where files are saved and which file is restored.
/// An interface so widget tests can run without platform dialogs.
abstract interface class BackupFiles {
  /// Asks for a location and writes [bytes] there. Returns a short
  /// description of where it went, or `null` if the user cancelled.
  Future<String?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  });

  /// Asks for a JSON file and returns its contents, or `null` if cancelled.
  Future<Uint8List?> pickJson();
}

/// System dialogs: the Storage Access Framework on Android, the XDG desktop
/// portal on Linux. Both write the bytes themselves.
class SystemBackupFiles implements BackupFiles {
  const SystemBackupFiles();

  @override
  Future<String?> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    if (uri == null) return null;
    return uri.scheme == 'file' ? uri.toFilePath() : fileName;
  }

  @override
  Future<Uint8List?> pickJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return file?.readAsBytes();
  }
}

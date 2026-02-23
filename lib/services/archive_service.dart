import 'dart:io';
import 'package:path/path.dart' as p;

/// Compresses a folder to .zip using 7-Zip and deletes the original.
class ArchiveService {
  final String sevenZipPath;

  ArchiveService(this.sevenZipPath);

  /// Archive [folderPath] into a .zip beside it, then delete the original.
  /// Returns a status message.
  Future<String> archiveFolder(String folderPath) async {
    final zipPath = '$folderPath.zip';
    final result = await Process.run(
      sevenZipPath,
      ['a', '-tzip', zipPath, folderPath],
    );
    if (result.exitCode != 0) {
      return 'ARCHIVE ERROR ${p.basename(folderPath)}: 7z failed\n${result.stderr}';
    }
    await Directory(folderPath).delete(recursive: true);
    return 'ARCHIVED ${p.basename(folderPath)} -> ${p.basename(zipPath)}';
  }
}

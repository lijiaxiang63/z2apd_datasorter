import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Wraps dcm2niix binary execution.
class Dcm2niixService {
  final String binaryPath;

  Dcm2niixService(this.binaryPath);

  /// Check if a folder contains DICOM files by attempting a quick scan.
  Future<bool> isDicomFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return false;

    try {
      final result = await Process.run(binaryPath, [
        '-q',
        'y',
        '-d',
        '1',
        folderPath,
      ]);
      final output = result.stdout.toString() + result.stderr.toString();
      return output.contains(RegExp(r'Found\s+\d+\s+DICOM file'));
    } catch (_) {
      return false;
    }
  }

  /// Collect DICOM sub-folders under a root directory.
  /// Prefers series-level folders over higher-level scan containers.
  Future<List<String>> collectDicomFolders(String rootPath) async {
    final normalizedRoot = p.normalize(rootPath);
    final directDicomChildren = await collectImmediateDicomChildren(
      normalizedRoot,
    );

    final nestedDicomFolders = <String>[];
    for (final childDir in directDicomChildren) {
      final nestedChildren = await collectImmediateDicomChildren(childDir);
      if (nestedChildren.isNotEmpty) {
        nestedDicomFolders.addAll(nestedChildren);
      }
    }

    if (nestedDicomFolders.isNotEmpty) {
      nestedDicomFolders.sort();
      return nestedDicomFolders;
    }

    if (directDicomChildren.isNotEmpty) {
      return directDicomChildren;
    }

    if (await isDicomFolder(normalizedRoot)) {
      return [normalizedRoot];
    }

    return [];
  }

  /// Collect immediate child directories that contain DICOM files.
  Future<List<String>> collectImmediateDicomChildren(String rootPath) async {
    final rootDir = Directory(rootPath);
    final folders = <String>[];
    await for (final entity in rootDir.list()) {
      if (entity is Directory) {
        if (await isDicomFolder(entity.path)) {
          folders.add(p.normalize(entity.path));
        }
      }
    }
    folders.sort();
    return folders;
  }

  /// Convert a single DICOM folder to NIfTI (no-rules path).
  Future<ProcessResult> convert({
    required String inputDir,
    required String outputDir,
    required String filenameFormat,
  }) async {
    return await Process.run(binaryPath, [
      '-ba',
      'n',
      '-z',
      'y',
      '-f',
      filenameFormat,
      '-o',
      outputDir,
      inputDir,
    ]);
  }

  /// Convert to a staging directory (rules path).
  Future<ProcessResult> convertToStaging({
    required String inputDir,
    required String stagingDir,
    required String filenameFormat,
  }) async {
    return await Process.run(binaryPath, [
      '-ba',
      'n',
      '-z',
      'y',
      '-f',
      filenameFormat,
      '-o',
      stagingDir,
      inputDir,
    ]);
  }

  /// Scan a DICOM folder tree and extract series metadata.
  /// Returns a map of SeriesDescription -> file count.
  Future<Map<String, int>> scanSeries(String folderPath) async {
    final tempDir = await Directory.systemTemp.createTemp('dcm2niix_scan_');
    try {
      await Process.run(binaryPath, [
        '-b',
        'o',
        '-ba',
        'n',
        '-z',
        'n',
        '-f',
        '%s_%d',
        '-o',
        tempDir.path,
        folderPath,
      ]);

      final seriesCounts = <String, int>{};
      for (final f in tempDir.listSync()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final data =
              jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          final studyDescription = data['StudyDescription'] as String? ?? '';
          final desc = data['SeriesDescription'] as String? ?? studyDescription;
          if (desc.isNotEmpty) {
            seriesCounts[desc] = (seriesCounts[desc] ?? 0) + 1;
          }
        } catch (_) {
          continue;
        }
      }
      return seriesCounts;
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// Scan all DICOM folders under root and aggregate series.
  Future<Map<String, int>> scanAllSeries(String rootPath) async {
    final dicomFolders = await collectDicomFolders(rootPath);
    final allSeries = <String, int>{};
    for (final folder in dicomFolders) {
      final series = await scanSeries(folder);
      for (final entry in series.entries) {
        allSeries[entry.key] = (allSeries[entry.key] ?? 0) + entry.value;
      }
    }
    return allSeries;
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/modality_constants.dart';
import '../models/modality_rule.dart';
import '../models/conversion_result.dart';
import 'dcm2niix_service.dart';
import 'patient_id_parser.dart';

/// Performs fnmatch-style glob matching (case-insensitive).
bool fnmatch(String pattern, String text) {
  // Convert glob pattern to regex: * -> .*, ? -> .
  final buf = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    switch (c) {
      case '*':
        buf.write('.*');
      case '?':
        buf.write('.');
      case '.':
      case '+':
      case '^':
      case '\$':
      case '{':
      case '}':
      case '(':
      case ')':
      case '|':
      case '[':
      case ']':
      case '\\':
        buf.write('\\$c');
      default:
        buf.write(c);
    }
  }
  buf.write(r'$');
  return RegExp(buf.toString(), caseSensitive: false).hasMatch(text);
}

/// Returns the modality for the first matching rule, or null.
String? matchRules(String seriesDesc, List<ModalityRule> rules) {
  for (final rule in rules) {
    if (fnmatch(rule.pattern, seriesDesc)) {
      return rule.modality;
    }
  }
  return null;
}

/// Orchestrates the full DICOM-to-NIfTI conversion for a single folder.
class BidsOrganizer {
  final Dcm2niixService dcm2niix;

  BidsOrganizer(this.dcm2niix);

  /// Convert a single DICOM folder.
  ///
  /// If [rules] is empty, uses the legacy no-rules path (all -> T1w/anat).
  /// If [rules] is provided, converts to staging dir, matches series, and
  /// organizes into BIDS structure.
  Future<ConversionResult> convertOne({
    required String inputDir,
    List<ModalityRule> rules = const [],
    bool onlyMatched = true,
  }) async {
    final inputPath = Directory(inputDir);
    final folderName = p.basename(inputDir);

    // Find first DICOM file to extract metadata via dcm2niix
    final tempMeta = await Directory.systemTemp.createTemp('dcm_meta_');
    try {
      await Process.run(
        dcm2niix.binaryPath,
        ['-b', 'o', '-ba', 'n', '-z', 'n', '-f', '%s_%d', '-o', tempMeta.path, inputDir],
      );

      final metaJsonFiles = tempMeta
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      if (metaJsonFiles.isEmpty) {
        return ConversionResult(
          status: ConversionStatus.skip,
          folderName: folderName,
          message: 'no DICOM files found or dcm2niix produced no output',
        );
      }

      // Read first JSON to get PatientName and SeriesDate
      final firstMeta =
          jsonDecode(await metaJsonFiles.first.readAsString()) as Map<String, dynamic>;
      final patientName = firstMeta['PatientName'] as String? ?? '';
      final patientId = extractPatientId(patientName);

      if (patientId == null) {
        return ConversionResult(
          status: ConversionStatus.error,
          folderName: folderName,
          message: 'PatientID not found in PatientName',
        );
      }

      var seriesDate = (firstMeta['SeriesDate'] as String? ?? '')
          .replaceAll('/', '')
          .replaceAll('-', '');

      if (seriesDate.isEmpty) {
        // Fallback: extract date portion from AcquisitionDateTime
        // Formats: "YYYY-MM-DDTHH:MM:SS.ffffff" or "YYYYMMDDHHMMSS.ffffff"
        final acqDt = firstMeta['AcquisitionDateTime'] as String? ?? '';
        if (acqDt.isNotEmpty) {
          seriesDate = acqDt
              .split('T')[0]
              .replaceAll('/', '')
              .replaceAll('-', '');
          if (seriesDate.length > 8) {
            seriesDate = seriesDate.substring(0, 8); // keep only YYYYMMDD
          }
        }
      }

      if (seriesDate.isEmpty) {
        return ConversionResult(
          status: ConversionStatus.error,
          folderName: folderName,
          message: 'SeriesDate and AcquisitionDateTime not found',
        );
      }

      // Session = date with last 2 chars stripped (YYYYMMDD -> YYYYMM)
      final session = seriesDate.length >= 2
          ? seriesDate.substring(0, seriesDate.length - 2)
          : seriesDate;

      // --- No-rules path: convert directly as T1w/anat ---
      if (rules.isEmpty) {
        final seriesDesc =
            (firstMeta['SeriesDescription'] as String? ?? '').replaceAll(' ', '');
        final outputDir = p.join(
          inputPath.parent.path,
          'sub-$patientId',
          'ses-$session',
          'anat',
        );
        await Directory(outputDir).create(recursive: true);

        final result = await dcm2niix.convert(
          inputDir: inputDir,
          outputDir: outputDir,
          filenameFormat:
              'sub-${patientId}_ses-${seriesDate}_acq-${seriesDesc}_T1w',
        );

        if (result.exitCode != 0) {
          return ConversionResult(
            status: ConversionStatus.error,
            folderName: folderName,
            message: 'dcm2niix failed\n${result.stderr}',
          );
        }

        return ConversionResult(
          status: ConversionStatus.ok,
          folderName: folderName,
          message: outputDir,
        );
      }

      // --- Rules path: convert to staging, match & rename ---
      final stagingDir = await Directory.systemTemp.createTemp('dcm_staging_');
      try {
        final tmpFmt = 'sub-${patientId}_ses-${seriesDate}_%s';
        final result = await dcm2niix.convertToStaging(
          inputDir: inputDir,
          stagingDir: stagingDir.path,
          filenameFormat: tmpFmt,
        );

        if (result.exitCode != 0) {
          return ConversionResult(
            status: ConversionStatus.error,
            folderName: folderName,
            message: 'dcm2niix failed\n${result.stderr}',
          );
        }

        // Read JSON sidecars from staging
        final jsonFiles = stagingDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

        if (jsonFiles.isEmpty) {
          return ConversionResult(
            status: ConversionStatus.skip,
            folderName: folderName,
            message: 'dcm2niix produced no output',
          );
        }

        final details = <String>[];
        for (final jf in jsonFiles) {
          Map<String, dynamic> meta;
          try {
            meta = jsonDecode(await jf.readAsString()) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }

          final seriesDesc = meta['SeriesDescription'] as String? ?? '';
          var modality = matchRules(seriesDesc, rules);

          if (modality == null) {
            if (onlyMatched) continue; // skip unmatched series
            modality = 'T1w'; // default fallback
          }

          final subfolder = modalitySubfolder[modality] ?? 'anat';
          // Clean acquisition label: remove non-alphanumeric chars
          final acqLabel = seriesDesc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

          final outputDir = p.join(
            inputPath.parent.path,
            'sub-$patientId',
            'ses-$session',
            subfolder,
          );
          await Directory(outputDir).create(recursive: true);

          // Move all files sharing this JSON's stem
          final baseStem = p.basenameWithoutExtension(jf.path);
          for (final src in stagingDir.listSync()) {
            if (src is! File) continue;
            if (!p.basename(src.path).startsWith(baseStem)) continue;

            final remainder = p.basename(src.path).substring(baseStem.length);
            final newName =
                'sub-${patientId}_ses-${seriesDate}_acq-${acqLabel}_$modality$remainder';
            await src.rename(p.join(outputDir, newName));
          }

          details.add('$seriesDesc -> $modality ($subfolder)');
        }

        if (details.isEmpty) {
          return ConversionResult(
            status: ConversionStatus.skip,
            folderName: folderName,
            message: 'no series matched rules',
          );
        }

        return ConversionResult(
          status: ConversionStatus.ok,
          folderName: folderName,
          message: '',
          details: details,
        );
      } finally {
        if (await stagingDir.exists()) {
          await stagingDir.delete(recursive: true);
        }
      }
    } finally {
      if (await tempMeta.exists()) {
        await tempMeta.delete(recursive: true);
      }
    }
  }
}

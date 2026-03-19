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

String seriesDescriptionFromMeta(Map<String, dynamic> meta) {
  final studyDescription = meta['StudyDescription'] as String? ?? '';
  return meta['SeriesDescription'] as String? ?? studyDescription;
}

String extractSeriesDate(Map<String, dynamic> meta) {
  var seriesDate = (meta['SeriesDate'] as String? ?? '')
      .replaceAll('/', '')
      .replaceAll('-', '');

  if (seriesDate.isNotEmpty) {
    return seriesDate;
  }

  // Formats: "YYYY-MM-DDTHH:MM:SS.ffffff" or "YYYYMMDDHHMMSS.ffffff"
  final acqDt = meta['AcquisitionDateTime'] as String? ?? '';
  if (acqDt.isEmpty) {
    return '';
  }

  seriesDate = acqDt.split('T')[0].replaceAll('/', '').replaceAll('-', '');
  if (seriesDate.length > 8) {
    return seriesDate.substring(0, 8);
  }
  return seriesDate;
}

Map<String, dynamic>? selectPrimaryMetaForConversion({
  required List<Map<String, dynamic>> metas,
  required List<ModalityRule> rules,
  required bool onlyMatched,
}) {
  Iterable<Map<String, dynamic>> candidates = metas;
  if (rules.isNotEmpty && onlyMatched) {
    candidates = metas.where(
      (meta) => matchRules(seriesDescriptionFromMeta(meta), rules) != null,
    );
  }

  Map<String, dynamic>? firstCandidate;
  for (final meta in candidates) {
    firstCandidate ??= meta;
    if (extractSeriesDate(meta).isNotEmpty) {
      return meta;
    }
  }

  return firstCandidate;
}

String extractPetTracerLabel(Map<String, dynamic> meta) {
  var tracer =
      meta['Radiopharmaceutical'] as String? ??
      meta['TracerName'] as String? ??
      '';

  if (tracer.isEmpty) {
    final sequence = meta['RadiopharmaceuticalInformationSequence'];
    if (sequence is List && sequence.isNotEmpty && sequence.first is Map) {
      tracer = (sequence.first as Map)['Radiopharmaceutical'] as String? ?? '';
    }
  }

  return sanitizeBidsLabel(tracer);
}

String buildPetFilenameStem({
  required String patientId,
  required String session,
  required String tracer,
}) {
  return 'sub-$patientId'
      '_ses-$session'
      '_trc-$tracer'
      '_pet';
}

bool shouldConvertPetSeries({
  required String seriesDesc,
  required List<ModalityRule> rules,
  required bool onlyMatched,
}) {
  if (rules.isEmpty) {
    return true;
  }

  if (matchRules(seriesDesc, rules) != null) {
    return true;
  }

  return !onlyMatched;
}

/// Orchestrates the full DICOM-to-NIfTI conversion for a single folder.
class BidsOrganizer {
  final Dcm2niixService dcm2niix;

  BidsOrganizer(this.dcm2niix);

  /// Convert a single DICOM folder.
  ///
  /// [outputRoot] is the directory where `sub-<label>` folders are created.
  /// If [rules] is empty, uses the legacy no-rules path (all -> T1w/anat).
  /// If [rules] is provided, converts to staging dir, matches series, and
  /// organizes into BIDS structure.
  Future<ConversionResult> convertOne({
    required String inputDir,
    required String outputRoot,
    List<ModalityRule> rules = const [],
    bool onlyMatched = true,
  }) async {
    final folderName = p.basename(inputDir);

    // Find first DICOM file to extract metadata via dcm2niix
    final tempMeta = await Directory.systemTemp.createTemp('dcm_meta_');
    try {
      await Process.run(dcm2niix.binaryPath, [
        '-b',
        'o',
        '-ba',
        'n',
        '-z',
        'n',
        '-f',
        '%s_%d',
        '-o',
        tempMeta.path,
        inputDir,
      ]);

      final metaJsonFiles =
          tempMeta
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      if (metaJsonFiles.isEmpty) {
        return ConversionResult(
          status: ConversionStatus.skip,
          folderName: folderName,
          message: 'no DICOM files found or dcm2niix produced no output',
        );
      }

      final metas = <Map<String, dynamic>>[];
      for (final metaJson in metaJsonFiles) {
        try {
          final meta = jsonDecode(await metaJson.readAsString());
          if (meta is Map<String, dynamic>) {
            metas.add(meta);
          }
        } catch (_) {
          continue;
        }
      }

      if (metas.isEmpty) {
        return ConversionResult(
          status: ConversionStatus.skip,
          folderName: folderName,
          message: 'dcm2niix produced no readable metadata',
        );
      }

      final primaryMeta = selectPrimaryMetaForConversion(
        metas: metas,
        rules: rules,
        onlyMatched: onlyMatched,
      );
      if (primaryMeta == null) {
        return ConversionResult(
          status: ConversionStatus.skip,
          folderName: folderName,
          message: 'no series matched rules',
        );
      }

      // Detect PET modality from DICOM Modality field
      final dicomModality = (primaryMeta['Modality'] as String? ?? '')
          .toUpperCase();
      final isPet = dicomModality == 'PT';

      // --- Extract patient ID ---
      String? patientId;
      if (isPet) {
        patientId = extractPatientIdFromScanPath(inputDir, stopAt: outputRoot);
      } else {
        final patientName = primaryMeta['PatientName'] as String? ?? '';
        final hospitalID = primaryMeta['PatientID'] as String?;
        patientId = extractPatientId(patientName) ?? hospitalID;
      }

      if (patientId == null || patientId.isEmpty) {
        return ConversionResult(
          status: ConversionStatus.error,
          folderName: folderName,
          message: isPet
              ? 'Could not extract PatientID from PET folder path'
              : 'PatientID not found in PatientName or HospitalID',
        );
      }

      patientId = sanitizeBidsLabel(patientId, fallback: '');

      final seriesDate = extractSeriesDate(primaryMeta);

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

      final subjectDir = p.join(outputRoot, 'sub-$patientId');

      // --- PET path: always use staging approach ---
      if (isPet) {
        return _convertPet(
          inputDir: inputDir,
          patientId: patientId,
          session: session,
          folderName: folderName,
          subjectDir: subjectDir,
          rules: rules,
          onlyMatched: onlyMatched,
        );
      }

      // --- No-rules path: convert directly as T1w/anat ---
      if (rules.isEmpty) {
        final seriesDesc = seriesDescriptionFromMeta(
          primaryMeta,
        ).replaceAll(' ', '');
        final outputDir = p.join(subjectDir, 'ses-$session', 'anat');
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
          subjectDir: subjectDir,
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
        final jsonFiles =
            stagingDir
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
          final seriesDesc = seriesDescriptionFromMeta(meta);
          var modality = matchRules(seriesDesc, rules);

          if (modality == null) {
            if (onlyMatched) continue; // skip unmatched series
            modality = 'T1w'; // default fallback
          }

          final subfolder = modalitySubfolder[modality] ?? 'anat';
          // Clean acquisition label: remove non-alphanumeric chars
          final acqLabel = seriesDesc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

          final outputDir = p.join(subjectDir, 'ses-$session', subfolder);
          await Directory(outputDir).create(recursive: true);

          // Move all files sharing this JSON's stem
          final baseStem = p.basenameWithoutExtension(jf.path);
          for (final src in stagingDir.listSync()) {
            if (src is! File) continue;
            if (!p.basename(src.path).startsWith(baseStem)) continue;

            final remainder = p.basename(src.path).substring(baseStem.length);
            final newName =
                'sub-${patientId}_ses-${seriesDate}_acq-${acqLabel}_$modality$remainder';
            final newPath = p.join(outputDir, newName);
            await src.copy(newPath);
            await src.delete();
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
          subjectDir: subjectDir,
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

  /// PET-specific conversion: extracts patient ID from folder name,
  /// tracer from DICOM metadata, and uses BIDS PET naming convention.
  Future<ConversionResult> _convertPet({
    required String inputDir,
    required String patientId,
    required String session,
    required String folderName,
    required String subjectDir,
    required List<ModalityRule> rules,
    required bool onlyMatched,
  }) async {
    final stagingDir = await Directory.systemTemp.createTemp('dcm_staging_');
    try {
      final tmpFmt = 'sub-${patientId}_ses-${session}_%s';
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

      final jsonFiles =
          stagingDir
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

        // Extract tracer label from DICOM metadata
        final tracer = extractPetTracerLabel(meta);
        final seriesDesc = seriesDescriptionFromMeta(meta);

        if (!shouldConvertPetSeries(
          seriesDesc: seriesDesc,
          rules: rules,
          onlyMatched: onlyMatched,
        )) {
          continue;
        }

        final outputDir = p.join(subjectDir, 'ses-$session', 'pet');
        await Directory(outputDir).create(recursive: true);

        // Move all files sharing this JSON's stem with PET naming
        final baseStem = p.basenameWithoutExtension(jf.path);
        for (final src in stagingDir.listSync()) {
          if (src is! File) continue;
          if (!p.basename(src.path).startsWith(baseStem)) continue;

          final remainder = p.basename(src.path).substring(baseStem.length);
          final newName =
              '${buildPetFilenameStem(patientId: patientId, session: session, tracer: tracer)}$remainder';
          final newPath = p.join(outputDir, newName);
          await src.copy(newPath);
          await src.delete();
        }

        details.add('$seriesDesc -> pet (trc-$tracer)');
      }

      if (details.isEmpty) {
        return ConversionResult(
          status: ConversionStatus.skip,
          folderName: folderName,
          message: 'dcm2niix produced no output for PET',
        );
      }

      return ConversionResult(
        status: ConversionStatus.ok,
        folderName: folderName,
        message: '',
        details: details,
        subjectDir: subjectDir,
      );
    } finally {
      if (await stagingDir.exists()) {
        await stagingDir.delete(recursive: true);
      }
    }
  }
}

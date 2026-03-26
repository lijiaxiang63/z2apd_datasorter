import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/conversion_result.dart';
import '../models/dicom_series_meta.dart';
import '../models/modality_constants.dart';
import '../models/modality_rule.dart';
import 'bids_filename_builder.dart';
import 'dcm2niix_service.dart';
import 'modality_rule_matcher.dart';
import 'patient_id_parser.dart';

// Re-export extracted functions so existing imports keep working.
export 'modality_rule_matcher.dart' show fnmatch, matchRules, shouldConvertPetSeries;
export 'bids_filename_builder.dart' show buildPetFilenameStem;

/// Select the primary metadata entry for conversion.
///
/// When [onlyMatched] is true and [rules] is non-empty, only series that
/// match a rule are considered. Among candidates, prefers one with a
/// non-empty series date.
DicomSeriesMeta? selectPrimaryMeta({
  required List<DicomSeriesMeta> metas,
  required List<ModalityRule> rules,
  required bool onlyMatched,
}) {
  Iterable<DicomSeriesMeta> candidates = metas;
  if (rules.isNotEmpty && onlyMatched) {
    candidates = metas.where(
      (meta) => matchRules(meta.seriesDescription, rules) != null,
    );
  }

  DicomSeriesMeta? firstCandidate;
  for (final meta in candidates) {
    firstCandidate ??= meta;
    if (meta.seriesDate.isNotEmpty) {
      return meta;
    }
  }

  return firstCandidate;
}

/// Legacy wrapper kept for test compatibility.
Map<String, dynamic>? selectPrimaryMetaForConversion({
  required List<Map<String, dynamic>> metas,
  required List<ModalityRule> rules,
  required bool onlyMatched,
}) {
  final wrapped = metas.map((m) => DicomSeriesMeta(m)).toList();
  final result = selectPrimaryMeta(
    metas: wrapped,
    rules: rules,
    onlyMatched: onlyMatched,
  );
  return result?.raw;
}

/// Legacy wrapper kept for test compatibility.
String seriesDescriptionFromMeta(Map<String, dynamic> meta) =>
    DicomSeriesMeta(meta).seriesDescription;

/// Legacy wrapper kept for test compatibility.
String extractSeriesDate(Map<String, dynamic> meta) =>
    DicomSeriesMeta(meta).seriesDate;

/// Legacy wrapper kept for test compatibility.
String extractPetTracerLabel(Map<String, dynamic> meta) =>
    DicomSeriesMeta(meta).petTracer;

/// Orchestrates the full DICOM-to-NIfTI conversion for a single folder.
class BidsOrganizer {
  final Dcm2niixService dcm2niix;

  BidsOrganizer(this.dcm2niix);

  Future<ConversionResult> convertOne({
    required String inputDir,
    required String outputRoot,
    List<ModalityRule> rules = const [],
    bool onlyMatched = true,
  }) async {
    final folderName = p.basename(inputDir);

    final metas = await dcm2niix.extractMetadata(inputDir);
    if (metas.isEmpty) {
      return ConversionResult(
        status: ConversionStatus.skip,
        folderName: folderName,
        message: 'no DICOM files found or dcm2niix produced no output',
      );
    }

    final primaryMeta = selectPrimaryMeta(
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

    // --- Extract patient ID ---
    String? patientId;
    if (primaryMeta.isPet) {
      patientId = extractPatientIdFromScanPath(inputDir, stopAt: outputRoot);
    } else {
      patientId =
          extractPatientId(primaryMeta.patientName) ?? primaryMeta.patientId;
    }

    if (patientId == null || patientId.isEmpty) {
      return ConversionResult(
        status: ConversionStatus.error,
        folderName: folderName,
        message: primaryMeta.isPet
            ? 'Could not extract PatientID from PET folder path'
            : 'PatientID not found in PatientName or HospitalID',
      );
    }

    patientId = sanitizeBidsLabel(patientId, fallback: '');

    final seriesDate = primaryMeta.seriesDate;
    if (seriesDate.isEmpty) {
      return ConversionResult(
        status: ConversionStatus.error,
        folderName: folderName,
        message: 'SeriesDate and AcquisitionDateTime not found',
      );
    }

    final session = seriesDate.length >= 2
        ? seriesDate.substring(0, seriesDate.length - 2)
        : seriesDate;

    final subjectDir = p.join(outputRoot, 'sub-$patientId');

    if (primaryMeta.isPet) {
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

    if (rules.isEmpty) {
      return _convertWithoutRules(
        inputDir: inputDir,
        patientId: patientId,
        session: session,
        seriesDate: seriesDate,
        seriesDesc: primaryMeta.seriesDescription,
        folderName: folderName,
        subjectDir: subjectDir,
      );
    }

    return _convertWithRules(
      inputDir: inputDir,
      patientId: patientId,
      session: session,
      seriesDate: seriesDate,
      folderName: folderName,
      subjectDir: subjectDir,
      rules: rules,
      onlyMatched: onlyMatched,
    );
  }

  Future<ConversionResult> _convertWithoutRules({
    required String inputDir,
    required String patientId,
    required String session,
    required String seriesDate,
    required String seriesDesc,
    required String folderName,
    required String subjectDir,
  }) async {
    final acqLabel = seriesDesc.replaceAll(' ', '');
    final outputDir = p.join(subjectDir, 'ses-$session', 'anat');
    await Directory(outputDir).create(recursive: true);

    final result = await dcm2niix.convert(
      inputDir: inputDir,
      outputDir: outputDir,
      filenameFormat:
          'sub-${patientId}_ses-${seriesDate}_acq-${acqLabel}_T1w',
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

  Future<ConversionResult> _convertWithRules({
    required String inputDir,
    required String patientId,
    required String session,
    required String seriesDate,
    required String folderName,
    required String subjectDir,
    required List<ModalityRule> rules,
    required bool onlyMatched,
  }) async {
    final stagingDir = await Directory.systemTemp.createTemp('dcm_staging_');
    try {
      final tmpFmt = 'sub-${patientId}_ses-${seriesDate}_%s';
      final result = await dcm2niix.convert(
        inputDir: inputDir,
        outputDir: stagingDir.path,
        filenameFormat: tmpFmt,
      );

      if (result.exitCode != 0) {
        return ConversionResult(
          status: ConversionStatus.error,
          folderName: folderName,
          message: 'dcm2niix failed\n${result.stderr}',
        );
      }

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
        Map<String, dynamic> rawMeta;
        try {
          rawMeta = jsonDecode(await jf.readAsString()) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final meta = DicomSeriesMeta(rawMeta);
        final seriesDesc = meta.seriesDescription;
        var modality = matchRules(seriesDesc, rules);

        if (modality == null) {
          if (onlyMatched) continue;
          modality = 'T1w';
        }

        final subfolder = modalitySubfolder[modality] ?? 'anat';
        final acqLabel = seriesDesc.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

        final outputDir = p.join(subjectDir, 'ses-$session', subfolder);
        await Directory(outputDir).create(recursive: true);

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
  }

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
      final result = await dcm2niix.convert(
        inputDir: inputDir,
        outputDir: stagingDir.path,
        filenameFormat: tmpFmt,
      );

      if (result.exitCode != 0) {
        return ConversionResult(
          status: ConversionStatus.error,
          folderName: folderName,
          message: 'dcm2niix failed\n${result.stderr}',
        );
      }

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
        Map<String, dynamic> rawMeta;
        try {
          rawMeta = jsonDecode(await jf.readAsString()) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
        final meta = DicomSeriesMeta(rawMeta);
        final tracer = meta.petTracer;
        final seriesDesc = meta.seriesDescription;

        if (!shouldConvertPetSeries(
          seriesDesc: seriesDesc,
          rules: rules,
          onlyMatched: onlyMatched,
        )) {
          continue;
        }

        final outputDir = p.join(subjectDir, 'ses-$session', 'pet');
        await Directory(outputDir).create(recursive: true);

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

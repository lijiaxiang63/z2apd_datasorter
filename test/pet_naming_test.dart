import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:z2apd_datasorter/models/modality_rule.dart';
import 'package:z2apd_datasorter/services/bids_organizer.dart';
import 'package:z2apd_datasorter/services/patient_id_parser.dart';

void main() {
  group('PET helpers', () {
    test('extracts patient id from scan folder name', () {
      expect(
        extractPatientIdFromScanFolderName('PATIENT123_456789_NAME_SCAN'),
        'PATIENT123',
      );
    });

    test('ignores folder names that are not scan-folder shaped', () {
      expect(extractPatientIdFromScanFolderName('z2scandown'), isNull);
    });

    test('extracts patient id from ancestor PET folder path', () {
      final selectedRoot = p.join('/tmp', 'z2scandown');
      final petSeriesPath = p.join(
        selectedRoot,
        '52284899_439813534_ZHOUCHUNTANG_PETFDG',
        'series1',
      );

      expect(
        extractPatientIdFromScanPath(petSeriesPath, stopAt: selectedRoot),
        '52284899',
      );
    });

    test('extracts patient id from a direct PET folder path', () {
      final selectedRoot = p.join('/tmp', 'z2scandown');
      final petFolderPath = p.join(
        selectedRoot,
        '52284899_439813534_ZHOUCHUNTANG_PETFDG',
      );

      expect(
        extractPatientIdFromScanPath(petFolderPath, stopAt: selectedRoot),
        '52284899',
      );
    });

    test('extracts tracer from nested metadata and sanitizes it', () {
      final tracer = extractPetTracerLabel({
        'RadiopharmaceuticalInformationSequence': [
          {'Radiopharmaceutical': '18F-FDG'},
        ],
      });

      expect(tracer, '18FFDG');
    });

    test('builds a BIDS PET filename stem', () {
      expect(
        buildPetFilenameStem(
          patientId: 'PATIENT123',
          session: '202603',
          tracer: '18FFDG',
        ),
        'sub-PATIENT123_ses-202603_trc-18FFDG_pet',
      );
    });

    test('converts only matched PET series when onlyMatched is enabled', () {
      final rules = [
        const ModalityRule(pattern: 'PET Brain  CIT', modality: 'pet'),
        const ModalityRule(pattern: 'PET Brain FDG', modality: 'pet'),
      ];

      expect(
        shouldConvertPetSeries(
          seriesDesc: 'PET Brain  CIT',
          rules: rules,
          onlyMatched: true,
        ),
        isTrue,
      );
      expect(
        shouldConvertPetSeries(
          seriesDesc: 'PET Brain FDG',
          rules: rules,
          onlyMatched: true,
        ),
        isTrue,
      );
      expect(
        shouldConvertPetSeries(
          seriesDesc: 'ScreenCap 2025/11/20 10:41:56',
          rules: rules,
          onlyMatched: true,
        ),
        isFalse,
      );
      expect(
        shouldConvertPetSeries(
          seriesDesc: 'PET Statistics',
          rules: rules,
          onlyMatched: true,
        ),
        isFalse,
      );
    });

    test('keeps unmatched PET series only when onlyMatched is disabled', () {
      final rules = [
        const ModalityRule(pattern: 'PET Brain FDG', modality: 'pet'),
      ];

      expect(
        shouldConvertPetSeries(
          seriesDesc: 'ScreenCap 2025/11/20 10:41:56',
          rules: rules,
          onlyMatched: false,
        ),
        isTrue,
      );
    });

    test(
      'selects matched dated metadata before unmatched undated metadata',
      () {
        final rules = [
          const ModalityRule(pattern: 'PET Brain FDG', modality: 'pet'),
        ];

        final meta = selectPrimaryMetaForConversion(
          metas: [
            {
              'SeriesDescription': 'PET Statistics',
              'AcquisitionDateTime': null,
            },
            {
              'SeriesDescription': 'PET Brain FDG',
              'AcquisitionDateTime': '2025-11-18T15:07:54.000000',
            },
          ],
          rules: rules,
          onlyMatched: true,
        );

        expect(meta?['SeriesDescription'], 'PET Brain FDG');
        expect(extractSeriesDate(meta!), '20251118');
      },
    );

    test('returns null when no selected series are present', () {
      final rules = [
        const ModalityRule(pattern: 'PET Brain FDG', modality: 'pet'),
      ];

      final meta = selectPrimaryMetaForConversion(
        metas: [
          {'SeriesDescription': 'PET Statistics'},
          {'SeriesDescription': 'Patient Protocol'},
        ],
        rules: rules,
        onlyMatched: true,
      );

      expect(meta, isNull);
    });
  });
}

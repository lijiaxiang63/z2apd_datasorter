import '../services/patient_id_parser.dart';

class DicomSeriesMeta {
  final Map<String, dynamic> raw;

  DicomSeriesMeta(this.raw);

  String get seriesDescription =>
      raw['SeriesDescription'] as String? ??
      raw['StudyDescription'] as String? ??
      '';

  String get seriesDate {
    var value = (raw['SeriesDate'] as String? ?? '')
        .replaceAll('/', '')
        .replaceAll('-', '');
    if (value.isNotEmpty) return value;

    final acqDt = raw['AcquisitionDateTime'] as String? ?? '';
    if (acqDt.isEmpty) return '';
    value = acqDt.split('T')[0].replaceAll('/', '').replaceAll('-', '');
    return value.length > 8 ? value.substring(0, 8) : value;
  }

  String get dicomModality => (raw['Modality'] as String? ?? '').toUpperCase();

  bool get isPet => dicomModality == 'PT';

  String get patientName => raw['PatientName'] as String? ?? '';

  String? get patientId => raw['PatientID'] as String?;

  String get petTracer {
    var tracer =
        raw['Radiopharmaceutical'] as String? ??
        raw['TracerName'] as String? ??
        '';

    if (tracer.isEmpty) {
      final sequence = raw['RadiopharmaceuticalInformationSequence'];
      if (sequence is List && sequence.isNotEmpty && sequence.first is Map) {
        tracer =
            (sequence.first as Map)['Radiopharmaceutical'] as String? ?? '';
      }
    }

    return sanitizeBidsLabel(tracer);
  }
}

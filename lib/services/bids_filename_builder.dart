import '../services/patient_id_parser.dart';

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

String buildSeriesFilenameStem({
  required String patientId,
  required String seriesDate,
  required String acqLabel,
  required String modality,
}) {
  return 'sub-${patientId}_ses-${seriesDate}_acq-${acqLabel}_$modality';
}

String sanitizeAcqLabel(String seriesDesc) {
  return sanitizeBidsLabel(seriesDesc.replaceAll(RegExp(r'\s'), ''));
}

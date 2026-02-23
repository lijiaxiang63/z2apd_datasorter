/// Extracts patient ID from the PatientName DICOM field.
///
/// The expected format contains `:bah:` as a separator,
/// with the patient ID following it.
/// Returns null if the separator is not found.
String? extractPatientId(String patientName) {
  final lower = patientName.toLowerCase();
  final idx = lower.indexOf(':bah:');
  if (idx == -1) return null;
  return lower.substring(idx + 5); // 5 = ':bah:'.length
}

import 'package:path/path.dart' as p;

/// Extracts patient ID from the PatientName DICOM field.
///
/// The expected format contains `:bah:` as a separator,
/// with the patient ID following it.
/// Returns null if the separator is not found.
String? extractPatientId(String patientName) {
  final lower = patientName.toLowerCase();
  final idx = lower.indexOf(':bah:');
  if (idx == -1) return null;
  return patientName.substring(idx + 5); // 5 = ':bah:'.length
}

String sanitizeBidsLabel(String value, {String fallback = 'unknown'}) {
  final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  return cleaned.isEmpty ? fallback : cleaned;
}

String? extractPatientIdFromScanFolderName(String folderName) {
  final parts = folderName
      .split('_')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  // PET scan folders are expected to look like `<patient>_<accession>_...`.
  if (parts.length < 2) {
    return null;
  }

  final patientId = sanitizeBidsLabel(parts.first, fallback: '');
  return patientId.isEmpty ? null : patientId;
}

String? extractPatientIdFromScanPath(String scanPath, {String? stopAt}) {
  final normalizedStop = stopAt == null ? null : p.normalize(stopAt);
  var currentPath = p.normalize(scanPath);

  while (true) {
    final patientId = extractPatientIdFromScanFolderName(
      p.basename(currentPath),
    );
    if (patientId != null) {
      return patientId;
    }

    if (normalizedStop != null && p.equals(currentPath, normalizedStop)) {
      return null;
    }

    final parentPath = p.dirname(currentPath);
    if (p.equals(parentPath, currentPath)) {
      return null;
    }

    currentPath = parentPath;
  }
}

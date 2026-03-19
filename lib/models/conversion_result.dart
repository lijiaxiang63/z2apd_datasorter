enum ConversionStatus { ok, skip, error, archived }

class ConversionResult {
  final ConversionStatus status;
  final String folderName;
  final String message;
  final List<String> details;
  /// The output subject directory (for example `.../sub-12345`).
  final String? subjectDir;

  const ConversionResult({
    required this.status,
    required this.folderName,
    required this.message,
    this.details = const [],
    this.subjectDir,
  });

  @override
  String toString() {
    final prefix = switch (status) {
      ConversionStatus.ok => 'OK',
      ConversionStatus.skip => 'SKIP',
      ConversionStatus.error => 'ERROR',
      ConversionStatus.archived => 'ARCHIVED',
    };
    final buf = StringBuffer('$prefix  $folderName: $message');
    for (final d in details) {
      buf.writeln();
      buf.write('  $d');
    }
    return buf.toString();
  }
}

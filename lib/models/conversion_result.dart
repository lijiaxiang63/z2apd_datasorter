enum ConversionStatus { ok, skip, error, archived }

class ConversionResult {
  final ConversionStatus status;
  final String folderName;
  final String message;
  final List<String> details;

  const ConversionResult({
    required this.status,
    required this.folderName,
    required this.message,
    this.details = const [],
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

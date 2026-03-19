class ConversionTarget {
  final String inputDir;
  final String archiveDir;

  const ConversionTarget({required this.inputDir, required this.archiveDir});
}

class ConversionPlan {
  final String outputRoot;
  final List<ConversionTarget> targets;

  const ConversionPlan({required this.outputRoot, required this.targets});
}

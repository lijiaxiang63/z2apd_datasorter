import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/conversion_target.dart';
import 'dcm2niix_service.dart';

class InputLayoutResolver {
  final Dcm2niixService dcm2niix;

  InputLayoutResolver(this.dcm2niix);

  Future<ConversionPlan> resolve(String selectedPath) async {
    final normalizedPath = p.normalize(selectedPath);
    final selectedDir = Directory(normalizedPath);
    final dicomFolders = await dcm2niix.collectDicomFolders(normalizedPath);

    if (dicomFolders.isEmpty) {
      return const ConversionPlan(outputRoot: '', targets: []);
    }

    if (dicomFolders.length == 1 && dicomFolders.single == normalizedPath) {
      return ConversionPlan(
        outputRoot: selectedDir.parent.path,
        targets: [
          ConversionTarget(
            inputDir: normalizedPath,
            archiveDir: normalizedPath,
          ),
        ],
      );
    }

    final hasNestedTargets = dicomFolders.any(
      (folder) => p.dirname(folder) != normalizedPath,
    );
    if (hasNestedTargets) {
      return ConversionPlan(
        outputRoot: normalizedPath,
        targets: [
          for (final folder in dicomFolders)
            ConversionTarget(inputDir: folder, archiveDir: p.dirname(folder)),
        ],
      );
    }

    return ConversionPlan(
      outputRoot: selectedDir.parent.path,
      targets: [
        for (final folder in dicomFolders)
          ConversionTarget(inputDir: folder, archiveDir: normalizedPath),
      ],
    );
  }
}

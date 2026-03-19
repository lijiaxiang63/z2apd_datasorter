import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:z2apd_datasorter/services/dcm2niix_service.dart';

class LayoutAwareFakeDcm2niixService extends Dcm2niixService {
  final Set<String> dicomFolders;

  LayoutAwareFakeDcm2niixService({required this.dicomFolders}) : super('fake');

  @override
  Future<bool> isDicomFolder(String folderPath) async {
    return dicomFolders.contains(p.normalize(folderPath));
  }
}

void main() {
  group('Dcm2niixService.collectDicomFolders', () {
    test('prefers nested series folders over scan container folders', () async {
      final tempRoot = await Directory.systemTemp.createTemp('dcm_layout_');
      addTearDown(() => tempRoot.delete(recursive: true));

      final scan1 = await Directory(
        p.join(tempRoot.path, 'PATIENT1_ACCESSION_NAME_SCAN1'),
      ).create();
      final scan2 = await Directory(
        p.join(tempRoot.path, 'PATIENT2_ACCESSION_NAME_SCAN2'),
      ).create();
      final series1 = await Directory(p.join(scan1.path, 'series1')).create();
      final series2 = await Directory(p.join(scan1.path, 'series2')).create();
      final series3 = await Directory(p.join(scan2.path, 'series1')).create();

      final service = LayoutAwareFakeDcm2niixService(
        dicomFolders: {
          p.normalize(scan1.path),
          p.normalize(scan2.path),
          p.normalize(series1.path),
          p.normalize(series2.path),
          p.normalize(series3.path),
        },
      );

      final folders = await service.collectDicomFolders(tempRoot.path);

      expect(folders, [
        p.normalize(series1.path),
        p.normalize(series2.path),
        p.normalize(series3.path),
      ]);
    });
  });
}

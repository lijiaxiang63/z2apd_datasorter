import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:z2apd_datasorter/services/dcm2niix_service.dart';
import 'package:z2apd_datasorter/services/input_layout_resolver.dart';

class FakeDcm2niixService extends Dcm2niixService {
  final Map<String, List<String>> folderMap;

  FakeDcm2niixService({required this.folderMap}) : super('fake');

  @override
  Future<List<String>> collectDicomFolders(String rootPath) async {
    return folderMap[p.normalize(rootPath)] ?? const [];
  }
}

void main() {
  group('InputLayoutResolver', () {
    test(
      'places outputs beside scan folders when root contains scan folders',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp('layout_root_');
        addTearDown(() => tempRoot.delete(recursive: true));

        final scan1 = await Directory(
          p.join(tempRoot.path, 'PATIENT1_SCAN1'),
        ).create();
        final scan2 = await Directory(
          p.join(tempRoot.path, 'PATIENT2_SCAN2'),
        ).create();
        final series1 = await Directory(p.join(scan1.path, 'series1')).create();
        final series2 = await Directory(p.join(scan1.path, 'series2')).create();
        final series3 = await Directory(p.join(scan2.path, 'series1')).create();

        final resolver = InputLayoutResolver(
          FakeDcm2niixService(
            folderMap: {
              p.normalize(tempRoot.path): [
                p.normalize(series1.path),
                p.normalize(series2.path),
                p.normalize(series3.path),
              ],
            },
          ),
        );

        final plan = await resolver.resolve(tempRoot.path);

        expect(plan.outputRoot, p.normalize(tempRoot.path));
        expect(plan.targets.map((target) => target.inputDir), [
          p.normalize(series1.path),
          p.normalize(series2.path),
          p.normalize(series3.path),
        ]);
        expect(plan.targets.map((target) => target.archiveDir), [
          p.normalize(scan1.path),
          p.normalize(scan1.path),
          p.normalize(scan2.path),
        ]);
      },
    );

    test(
      'places outputs beside a single scan folder and archives the scan folder once',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp(
          'layout_single_',
        );
        addTearDown(() => tempRoot.delete(recursive: true));

        final scan = await Directory(
          p.join(tempRoot.path, 'PATIENT1_SCAN'),
        ).create();
        final series1 = await Directory(p.join(scan.path, 'series1')).create();
        final series2 = await Directory(p.join(scan.path, 'series2')).create();

        final resolver = InputLayoutResolver(
          FakeDcm2niixService(
            folderMap: {
              p.normalize(scan.path): [
                p.normalize(series1.path),
                p.normalize(series2.path),
              ],
            },
          ),
        );

        final plan = await resolver.resolve(scan.path);

        expect(plan.outputRoot, p.normalize(tempRoot.path));
        expect(plan.targets.map((target) => target.inputDir), [
          p.normalize(series1.path),
          p.normalize(series2.path),
        ]);
        expect(plan.targets.map((target) => target.archiveDir), [
          p.normalize(scan.path),
          p.normalize(scan.path),
        ]);
      },
    );

    test(
      'keeps direct dicom folders as a single-target scan when no child inputs exist',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp('layout_leaf_');
        addTearDown(() => tempRoot.delete(recursive: true));

        final leaf = await Directory(
          p.join(tempRoot.path, 'series_leaf'),
        ).create();

        final resolver = InputLayoutResolver(
          FakeDcm2niixService(
            folderMap: {
              p.normalize(leaf.path): [p.normalize(leaf.path)],
            },
          ),
        );

        final plan = await resolver.resolve(leaf.path);

        expect(plan.outputRoot, p.normalize(tempRoot.path));
        expect(plan.targets.map((target) => target.inputDir), [
          p.normalize(leaf.path),
        ]);
        expect(plan.targets.map((target) => target.archiveDir), [
          p.normalize(leaf.path),
        ]);
      },
    );
  });
}

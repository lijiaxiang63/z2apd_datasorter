import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:z2apd_datasorter/services/dcm2niix_service.dart';

void main() {
  group('Dcm2niixService.isDicomFolder', () {
    test('detects dicom files one level below a scan container', () async {
      final tempRoot = await Directory.systemTemp.createTemp('probe_test_');
      addTearDown(() => tempRoot.delete(recursive: true));

      final fakeBinary = File(p.join(tempRoot.path, 'fake_dcm2niix.sh'));
      await fakeBinary.writeAsString(_fakeDcm2niixScript);
      await Process.run('chmod', ['+x', fakeBinary.path]);

      final scanContainer = await Directory(
        p.join(tempRoot.path, 'scan_container'),
      ).create();
      final seriesFolder = await Directory(
        p.join(scanContainer.path, 'series1'),
      ).create();
      await File(
        p.join(seriesFolder.path, 'image1.dcm'),
      ).writeAsString('dicom');

      final service = Dcm2niixService(fakeBinary.path);

      expect(await service.isDicomFolder(scanContainer.path), isTrue);
      expect(await service.isDicomFolder(seriesFolder.path), isTrue);
      expect(await service.isDicomFolder(tempRoot.path), isFalse);
    });
  });
}

const String _fakeDcm2niixScript = r'''#!/bin/sh
mode=""
depth=0
last=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    -q)
      mode="$2"
      shift 2
      ;;
    -d)
      depth="$2"
      shift 2
      ;;
    *)
      last="$1"
      shift
      ;;
  esac
done

if [ "$mode" != "y" ]; then
  echo "unsupported"
  exit 1
fi

count=$(/usr/bin/python3 - "$last" "$depth" <<'PY'
import os
import sys

root = sys.argv[1]
max_depth = int(sys.argv[2])
count = 0

for dirpath, dirnames, filenames in os.walk(root):
    if dirpath == root:
        depth = 0
    else:
        depth = os.path.relpath(dirpath, root).count(os.sep) + 1
    if depth > max_depth:
        dirnames[:] = []
        continue
    for filename in filenames:
        if filename.endswith('.dcm'):
            count += 1

print(count)
PY
)
if [ "$count" -gt 0 ]; then
  echo "Found $count DICOM file(s)"
  exit 0
fi

echo "Error: Unable to find any DICOM images in $last (or subfolders $depth deep)" >&2
exit 2
''';

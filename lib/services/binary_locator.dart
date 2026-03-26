import 'dart:io';
import 'package:path/path.dart' as p;

class BinaryLocator {
  static String? _projectRoot;

  static String get dcm2niixPath =>
      _resolveBinary(macName: 'dcm2niix', windowsName: 'dcm2niix.exe');

  static String get sevenZipPath =>
      _resolveBinary(macName: '7zz', windowsName: '7za.exe');

  static bool get dcm2niixExists => File(dcm2niixPath).existsSync();
  static bool get sevenZipExists => File(sevenZipPath).existsSync();

  static String _resolveBinary({
    required String macName,
    required String windowsName,
  }) {
    final name = Platform.isMacOS ? macName : windowsName;

    if (_isDebugMode) {
      final root = _getProjectRoot();
      if (root != null) {
        final path = p.join(root, 'dependency', name);
        if (File(path).existsSync()) return path;
      }
    }

    if (Platform.isMacOS) {
      final execDir = p.dirname(Platform.resolvedExecutable);
      final resourcesDir = p.join(p.dirname(execDir), 'Resources');
      return p.join(resourcesDir, macName);
    } else if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      return p.join(exeDir, windowsName);
    }
    throw UnsupportedError('Unsupported platform');
  }

  static bool get _isDebugMode {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }

  static String? _getProjectRoot() {
    if (_projectRoot != null) return _projectRoot;

    for (final start in [
      Directory.current,
      Directory(p.dirname(Platform.script.toFilePath())),
    ]) {
      var dir = start;
      for (var i = 0; i < 10; i++) {
        if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
          _projectRoot = dir.path;
          return _projectRoot;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }

    return null;
  }
}

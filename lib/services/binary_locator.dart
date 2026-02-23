import 'dart:io';
import 'package:path/path.dart' as p;

class BinaryLocator {
  static String? _projectRoot;

  /// In debug mode, resolve binaries from the project's dependency/ folder.
  /// In release mode, resolve from the app bundle.
  static String get dcm2niixPath {
    if (_isDebugMode) {
      final root = _getProjectRoot();
      if (root != null) {
        final path = p.join(
          root,
          'dependency',
          Platform.isMacOS ? 'dcm2niix' : 'dcm2niix.exe',
        );
        if (File(path).existsSync()) return path;
      }
    }

    if (Platform.isMacOS) {
      // Inside .app bundle: MyApp.app/Contents/MacOS/MyApp
      // Resources is at: MyApp.app/Contents/Resources/
      final execDir = p.dirname(Platform.resolvedExecutable);
      final resourcesDir = p.join(p.dirname(execDir), 'Resources');
      return p.join(resourcesDir, 'dcm2niix');
    } else if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      return p.join(exeDir, 'dcm2niix.exe');
    }
    throw UnsupportedError('Unsupported platform');
  }

  static String get sevenZipPath {
    if (_isDebugMode) {
      final root = _getProjectRoot();
      if (root != null) {
        final path = p.join(
          root,
          'dependency',
          Platform.isMacOS ? '7zz' : '7za.exe',
        );
        if (File(path).existsSync()) return path;
      }
    }

    if (Platform.isMacOS) {
      final execDir = p.dirname(Platform.resolvedExecutable);
      final resourcesDir = p.join(p.dirname(execDir), 'Resources');
      return p.join(resourcesDir, '7zz');
    } else if (Platform.isWindows) {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      return p.join(exeDir, '7za.exe');
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

    // Walk up from the current executable to find the project root
    // In debug mode on macOS, the executable is deep in the build cache.
    // Try to find the project by looking for pubspec.yaml.
    var dir = Directory.current;
    for (var i = 0; i < 10; i++) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        _projectRoot = dir.path;
        return _projectRoot;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    // Fallback: try from script directory
    final scriptDir = Platform.script.toFilePath();
    dir = Directory(p.dirname(scriptDir));
    for (var i = 0; i < 10; i++) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        _projectRoot = dir.path;
        return _projectRoot;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }

    return null;
  }

  static bool get dcm2niixExists => File(dcm2niixPath).existsSync();
  static bool get sevenZipExists => File(sevenZipPath).existsSync();
}

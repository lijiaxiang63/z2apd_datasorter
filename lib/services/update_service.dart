import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

import '../app_info.dart';

class ReleaseInfo {
  final String tagName;
  final Version version;
  final String htmlUrl;
  final String assetUrl;
  final String assetName;
  final int assetSize;

  ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.htmlUrl,
    required this.assetUrl,
    required this.assetName,
    required this.assetSize,
  });
}

class UpdateService {
  final http.Client _client;
  final bool _skipDebugCheck;

  static final _apiBase =
      'https://api.github.com/repos/$repoOwner/$repoName';

  UpdateService({http.Client? client, bool skipDebugCheck = false})
      : _client = client ?? http.Client(),
        _skipDebugCheck = skipDebugCheck;

  static bool get _isDebugMode {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }

  /// Check GitHub for a newer release. Returns null if up-to-date or on error.
  Future<ReleaseInfo?> checkForUpdate() async {
    if (!_skipDebugCheck && _isDebugMode) return null;
    try {
      final uri = Uri.parse('$_apiBase/releases/latest');
      final response = await _client.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
      });

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String;
      final versionStr =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;

      final remoteVersion = Version.parse(versionStr);
      final localVersion = Version.parse(appVersion);

      if (remoteVersion <= localVersion) return null;

      final assets = json['assets'] as List;
      final platformKey = Platform.isMacOS ? 'macos' : 'windows';
      final asset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String).contains(platformKey),
            orElse: () => <String, dynamic>{},
          );

      if (asset.isEmpty) return null;

      return ReleaseInfo(
        tagName: tagName,
        version: remoteVersion,
        htmlUrl: json['html_url'] as String,
        assetUrl: asset['browser_download_url'] as String,
        assetName: asset['name'] as String,
        assetSize: asset['size'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  /// Download the release ZIP. Returns path to the downloaded file.
  Future<String> downloadRelease(
    ReleaseInfo release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final updateDir = Directory(p.join(tempDir.path, 'z2apd_update'));
    if (await updateDir.exists()) {
      await updateDir.delete(recursive: true);
    }
    await updateDir.create(recursive: true);

    final zipPath = p.join(updateDir.path, release.assetName);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(release.assetUrl));
      final response = await client.send(request);

      final totalBytes = response.contentLength ?? release.assetSize;
      var receivedBytes = 0;
      final sink = File(zipPath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress?.call(receivedBytes, totalBytes);
      }
      await sink.close();
    } finally {
      client.close();
    }

    return zipPath;
  }

  /// Extract ZIP and apply the update. This will exit the current process.
  Future<void> applyUpdate(String zipPath) async {
    final tempDir = await getTemporaryDirectory();
    final extractDir = p.join(tempDir.path, 'z2apd_update', 'extracted');
    await Directory(extractDir).create(recursive: true);

    // Extract ZIP
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = p.join(extractDir, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    if (Platform.isMacOS) {
      await _applyMacOS(extractDir, tempDir.path);
    } else if (Platform.isWindows) {
      await _applyWindows(extractDir, tempDir.path);
    }
  }

  Future<void> _applyMacOS(String extractDir, String tempBase) async {
    // Platform.resolvedExecutable -> MyApp.app/Contents/MacOS/MyApp
    final exe = Platform.resolvedExecutable;
    final macosDir = p.dirname(exe);
    final contentsDir = p.dirname(macosDir);
    final appBundle = p.dirname(contentsDir);
    final installDir = p.dirname(appBundle);
    final appBundleName = p.basename(appBundle);

    // Find extracted .app bundle
    final extractedEntries = Directory(extractDir).listSync();
    String? newAppPath;
    for (final entry in extractedEntries) {
      if (entry is Directory && entry.path.endsWith('.app')) {
        newAppPath = entry.path;
        break;
      }
    }
    newAppPath ??= p.join(extractDir, appBundleName);

    final scriptPath = p.join(tempBase, 'z2apd_update', 'update.sh');
    final script = '''#!/bin/bash
sleep 1
rm -rf "$installDir/$appBundleName"
mv "$newAppPath" "$installDir/"
chmod -R +x "$installDir/$appBundleName/Contents/MacOS/"
if [ -f "$installDir/$appBundleName/Contents/Resources/dcm2niix" ]; then
  chmod +x "$installDir/$appBundleName/Contents/Resources/dcm2niix"
fi
if [ -f "$installDir/$appBundleName/Contents/Resources/7zz" ]; then
  chmod +x "$installDir/$appBundleName/Contents/Resources/7zz"
fi
open "$installDir/$appBundleName"
rm -rf "$tempBase/z2apd_update"
''';

    await File(scriptPath).writeAsString(script);
    await Process.run('chmod', ['+x', scriptPath]);
    await Process.start(
      '/bin/bash',
      [scriptPath],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  Future<void> _applyWindows(String extractDir, String tempBase) async {
    final installDir = p.dirname(Platform.resolvedExecutable);
    final updateTempDir = p.join(tempBase, 'z2apd_update');

    final scriptPath = p.join(updateTempDir, 'update.bat');
    // Use forward-slash-safe paths by normalizing with windows separators
    final script = '''@echo off
timeout /t 2 /nobreak >nul
:retry
xcopy /E /Y /Q "$extractDir\\*" "$installDir\\" >nul 2>&1
if errorlevel 1 (
    timeout /t 1 /nobreak >nul
    goto retry
)
start "" "${Platform.resolvedExecutable}"
timeout /t 2 /nobreak >nul
rmdir /S /Q "$updateTempDir"
''';

    await File(scriptPath).writeAsString(script);
    await Process.start(
      'cmd.exe',
      ['/c', scriptPath],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}

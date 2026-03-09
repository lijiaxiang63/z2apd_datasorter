import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:z2apd_datasorter/providers/update_provider.dart';
import 'package:z2apd_datasorter/services/update_service.dart';

String _fakeReleaseJson({
  String tagName = 'v2.0.0',
  String assetName = 'z2apd_datasorter-macos.zip',
  int assetSize = 1024,
}) {
  return jsonEncode({
    'tag_name': tagName,
    'html_url': 'https://github.com/lijiaxiang63/z2apd_datasorter/releases/$tagName',
    'assets': [
      {
        'name': assetName,
        'browser_download_url':
            'https://github.com/lijiaxiang63/z2apd_datasorter/releases/download/$tagName/$assetName',
        'size': assetSize,
      },
    ],
  });
}

MockClient _mockClient(int statusCode, String body) {
  return MockClient((request) async {
    return http.Response(body, statusCode);
  });
}

void main() {
  group('UpdateService.checkForUpdate', () {
    test('returns ReleaseInfo when a newer version is available', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v9.9.9'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.tagName, 'v9.9.9');
      expect(result.version, Version.parse('9.9.9'));
      expect(result.assetName, 'z2apd_datasorter-macos.zip');
      expect(result.assetSize, 1024);
    });

    test('returns null when remote version equals local version', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v1.1.1'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNull);
    });

    test('returns null when remote version is older', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v0.1.0'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNull);
    });

    test('returns null on non-200 status code', () async {
      final client = _mockClient(404, 'Not found');
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNull);
    });

    test('returns null on malformed JSON', () async {
      final client = _mockClient(200, 'not json');
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNull);
    });

    test('returns null when no matching platform asset', () async {
      final client = _mockClient(
        200,
        _fakeReleaseJson(
          tagName: 'v9.9.9',
          assetName: 'z2apd_datasorter-linux.zip',
        ),
      );
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      // On macOS test runner, expects "macos" in asset name — "linux" won't match
      expect(result, isNull);
    });

    test('handles tag without v prefix', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: '9.0.0'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNotNull);
      expect(result!.version, Version.parse('9.0.0'));
    });

    test('returns null in debug mode when skipDebugCheck is false', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v9.9.9'));
      final service =
          UpdateService(client: client, skipDebugCheck: false);

      final result = await service.checkForUpdate();

      // Tests run in debug mode, so this should return null
      expect(result, isNull);
    });

    test('returns null on network error', () async {
      final client = MockClient((request) async {
        throw Exception('No network');
      });
      final service =
          UpdateService(client: client, skipDebugCheck: true);

      final result = await service.checkForUpdate();

      expect(result, isNull);
    });
  });

  group('UpdateProvider', () {
    test('starts with idle status', () {
      final provider = UpdateProvider();

      expect(provider.status, UpdateStatus.idle);
      expect(provider.releaseInfo, isNull);
    });

    test('transitions to available when update found', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v9.9.9'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);
      final provider = UpdateProvider(service: service);

      final states = <UpdateStatus>[];
      provider.addListener(() => states.add(provider.status));

      await provider.checkForUpdate();

      expect(states, [UpdateStatus.checking, UpdateStatus.available]);
      expect(provider.releaseInfo, isNotNull);
      expect(provider.releaseInfo!.tagName, 'v9.9.9');
    });

    test('transitions to idle when no update found', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v1.1.1'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);
      final provider = UpdateProvider(service: service);

      final states = <UpdateStatus>[];
      provider.addListener(() => states.add(provider.status));

      await provider.checkForUpdate();

      expect(states, [UpdateStatus.checking, UpdateStatus.idle]);
      expect(provider.releaseInfo, isNull);
    });

    test('transitions to idle on error', () async {
      final client = MockClient((request) async {
        throw Exception('No network');
      });
      final service =
          UpdateService(client: client, skipDebugCheck: true);
      final provider = UpdateProvider(service: service);

      final states = <UpdateStatus>[];
      provider.addListener(() => states.add(provider.status));

      await provider.checkForUpdate();

      expect(states, [UpdateStatus.checking, UpdateStatus.idle]);
    });

    test('dismiss resets state', () async {
      final client = _mockClient(200, _fakeReleaseJson(tagName: 'v9.9.9'));
      final service =
          UpdateService(client: client, skipDebugCheck: true);
      final provider = UpdateProvider(service: service);

      await provider.checkForUpdate();
      expect(provider.status, UpdateStatus.available);

      provider.dismiss();

      expect(provider.status, UpdateStatus.idle);
      expect(provider.releaseInfo, isNull);
    });
  });
}

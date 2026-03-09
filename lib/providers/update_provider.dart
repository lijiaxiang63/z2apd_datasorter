import 'package:flutter/foundation.dart';

import '../services/update_service.dart';

enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  installing,
  error,
}

class UpdateProvider extends ChangeNotifier {
  final UpdateService _service;

  UpdateProvider({UpdateService? service})
      : _service = service ?? UpdateService();

  UpdateStatus _status = UpdateStatus.idle;
  ReleaseInfo? _releaseInfo;
  double _downloadProgress = 0;
  String? _errorMessage;
  String? _downloadedZipPath;

  UpdateStatus get status => _status;
  ReleaseInfo? get releaseInfo => _releaseInfo;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;

  Future<void> checkForUpdate() async {
    _status = UpdateStatus.checking;
    notifyListeners();
    try {
      _releaseInfo = await _service.checkForUpdate();
      _status =
          _releaseInfo != null ? UpdateStatus.available : UpdateStatus.idle;
    } catch (_) {
      _status = UpdateStatus.idle;
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    if (_releaseInfo == null) return;
    _status = UpdateStatus.downloading;
    _downloadProgress = 0;
    notifyListeners();
    try {
      _downloadedZipPath = await _service.downloadRelease(
        _releaseInfo!,
        onProgress: (received, total) {
          _downloadProgress = total > 0 ? received / total : 0;
          notifyListeners();
        },
      );
      _status = UpdateStatus.readyToInstall;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = 'Download failed: $e';
    }
    notifyListeners();
  }

  Future<void> installUpdate() async {
    if (_downloadedZipPath == null) return;
    _status = UpdateStatus.installing;
    notifyListeners();
    await _service.applyUpdate(_downloadedZipPath!);
  }

  void dismiss() {
    _status = UpdateStatus.idle;
    _releaseInfo = null;
    notifyListeners();
  }
}

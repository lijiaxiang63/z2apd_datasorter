import 'package:flutter/foundation.dart';
import '../models/modality_rule.dart';
import '../models/conversion_result.dart';
import '../services/binary_locator.dart';
import '../services/dcm2niix_service.dart';
import '../services/archive_service.dart';
import '../services/bids_organizer.dart';

class ConversionProvider extends ChangeNotifier {
  final List<String> _logLines = [];
  String _selectedPath = '';
  double _progress = 0;
  int _total = 0;
  String _currentFolder = '';
  bool _isRunning = false;
  bool _archiveEnabled = true;

  List<String> get logLines => List.unmodifiable(_logLines);
  String get selectedPath => _selectedPath;
  double get progress => _progress;
  int get total => _total;
  String get currentFolder => _currentFolder;
  bool get isRunning => _isRunning;
  bool get archiveEnabled => _archiveEnabled;

  void setPath(String path) {
    _selectedPath = path;
    notifyListeners();
  }

  void setArchiveEnabled(bool value) {
    _archiveEnabled = value;
    notifyListeners();
  }

  void addLog(String line) {
    _logLines.add(line);
    notifyListeners();
  }

  void clearLog() {
    _logLines.clear();
    _progress = 0;
    _total = 0;
    _currentFolder = '';
    notifyListeners();
  }

  Future<void> startConversion({
    required List<ModalityRule> rules,
    required bool onlyMatched,
  }) async {
    if (_isRunning) return;
    if (_selectedPath.isEmpty) return;

    _isRunning = true;
    notifyListeners();

    try {
      final dcm2niixPath = BinaryLocator.dcm2niixPath;
      if (!BinaryLocator.dcm2niixExists) {
        addLog('ERROR: dcm2niix not found at $dcm2niixPath');
        return;
      }

      final dcm2niixService = Dcm2niixService(dcm2niixPath);
      final bidsOrganizer = BidsOrganizer(dcm2niixService);

      ArchiveService? archiveService;
      if (_archiveEnabled) {
        final sevenZipPath = BinaryLocator.sevenZipPath;
        if (!BinaryLocator.sevenZipExists) {
          addLog('ERROR: 7z not found at $sevenZipPath');
          return;
        }
        archiveService = ArchiveService(sevenZipPath);
      }

      addLog('Scanning $_selectedPath ...');
      if (rules.isNotEmpty) {
        addLog(
          'Using ${rules.length} mapping rule(s)'
          "${onlyMatched ? ' (only matched)' : ' (unmatched -> T1w)'}.",
        );
      }

      final folders = await dcm2niixService.collectDicomFolders(_selectedPath);
      _total = folders.length;

      if (_total == 0) {
        addLog('No DICOM folders found.');
        return;
      }

      addLog('Found $_total DICOM folder(s).\n');
      _progress = 0;
      notifyListeners();

      for (var i = 0; i < folders.length; i++) {
        final folder = folders[i];
        final folderName = folder.split('/').last;
        _currentFolder = 'Processing ${i + 1}/$_total: $folderName';
        notifyListeners();

        final result = await bidsOrganizer.convertOne(
          inputDir: folder,
          rules: rules,
          onlyMatched: onlyMatched,
        );
        addLog(result.toString());

        if (_archiveEnabled &&
            archiveService != null &&
            result.status == ConversionStatus.ok) {
          final arcMsg = await archiveService.archiveFolder(folder);
          addLog(arcMsg);
        }

        _progress = (i + 1) / _total;
        notifyListeners();
      }

      addLog('\n--- All done. ---');
      _currentFolder = 'Complete';
      notifyListeners();
    } catch (e) {
      addLog('ERROR: $e');
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }
}

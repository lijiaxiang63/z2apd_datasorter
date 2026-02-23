import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/modality_constants.dart';
import '../models/modality_rule.dart';
import '../providers/rules_provider.dart';
import '../providers/conversion_provider.dart';
import '../services/binary_locator.dart';
import '../services/dcm2niix_service.dart';
import '../services/modality_guesser.dart';

Future<void> showScanSeriesDialog(BuildContext context) {
  final path = context.read<ConversionProvider>().selectedPath;
  if (path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a valid directory first.')),
    );
    return Future.value();
  }

  return showDialog(
    context: context,
    builder: (_) => _ScanSeriesDialog(folderPath: path),
  );
}

class _SeriesEntry {
  final String description;
  final int count;
  String modality;
  bool selected = true;

  _SeriesEntry({
    required this.description,
    required this.count,
    required this.modality,
  });
}

class _ScanSeriesDialog extends StatefulWidget {
  final String folderPath;

  const _ScanSeriesDialog({required this.folderPath});

  @override
  State<_ScanSeriesDialog> createState() => _ScanSeriesDialogState();
}

class _ScanSeriesDialogState extends State<_ScanSeriesDialog> {
  List<_SeriesEntry>? _entries;
  String _statusText = 'Scanning DICOM headers...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    try {
      final dcm2niixPath = BinaryLocator.dcm2niixPath;
      final service = Dcm2niixService(dcm2niixPath);
      final series = await service.scanAllSeries(widget.folderPath);

      if (!mounted) return;

      final existingPatterns =
          context.read<RulesProvider>().rules.map((r) => r.pattern).toSet();

      setState(() {
        _isLoading = false;
        if (series.isEmpty) {
          _statusText = 'No series found.';
          _entries = [];
        } else {
          _statusText =
              'Found ${series.length} unique series. '
              'Toggle checkboxes and change modalities as needed.';
          _entries = series.entries.map((e) {
            final entry = _SeriesEntry(
              description: e.key,
              count: e.value,
              modality: guessModality(e.key),
            );
            // Auto-deselect if a rule for this description already exists
            if (existingPatterns.contains(e.key)) {
              entry.selected = false;
            }
            return entry;
          }).toList()
            ..sort((a, b) => a.description.compareTo(b.description));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusText = 'Error scanning: $e';
        _entries = [];
      });
    }
  }

  void _addSelected() {
    if (_entries == null) return;

    final selected = _entries!.where((e) => e.selected).toList();
    if (selected.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final newRules = selected
        .map((e) => ModalityRule(pattern: e.description, modality: e.modality))
        .toList();

    context.read<RulesProvider>().addRules(newRules);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Discovered Series'),
      content: SizedBox(
        width: 580,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _statusText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_entries != null && _entries!.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 36,
                    columnSpacing: 16,
                    columns: const [
                      DataColumn(label: SizedBox(width: 30)),
                      DataColumn(label: Text('Series Description')),
                      DataColumn(label: Text('Files'), numeric: true),
                      DataColumn(label: Text('Modality')),
                    ],
                    rows: _entries!.map((entry) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: entry.selected,
                              onChanged: (v) {
                                setState(
                                    () => entry.selected = v ?? true);
                              },
                            ),
                          ),
                          DataCell(Text(
                            entry.description,
                            overflow: TextOverflow.ellipsis,
                          )),
                          DataCell(Text('${entry.count}')),
                          DataCell(
                            DropdownButton<String>(
                              value: entry.modality,
                              isDense: true,
                              underline: const SizedBox(),
                              items: modalityChoices
                                  .map((m) => DropdownMenuItem(
                                      value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => entry.modality = v);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(child: Text('No series found.')),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _isLoading || (_entries?.isEmpty ?? true) ? null : _addSelected,
          child: const Text('Add Selected as Rules'),
        ),
      ],
    );
  }
}

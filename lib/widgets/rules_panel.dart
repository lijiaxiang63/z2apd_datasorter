import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rules_provider.dart';
import 'add_rule_dialog.dart';
import 'scan_series_dialog.dart';

class RulesPanel extends StatefulWidget {
  const RulesPanel({super.key});

  @override
  State<RulesPanel> createState() => _RulesPanelState();
}

class _RulesPanelState extends State<RulesPanel> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final rulesProvider = context.watch<RulesProvider>();
    final rules = rulesProvider.rules;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Series -> Modality Rules',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            // Rules table
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(4),
              ),
              child: rules.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No rules defined. Add rules or scan folders.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: rules.length + 1, // +1 for header
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Header row
                          return Container(
                            color: colorScheme.surfaceContainerHigh,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text('Pattern',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text('Modality',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }
                        final ruleIndex = index - 1;
                        final rule = rules[ruleIndex];
                        final isSelected = _selectedIndex == ruleIndex;
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedIndex = ruleIndex),
                          child: Container(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : null,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 3, child: Text(rule.pattern)),
                                Expanded(
                                    flex: 1, child: Text(rule.modality)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            // Buttons row
            Row(
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Rule'),
                  onPressed: () => showAddRuleDialog(context),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Remove'),
                  onPressed: _selectedIndex != null &&
                          _selectedIndex! < rules.length
                      ? () {
                          rulesProvider.removeRuleAt(_selectedIndex!);
                          setState(() => _selectedIndex = null);
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Scan Folders'),
                  onPressed: () => showScanSeriesDialog(context),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: rulesProvider.onlyMatched,
                      onChanged: (v) =>
                          rulesProvider.setOnlyMatched(v ?? true),
                    ),
                    const Text('Only convert matched series'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

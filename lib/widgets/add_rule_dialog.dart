import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/modality_constants.dart';
import '../models/modality_rule.dart';
import '../providers/rules_provider.dart';

Future<void> showAddRuleDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const _AddRuleDialog(),
  );
}

class _AddRuleDialog extends StatefulWidget {
  const _AddRuleDialog();

  @override
  State<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<_AddRuleDialog> {
  final _patternController = TextEditingController();
  String _modality = modalityChoices.first;

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  void _submit() {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a pattern.')),
      );
      return;
    }

    final rulesProvider = context.read<RulesProvider>();
    if (rulesProvider.hasPattern(pattern)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pattern '$pattern' already exists.")),
      );
      return;
    }

    rulesProvider.addRule(ModalityRule(pattern: pattern, modality: _modality));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Rule'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _patternController,
              decoration: const InputDecoration(
                labelText: 'Pattern',
                hintText: 'e.g.  *dark-fluid*',
                helperText: 'Use * as wildcard',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _modality,
              decoration: const InputDecoration(
                labelText: 'Modality',
                border: OutlineInputBorder(),
              ),
              items: modalityChoices
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _modality = v);
              },
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
          onPressed: _submit,
          child: const Text('OK'),
        ),
      ],
    );
  }
}

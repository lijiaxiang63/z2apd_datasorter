import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversion_provider.dart';
import '../providers/rules_provider.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final conversion = context.watch<ConversionProvider>();
    final rules = context.read<RulesProvider>();

    return Row(
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Convert'),
          onPressed: conversion.isRunning || conversion.selectedPath.isEmpty
              ? null
              : () => conversion.startConversion(
                    rules: rules.rules,
                    onlyMatched: rules.onlyMatched,
                  ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear Log'),
          onPressed: () => conversion.clearLog(),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: conversion.archiveEnabled,
              onChanged: (v) => conversion.setArchiveEnabled(v ?? true),
            ),
            const Text('Archive'),
          ],
        ),
      ],
    );
  }
}

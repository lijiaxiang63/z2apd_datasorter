import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversion_provider.dart';

class ProgressSection extends StatelessWidget {
  const ProgressSection({super.key});

  @override
  Widget build(BuildContext context) {
    final conversion = context.watch<ConversionProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: conversion.total > 0 ? conversion.progress : 0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        if (conversion.currentFolder.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            conversion.currentFolder,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

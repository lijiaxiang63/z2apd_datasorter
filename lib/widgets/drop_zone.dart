import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import '../providers/conversion_provider.dart';

class DropZone extends StatefulWidget {
  const DropZone({super.key});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        if (details.files.isNotEmpty) {
          final path = details.files.first.path;
          if (Directory(path).existsSync()) {
            context.read<ConversionProvider>().setPath(path);
          }
        }
      },
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isDragging
                ? colorScheme.primary
                : colorScheme.outline,
            width: _isDragging ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _isDragging
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLow,
        ),
        child: Center(
          child: Text(
            'Drop DICOM folder here',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

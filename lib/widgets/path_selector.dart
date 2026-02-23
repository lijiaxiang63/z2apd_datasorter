import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/conversion_provider.dart';

class PathSelector extends StatelessWidget {
  const PathSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConversionProvider>();

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: TextEditingController(text: provider.selectedPath)
              ..selection = TextSelection.collapsed(
                  offset: provider.selectedPath.length),
            decoration: const InputDecoration(
              hintText: 'DICOM folder path...',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onSubmitted: (value) => provider.setPath(value.trim()),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonal(
          onPressed: () async {
            final result = await FilePicker.platform.getDirectoryPath(
              dialogTitle: 'Select DICOM folder',
            );
            if (result != null) {
              provider.setPath(result);
            }
          },
          child: const Text('Browse...'),
        ),
      ],
    );
  }
}

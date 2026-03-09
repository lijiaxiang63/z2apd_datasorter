import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/update_provider.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final update = context.watch<UpdateProvider>();

    if (update.status == UpdateStatus.idle ||
        update.status == UpdateStatus.checking) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(child: _buildContent(context, update)),
          ..._buildActions(context, update),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, UpdateProvider update) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle =
        TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 13);

    switch (update.status) {
      case UpdateStatus.available:
        return Text(
          'Version ${update.releaseInfo!.tagName} is available',
          style: textStyle,
        );
      case UpdateStatus.downloading:
        final pct = (update.downloadProgress * 100).toStringAsFixed(0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Downloading update... $pct%', style: textStyle),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: update.downloadProgress),
          ],
        );
      case UpdateStatus.readyToInstall:
        return Text('Update downloaded and ready to install', style: textStyle);
      case UpdateStatus.installing:
        return Text('Installing update...', style: textStyle);
      case UpdateStatus.error:
        return Text(
          update.errorMessage ?? 'Update failed',
          style: textStyle.copyWith(color: colorScheme.error),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildActions(BuildContext context, UpdateProvider update) {
    switch (update.status) {
      case UpdateStatus.available:
        return [
          TextButton(
            onPressed: () => update.downloadUpdate(),
            child: const Text('Download'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => update.dismiss(),
            tooltip: 'Dismiss',
          ),
        ];
      case UpdateStatus.readyToInstall:
        return [
          TextButton(
            onPressed: () => update.installUpdate(),
            child: const Text('Install & Restart'),
          ),
        ];
      case UpdateStatus.error:
        return [
          TextButton(
            onPressed: () => update.downloadUpdate(),
            child: const Text('Retry'),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => update.dismiss(),
            tooltip: 'Dismiss',
          ),
        ];
      default:
        return [];
    }
  }
}

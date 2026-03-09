import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_info.dart';
import '../providers/update_provider.dart';
import '../widgets/drop_zone.dart';
import '../widgets/path_selector.dart';
import '../widgets/rules_panel.dart';
import '../widgets/action_bar.dart';
import '../widgets/progress_section.dart';
import '../widgets/log_panel.dart';
import '../widgets/update_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'z2apd_datasorter',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Drag-and-drop a folder here, or use the buttons below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'Version $appVersionLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Update banner (self-hiding when no update)
              const UpdateBanner(),

              // Drop zone
              const DropZone(),
              const SizedBox(height: 12),

              // Path selector
              const PathSelector(),
              const SizedBox(height: 12),

              // Rules panel
              const RulesPanel(),
              const SizedBox(height: 12),

              // Action bar
              const ActionBar(),
              const SizedBox(height: 8),

              // Progress
              const ProgressSection(),
              const SizedBox(height: 8),

              // Log panel (expands to fill remaining space)
              const Expanded(child: LogPanel()),
            ],
          ),
        ),
    );

    if (!Platform.isMacOS) return scaffold;

    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: appName,
          menus: [
            if (PlatformProvidedMenuItem.hasMenu(
                PlatformProvidedMenuItemType.about))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.about,
              ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Check for Updates...',
                  onSelected: () {
                    final provider =
                        Provider.of<UpdateProvider>(context, listen: false);
                    provider.checkForUpdate().then((_) {
                      if (provider.status == UpdateStatus.idle &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('You are running the latest version.'),
                          ),
                        );
                      }
                    });
                  },
                ),
              ],
            ),
            if (PlatformProvidedMenuItem.hasMenu(
                PlatformProvidedMenuItemType.quit))
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit,
              ),
          ],
        ),
      ],
      child: scaffold,
    );
  }
}

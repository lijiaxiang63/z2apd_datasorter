import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversion_provider.dart';

class LogPanel extends StatefulWidget {
  const LogPanel({super.key});

  @override
  State<LogPanel> createState() => _LogPanelState();
}

class _LogPanelState extends State<LogPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<ConversionProvider>().logLines;
    final colorScheme = Theme.of(context).colorScheme;

    // Auto-scroll when new logs arrive
    if (logs.isNotEmpty) _scrollToBottom();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: logs.isEmpty
          ? Center(
              child: Text(
                'Log output will appear here...',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final line = logs[i];
                Color? textColor;
                if (line.startsWith('ERROR') || line.contains('ERROR')) {
                  textColor = colorScheme.error;
                } else if (line.startsWith('OK')) {
                  textColor = Colors.green;
                } else if (line.startsWith('SKIP')) {
                  textColor = Colors.orange;
                } else if (line.startsWith('ARCHIVED')) {
                  textColor = Colors.blue;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: SelectableText(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

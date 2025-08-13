import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DiagnosticsOverlay extends StatefulWidget {
  const DiagnosticsOverlay({required this.logFeed, super.key});
  final ValueListenable<List<String>> logFeed;

  @override
  State<DiagnosticsOverlay> createState() => _DiagnosticsOverlayState();
}
class _DiagnosticsOverlayState extends State<DiagnosticsOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(
          left: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_expanded)
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: widget.logFeed,
                    builder: (context, logs, _) {
                      final items = logs.reversed.take(100).toList();
                      return Scrollbar(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return Text(
                              items[index],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: '_diag_fab',
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Icon(_expanded ? Icons.close : Icons.bug_report_outlined),
              ),
            ],
          ),
        )
      ],
    );
  }
}


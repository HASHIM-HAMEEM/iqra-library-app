import 'package:flutter/material.dart';

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: theme.colorScheme.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final insets = MediaQuery.of(ctx).viewInsets;
      // Remove animation to avoid IME-induced jank on some devices
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: insets.bottom + 24,
          top: 8,
        ),
        child: builder(ctx),
      );
    },
  );
}

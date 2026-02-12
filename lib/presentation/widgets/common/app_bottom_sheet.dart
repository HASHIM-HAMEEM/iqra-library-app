import 'package:flutter/material.dart';
import 'package:library_registration_app/core/responsive/responsive.dart';
import 'package:library_registration_app/core/theme/design_tokens.dart';

Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  double? dialogMaxWidth,
}) {
  final theme = Theme.of(context);
  final useDialog = ResponsiveUtils.isDesktop(context) || ResponsiveUtils.isWeb;

  // On desktop / web, render as a centered dialog instead of a bottom sheet
  if (useDialog && MediaQuery.of(context).size.width >= 900) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth ?? ResponsiveUtils.getDialogWidth(ctx),
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.borderXl,
              clipBehavior: Clip.antiAlias,
              elevation: 8,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: builder(ctx),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: theme.colorScheme.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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

import 'package:flutter/material.dart';

class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    required this.options, required this.selected, required this.onSelected, super.key,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: options.map((option) {
          final isActive = option == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option),
              selected: isActive,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              onSelected: (_) => onSelected(option),
            ),
          );
        }).toList(),
      ),
    );
  }
}

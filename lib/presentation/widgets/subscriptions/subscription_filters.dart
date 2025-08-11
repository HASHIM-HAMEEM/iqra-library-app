import 'package:flutter/material.dart';

import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';

class SubscriptionFilters extends StatelessWidget {
  const SubscriptionFilters({
    required this.selectedStatus,
    required this.searchQuery,
    required this.onStatusChanged,
    required this.onSearchChanged,
    super.key,
  });

  final SubscriptionStatus? selectedStatus;
  final String searchQuery;
  final ValueChanged<SubscriptionStatus?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveWidget(
      mobile: Column(
        children: [
          _buildSearchField(theme),
          const SizedBox(height: 16),
          _buildStatusFilters(theme),
        ],
      ),
      tablet: Row(
        children: [
          Expanded(flex: 2, child: _buildSearchField(theme)),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildStatusFilters(theme)),
        ],
      ),
      desktop: Row(
        children: [
          Expanded(flex: 2, child: _buildSearchField(theme)),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: _buildStatusFilters(theme)),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search by plan name or student ID...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onSearchChanged(''),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
      ),
    );
  }

  Widget _buildStatusFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatusChip(theme, 'All', null, selectedStatus == null),
          const SizedBox(width: 8),
          ...SubscriptionStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildStatusChip(
                theme,
                _getStatusDisplayName(status),
                status,
                selectedStatus == status,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    ThemeData theme,
    String label,
    SubscriptionStatus? status,
    bool isSelected,
  ) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (isSelected) {
      if (status == null) {
        backgroundColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
        borderColor = theme.colorScheme.primary;
      } else {
        switch (status) {
          case SubscriptionStatus.active:
            backgroundColor = theme.colorScheme.primary;
            textColor = theme.colorScheme.onPrimary;
            borderColor = theme.colorScheme.primary;
          case SubscriptionStatus.expired:
            backgroundColor = theme.colorScheme.error;
            textColor = theme.colorScheme.onError;
            borderColor = theme.colorScheme.error;
          case SubscriptionStatus.cancelled:
            backgroundColor = theme.colorScheme.onSurfaceVariant;
            textColor = theme.colorScheme.surface;
            borderColor = theme.colorScheme.onSurfaceVariant;
          case SubscriptionStatus.pending:
            backgroundColor = const Color(0xFFF59E0B);
            textColor = theme.colorScheme.onPrimary;
            borderColor = const Color(0xFFF59E0B);
        }
      }
    } else {
      backgroundColor = theme.colorScheme.surface;
      textColor = theme.colorScheme.onSurface;
      borderColor = theme.colorScheme.outline;
    }

    return FilterChip(
      label: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onStatusChanged(status),
      backgroundColor: backgroundColor,
      selectedColor: backgroundColor,
      side: BorderSide(color: borderColor),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  String _getStatusDisplayName(SubscriptionStatus status) {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pending:
        return 'Pending';
    }
  }
}

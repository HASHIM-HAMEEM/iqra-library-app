import 'package:flutter/material.dart';

import 'package:library_registration_app/core/utils/responsive_utils.dart';
import 'package:library_registration_app/domain/entities/subscription.dart';

class SubscriptionFilters extends StatelessWidget {
  const SubscriptionFilters({
    required this.selectedStatus,
    required this.searchQuery,
    required this.onStatusChanged,
    required this.onSearchChanged,
    this.onClearFilters,
    super.key,
  });

  final SubscriptionStatus? selectedStatus;
  final String searchQuery;
  final ValueChanged<SubscriptionStatus?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onClearFilters;

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
          const SizedBox(width: 16),
          Expanded(flex: 3, child: _buildStatusFilters(theme)),
          const SizedBox(width: 16),
          _buildClearFiltersButton(theme),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return TextField(
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search by plan, student name, email, phone, seat number, amount, or ID...',
        prefixIcon: Icon(
          Icons.search,
          color: searchQuery.isNotEmpty ? theme.colorScheme.primary : null,
        ),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () => onSearchChanged(''),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: searchQuery.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: searchQuery.isNotEmpty ? 2 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: searchQuery.isNotEmpty
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStatusFilters(ThemeData theme) {
    final hasActiveFilters = selectedStatus != null || searchQuery.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Stack(
            children: [
              _buildStatusChip(theme, 'All', null, selectedStatus == null),
              if (hasActiveFilters && selectedStatus == null)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          ...SubscriptionStatus.values.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  _buildStatusChip(
                    theme,
                    _getStatusDisplayName(status),
                    status,
                    selectedStatus == status,
                  ),
                  if (selectedStatus == status)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
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

  Widget _buildClearFiltersButton(ThemeData theme) {
    final hasActiveFilters = selectedStatus != null || searchQuery.isNotEmpty;

    if (!hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: hasActiveFilters ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: OutlinedButton.icon(
        onPressed: hasActiveFilters ? () {
          onStatusChanged(null);
          onSearchChanged('');
          onClearFilters?.call();
        } : null,
        icon: const Icon(Icons.clear_all, size: 18),
        label: Text(hasActiveFilters ? 'Clear Filters' : 'Clear'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: theme.colorScheme.outline),
          foregroundColor: theme.colorScheme.primary,
        ),
      ),
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

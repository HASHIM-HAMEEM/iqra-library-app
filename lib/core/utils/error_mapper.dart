class ErrorMapper {
  static String friendly(Object error) {
    final text = error.toString().toLowerCase();
    if (_isOverlap(text)) {
      return 'This period overlaps an existing subscription. Adjust dates to avoid conflicts.';
    }
    if (text.contains('start date cannot be after end date') ||
        text.contains('end date cannot be before start date')) {
      return 'Start date must be earlier than or equal to End date.';
    }
    if (text.contains('timeout') || text.contains('socket') || text.contains('network')) {
      return "Couldn't save right now. Check your connection and try again.";
    }
    return 'Could not complete the action. Please try again.';
  }

  static bool isOverlap(Object error) => _isOverlap(error.toString().toLowerCase());

  static bool _isOverlap(String text) => text.contains('overlap');
}



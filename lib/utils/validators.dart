import '../core/constants.dart';

/// Form validation helper functions.
class InputValidators {
  InputValidators._();

  /// Validates node display name.
  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display name cannot be empty';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (trimmed.length > 24) {
      return 'Name must not exceed 24 characters';
    }
    return null;
  }

  /// Validates chat message text length.
  static String? validateMessageText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Message cannot be empty';
    }
    if (value.length > MeshConstants.maxTextMessageLength) {
      return 'Message exceeds maximum length of ${MeshConstants.maxTextMessageLength} characters';
    }
    return null;
  }
}

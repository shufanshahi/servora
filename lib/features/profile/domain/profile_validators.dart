/// Form rules for the profile. They mirror the API (same limits, same words), so the
/// form rejects what the server would reject.
abstract final class ProfileValidators {
  static const phoneMinDigits = 6;
  static const phoneMaxDigits = 15;
  static const phoneMaxLength = 30;

  static final RegExp _phone = RegExp(r'^\+?[0-9(][0-9 ()\-.]*$');

  static const phoneMessage =
      'Enter a valid phone number (6 to 15 digits, for example +1 555 123 4567)';

  /// Optional: blank is fine (it removes the number).
  static String? phone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'\D'), '').length;
    if (!_phone.hasMatch(text) ||
        digits < phoneMinDigits ||
        digits > phoneMaxDigits ||
        text.length > phoneMaxLength) {
      return phoneMessage;
    }
    return null;
  }

  /// The current password only needs to be present.
  static String? currentPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Current password is required';
    return null;
  }
}

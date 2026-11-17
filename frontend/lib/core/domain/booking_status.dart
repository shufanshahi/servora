/// Lifecycle status of a booking, as defined by the API.
enum BookingStatus {
  pending('PENDING', 'Pending'),
  confirmed('CONFIRMED', 'Confirmed'),
  cancelled('CANCELLED', 'Cancelled'),
  completed('COMPLETED', 'Completed');

  const BookingStatus(this.apiValue, this.label);

  /// Value used on the wire, for example `PENDING`.
  final String apiValue;

  /// Human-readable name shown in the UI.
  final String label;

  /// Parses the API value. Throws [FormatException] for anything unknown so a
  /// contract change fails loudly instead of silently showing a wrong status.
  static BookingStatus fromApi(String value) {
    for (final status in BookingStatus.values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Unknown booking status: $value');
  }
}

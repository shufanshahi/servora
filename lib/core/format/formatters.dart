import 'package:intl/intl.dart';

/// Formats a price for display: `$65` for whole amounts, `$49.99` otherwise.
///
/// The currency is fixed to dollars for now; the API does not send one.
String formatPrice(double price) {
  final whole = price == price.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: whole ? 0 : 2,
  ).format(price);
}

/// Formats a length of time: `30 min`, `1 h`, `1 h 30 min`.
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// `Mon, 6 May 2030` for a moment, in the device's time zone.
String formatDate(DateTime moment) =>
    DateFormat('EEE, d MMM y', 'en_US').format(moment.toLocal());

/// `10:00 AM` for a moment, in the device's time zone.
String formatTime(DateTime moment) =>
    DateFormat('h:mm a', 'en_US').format(moment.toLocal());

/// `10:00 AM - 11:00 AM`, in the device's time zone.
String formatTimeRange(DateTime start, DateTime end) =>
    '${formatTime(start)} - ${formatTime(end)}';

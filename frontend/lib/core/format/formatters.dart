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

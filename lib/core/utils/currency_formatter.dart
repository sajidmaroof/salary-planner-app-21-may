import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String symbol = 'Rs. '}) {
    final format = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 0,
    );
    return format.format(amount);
  }
}

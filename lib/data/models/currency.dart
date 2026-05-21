class AppCurrency {
  final String code;
  final String symbol;
  final String name;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  static const List<AppCurrency> supportedCurrencies = [
    AppCurrency(code: 'USD', symbol: '\$', name: 'USD (\$)'),
    AppCurrency(code: 'EUR', symbol: '€', name: 'EUR (€)'),
    AppCurrency(code: 'GBP', symbol: '£', name: 'GBP (£)'),
    AppCurrency(code: 'PKR', symbol: 'Rs. ', name: 'PKR (Rs.)'),
    AppCurrency(code: 'INR', symbol: '₹', name: 'INR (₹)'),
    AppCurrency(code: 'AED', symbol: 'د.إ ', name: 'AED (د.إ)'),
    AppCurrency(code: 'SAR', symbol: '﷼ ', name: 'SAR (﷼)'),
    AppCurrency(code: 'CAD', symbol: 'C\$', name: 'CAD (C\$)'),
    AppCurrency(code: 'AUD', symbol: 'A\$', name: 'AUD (A\$)'),
  ];

  static AppCurrency fromCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies[3], // Default to PKR based on existing formatter
    );
  }
}

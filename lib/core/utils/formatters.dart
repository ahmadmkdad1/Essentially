import 'package:intl/intl.dart';

import '../../data/models/enums.dart';

abstract final class Fmt {
  static final _date = DateFormat('d MMM yyyy');
  static final _dateTime = DateFormat('d MMM yyyy · HH:mm');

  static String money(double amount, [String currency = 'USD']) {
    final symbol = switch (currency.toUpperCase()) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      'LBP' => 'LL ',
      _ => '$currency ',
    };
    final decimals = amount == amount.roundToDouble() ? 0 : 2;
    return '$symbol${NumberFormat.decimalPatternDigits(decimalDigits: decimals).format(amount)}';
  }

  static String price(double amount, String currency, PriceUnit unit) => '${money(amount, currency)}${unit.suffix}';

  static String distance(double? km) {
    if (km == null) return '';
    if (km < 0.05) return '< 50 m';
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);

  static String percent(double? ratio) => ratio == null ? '—' : '${(ratio * 100).round()}%';

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.isNegative) {
      final ahead = d.difference(DateTime.now());
      if (ahead.inDays >= 1) return 'in ${ahead.inDays}d';
      if (ahead.inHours >= 1) return 'in ${ahead.inHours}h';
      return 'soon';
    }
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(d);
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

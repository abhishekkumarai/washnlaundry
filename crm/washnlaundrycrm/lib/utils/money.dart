import 'package:intl/intl.dart';

/// Currency formatting, driven by the shop record.
///
/// `'₹'` used to be a bare literal in roughly fifteen widgets and the `en_IN`
/// grouping was hardcoded in the Reports screen, so the currency was a
/// property of the *app* rather than of the shop.
///
/// This is deliberately a static holder rather than something threaded through
/// `BuildContext`: the symbol appears inside dozens of `'₹${...}'`
/// interpolations in helper methods that have no context to hand, and
/// rewriting all of them to take one would be a far larger change than the
/// problem warrants. [AppProvider] calls [configure] whenever the shop loads,
/// so there is exactly one writer.
class Money {
  Money._();

  static const String defaultSymbol = '₹';
  static const String defaultLocale = 'en_IN';

  static String symbol = defaultSymbol;
  static String locale = defaultLocale;

  /// Point the formatter at a shop. Blank values keep the defaults, so a shop
  /// that has not set a currency still renders sensibly.
  static void configure({String? symbol, String? locale}) {
    if (symbol != null && symbol.trim().isNotEmpty)
      Money.symbol = symbol.trim();
    if (locale != null && locale.trim().isNotEmpty)
      Money.locale = locale.trim();
  }

  /// Restores the defaults. Tests use this so one test's shop cannot leak into
  /// the next — the statics outlive a single `AppProvider`.
  static void reset() {
    symbol = defaultSymbol;
    locale = defaultLocale;
  }

  /// "₹4850" — a plain rounded amount.
  static String format(num? value) => '$symbol${(value ?? 0).round()}';

  /// "₹4,850" — grouped in the shop's locale.
  static String grouped(num? value) {
    final rounded = (value ?? 0).round();
    try {
      return '$symbol${NumberFormat.decimalPattern(locale).format(rounded)}';
    } catch (_) {
      // An unknown locale must not take the screen down over a comma. intl
      // raises an ArgumentError here, which is an Error rather than an
      // Exception, so this catch has to be unqualified.
      return '$symbol$rounded';
    }
  }
}

import 'package:intl/intl.dart';

String rub(double value, String locale) => NumberFormat.currency(
  locale: locale == 'ru' ? 'ru_RU' : 'en_US',
  symbol: '₽',
  decimalDigits: value % 1 == 0 ? 0 : 2,
).format(value);
String localized(Map<String, String> text, String locale) =>
    text[locale] ?? text['ru'] ?? '';
String scheduleDay(int weekday, String locale) => DateFormat.EEEE(
  locale,
).format(DateTime(2026, 1, 4).add(Duration(days: weekday)));

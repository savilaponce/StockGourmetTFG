import 'package:intl/intl.dart';

/// Utilidades de formateo para moneda, fechas, etc.
class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 2,
  );

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Formatea un número como moneda: 12.50 → "12,50 €"
  static String currency(num? value) {
    if (value == null) return '-';
    return _currencyFormat.format(value);
  }

  /// Formatea una fecha: 2025-03-19 → "19/03/2025"
  static String date(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  /// Formatea fecha y hora
  static String dateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date);
  }

  /// Formatea porcentaje: 0.35 → "35.00%"
  static String percentage(num? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(1)}%';
  }

  /// Formatea cantidad con unidad: 2.5 kg
  static String cantidad(num value, String unidad) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()} $unidad';
    }
    return '${value.toStringAsFixed(2)} $unidad';
  }
}

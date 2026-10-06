import 'package:intl/intl.dart';

/// Formatos de fecha y hora en español.
class Fmt {
  Fmt._();

  static const locale = 'es';

  /// "domingo, 4 de octubre"
  static String longDay(DateTime d) => DateFormat("EEEE, d 'de' MMMM", locale).format(d);

  /// "4 oct"
  static String shortDay(DateTime d) => DateFormat('d MMM', locale).format(d).replaceAll('.', '');

  /// "oct" (para la tarjeta de fecha)
  static String monthShort(DateTime d) => DateFormat('MMM', locale).format(d).replaceAll('.', '');

  /// "09:00"
  static String time(DateTime d) => DateFormat('HH:mm', locale).format(d);

  /// "09:00 – 09:45"
  static String timeRange(DateTime start, DateTime? end) =>
      end == null ? time(start) : '${time(start)} – ${time(end)}';

  /// Hoy / Mañana / Ayer / "lun 6 oct"
  static String relativeDay(DateTime d) {
    final today = DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(d.year, d.month, d.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    return DateFormat('EEE d MMM', locale).format(d).replaceAll('.', '');
  }

  /// "8 min", "2 h", "3 d"
  static String ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} d';
    return shortDay(d);
  }

  /// "2 h 30 min"
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  static String greeting(DateTime now) {
    if (now.hour < 12) return 'Buenos días';
    if (now.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// "$1,234.50"
  static String money(num value) => NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(value);

  /// "octubre de 2026"
  static String monthYear(DateTime d) => DateFormat("MMMM 'de' y", locale).format(d);

  /// "350 m" / "1.2 km"
  static String distance(num meters) {
    if (meters < 1000) return '${(meters / 10).round() * 10} m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
  }

  static String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Utilidades para fechas que viajan como ISO UTC hacia/desde la API.
DateTime? parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

String toApiDate(DateTime d) => d.toUtc().toIso8601String();

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

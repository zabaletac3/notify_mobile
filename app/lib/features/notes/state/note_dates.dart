/// Fechas de la lista de notas, como en el diseño (`28 sep`, `Ayer`, `09:12`, `Lun`). Textos en
/// español, medidos en los tableros «Android — Lista de notas» y «Android — Papelera».
library;

const List<String> _weekdays = [
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

const List<String> _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Fecha de la tarjeta en la lista de notas: hora si es de hoy, «Ayer» si fue ayer, el día de la
/// semana si es de los últimos 7 días, «d mmm» si es del mismo año y «d mmm yyyy» si no.
String noteListDate(String iso, DateTime now) {
  final date = DateTime.parse(iso);
  final days = _localDay(now).difference(_localDay(date)).inDays;
  if (days <= 0) {
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  if (days == 1) return 'Ayer';
  if (days < 7) return _weekdays[date.toLocal().weekday - 1];
  final local = date.toLocal();
  final month = _months[local.month - 1];
  if (local.year == now.toLocal().year) return '${local.day} $month';
  return '${local.day} $month ${local.year}';
}

/// Fecha relativa de una nota de la papelera (`Ayer`, `Hace 2 sem.`), del tablero «Papelera».
String trashDate(String iso, DateTime now) {
  final date = DateTime.parse(iso);
  final days = _localDay(now).difference(_localDay(date)).inDays;
  if (days <= 0) return 'Hoy';
  if (days == 1) return 'Ayer';
  if (days < 7) return 'Hace $days días';
  return 'Hace ${days ~/ 7} sem.';
}

/// Texto de los días que le quedan a una nota de la papelera («Se elimina en 29 días»).
String purgeLabel(int days) =>
    days == 1 ? 'Se elimina en 1 día' : 'Se elimina en $days días';

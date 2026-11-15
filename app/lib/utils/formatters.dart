import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';

/// Traduce una clave y, si no existe, devuelve [fallback] (ej. un id desconocido).
String _trOr(BuildContext c, String key, String fallback) {
  final text = c.tr(key);
  return text == key ? fallback : text;
}

String monthName(BuildContext c, int month) =>
    (month < 1 || month > 12) ? '' : c.tr('month.$month');

String monthShortName(BuildContext c, int month) =>
    (month < 1 || month > 12) ? '' : c.tr('mshort.$month');

String cropEmoji(String id) {
  switch (id) {
    case 'papa':
      return '🥔';
    case 'haba':
    case 'arveja':
      return '🫘';
    case 'avena_forrajera':
    case 'cebada':
    case 'trigo':
      return '🌾';
    case 'tarwi':
      return '🌱';
    case 'quinua':
      return '🌾';
    case 'maiz_amilaceo':
    case 'maiz_duro':
      return '🌽';
    case 'oca':
      return '🟠';
    case 'olluco':
      return '🟡';
    case 'pasto':
      return '🌿';
    case 'descanso':
      return '💤';
    default:
      return '🌱';
  }
}

String cropName(BuildContext c, String id) => _trOr(c, 'crop.$id', id);

String prettyZoneName(String name) {
  return name
      .replaceAll('Huanuco', 'Huánuco')
      .replaceAll('Peru', 'Perú')
      .replaceAll('Tingo Maria', 'Tingo María');
}

String eventEmoji(String tipo) {
  switch (tipo) {
    case 'helada':
      return '❄️';
    case 'sequia':
      return '☀️';
    case 'lluvia_fuerte':
      return '🌧️';
    case 'granizo':
      return '🌨️';
    case 'plaga':
      return '🐛';
    default:
      return '📍';
  }
}

String eventLabel(BuildContext c, String tipo) =>
    _trOr(c, 'event.$tipo', tipo);

String factorLabel(BuildContext c, String key) =>
    _trOr(c, 'factor.$key', key);

String confidenceLabel(BuildContext c, String value) =>
    _trOr(c, 'conf.$value', value);

String priorityEmoji(String factor) {
  switch (factor) {
    case 'riesgo':
      return '🍲';
    case 'ingresos':
      return '💰';
    case 'suelo':
      return '🌱';
    case 'agua':
      return '💧';
    default:
      return '🌿';
  }
}

String priorityTitle(BuildContext c, String factor) =>
    _trOr(c, 'prio.$factor', factor);

String formatVersion(String iso) {
  if (iso.isEmpty) return '—';
  final base = iso.contains('+') ? iso.split('+').first : iso;
  final parsed = DateTime.tryParse(base);
  if (parsed == null) return base;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

String formatKb(double kb) {
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

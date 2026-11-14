const List<String> monthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const List<String> monthShort = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

String monthName(int month) {
  if (month < 1 || month > 12) return '';
  return monthNames[month - 1];
}

String monthShortName(int month) {
  if (month < 1 || month > 12) return '';
  return monthShort[month - 1];
}

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

String cropName(String id) {
  switch (id) {
    case 'papa':
      return 'Papa';
    case 'haba':
      return 'Haba';
    case 'avena_forrajera':
      return 'Avena';
    case 'tarwi':
      return 'Tarwi';
    case 'quinua':
      return 'Quinua';
    case 'maiz_amilaceo':
      return 'Maíz amiláceo';
    case 'maiz_duro':
      return 'Maíz duro';
    case 'arveja':
      return 'Arveja';
    case 'cebada':
      return 'Cebada';
    case 'trigo':
      return 'Trigo';
    case 'oca':
      return 'Oca';
    case 'olluco':
      return 'Olluco';
    case 'pasto':
      return 'Pasto';
    case 'descanso':
      return 'Descanso';
    default:
      return id;
  }
}

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

String eventLabel(String tipo) {
  switch (tipo) {
    case 'helada':
      return 'Helada';
    case 'sequia':
      return 'Sequía';
    case 'lluvia_fuerte':
      return 'Lluvia fuerte';
    case 'granizo':
      return 'Granizo';
    case 'plaga':
      return 'Plaga';
    default:
      return tipo;
  }
}

String factorLabel(String key) {
  switch (key) {
    case 'agua':
      return 'Agua';
    case 'suelo':
      return 'Suelo';
    case 'ingresos':
      return 'Ingresos';
    case 'riesgo':
      return 'Menor riesgo';
    default:
      return key;
  }
}

String confidenceLabel(String value) {
  switch (value) {
    case 'alta':
      return 'Alta';
    case 'media':
      return 'Media';
    case 'baja':
      return 'Baja';
    case 'sin_datos':
      return 'Sin datos';
    default:
      return value;
  }
}

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

String priorityTitle(String factor) {
  switch (factor) {
    case 'riesgo':
      return 'Comida';
    case 'ingresos':
      return 'Ingresos';
    case 'suelo':
      return 'Suelo';
    case 'agua':
      return 'Agua';
    default:
      return factor;
  }
}

String formatVersion(String iso) {
  if (iso.isEmpty) return 'Sin fecha';
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

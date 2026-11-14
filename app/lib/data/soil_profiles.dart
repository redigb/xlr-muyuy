import '../models/models.dart';

class SoilProfile {
  const SoilProfile({
    required this.index,
    required this.key,
    required this.label,
    required this.summary,
    required this.strengths,
    required this.cautions,
    required this.tips,
  });

  final int index;
  final String key;
  final String label;
  final String summary;
  final List<String> strengths;
  final List<String> cautions;
  final List<String> tips;
}

const List<String> soilLabelsEs = [
  'Suelo aluvial',
  'Suelo negro',
  'Suelo arcilloso',
  'Suelo rojo',
];

const List<String> soilLabelsEn = [
  'Alluvial soil',
  'Black Soil',
  'Clay soil',
  'Red soil',
];

const List<SoilProfile> soilProfiles = [
  SoilProfile(
    index: 0,
    key: 'aluvial',
    label: 'Suelo aluvial',
    summary:
        'Suele ser profundo y fértil, arrastrado por los ríos. Buen potencial '
        'para cultivos exigentes.',
    strengths: [
      'Buena fertilidad natural.',
      'Retiene humedad sin encharcarse tanto como el arcilloso.',
    ],
    cautions: [
      'Puede inundarse en meses de lluvia fuerte.',
      'En pendiente, revisa que no se lave la capa fértil.',
    ],
    tips: [
      'Aprovéchalo para los cultivos más exigentes de tu rotación.',
      'En meses muy lluviosos, cuida el drenaje antes de sembrar.',
    ],
  ),
  SoilProfile(
    index: 1,
    key: 'negro',
    label: 'Suelo negro',
    summary:
        'Suele tener alto contenido de materia orgánica y una estructura '
        'estable. Es un suelo que vale la pena conservar.',
    strengths: [
      'Mucha materia orgánica.',
      'Buena estructura y retención de nutrientes.',
    ],
    cautions: [
      'Se puede compactar si se trabaja cuando está muy húmedo.',
      'Pierde calidad si se deja sin cobertura.',
    ],
    tips: [
      'Mantén la materia orgánica con leguminosas y cobertura.',
      'Evita labrar con el suelo mojado.',
    ],
  ),
  SoilProfile(
    index: 2,
    key: 'arcilloso',
    label: 'Suelo arcilloso',
    summary:
        'Retiene mucha agua y drena lento. Guarda humedad, pero se compacta y '
        'puede encharcar.',
    strengths: [
      'Guarda humedad por más tiempo.',
      'Buen potencial si se maneja bien la estructura.',
    ],
    cautions: [
      'Drenaje lento: se encharca y se compacta.',
      'Muy duro en seco y pegajoso en mojado.',
    ],
    tips: [
      'Prioriza raíces profundas y cultivos de cobertura para aflojarlo.',
      'Evita labrar mojado y cuida los meses muy lluviosos.',
    ],
  ),
  SoilProfile(
    index: 3,
    key: 'rojo',
    label: 'Suelo rojo',
    summary:
        'Drena bien y se calienta rápido, pero puede ser ácido y erosionarse '
        'con facilidad.',
    strengths: [
      'Buen drenaje.',
      'Se calienta rápido en primavera.',
    ],
    cautions: [
      'Puede ser ácido y con baja retención de nutrientes.',
      'Riesgo de erosión si queda sin cobertura.',
    ],
    tips: [
      'Usa cobertura para protegerlo de la erosión.',
      'Confirma el pH con un análisis antes de decidir fertilización.',
    ],
  ),
];

SoilProfile soilProfileFor(int index) {
  if (index < 0 || index >= soilProfiles.length) return soilProfiles.first;
  return soilProfiles[index];
}

double soilAffinity(SoilProfile profile, Rotacion rotation, Paquete paquete) {
  final soilScore = (rotation.puntajes['suelo'] ?? 0.0).toDouble();
  final crops = <Cultivo>[
    for (final id in rotation.secuencia)
      if (paquete.cultivoPorId(id) != null) paquete.cultivoPorId(id)!,
  ];
  final hasCover = crops.any((item) => item.cobertura);
  final hasDeepRoot = crops.any((item) => item.raizProfunda);
  final hasLegume = crops.any((item) => item.fijaNitrogeno);

  double value;
  switch (profile.key) {
    case 'arcilloso':
      value = soilScore * 0.5 +
          (hasCover ? 0.25 : 0) +
          (hasDeepRoot ? 0.25 : 0);
      break;
    case 'negro':
      value = soilScore * 0.5 +
          (hasLegume ? 0.3 : 0) +
          (hasCover ? 0.2 : 0);
      break;
    case 'rojo':
      value = soilScore * 0.5 +
          (hasDeepRoot ? 0.3 : 0) +
          (hasCover ? 0.2 : 0);
      break;
    default:
      value = soilScore * 0.6 +
          (hasLegume ? 0.2 : 0) +
          (hasCover ? 0.2 : 0);
  }
  return value.clamp(0.0, 1.0).toDouble();
}

String soilFitLabel(double affinity) {
  if (affinity >= 0.7) return 'Alta';
  if (affinity >= 0.5) return 'Media';
  return 'Baja';
}

String soilRotationNote(SoilProfile profile, Rotacion rotation, Paquete paquete) {
  final fit = soilFitLabel(soilAffinity(profile, rotation, paquete));
  return 'Afinidad con tu ${profile.label.toLowerCase()}: $fit';
}

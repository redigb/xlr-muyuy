import '../l10n/strings.dart';

/// Nivel de riesgo agronómico de la clase detectada.
enum DiseaseRisk { low, medium, high }

/// Ficha agronómica de una clase de AgroVision (mismo orden de salida del
/// modelo: 0–9).
class CropDisease {
  const CropDisease({
    required this.index,
    required this.key,
    required this.pathogen,
    required this.summary,
    required this.risk,
    required this.symptoms,
    required this.causes,
    required this.treatment,
    required this.prevention,
  });

  final int index;
  final String key;

  /// Agente causal (hongo, bacteria, virus, ácaro).
  final String pathogen;
  final String summary;
  final DiseaseRisk risk;
  final List<String> symptoms;
  final List<String> causes;
  final List<String> treatment;
  final List<String> prevention;

  bool get healthy => index == 9;

  String get riskKey => 'agro.risk.${risk.name}';
}

const List<CropDisease> cropDiseases = [
  CropDisease(
    index: 0,
    key: 'bacterial_spot',
    pathogen: 'Xanthomonas spp. (bacteria)',
    summary:
        'Manchas pequeñas y aceitosas que crecen con un halo amarillo. Avanza '
        'rápido en días cálidos y húmedos.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Manchas pequeñas de aspecto aceitoso que luego se vuelven marrones con halo amarillo.',
      'Centros ásperos o costrosos, a veces con huecos en la hoja.',
      'También aparecen manchas en los frutos verdes.',
    ],
    causes: [
      'Semilla y almacigo contaminados.',
      'Salpicadura de lluvia o riego por aspersión.',
      'Clima cálido y húmedo con hojas mojadas por horas.',
      'Trabajar o cosechar con las plantas mojadas.',
    ],
    treatment: [
      'Quita y entierra las hojas muy afectadas; no las dejes sobre el suelo.',
      'Aplica un bactericida a base de cobre según etiqueta y repite tras la lluvia.',
      'Pasa a riego por goteo y riega temprano.',
      'Desinfecta manos y herramientas al pasar de planta a planta.',
    ],
    prevention: [
      'Usa semilla certificada y almacigo sano.',
      'Rota el tomate con cultivos que no sean solanáceas al menos 2 años.',
      'Tutora y poda para que el follaje se seque rápido.',
      'Evita mojar las hojas al regar.',
    ],
  ),
  CropDisease(
    index: 1,
    key: 'early_blight',
    pathogen: 'Alternaria solani (hongo)',
    summary:
        'Anillos concéntricos marrones en hojas viejas, con halo amarillo. '
        'Sube desde abajo y debilita la planta.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Manchas marrones con anillos concéntricos, como un tiro al blanco.',
      'Halo amarillo alrededor de la mancha.',
      'Empieza en hojas bajas y provoca caída de hojas.',
    ],
    causes: [
      'Hojas mojadas más de 8 horas con temperatura templada a cálida.',
      'Restos de cosecha infectados en el suelo.',
      'Salpicadura de tierra hacia las hojas.',
      'Plantas débiles por baja nutrición, sobre todo potasio.',
    ],
    treatment: [
      'Elimina las hojas bajas afectadas y sácalas del lote.',
      'Aplica fungicida con clorotalonil, mancozeb o cobre, alternando ingredientes activos.',
      'Coloca cobertura (paja) para frenar la salpicadura de tierra.',
      'Refuerza la nutrición con potasio.',
    ],
    prevention: [
      'Rota cultivos 2–3 años y elimina restos.',
      'Usa cobertura y riego por goteo.',
      'Siembra con buena distancia entre plantas.',
      'Revisa las hojas bajas cada semana.',
    ],
  ),
  CropDisease(
    index: 2,
    key: 'late_blight',
    pathogen: 'Phytophthora infestans (oomiceto)',
    summary:
        'La enfermedad más agresiva del tomate: manchas oscuras que crecen en '
        'días. Actúa el mismo día que la detectas.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Manchas grandes, verde oscuro a marrón, con borde húmedo y halo verde pálido.',
      'Moho blanco en el envés en mañanas húmedas.',
      'Frutos con manchas duras y marrones.',
      'La planta se marchita en pocos días.',
    ],
    causes: [
      'Humedad alta con hojas mojadas 4 horas o más.',
      'Temperaturas frescas a templadas (15–22 °C), niebla o lluvia.',
      'Follaje muy denso que no se seca.',
      'Plantas o frutos infectados que llegan al lote.',
    ],
    treatment: [
      'Retira y entierra o quema las plantas muy afectadas de inmediato.',
      'Aplica cobre (oxicloruro o caldo bordelés) o metalaxil + mancozeb según etiqueta.',
      'Suspende el riego por aspersión y riega solo al pie.',
      'Revisa el lote cada día hasta que el clima se seque.',
    ],
    prevention: [
      'Prefiere variedades tolerantes.',
      'Siembra con buena ventilación y tutorado.',
      'Riega temprano y al pie.',
      'Con lluvia y 15–22 °C, refuerza la protección preventiva.',
    ],
  ),
  CropDisease(
    index: 3,
    key: 'leaf_mold',
    pathogen: 'Passalora fulva (hongo)',
    summary:
        'Manchas amarillas arriba y moho verde oliva debajo. Típica de '
        'invernadero o tunelillo con poca ventilación.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Manchas verde pálido o amarillas en el haz.',
      'Moho verde oliva aterciopelado en el envés.',
      'Hojas que se enrollan y caen.',
    ],
    causes: [
      'Humedad relativa mayor a 85 %.',
      'Poca ventilación, sobre todo bajo cubierta.',
      'Hojas mojadas y follaje muy denso.',
      'Temperatura de 22–25 °C con aire estancado.',
    ],
    treatment: [
      'Abre la ventilación y separa las plantas.',
      'Poda hojas bajas y afectadas.',
      'Aplica fungicida (clorotalonil o difenoconazol) alternando grupos.',
      'Riega al pie, nunca sobre el follaje.',
    ],
    prevention: [
      'Ventila todas las mañanas.',
      'Evita densidad excesiva de plantas.',
      'Riego por goteo.',
      'Limpia restos de hojas del suelo.',
    ],
  ),
  CropDisease(
    index: 4,
    key: 'septoria_leaf_spot',
    pathogen: 'Septoria lycopersici (hongo)',
    summary:
        'Muchas manchas pequeñas con centro claro y borde oscuro. Sube desde '
        'las hojas bajas después de la lluvia.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Manchas circulares pequeñas con centro gris claro y borde marrón.',
      'Puntos negros diminutos dentro de la mancha.',
      'Amarillamiento y caída de hojas bajas.',
    ],
    causes: [
      'Hojas mojadas y lluvia frecuente.',
      'Salpicadura de suelo y restos infectados.',
      'Malezas solanáceas cerca del cultivo.',
      'Temperaturas cálidas con humedad alta.',
    ],
    treatment: [
      'Quita hojas enfermas y restos del suelo.',
      'Aplica fungicida con clorotalonil, mancozeb o cobre según etiqueta.',
      'Coloca cobertura para evitar la salpicadura.',
      'Controla las malezas hospedantes.',
    ],
    prevention: [
      'Rota 2 años con cultivos que no sean solanáceas.',
      'Usa cobertura y goteo.',
      'Desinfecta tutores y herramientas.',
      'Siembra con distancia adecuada.',
    ],
  ),
  CropDisease(
    index: 5,
    key: 'spider_mites',
    pathogen: 'Tetranychus urticae (ácaro)',
    summary:
        'No es una enfermedad: es un ácaro. Puntea la hoja de amarillo y deja '
        'telarañas finas; avanza en clima seco.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Punteado amarillo o plateado en el haz.',
      'Telarañas finas en el envés y entre hojas.',
      'Hojas bronceadas, secas y con caída.',
    ],
    causes: [
      'Clima caluroso y seco, con polvo.',
      'Estrés hídrico de la planta.',
      'Insecticidas de amplio espectro que matan a sus enemigos naturales.',
      'Exceso de nitrógeno, que da follaje tierno.',
    ],
    treatment: [
      'Lava el envés con agua a presión.',
      'Aplica jabón potásico o aceite de neem; repite cada 5–7 días.',
      'Si persiste, usa un acaricida específico según etiqueta, rotando ingredientes.',
      'Evita productos de amplio espectro.',
    ],
    prevention: [
      'Mantén humedad y evita el polvo.',
      'Revisa el envés de 10 hojas por semana.',
      'Conserva fauna benéfica como crisopas y ácaros depredadores.',
      'Evita el exceso de nitrógeno.',
    ],
  ),
  CropDisease(
    index: 6,
    key: 'target_spot',
    pathogen: 'Corynespora cassiicola (hongo)',
    summary:
        'Manchas marrones con anillos y halo amarillo; puede marcar y hundir '
        'la piel del fruto.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Manchas marrones con anillos concéntricos y halo amarillo.',
      'Lesiones corchosas o hundidas en frutos.',
      'Caída de hojas en ataques fuertes.',
    ],
    causes: [
      'Humedad alta y hojas mojadas por mucho tiempo.',
      'Follaje denso con poca ventilación.',
      'Restos de cultivo en el suelo.',
      'Clima cálido y húmedo.',
    ],
    treatment: [
      'Elimina hojas y frutos afectados.',
      'Fungicida con clorotalonil, difenoconazol o mancozeb alternando.',
      'Mejora la ventilación y poda.',
      'Riega al pie.',
    ],
    prevention: [
      'Rotación y limpieza de restos.',
      'Tutorado y distancia adecuada.',
      'Goteo y cobertura.',
      'Monitoreo semanal del follaje medio.',
    ],
  ),
  CropDisease(
    index: 7,
    key: 'yellow_leaf_curl',
    pathogen: 'Virus TYLCV (transmitido por mosca blanca)',
    summary:
        'La hoja se riza y amarillea y la planta deja de crecer. No tiene '
        'cura: lo importante es frenar la mosca blanca.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Bordes de la hoja amarillos y curvados hacia arriba.',
      'Hoja pequeña y coriácea, planta achaparrada.',
      'Pocas flores y frutos pequeños.',
    ],
    causes: [
      'Mosca blanca (Bemisia tabaci), que transmite el virus.',
      'Almacigo o plantines ya infectados.',
      'Cultivos y malezas infectados cerca.',
      'Siembra en época de alta población de mosca blanca.',
    ],
    treatment: [
      'No hay cura: arranca y elimina las plantas con síntomas.',
      'Controla la mosca blanca con trampas amarillas y jabón potásico o neem.',
      'Usa insecticida específico solo si la población es alta, según etiqueta.',
      'Protege el almacigo con malla.',
    ],
    prevention: [
      'Usa semilla y plantines certificados.',
      'Malla en el almacigo y trampas amarillas desde el trasplante.',
      'Elimina malezas hospedantes.',
      'Prefiere variedades tolerantes.',
    ],
  ),
  CropDisease(
    index: 8,
    key: 'mosaic_virus',
    pathogen: 'Virus ToMV (mosaico del tomate)',
    summary:
        'Virus muy estable que pasa de planta a planta por contacto. Mosaico y '
        'deformación, sin cura.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Mosaico verde claro y oscuro en la hoja.',
      'Hoja deformada o con burbujas.',
      'Planta con menos vigor y frutos con manchas internas.',
    ],
    causes: [
      'Semilla contaminada.',
      'Manos, herramientas y tutores con savia infectada.',
      'Tabaco y productos de tabaco.',
      'Contacto entre plantas al podar o cosechar.',
    ],
    treatment: [
      'No hay cura: elimina las plantas afectadas.',
      'Desinfecta manos y herramientas con leche al 10 % o fosfato trisódico.',
      'No fumes ni manipules tabaco cerca del cultivo.',
      'Trabaja primero las plantas sanas.',
    ],
    prevention: [
      'Usa semilla y variedades libres del virus.',
      'Desinfecta herramientas entre surcos.',
      'Lávate las manos antes de entrar al lote.',
      'Rota y elimina restos de cultivo.',
    ],
  ),
  CropDisease(
    index: 9,
    key: 'healthy',
    pathogen: 'Sin patógeno detectado',
    summary:
        'El modelo no reconoce signos claros de enfermedad en esta hoja. '
        'Mantén el monitoreo semanal.',
    risk: DiseaseRisk.low,
    symptoms: [
      'Color verde uniforme.',
      'Sin manchas ni deformaciones visibles.',
    ],
    causes: [
      'Humedad y ventilación adecuadas.',
      'Nutrición equilibrada.',
      'Buen manejo de riego y sanidad.',
    ],
    treatment: [
      'No requiere tratamiento curativo.',
      'Mantén el riego al pie y la nutrición balanceada.',
      'Repite el análisis si aparecen manchas.',
    ],
    prevention: [
      'Revisa el envés de las hojas cada semana.',
      'Rota cultivos y usa cobertura.',
      'Evita mojar las hojas y respeta los tiempos de espera de los productos.',
    ],
  ),
];

const List<CropDisease> cropDiseasesEn = [
  CropDisease(
    index: 0,
    key: 'bacterial_spot',
    pathogen: 'Xanthomonas spp. (bacteria)',
    summary:
        'Small, greasy spots that grow a yellow halo. It spreads fast in warm, '
        'humid days.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Small water-soaked spots that turn brown with a yellow halo.',
      'Scabby centers, sometimes with holes in the leaf.',
      'Spots also appear on green fruit.',
    ],
    causes: [
      'Contaminated seed and seedlings.',
      'Rain splash or overhead irrigation.',
      'Warm, humid weather with leaves wet for hours.',
      'Working or harvesting when plants are wet.',
    ],
    treatment: [
      'Remove and bury badly affected leaves; do not leave them on the soil.',
      'Apply a copper-based bactericide per label and repeat after rain.',
      'Switch to drip irrigation and water early.',
      'Disinfect hands and tools between plants.',
    ],
    prevention: [
      'Use certified seed and healthy seedlings.',
      'Rotate tomato with non-solanaceous crops for at least 2 years.',
      'Stake and prune so the canopy dries quickly.',
      'Avoid wetting the leaves when watering.',
    ],
  ),
  CropDisease(
    index: 1,
    key: 'early_blight',
    pathogen: 'Alternaria solani (fungus)',
    summary:
        'Brown concentric rings on older leaves with a yellow halo. It climbs '
        'from the bottom and weakens the plant.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Brown spots with concentric rings, like a target.',
      'Yellow halo around the spot.',
      'Starts on lower leaves and causes leaf drop.',
    ],
    causes: [
      'Leaves wet for more than 8 hours with mild to warm weather.',
      'Infected crop debris in the soil.',
      'Soil splash onto the leaves.',
      'Weak plants from poor nutrition, especially potassium.',
    ],
    treatment: [
      'Remove affected lower leaves and take them out of the plot.',
      'Apply fungicide with chlorothalonil, mancozeb or copper, rotating actives.',
      'Add mulch (straw) to stop soil splash.',
      'Reinforce potassium nutrition.',
    ],
    prevention: [
      'Rotate crops 2–3 years and remove debris.',
      'Use mulch and drip irrigation.',
      'Plant with good spacing between plants.',
      'Check the lower leaves every week.',
    ],
  ),
  CropDisease(
    index: 2,
    key: 'late_blight',
    pathogen: 'Phytophthora infestans (oomycete)',
    summary:
        'The most aggressive tomato disease: dark spots that grow in days. Act '
        'the same day you detect it.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Large dark green to brown spots with a wet edge and pale green halo.',
      'White mold on the underside on humid mornings.',
      'Fruit with firm brown spots.',
      'The plant wilts within a few days.',
    ],
    causes: [
      'High humidity with leaves wet for 4 hours or more.',
      'Cool to mild temperatures (15–22 °C), fog or rain.',
      'Very dense canopy that does not dry.',
      'Infected plants or fruit arriving in the plot.',
    ],
    treatment: [
      'Remove and bury or burn badly affected plants immediately.',
      'Apply copper (copper oxychloride or Bordeaux mixture) or metalaxyl + mancozeb per label.',
      'Stop overhead irrigation and water only at the base.',
      'Check the plot daily until the weather dries.',
    ],
    prevention: [
      'Prefer tolerant varieties.',
      'Plant with good ventilation and staking.',
      'Water early and at the base.',
      'With rain and 15–22 °C, reinforce preventive protection.',
    ],
  ),
  CropDisease(
    index: 3,
    key: 'leaf_mold',
    pathogen: 'Passalora fulva (fungus)',
    summary:
        'Yellow spots on top and olive-green mold below. Typical of '
        'greenhouses or tunnels with poor ventilation.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Pale green or yellow spots on the upper side.',
      'Velvety olive-green mold on the underside.',
      'Leaves curl and drop.',
    ],
    causes: [
      'Relative humidity above 85 %.',
      'Poor ventilation, especially under cover.',
      'Wet leaves and a very dense canopy.',
      '22–25 °C with stagnant air.',
    ],
    treatment: [
      'Open the ventilation and separate the plants.',
      'Prune lower and affected leaves.',
      'Apply fungicide (chlorothalonil or difenoconazole), alternating groups.',
      'Water at the base, never over the foliage.',
    ],
    prevention: [
      'Ventilate every morning.',
      'Avoid excessive plant density.',
      'Use drip irrigation.',
      'Clean leaf debris from the soil.',
    ],
  ),
  CropDisease(
    index: 4,
    key: 'septoria_leaf_spot',
    pathogen: 'Septoria lycopersici (fungus)',
    summary:
        'Many small spots with a light center and dark edge. It climbs from '
        'lower leaves after rain.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Small circular spots with a light gray center and brown edge.',
      'Tiny black dots inside the spot.',
      'Yellowing and drop of lower leaves.',
    ],
    causes: [
      'Wet leaves and frequent rain.',
      'Soil splash and infected debris.',
      'Solanaceous weeds near the crop.',
      'Warm temperatures with high humidity.',
    ],
    treatment: [
      'Remove sick leaves and debris from the soil.',
      'Apply fungicide with chlorothalonil, mancozeb or copper per label.',
      'Add mulch to prevent splash.',
      'Control host weeds.',
    ],
    prevention: [
      'Rotate 2 years with non-solanaceous crops.',
      'Use mulch and drip.',
      'Disinfect stakes and tools.',
      'Plant with adequate spacing.',
    ],
  ),
  CropDisease(
    index: 5,
    key: 'spider_mites',
    pathogen: 'Tetranychus urticae (mite)',
    summary:
        'Not a disease: it is a mite. It speckles the leaf yellow and leaves '
        'fine webbing; it spreads in dry weather.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Yellow or silvery stippling on the upper side.',
      'Fine webbing on the underside and between leaves.',
      'Bronzed, dry leaves that drop.',
    ],
    causes: [
      'Hot, dry weather with dust.',
      'Water stress on the plant.',
      'Broad-spectrum insecticides that kill natural enemies.',
      'Excess nitrogen, which makes tender foliage.',
    ],
    treatment: [
      'Wash the underside with a strong water jet.',
      'Apply potassium soap or neem oil; repeat every 5–7 days.',
      'If it persists, use a specific acaricide per label, rotating actives.',
      'Avoid broad-spectrum products.',
    ],
    prevention: [
      'Keep humidity up and dust down.',
      'Check the underside of 10 leaves per week.',
      'Keep beneficial fauna such as lacewings and predatory mites.',
      'Avoid excess nitrogen.',
    ],
  ),
  CropDisease(
    index: 6,
    key: 'target_spot',
    pathogen: 'Corynespora cassiicola (fungus)',
    summary:
        'Brown spots with rings and a yellow halo; it can pit and sink the '
        'fruit skin.',
    risk: DiseaseRisk.medium,
    symptoms: [
      'Brown spots with concentric rings and a yellow halo.',
      'Corky or sunken lesions on fruit.',
      'Leaf drop in heavy attacks.',
    ],
    causes: [
      'High humidity and leaves wet for a long time.',
      'Dense canopy with poor ventilation.',
      'Crop debris in the soil.',
      'Warm, humid weather.',
    ],
    treatment: [
      'Remove affected leaves and fruit.',
      'Fungicide with chlorothalonil, difenoconazole or mancozeb, alternating.',
      'Improve ventilation and prune.',
      'Water at the base.',
    ],
    prevention: [
      'Rotation and debris cleanup.',
      'Staking and adequate spacing.',
      'Drip and mulch.',
      'Weekly monitoring of the middle canopy.',
    ],
  ),
  CropDisease(
    index: 7,
    key: 'yellow_leaf_curl',
    pathogen: 'TYLCV virus (spread by whitefly)',
    summary:
        'Leaves curl and yellow and the plant stops growing. There is no cure: '
        'the key is to stop the whitefly.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Yellow leaf edges curling upwards.',
      'Small, leathery leaves and a stunted plant.',
      'Few flowers and small fruit.',
    ],
    causes: [
      'Whitefly (Bemisia tabaci), which transmits the virus.',
      'Already infected seedlings.',
      'Infected crops and weeds nearby.',
      'Planting when whitefly populations are high.',
    ],
    treatment: [
      'No cure: pull out and remove plants with symptoms.',
      'Control whitefly with yellow traps and potassium soap or neem.',
      'Use a specific insecticide only if the population is high, per label.',
      'Protect the seedbed with mesh.',
    ],
    prevention: [
      'Use certified seed and seedlings.',
      'Mesh on the seedbed and yellow traps from transplanting.',
      'Remove host weeds.',
      'Prefer tolerant varieties.',
    ],
  ),
  CropDisease(
    index: 8,
    key: 'mosaic_virus',
    pathogen: 'ToMV virus (tomato mosaic)',
    summary:
        'A very stable virus that moves plant to plant by contact. Mosaic and '
        'distortion, with no cure.',
    risk: DiseaseRisk.high,
    symptoms: [
      'Light and dark green mosaic on the leaf.',
      'Deformed or blistered leaves.',
      'Low vigor and fruit with internal blemishes.',
    ],
    causes: [
      'Contaminated seed.',
      'Hands, tools and stakes with infected sap.',
      'Tobacco and tobacco products.',
      'Contact between plants when pruning or harvesting.',
    ],
    treatment: [
      'No cure: remove the affected plants.',
      'Disinfect hands and tools with 10 % milk or trisodium phosphate.',
      'Do not smoke or handle tobacco near the crop.',
      'Work on healthy plants first.',
    ],
    prevention: [
      'Use virus-free seed and varieties.',
      'Disinfect tools between rows.',
      'Wash your hands before entering the plot.',
      'Rotate and remove crop debris.',
    ],
  ),
  CropDisease(
    index: 9,
    key: 'healthy',
    pathogen: 'No pathogen detected',
    summary:
        'The model does not recognize clear disease signs on this leaf. Keep '
        'the weekly monitoring.',
    risk: DiseaseRisk.low,
    symptoms: ['Even green color.', 'No visible spots or deformation.'],
    causes: [
      'Adequate humidity and ventilation.',
      'Balanced nutrition.',
      'Good water and sanitation management.',
    ],
    treatment: [
      'No curative treatment needed.',
      'Keep watering at the base and balanced nutrition.',
      'Repeat the scan if spots appear.',
    ],
    prevention: [
      'Check the underside of the leaves every week.',
      'Rotate crops and use mulch.',
      'Avoid wetting the leaves and respect product waiting periods.',
    ],
  ),
];

CropDisease cropDiseaseFor(int index, [AppLang lang = AppLang.es]) {
  final list = lang == AppLang.en ? cropDiseasesEn : cropDiseases;
  if (index < 0 || index >= list.length) return list.last;
  return list[index];
}

import 'dart:convert';
import 'dart:typed_data';

import '../utils/package_hash.dart';

enum MesEstado { helada, seco, bueno }

enum PackageOrigin { api, cache, asset, demo, imported, location }

/// Estado de vigencia de una sección del paquete (🟢 🟡 🔴).
enum ValidityState { fresh, expiring, expired, unknown }

extension PackageOriginLabel on PackageOrigin {
  String get label {
    switch (this) {
      case PackageOrigin.api:
        return 'Actualizado desde la API';
      case PackageOrigin.cache:
        return 'Guardado en el celular';
      case PackageOrigin.asset:
        return 'Paquete incluido';
      case PackageOrigin.demo:
        return 'Vista previa demo';
      case PackageOrigin.imported:
        return 'Paquete importado';
      case PackageOrigin.location:
        return 'Calculado para tu ubicación';
    }
  }

  String get shortLabel {
    switch (this) {
      case PackageOrigin.api:
        return 'API';
      case PackageOrigin.cache:
        return 'Offline';
      case PackageOrigin.asset:
        return 'Respaldo';
      case PackageOrigin.demo:
        return 'Demo';
      case PackageOrigin.imported:
        return 'Importado';
      case PackageOrigin.location:
        return 'Tu ubicación';
    }
  }

  /// Claves de `lib/l10n/strings.dart`: `origin.<name>` y `origin.short.<name>`.
  String get labelKey => 'origin.$name';
  String get shortLabelKey => 'origin.short.$name';
}

class Zona {
  const Zona({
    required this.id,
    required this.nombre,
    required this.lat,
    required this.lon,
    this.elevacionM = 0,
    this.region = '',
    this.riego = false,
    this.cultivosIniciales = const [],
    this.practicaComun = const [],
  });

  final String id;
  final String nombre;
  final double lat;
  final double lon;
  final double elevacionM;
  final String region;
  final bool riego;
  final List<String> cultivosIniciales;
  final List<String> practicaComun;

  factory Zona.fromJson(Map<String, dynamic> json) {
    return Zona(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      lat: _toDouble(json['lat']),
      lon: _toDouble(json['lon']),
      elevacionM: _toDouble(json['elevacion_m'] ?? json['elevacionM']),
      region: json['region'] as String? ?? '',
      riego: json['riego'] as bool? ?? false,
      cultivosIniciales: _toStringList(json['cultivos_iniciales']),
      practicaComun: _toStringList(json['practica_comun']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'lat': lat,
    'lon': lon,
    'elevacion_m': elevacionM,
    if (region.isNotEmpty) 'region': region,
    'riego': riego,
    if (cultivosIniciales.isNotEmpty) 'cultivos_iniciales': cultivosIniciales,
    if (practicaComun.isNotEmpty) 'practica_comun': practicaComun,
  };

  Zona copyWith({
    String? nombre,
    double? lat,
    double? lon,
    double? elevacionM,
    String? region,
    bool? riego,
    List<String>? cultivosIniciales,
    List<String>? practicaComun,
  }) {
    return Zona(
      id: id,
      nombre: nombre ?? this.nombre,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      elevacionM: elevacionM ?? this.elevacionM,
      region: region ?? this.region,
      riego: riego ?? this.riego,
      cultivosIniciales: cultivosIniciales ?? this.cultivosIniciales,
      practicaComun: practicaComun ?? this.practicaComun,
    );
  }

  String get coordenadas =>
      '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
}

class CalendarioMes {
  const CalendarioMes({
    required this.mes,
    required this.probHelada,
    required this.lluviaMm,
    required this.etMm,
    required this.balanceHidricoMm,
    required this.estresCalor,
    this.tMin,
    this.tMax,
  });

  final int mes;
  final double probHelada;
  final double lluviaMm;
  final double etMm;
  final double balanceHidricoMm;
  final double estresCalor;
  final double? tMin;
  final double? tMax;

  factory CalendarioMes.fromJson(Map<String, dynamic> json) {
    return CalendarioMes(
      mes: _toInt(json['mes']),
      probHelada: _toDouble(json['prob_helada']),
      lluviaMm: _toDouble(json['lluvia_mm']),
      etMm: _toDouble(json['et_mm']),
      balanceHidricoMm: _toDouble(json['balance_hidrico_mm']),
      estresCalor: _toDouble(json['estres_calor']),
      tMin: _toNullableDouble(json['t_min']),
      tMax: _toNullableDouble(json['t_max']),
    );
  }

  Map<String, dynamic> toJson() => {
    'mes': mes,
    'prob_helada': probHelada,
    'lluvia_mm': lluviaMm,
    'et_mm': etMm,
    'balance_hidrico_mm': balanceHidricoMm,
    'estres_calor': estresCalor,
    if (tMin != null) 't_min': tMin,
    if (tMax != null) 't_max': tMax,
  };

  MesEstado get estado {
    if (probHelada >= 0.5) return MesEstado.helada;
    if (balanceHidricoMm < -40) return MesEstado.seco;
    return MesEstado.bueno;
  }

  String get mesesHeladaLabel => '${(probHelada * 10).round()} de cada 10 años';

  String get temperaturaLabel {
    if (tMin == null || tMax == null) return 'Sin dato';
    return '${tMin!.round()}° – ${tMax!.round()}°C';
  }
}

class Cultivo {
  const Cultivo({
    required this.id,
    required this.nombre,
    required this.familia,
    required this.fijaNitrogeno,
    required this.toleraHelada,
    required this.agua,
    required this.cicloMeses,
    this.zonas = const [],
    this.tOptMin = 0,
    this.tOptMax = 0,
    this.ktmp = 0,
    this.lluviaOptMin = 0,
    this.lluviaOptMax = 0,
    this.valorMercado = 0,
    this.cobertura = false,
    this.raizProfunda = false,
    this.fuente = const {},
  });

  final String id;
  final String nombre;
  final String familia;
  final bool fijaNitrogeno;
  final String toleraHelada;
  final String agua;
  final int cicloMeses;
  final List<String> zonas;
  final double tOptMin;
  final double tOptMax;
  final double ktmp;
  final double lluviaOptMin;
  final double lluviaOptMax;
  final double valorMercado;
  final bool cobertura;
  final bool raizProfunda;
  final Map<String, String> fuente;

  factory Cultivo.fromJson(Map<String, dynamic> json) {
    return Cultivo(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      familia: json['familia'] as String? ?? '',
      fijaNitrogeno: json['fija_nitrogeno'] as bool? ?? false,
      toleraHelada: json['tolera_helada'] as String? ?? 'media',
      agua: json['agua'] as String? ?? 'media',
      cicloMeses: _toInt(json['ciclo_meses']),
      zonas: _toStringList(json['zonas']),
      tOptMin: _toDouble(json['t_opt_min']),
      tOptMax: _toDouble(json['t_opt_max']),
      ktmp: _toDouble(json['ktmp']),
      lluviaOptMin: _toDouble(json['lluvia_opt_min']),
      lluviaOptMax: _toDouble(json['lluvia_opt_max']),
      valorMercado: _toDouble(json['valor_mercado']),
      cobertura: json['cobertura'] as bool? ?? false,
      raizProfunda: json['raiz_profunda'] as bool? ?? false,
      fuente: _toStringMap(json['fuente']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'familia': familia,
    'fija_nitrogeno': fijaNitrogeno,
    'tolera_helada': toleraHelada,
    'agua': agua,
    'ciclo_meses': cicloMeses,
    if (zonas.isNotEmpty) 'zonas': zonas,
    't_opt_min': tOptMin,
    't_opt_max': tOptMax,
    'ktmp': ktmp,
    'lluvia_opt_min': lluviaOptMin,
    'lluvia_opt_max': lluviaOptMax,
    'valor_mercado': valorMercado,
    'cobertura': cobertura,
    'raiz_profunda': raizProfunda,
    if (fuente.isNotEmpty) 'fuente': fuente,
  };
}

class Rotacion {
  const Rotacion({
    required this.id,
    required this.esActual,
    required this.secuencia,
    required this.puntajes,
    required this.confianza,
    required this.explicacion,
    required this.validarConExperto,
    this.cultivoInicial = '',
  });

  final String id;
  final bool esActual;
  final String cultivoInicial;
  final List<String> secuencia;
  final Map<String, double> puntajes;
  final Map<String, String> confianza;
  final String explicacion;
  final String validarConExperto;

  bool get esPracticaComun => esActual;
  double? get total => puntajes['total'];

  factory Rotacion.fromJson(Map<String, dynamic> json) {
    final secuencia = _toStringList(json['secuencia']);
    final initial =
        json['cultivo_inicial'] as String? ??
        (secuencia.isEmpty ? '' : secuencia.first);
    return Rotacion(
      id: json['id'] as String? ?? '',
      esActual:
          json['es_practica_comun'] as bool? ??
          json['es_actual'] as bool? ??
          false,
      cultivoInicial: initial,
      secuencia: secuencia,
      puntajes: _toDoubleMap(json['puntajes']),
      confianza: _toStringMap(json['confianza']),
      explicacion: json['explicacion'] as String? ?? '',
      validarConExperto: json['validar_con_experto'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'cultivo_inicial': cultivoInicial,
    'es_practica_comun': esActual,
    'secuencia': secuencia,
    'puntajes': puntajes,
    'confianza': confianza,
    'explicacion': explicacion,
    'validar_con_experto': validarConExperto,
  };

  double puntajeFinal(Set<String> prioridades) {
    const base = 1.0;
    const extra = 2.0;
    var total = 0.0;
    var pesos = 0.0;
    for (final factor in const ['agua', 'suelo', 'ingresos', 'riesgo']) {
      final peso = prioridades.contains(factor) ? extra : base;
      total += (puntajes[factor] ?? 0) * peso;
      pesos += peso;
    }
    return pesos == 0 ? 0 : total / pesos;
  }

  Rotacion copyWith({
    List<String>? secuencia,
    Map<String, double>? puntajes,
    Map<String, String>? confianza,
    String? explicacion,
    String? cultivoInicial,
  }) {
    return Rotacion(
      id: id,
      esActual: esActual,
      cultivoInicial: cultivoInicial ?? this.cultivoInicial,
      secuencia: secuencia ?? this.secuencia,
      puntajes: puntajes ?? this.puntajes,
      confianza: confianza ?? this.confianza,
      explicacion: explicacion ?? this.explicacion,
      validarConExperto: validarConExperto,
    );
  }
}

class SeccionValidez {
  const SeccionValidez({this.actualizado = '', this.validoHasta = ''});

  final String actualizado;
  final String validoHasta;

  factory SeccionValidez.fromJson(Map<String, dynamic> json) {
    return SeccionValidez(
      actualizado: json['actualizado'] as String? ?? '',
      validoHasta: json['valido_hasta'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    if (actualizado.isNotEmpty) 'actualizado': actualizado,
    if (validoHasta.isNotEmpty) 'valido_hasta': validoHasta,
  };

  bool get vencida => estadoEn(DateTime.now()) == ValidityState.expired;

  /// 🟢 vigente · 🟡 queda ≤ 25 % del periodo (mín. 3 días) · 🔴 vencido.
  ValidityState estadoEn(DateTime now) {
    final hasta = DateTime.tryParse(validoHasta);
    if (hasta == null) return ValidityState.unknown;
    final hoy = DateTime(now.year, now.month, now.day);
    if (hasta.isBefore(hoy)) return ValidityState.expired;
    final desde = DateTime.tryParse(actualizado);
    final total = desde == null ? 0 : hasta.difference(desde).inDays;
    final margen = total <= 0 ? 3 : (total * 0.25).ceil().clamp(3, 30);
    return hasta.difference(hoy).inDays <= margen
        ? ValidityState.expiring
        : ValidityState.fresh;
  }

  ValidityState get estado => estadoEn(DateTime.now());
}

class PaqueteMeta {
  const PaqueteMeta({
    required this.formato,
    required this.origen,
    required this.zonaId,
    required this.celda,
    required this.validadaLocalmente,
    required this.idioma,
    required this.version,
    required this.generado,
    required this.hash,
    required this.secciones,
    required this.extras,
  });

  final int formato;
  final String origen;
  final String zonaId;
  final String celda;
  final bool validadaLocalmente;
  final String idioma;
  final int version;
  final String generado;
  final String hash;
  final Map<String, SeccionValidez> secciones;
  final List<String> extras;

  factory PaqueteMeta.fromJson(
    Map<String, dynamic> json, {
    required String fallbackZonaId,
    String fallbackGenerated = '',
  }) {
    final secciones = <String, SeccionValidez>{};
    final rawSecciones = json['secciones'];
    if (rawSecciones is Map) {
      rawSecciones.forEach((key, value) {
        if (value is Map) {
          secciones[key.toString()] = SeccionValidez.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return PaqueteMeta(
      formato: _toInt(json['formato']),
      origen: json['origen'] as String? ?? 'legacy',
      zonaId: json['zona'] as String? ?? fallbackZonaId,
      celda: json['celda'] as String? ?? '',
      validadaLocalmente: json['validada_localmente'] as bool? ?? false,
      idioma: json['idioma'] as String? ?? 'es',
      version: _toInt(json['version']),
      generado: json['generado'] as String? ?? fallbackGenerated,
      hash: json['hash'] as String? ?? '',
      secciones: secciones,
      extras: _toStringList(json['extras']),
    );
  }

  Map<String, dynamic> toJson() => {
    'formato': formato,
    'origen': origen,
    'zona': zonaId.isEmpty ? null : zonaId,
    'celda': celda.isEmpty ? null : celda,
    'validada_localmente': validadaLocalmente,
    'idioma': idioma,
    'version': version,
    'generado': generado,
    'hash': hash,
    'secciones': {
      for (final entry in secciones.entries) entry.key: entry.value.toJson(),
    },
    'extras': extras,
  };

  bool get seccionesVencidas => secciones.values.any((item) => item.vencida);
}

class Alerta {
  const Alerta({
    required this.tipo,
    required this.fecha,
    required this.confirmaciones,
  });

  final String tipo;
  final String fecha;
  final int confirmaciones;

  factory Alerta.fromJson(Map<String, dynamic> json) {
    return Alerta(
      tipo: json['tipo'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      confirmaciones: _toInt(json['confirmaciones']),
    );
  }

  Map<String, dynamic> toJson() => {
    'tipo': tipo,
    'fecha': fecha,
    'confirmaciones': confirmaciones,
  };
}

class Paquete {
  const Paquete({
    required this.meta,
    required this.zona,
    required this.fuenteClima,
    required this.inicioSiembraMes,
    required this.calendario,
    required this.cultivos,
    required this.rotaciones,
    this.alertas = const [],
    this.condiciones = const {},
    this.extras = const {},
    this.raw,
    this.rawJson,
    this.verified = false,
  });

  final PaqueteMeta meta;
  final Zona zona;
  final String fuenteClima;
  final int inicioSiembraMes;
  final List<CalendarioMes> calendario;
  final List<Cultivo> cultivos;
  final List<Rotacion> rotaciones;
  final List<Alerta> alertas;
  final Map<String, dynamic> condiciones;
  final Map<String, dynamic> extras;
  final Map<String, dynamic>? raw;
  final String? rawJson;
  final bool verified;

  int get packageVersion => meta.version;

  static final _imagenes = Expando<Uint8List>();

  /// Foto satelital de la zona (extras, cubierta por el hash). Null si no vino.
  Uint8List? get imagenSatelital {
    final cached = _imagenes[this];
    if (cached != null) return cached;
    final b64 = extras['imagen_satelital_b64'];
    if (b64 is! String || b64.isEmpty) return null;
    try {
      return _imagenes[this] = base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  String get version =>
      meta.generado.isNotEmpty ? meta.generado : 'v${meta.version}';
  String get versionLabel =>
      meta.version > 0 ? 'v${meta.version}' : 'Sin versión';
  bool get validadaLocalmente => meta.validadaLocalmente;
  String get hash => meta.hash;

  /// Clave de almacenamiento: id de zona oficial o `celda_<celda>`.
  String get clave => zona.id;

  /// Identificador para conexiones: `huanuco-sierra@12`.
  String get etiquetaVersion => '$clave@${meta.version}';

  bool get esCoordenada => meta.origen == 'coordenada';

  /// Vigencia de cada sección presente en `meta.secciones`.
  Map<String, ValidityState> get vigencias => {
    for (final entry in meta.secciones.entries) entry.key: entry.value.estado,
  };

  factory Paquete.fromJson(
    Map<String, dynamic> json, {
    bool verify = true,
    String? rawJson,
  }) {
    final isWrapped = json['paquete'] is Map;
    final p = Map<String, dynamic>.from(
      (isWrapped ? json['paquete'] : json) as Map,
    );
    final hasNucleo = p['nucleo'] is Map;
    final nucleo = hasNucleo
        ? Map<String, dynamic>.from(p['nucleo'] as Map)
        : p;
    final metaJson = p['meta'] is Map
        ? Map<String, dynamic>.from(p['meta'] as Map)
        : <String, dynamic>{};

    final zonaJson = nucleo['zona'] is Map
        ? Map<String, dynamic>.from(nucleo['zona'] as Map)
        : (p['zona'] is Map
              ? Map<String, dynamic>.from(p['zona'] as Map)
              : <String, dynamic>{});
    var zona = Zona.fromJson(zonaJson);

    final meta = PaqueteMeta.fromJson(
      metaJson,
      fallbackZonaId: zona.id,
      fallbackGenerated: p['version'] as String? ?? '',
    );
    // Paquetes por coordenada: "zona": null y "celda": "-0.5_36.0".
    if (zona.id.isEmpty && meta.celda.isNotEmpty) {
      zona = Zona(
        id: 'celda_${meta.celda}',
        nombre: zona.nombre.isNotEmpty ? zona.nombre : meta.celda,
        lat: zona.lat,
        lon: zona.lon,
        elevacionM: zona.elevacionM,
        region: 'global',
        riego: zona.riego,
      );
    }

    final rawDoc = (isWrapped || hasNucleo)
        ? (isWrapped ? Map<String, dynamic>.from(json) : {'paquete': p})
        : null;
    var verified = false;
    if (verify && meta.hash.isNotEmpty) {
      if (rawJson != null) {
        verified = verifyPackageIntegrityRaw(rawJson, meta.hash);
      } else if (rawDoc != null) {
        verified = verifyPackageIntegrity(rawDoc, meta.hash);
      }
    }

    return Paquete(
      meta: meta,
      zona: zona,
      fuenteClima:
          nucleo['fuente_clima'] as String? ??
          p['fuente_clima'] as String? ??
          '',
      inicioSiembraMes: _toInt(nucleo['inicio_siembra_mes']),
      calendario: _toMapList(nucleo['calendario'] ?? p['calendario'])
          .map(CalendarioMes.fromJson)
          .toList(),
      cultivos: _toMapList(nucleo['cultivos'] ?? p['cultivos'])
          .map(Cultivo.fromJson)
          .toList(),
      rotaciones: _toMapList(nucleo['rotaciones'] ?? p['rotaciones'])
          .map(Rotacion.fromJson)
          .toList(),
      alertas: _toMapList(nucleo['alertas_comunidad'] ?? p['alertas_comunidad'])
          .map(Alerta.fromJson)
          .toList(),
      condiciones: _toMap(nucleo['condiciones']),
      extras: _toMap(p['extras']),
      raw: rawDoc,
      rawJson: rawJson,
      verified: verified,
    );
  }

  Map<String, dynamic> toJson() {
    if (raw != null) return raw!;
    return {
      'paquete': {
        'meta': meta.toJson(),
        'nucleo': {
          'zona': zona.toJson(),
          'fuente_clima': fuenteClima,
          'inicio_siembra_mes': inicioSiembraMes,
          'calendario': calendario.map((item) => item.toJson()).toList(),
          'condiciones': condiciones,
          'cultivos': cultivos.map((item) => item.toJson()).toList(),
          'rotaciones': rotaciones.map((item) => item.toJson()).toList(),
          'alertas_comunidad': alertas.map((item) => item.toJson()).toList(),
        },
        'extras': extras,
      },
    };
  }

  String toJsonString({bool pretty = false}) {
    if (rawJson != null) return rawJson!;
    final value = toJson();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(value)
        : jsonEncode(value);
  }

  Cultivo? cultivoPorId(String id) {
    for (final cultivo in cultivos) {
      if (cultivo.id == id) return cultivo;
    }
    return null;
  }

  CalendarioMes? mes(int numero) {
    for (final item in calendario) {
      if (item.mes == numero) return item;
    }
    return null;
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _toNullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<Map<String, dynamic>> _toMapList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<String> _toStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  return const [];
}

Map<String, double> _toDoubleMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), _toDouble(val)));
  }
  return const {};
}

Map<String, String> _toStringMap(dynamic value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val.toString()));
  }
  return const {};
}

class DeviceCredential {
  const DeviceCredential({required this.id, required this.token});

  final String id;
  final String token;

  factory DeviceCredential.fromJson(Map<String, dynamic> json) {
    return DeviceCredential(
      id: json['id'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'token': token};
}

class Observacion {
  const Observacion({
    required this.idLocal,
    required this.zonaId,
    required this.tipo,
    required this.fechaEvento,
    required this.demo,
    required this.creado,
    this.valor,
    this.celda,
    this.latAprox,
    this.lonAprox,
  });

  final String idLocal;
  final String zonaId;
  final String? celda;
  final double? latAprox;
  final double? lonAprox;
  final String tipo;
  final String fechaEvento;
  final bool demo;
  final String creado;
  final double? valor;

  factory Observacion.fromJson(Map<String, dynamic> json) {
    return Observacion(
      idLocal: json['id_local'] as String? ?? '',
      zonaId: json['zona_id'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      fechaEvento: json['fecha_evento'] as String? ?? '',
      demo: json['demo'] as bool? ?? false,
      creado: json['creado'] as String? ?? '',
      valor: (json['valor'] as num?)?.toDouble(),
      celda: json['celda'] as String?,
      latAprox: (json['lat_aprox'] as num?)?.toDouble(),
      lonAprox: (json['lon_aprox'] as num?)?.toDouble(),
    );
  }

  /// Contrato de `/api/sync` (spec 11.2): zona oficial o celda, nunca ambas.
  Map<String, dynamic> toJson() => {
    'id_local': idLocal,
    'zona_id': celda == null ? zonaId : null,
    'celda': celda,
    'lat_aprox': latAprox,
    'lon_aprox': lonAprox,
    'tipo': tipo,
    'fecha_evento': fechaEvento,
    'demo': demo,
    'creado': creado,
    if (valor != null) 'valor': valor,
  };
}

/// Conexión `COMPARTIO`: quién me pasó el paquete (spec 9.1). Se guarda offline.
class Conexion {
  const Conexion({
    required this.origen,
    required this.destino,
    required this.paquete,
    required this.fecha,
    required this.demo,
    this.tipo = 'COMPARTIO',
  });

  final String origen;
  final String destino;
  final String tipo;
  final String paquete;
  final String fecha;
  final bool demo;

  factory Conexion.fromJson(Map<String, dynamic> json) {
    return Conexion(
      origen: json['origen'] as String? ?? '',
      destino: json['destino'] as String? ?? '',
      tipo: json['tipo'] as String? ?? 'COMPARTIO',
      paquete: json['paquete'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      demo: json['demo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'origen': origen,
    'destino': destino,
    'tipo': tipo,
    'paquete': paquete,
    'demo': demo,
    'fecha': fecha,
  };

  bool sameAs(Conexion other) =>
      origen == other.origen &&
      destino == other.destino &&
      tipo == other.tipo &&
      paquete == other.paquete;
}

/// Estado de un reporte para mostrar ⏳ / ✅ (spec 7).
/// `estado`: `por_enviar` | `validada` | `pendiente` | `sospechosa` | `rechazada`.
class Reporte {
  const Reporte({
    required this.idLocal,
    required this.tipo,
    required this.fechaEvento,
    required this.estado,
    this.puntaje,
  });

  final String idLocal;
  final String tipo;
  final String fechaEvento;
  final String estado;
  final int? puntaje;

  bool get enviado => estado != 'por_enviar';

  /// Clave de `lib/l10n/strings.dart`.
  String get estadoKey =>
      estado == 'por_enviar' ? 'report.pending' : 'report.$estado';

  factory Reporte.fromJson(Map<String, dynamic> json) {
    return Reporte(
      idLocal: json['id_local'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      fechaEvento: json['fecha_evento'] as String? ?? '',
      estado: json['estado'] as String? ?? 'por_enviar',
      puntaje: (json['puntaje'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id_local': idLocal,
    'tipo': tipo,
    'fecha_evento': fechaEvento,
    'estado': estado,
    if (puntaje != null) 'puntaje': puntaje,
  };

  Reporte withEstado(String value, {int? puntaje}) => Reporte(
    idLocal: idLocal,
    tipo: tipo,
    fechaEvento: fechaEvento,
    estado: value,
    puntaje: puntaje ?? this.puntaje,
  );
}

class SyncDetalle {
  const SyncDetalle({
    required this.idLocal,
    required this.aceptada,
    required this.estado,
    required this.puntaje,
    required this.motivo,
  });

  final String idLocal;
  final bool aceptada;
  final String estado;
  final int puntaje;
  final String motivo;

  factory SyncDetalle.fromJson(Map<String, dynamic> json) {
    return SyncDetalle(
      idLocal: json['id_local'] as String? ?? '',
      aceptada: json['aceptada'] as bool? ?? false,
      estado: json['estado'] as String? ?? '',
      puntaje: (json['puntaje'] as num?)?.toInt() ?? 0,
      motivo: json['motivo'] as String? ?? '',
    );
  }
}

class SyncSummary {
  const SyncSummary({
    required this.aceptadas,
    required this.rechazadas,
    required this.conexiones,
    required this.detalle,
    this.estados = const [],
  });

  final int aceptadas;
  final int rechazadas;
  final int conexiones;
  final List<SyncDetalle> detalle;

  /// Estado ACTUAL de los reportes recientes del celular (cambia con el consenso).
  final List<SyncDetalle> estados;

  factory SyncSummary.fromJson(Map<String, dynamic> json) {
    final rawDetalle = json['detalle'];
    final rawEstados = json['estados'];
    return SyncSummary(
      aceptadas: (json['aceptadas'] as num?)?.toInt() ?? 0,
      rechazadas: (json['rechazadas'] as num?)?.toInt() ?? 0,
      conexiones: (json['conexiones'] as num?)?.toInt() ?? 0,
      detalle: rawDetalle is List
          ? rawDetalle
                .whereType<Map>()
                .map(
                  (item) =>
                      SyncDetalle.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      estados: rawEstados is List
          ? rawEstados
                .whereType<Map>()
                .map(
                  (item) =>
                      SyncDetalle.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class PackageVersionInfo {
  const PackageVersionInfo({required this.version, required this.hash});

  final int version;
  final String hash;

  factory PackageVersionInfo.fromJson(Map<String, dynamic> json) {
    return PackageVersionInfo(
      version: (json['version'] as num?)?.toInt() ?? 0,
      hash: json['hash'] as String? ?? '',
    );
  }
}

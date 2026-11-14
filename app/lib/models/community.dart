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
  });

  final String idLocal;
  final String zonaId;
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
    );
  }

  Map<String, dynamic> toJson() => {
    'id_local': idLocal,
    'zona_id': zonaId,
    'tipo': tipo,
    'fecha_evento': fechaEvento,
    'demo': demo,
    'creado': creado,
    if (valor != null) 'valor': valor,
  };
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
  });

  final int aceptadas;
  final int rechazadas;
  final int conexiones;
  final List<SyncDetalle> detalle;

  factory SyncSummary.fromJson(Map<String, dynamic> json) {
    final rawDetalle = json['detalle'];
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

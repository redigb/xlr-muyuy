import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/community.dart';
import '../models/models.dart';
import '../models/soil_analysis.dart';
import '../utils/package_hash.dart';
import 'api_service.dart';
import 'local_store.dart';
import 'package_file_stub.dart' if (dart.library.io) 'package_file_io.dart';

class LocalPackage {
  const LocalPackage(this.paquete, this.origin);

  final Paquete paquete;
  final PackageOrigin origin;
}

/// Resultado de importar un archivo (spec 3.5: verificar → comparar → instalar o descartar).
enum ImportOutcome { installed, same, older }

class ImportResult {
  const ImportResult({
    required this.paquete,
    required this.outcome,
    this.installedVersion,
    this.compartidoPor,
  });

  /// El paquete que quedó activo (el importado o el que ya estaba).
  final Paquete paquete;
  final ImportOutcome outcome;
  final int? installedVersion;

  /// `sobre.compartido_por` del archivo, si venía.
  final String? compartidoPor;
}

/// Error de importación con clave de `lib/l10n/strings.dart`.
class ImportException implements Exception {
  const ImportException(this.code);

  final String code;

  @override
  String toString() => code;
}

class PackageRepository {
  PackageRepository({ApiService? api, LocalStore? store})
    : _api = api ?? ApiService(),
      _store = store ?? LocalStore();

  final ApiService _api;
  final LocalStore _store;

  static const fallbackZona = 'huanuco-sierra';
  static const fallbackAsset = 'assets/data/paquete_huanuco-sierra.json';

  final Map<String, Paquete> _assetCache = {};

  String get apiBaseUrl => _api.baseUrl;

  Future<List<Zona>> fetchZonas() => _api.fetchZonas();

  Future<PackageVersionInfo> fetchVersion(String zonaId, {String lang = 'es'}) {
    return _api.fetchVersion(zonaId, lang: lang);
  }

  Future<bool> checkHealth() => _api.checkSalud();

  /// Copia del celular (solo si su hash verifica); si no, el paquete incluido.
  Future<LocalPackage?> loadLocal(String zonaId) async {
    final cached = await _store.readPackageJson(zonaId);
    if (cached != null && cached.isNotEmpty) {
      try {
        final paquete = Paquete.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
          rawJson: cached,
        );
        if (paquete.hash.isNotEmpty && paquete.verified) {
          return LocalPackage(
            paquete,
            paquete.esCoordenada ? PackageOrigin.location : PackageOrigin.cache,
          );
        }
      } catch (_) {
        // Una caché dañada nunca bloquea el paquete incluido.
      }
    }

    final asset = await _loadAsset(zonaId);
    if (asset != null) {
      return LocalPackage(asset, PackageOrigin.asset);
    }
    return null;
  }

  Future<Paquete> fetchRemote(String zonaId, {String lang = 'es'}) async {
    final paquete = await _api.fetchPaquete(zonaId, lang: lang);
    await _save(paquete);
    return paquete;
  }

  Future<Paquete> fetchCoordenada({
    required double lat,
    required double lon,
    required String lang,
    bool riego = false,
  }) async {
    final paquete = await _api.fetchCoordenada(
      lat: lat,
      lon: lon,
      lang: lang,
      riego: riego,
    );
    await _save(paquete);
    return paquete;
  }

  /// Verifica el hash, compara versiones ("gana la más nueva") e instala
  /// solo si es más nueva que la instalada. Nunca acepta paquetes sin hash.
  Future<ImportResult> importJson(String rawJson) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      throw const ImportException('import.notMuyuy');
    }
    if (decoded is! Map) throw const ImportException('import.notMuyuy');
    final document = Map<String, dynamic>.from(decoded);
    final Paquete paquete;
    try {
      paquete = Paquete.fromJson(document, rawJson: rawJson);
    } catch (_) {
      throw const ImportException('import.invalid');
    }
    if (paquete.clave.isEmpty || paquete.rotaciones.isEmpty) {
      throw const ImportException('import.invalid');
    }
    if (paquete.hash.isEmpty) throw const ImportException('import.unsigned');
    if (!paquete.verified) throw const ImportException('import.tampered');

    final sobre = document['sobre'];
    final compartidoPor = sobre is Map
        ? sobre['compartido_por']?.toString()
        : null;

    final current = (await loadLocal(paquete.clave))?.paquete;
    // Las versiones solo se comparan dentro del mismo idioma (es y en se numeran aparte).
    if (current != null &&
        current.clave == paquete.clave &&
        current.meta.idioma == paquete.meta.idioma) {
      final installedVersion = current.packageVersion;
      if (installedVersion > paquete.packageVersion) {
        return ImportResult(
          paquete: current,
          outcome: ImportOutcome.older,
          installedVersion: installedVersion,
          compartidoPor: compartidoPor,
        );
      }
      if (installedVersion == paquete.packageVersion &&
          current.hash == paquete.hash) {
        return ImportResult(
          paquete: current,
          outcome: ImportOutcome.same,
          installedVersion: installedVersion,
          compartidoPor: compartidoPor,
        );
      }
    }

    // Se guarda solo el paquete, sin el sobre de quien lo compartió.
    final paqueteRaw = rawTopLevelMember(rawJson, 'paquete');
    final clean = paqueteRaw == null
        ? paquete
        : Paquete.fromJson(
            {'paquete': jsonDecode(paqueteRaw)},
            rawJson: '{"paquete":$paqueteRaw}',
          );
    await _save(clean);
    return ImportResult(
      paquete: clean,
      outcome: ImportOutcome.installed,
      installedVersion: current?.packageVersion,
      compartidoPor: compartidoPor,
    );
  }

  Future<void> save(Paquete paquete) => _save(paquete);

  Future<String> readZonaId() async => await _store.readZonaId() ?? '';

  Future<List<String>> readPrioridades() => _store.readPrioridades();

  Future<bool?> readRiego(String zonaId) => _store.readRiego(zonaId);

  Future<String> readCultivoId() async => await _store.readCultivoId() ?? '';

  Future<String?> readLang() => _store.readLang();

  Future<void> saveLang(String code) => _store.writeLang(code);

  Future<String?> readLocalId() => _store.readLocalId();

  Future<void> saveLocalId(String id) => _store.writeLocalId(id);

  Future<void> saveZonaId(String zonaId) => _store.writeZonaId(zonaId);

  Future<void> savePrioridades(Iterable<String> prioridades) {
    return _store.writePrioridades(prioridades);
  }

  Future<void> saveRiego(String zonaId, bool value) {
    return _store.writeRiego(zonaId, value);
  }

  Future<void> saveCultivoId(String cultivoId) {
    return _store.writeCultivoId(cultivoId);
  }

  Future<void> clearAll() async {
    _assetCache.clear();
    await _store.clearAll();
  }

  Future<DeviceCredential?> readDevice() async {
    final raw = await _store.readDeviceJson();
    if (raw == null || raw.isEmpty) return null;
    try {
      return DeviceCredential.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDevice(DeviceCredential credential) {
    return _store.writeDeviceJson(jsonEncode(credential.toJson()));
  }

  Future<void> clearDevice() => _store.clearDevice();

  Future<List<Observacion>> readObservaciones() async {
    final list = _decodeList(await _store.readObservacionesJson());
    return list.map(Observacion.fromJson).toList();
  }

  Future<void> writeObservaciones(List<Observacion> observaciones) {
    return _store.writeObservacionesJson(
      jsonEncode(observaciones.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<Conexion>> readConexiones() async {
    final list = _decodeList(await _store.readConexionesJson());
    return list.map(Conexion.fromJson).toList();
  }

  Future<void> writeConexiones(List<Conexion> conexiones) {
    return _store.writeConexionesJson(
      jsonEncode(conexiones.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<Reporte>> readReportes() async {
    final list = _decodeList(await _store.readReportesJson());
    return list.map(Reporte.fromJson).toList();
  }

  Future<void> writeReportes(List<Reporte> reportes) {
    return _store.writeReportesJson(
      jsonEncode(reportes.map((item) => item.toJson()).toList()),
    );
  }

  Future<SoilRecord?> readSoil(String zonaId) async {
    final raw = await _store.readSoilJson(zonaId);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SoilRecord.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSoil(SoilRecord record) {
    return _store.writeSoilJson(record.zonaId, jsonEncode(record.toJson()));
  }

  Future<DeviceCredential> registerDevice({
    required bool demo,
    String? idLocal,
  }) {
    return _api.registerDevice(demo: demo, idLocal: idLocal);
  }

  Future<SyncSummary> sync({
    required String token,
    required List<Observacion> observaciones,
    required List<Conexion> conexiones,
  }) {
    return _api.sync(
      token: token,
      observaciones: observaciones,
      conexiones: conexiones,
    );
  }

  /// Archivo para compartir: `sobre` nuevo (fuera del hash) + paquete intacto.
  String encode(Paquete paquete, {required String compartidoPor}) {
    return wrapWithSobre(paquete.toJsonString(), {
      'compartido_por': compartidoPor,
      'fecha_compartido': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<ShareBundle> prepareShare(
    Paquete paquete, {
    required String compartidoPor,
  }) async {
    final json = encode(paquete, compartidoPor: compartidoPor);
    final fileName = 'muyuy_${paquete.clave}_v${paquete.packageVersion}.json';
    final path = await writePackageFile(fileName, json);
    return ShareBundle(
      json: json,
      fileName: fileName,
      filePath: path,
      bytes: utf8.encode(json).length,
    );
  }

  List<Map<String, dynamic>> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(Paquete paquete) async {
    final raw = paquete.rawJson ?? jsonEncode(paquete.toJson());
    await _store.writePackageJson(paquete.clave, raw);
  }

  Future<Paquete?> _loadAsset(String zonaId) async {
    final cached = _assetCache[zonaId];
    if (cached != null) return cached;

    final assets = [
      if (zonaId.isNotEmpty) 'assets/data/paquete_$zonaId.json',
      if (zonaId != fallbackZona) fallbackAsset,
    ];

    for (final asset in assets) {
      try {
        final raw = await rootBundle.loadString(asset);
        final paquete = Paquete.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
          rawJson: raw,
        );
        if (paquete.hash.isEmpty || !paquete.verified) continue;
        _assetCache[paquete.clave] = paquete;
        return paquete;
      } catch (_) {
        // Probar el siguiente paquete incluido.
      }
    }
    return null;
  }

  void dispose() {
    _api.dispose();
  }
}

class ShareBundle {
  const ShareBundle({
    required this.json,
    required this.fileName,
    required this.filePath,
    required this.bytes,
  });

  final String json;
  final String fileName;
  final String? filePath;
  final int bytes;

  double get sizeKb => bytes / 1024;
}

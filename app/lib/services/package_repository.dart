import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/community.dart';
import '../models/models.dart';
import '../models/soil_analysis.dart';
import 'api_service.dart';
import 'local_store.dart';
import 'package_file_stub.dart' if (dart.library.io) 'package_file_io.dart';

class LocalPackage {
  const LocalPackage(this.paquete, this.origin);

  final Paquete paquete;
  final PackageOrigin origin;
}

class PackageRepository {
  PackageRepository({ApiService? api, LocalStore? store})
    : _api = api ?? ApiService(),
      _store = store ?? LocalStore();

  final ApiService _api;
  final LocalStore _store;

  static const fallbackAsset = 'assets/data/paquete_huanuco-sierra.json';

  final Map<String, Paquete> _assetCache = {};

  String get apiBaseUrl => _api.baseUrl;

  Future<List<Zona>> fetchZonas() => _api.fetchZonas();

  Future<PackageVersionInfo> fetchVersion(String zonaId) {
    return _api.fetchVersion(zonaId);
  }

  Future<bool> checkHealth() => _api.checkSalud();

  Future<LocalPackage?> loadLocal(String zonaId) async {
    final cached = await _store.readPackageJson(zonaId);
    if (cached != null && cached.isNotEmpty) {
      try {
        final paquete = Paquete.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
          rawJson: cached,
        );
        if (paquete.hash.isEmpty || paquete.verified) {
          return LocalPackage(paquete, PackageOrigin.cache);
        }
      } catch (_) {
        // A damaged cache must never block the bundled package.
      }
    }

    final asset = await _loadAsset(zonaId);
    if (asset != null) {
      return LocalPackage(asset, PackageOrigin.asset);
    }
    return null;
  }

  Future<Paquete> fetchRemote(String zonaId) async {
    final paquete = await _api.fetchPaquete(zonaId);
    await _save(paquete);
    return paquete;
  }

  Future<Paquete?> fetchRemoteSilently(String zonaId) async {
    try {
      return await fetchRemote(zonaId);
    } catch (_) {
      return null;
    }
  }

  Future<Paquete> importJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('El archivo no es un paquete MUYUY.');
    }
    final paquete = Paquete.fromJson(
      Map<String, dynamic>.from(decoded),
      rawJson: rawJson,
    );
    if (paquete.zona.id.isEmpty || paquete.rotaciones.isEmpty) {
      throw const FormatException('El archivo no es un paquete MUYUY válido.');
    }
    if (paquete.hash.isNotEmpty && !paquete.verified) {
      throw const FormatException(
        'El paquete no pasó la verificación de integridad.',
      );
    }
    await _save(paquete);
    return paquete;
  }

  Future<void> save(Paquete paquete) => _save(paquete);

  Future<String> readZonaId() async => await _store.readZonaId() ?? '';

  Future<List<String>> readPrioridades() => _store.readPrioridades();

  Future<bool> readRiego() => _store.readRiego();

  Future<String> readCultivoId() async => await _store.readCultivoId() ?? '';

  Future<void> saveZonaId(String zonaId) => _store.writeZonaId(zonaId);

  Future<void> savePrioridades(Iterable<String> prioridades) {
    return _store.writePrioridades(prioridades);
  }

  Future<void> saveRiego(bool value) => _store.writeRiego(value);

  Future<void> saveCultivoId(String cultivoId) {
    return _store.writeCultivoId(cultivoId);
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
    final raw = await _store.readObservacionesJson();
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Observacion.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> writeObservaciones(List<Observacion> observaciones) {
    return _store.writeObservacionesJson(
      jsonEncode(observaciones.map((item) => item.toJson()).toList()),
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

  Future<DeviceCredential> registerDevice({required bool demo}) {
    return _api.registerDevice(demo: demo);
  }

  Future<SyncSummary> sync({
    required String token,
    required List<Observacion> observaciones,
  }) {
    return _api.sync(token: token, observaciones: observaciones);
  }

  Future<String> encode(Paquete paquete) async {
    return paquete.toJsonString(pretty: true);
  }

  Future<ShareBundle> prepareShare(Paquete paquete) async {
    final json = await encode(paquete);
    final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
    final fileName = 'muyuy_${paquete.zona.id}_$stamp.json';
    final path = await writePackageFile(fileName, json);
    return ShareBundle(
      json: json,
      fileName: fileName,
      filePath: path,
      bytes: utf8.encode(json).length,
    );
  }

  Future<void> _save(Paquete paquete) async {
    final raw = paquete.rawJson ?? jsonEncode(paquete.toJson());
    await _store.writePackageJson(paquete.zona.id, raw);
  }

  Future<Paquete?> _loadAsset(String zonaId) async {
    final cached = _assetCache[zonaId];
    if (cached != null) return cached;

    final assets = [
      if (zonaId.isNotEmpty) 'assets/data/paquete_$zonaId.json',
      if (zonaId != 'huanuco-sierra') fallbackAsset,
    ];

    for (final asset in assets) {
      try {
        final raw = await rootBundle.loadString(asset);
        final paquete = Paquete.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
          rawJson: raw,
        );
        if (paquete.hash.isNotEmpty && !paquete.verified) continue;
        _assetCache[paquete.zona.id] = paquete;
        return paquete;
      } catch (_) {
        // Try the next bundled package.
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

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore({SharedPreferencesAsync? preferences})
    : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _prefix = 'muyuy.';
  static const _zonaKey = 'muyuy.zona';
  static const _prioridadesKey = 'muyuy.prioridades';
  static const _riegoKey = 'muyuy.riego';
  static const _cultivoKey = 'muyuy.cultivo';
  static const _rotacionKey = 'muyuy.rotacion';
  static const _paqueteKey = 'muyuy.paquete.';
  static const _deviceKey = 'muyuy.dispositivo';
  static const _localIdKey = 'muyuy.id_local';
  static const _observacionesKey = 'muyuy.observaciones';
  static const _conexionesKey = 'muyuy.conexiones';
  static const _reportesKey = 'muyuy.reportes';
  static const _soilKey = 'muyuy.suelo.';
  static const _langKey = 'muyuy.idioma';

  Future<String?> readZonaId() => _prefs.getString(_zonaKey);

  Future<void> writeZonaId(String zonaId) => _prefs.setString(_zonaKey, zonaId);

  Future<List<String>> readPrioridades() async {
    final raw = await _prefs.getString(_prioridadesKey);
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> writePrioridades(Iterable<String> prioridades) {
    return _prefs.setString(_prioridadesKey, prioridades.join(','));
  }

  /// `null` si el usuario nunca lo eligió (se usa el valor de la zona).
  Future<bool?> readRiego(String zonaId) =>
      _prefs.getBool('$_riegoKey.$zonaId');

  Future<void> writeRiego(String zonaId, bool value) {
    return _prefs.setBool('$_riegoKey.$zonaId', value);
  }

  Future<String?> readRotacionId(String zonaId) =>
      _prefs.getString('$_rotacionKey.$zonaId');

  Future<void> writeRotacionId(String zonaId, String rotacionId) {
    return _prefs.setString('$_rotacionKey.$zonaId', rotacionId);
  }

  Future<String?> readCultivoId() => _prefs.getString(_cultivoKey);

  Future<void> writeCultivoId(String cultivoId) {
    return _prefs.setString(_cultivoKey, cultivoId);
  }

  Future<String?> readLang() => _prefs.getString(_langKey);

  Future<void> writeLang(String code) => _prefs.setString(_langKey, code);

  /// UUID anónimo generado al primer uso (spec 7). Se usa en el `sobre`
  /// y en las conexiones, aunque el celular nunca se haya registrado.
  Future<String?> readLocalId() => _prefs.getString(_localIdKey);

  Future<void> writeLocalId(String id) => _prefs.setString(_localIdKey, id);

  Future<String?> readDeviceJson() => _prefs.getString(_deviceKey);

  Future<void> writeDeviceJson(String json) {
    return _prefs.setString(_deviceKey, json);
  }

  Future<void> clearDevice() => _prefs.remove(_deviceKey);

  Future<String?> readObservacionesJson() {
    return _prefs.getString(_observacionesKey);
  }

  Future<void> writeObservacionesJson(String json) {
    return _prefs.setString(_observacionesKey, json);
  }

  Future<String?> readConexionesJson() => _prefs.getString(_conexionesKey);

  Future<void> writeConexionesJson(String json) {
    return _prefs.setString(_conexionesKey, json);
  }

  Future<String?> readReportesJson() => _prefs.getString(_reportesKey);

  Future<void> writeReportesJson(String json) {
    return _prefs.setString(_reportesKey, json);
  }

  Future<String?> readPackageJson(String zonaId) {
    return _prefs.getString('$_paqueteKey$zonaId');
  }

  Future<void> writePackageJson(String zonaId, String json) {
    return _prefs.setString('$_paqueteKey$zonaId', json);
  }

  Future<String?> readSoilJson(String zonaId) {
    return _prefs.getString('$_soilKey$zonaId');
  }

  Future<void> writeSoilJson(String zonaId, String json) {
    return _prefs.setString('$_soilKey$zonaId', json);
  }

  /// "Reiniciar demo": borra todo lo de MUYUY menos el idioma elegido.
  Future<void> clearAll() async {
    final keys = await _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_prefix) && key != _langKey) {
        await _prefs.remove(key);
      }
    }
  }
}

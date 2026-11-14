import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  LocalStore({SharedPreferencesAsync? preferences})
    : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _zonaKey = 'muyuy.zona';
  static const _prioridadesKey = 'muyuy.prioridades';
  static const _riegoKey = 'muyuy.riego';
  static const _cultivoKey = 'muyuy.cultivo';
  static const _paqueteKey = 'muyuy.paquete.';
  static const _deviceKey = 'muyuy.dispositivo';
  static const _observacionesKey = 'muyuy.observaciones';
  static const _soilKey = 'muyuy.suelo.';

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

  Future<bool> readRiego() async {
    return await _prefs.getBool(_riegoKey) ?? false;
  }

  Future<void> writeRiego(bool value) => _prefs.setBool(_riegoKey, value);

  Future<String?> readCultivoId() => _prefs.getString(_cultivoKey);

  Future<void> writeCultivoId(String cultivoId) {
    return _prefs.setString(_cultivoKey, cultivoId);
  }

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
}

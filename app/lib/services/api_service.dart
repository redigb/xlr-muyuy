import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/strings.dart';
import '../models/community.dart';
import '../models/models.dart';

/// Error de API. `code` es una clave de `lib/l10n/strings.dart`;
/// `serverMessage` es el texto que mandó el backend (si mandó).
class ApiException implements Exception {
  const ApiException(this.code, {this.statusCode, this.serverMessage});

  final String code;
  final int? statusCode;
  final String? serverMessage;

  /// Siempre en el idioma del usuario (el backend responde en inglés).
  String messageIn(AppLang lang) => tr(lang, code, {'code': statusCode});

  String get message => messageIn(AppLang.es);

  @override
  String toString() => message;
}

class ApiAuthException extends ApiException {
  const ApiAuthException({super.serverMessage})
    : super('err.server', statusCode: 401);
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? defaultBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  static const _envBaseUrl = String.fromEnvironment('MUYUY_API_URL');
  static const _productionBaseUrl = 'https://muyuy-bk.rdev7.net.pe';

  static String get defaultBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return _productionBaseUrl;
  }

  static const _timeout = Duration(seconds: 10);

  Future<List<Zona>> fetchZonas() async {
    final response = await _get('/api/zonas');
    final decoded = jsonDecode(response);
    if (decoded is! List) {
      throw const ApiException('err.format');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Zona.fromJson(Map<String, dynamic>.from(e)))
        .where((zona) => zona.id.isNotEmpty)
        .toList();
  }

  /// `lang`: idioma de las explicaciones (es / en).
  Future<Paquete> fetchPaquete(String zonaId, {String lang = 'es'}) async {
    return _parsePaquete(await _get('/api/paquete/$zonaId?lang=$lang'));
  }

  /// Paquete bajo demanda para cualquier punto (spec 11.1). Hasta 30 s.
  Future<Paquete> fetchCoordenada({
    required double lat,
    required double lon,
    required String lang,
  }) async {
    final query = 'lat=${lat.toStringAsFixed(4)}&lon=${lon.toStringAsFixed(4)}'
        '&lang=$lang';
    final response = await _get(
      '/api/paquete/coordenada?$query',
      timeout: coordenadaTimeout,
    );
    return _parsePaquete(response);
  }

  static const coordenadaTimeout = Duration(seconds: 30);

  Paquete _parsePaquete(String response) {
    final decoded = jsonDecode(response);
    if (decoded is! Map) throw const ApiException('err.format');
    final paquete = Paquete.fromJson(
      Map<String, dynamic>.from(decoded),
      rawJson: response,
    );
    if (paquete.hash.isEmpty || !paquete.verified) {
      throw const ApiException('err.integrity');
    }
    return paquete;
  }

  Future<PackageVersionInfo> fetchVersion(
    String zonaId, {
    String lang = 'es',
  }) async {
    final response = await _get('/api/paquete/$zonaId/version?lang=$lang');
    final decoded = jsonDecode(response);
    if (decoded is! Map) {
      throw const ApiException('err.format');
    }
    return PackageVersionInfo.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<bool> checkSalud() async {
    try {
      final response = await _get('/api/salud');
      final decoded = jsonDecode(response);
      return decoded is Map && decoded['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceCredential> registerDevice({
    bool demo = false,
    String? idLocal,
  }) async {
    final response = await _post('/api/dispositivos', {
      'demo': demo,
      if (idLocal != null && idLocal.isNotEmpty) 'id_local': idLocal,
    });
    final decoded = jsonDecode(response);
    if (decoded is! Map) {
      throw const ApiException('err.device');
    }
    final credential = DeviceCredential.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (credential.id.isEmpty || credential.token.isEmpty) {
      throw const ApiException('err.device');
    }
    return credential;
  }

  Future<SyncSummary> sync({
    required String token,
    required List<Observacion> observaciones,
    List<Conexion> conexiones = const [],
  }) async {
    final response = await _post('/api/sync', {
      'observaciones': observaciones.map((item) => item.toJson()).toList(),
      'conexiones': conexiones.map((item) => item.toJson()).toList(),
    }, token: token);
    final decoded = jsonDecode(response);
    if (decoded is! Map) throw const ApiException('err.format');
    return SyncSummary.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<String> _get(String path, {Duration timeout = _timeout}) async {
    return _request(
      () => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: const {'Accept': 'application/json'},
      ),
      timeout: timeout,
    );
  }

  Future<String> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _request(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ),
    );
  }

  Future<String> _request(
    Future<http.Response> Function() send, {
    Duration timeout = _timeout,
  }) async {
    try {
      final response = await send().timeout(timeout);
      final text = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _errorMessage(text);
        if (response.statusCode == 401) {
          throw ApiAuthException(serverMessage: message);
        }
        throw ApiException(
          'err.server',
          statusCode: response.statusCode,
          serverMessage: message,
        );
      }
      return text;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException('err.network');
    }
  }

  String? _errorMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // Ignore non-JSON error bodies.
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}

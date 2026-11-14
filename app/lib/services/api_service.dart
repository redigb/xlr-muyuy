import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/community.dart';
import '../models/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiAuthException extends ApiException {
  const ApiAuthException(super.message) : super(statusCode: 401);
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
      throw const ApiException('La API devolvió un formato inesperado.');
    }
    return decoded
        .whereType<Map>()
        .map((e) => Zona.fromJson(Map<String, dynamic>.from(e)))
        .where((zona) => zona.id.isNotEmpty)
        .toList();
  }

  Future<Paquete> fetchPaquete(String zonaId) async {
    final response = await _get('/api/paquete/$zonaId');
    final decoded = jsonDecode(response);
    if (decoded is! Map) {
      throw const ApiException('El paquete no tiene el formato esperado.');
    }
    final paquete = Paquete.fromJson(
      Map<String, dynamic>.from(decoded),
      rawJson: response,
    );
    if (paquete.hash.isNotEmpty && !paquete.verified) {
      throw const ApiException(
        'El paquete no pasó la verificación de integridad. No se guardó.',
      );
    }
    return paquete;
  }

  Future<PackageVersionInfo> fetchVersion(String zonaId) async {
    final response = await _get('/api/paquete/$zonaId/version');
    final decoded = jsonDecode(response);
    if (decoded is! Map) {
      throw const ApiException('La versión del paquete no es válida.');
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

  Future<DeviceCredential> registerDevice({bool demo = false}) async {
    final response = await _post('/api/dispositivos', {'demo': demo});
    final decoded = jsonDecode(response);
    if (decoded is! Map) {
      throw const ApiException(
        'La API no devolvió las credenciales del equipo.',
      );
    }
    final credential = DeviceCredential.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (credential.id.isEmpty || credential.token.isEmpty) {
      throw const ApiException('Las credenciales del equipo están vacías.');
    }
    return credential;
  }

  Future<SyncSummary> sync({
    required String token,
    required List<Observacion> observaciones,
  }) async {
    final response = await _post('/api/sync', {
      'observaciones': observaciones.map((item) => item.toJson()).toList(),
      'conexiones': const [],
    }, token: token);
    final decoded = jsonDecode(response);
    if (decoded is! Map) {
      throw const ApiException(
        'La sincronización devolvió un formato extraño.',
      );
    }
    return SyncSummary.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<String> _get(String path) async {
    return _request(
      () => _client.get(
        Uri.parse('$baseUrl$path'),
        headers: const {'Accept': 'application/json'},
      ),
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

  Future<String> _request(Future<http.Response> Function() send) async {
    try {
      final response = await send().timeout(_timeout);
      final text = utf8.decode(response.bodyBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            _errorMessage(text) ??
            'El servidor respondió ${response.statusCode}. Intenta otra vez.';
        if (response.statusCode == 401) {
          throw ApiAuthException(message);
        }
        throw ApiException(message, statusCode: response.statusCode);
      }
      return text;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. Revisa tu señal.',
      );
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

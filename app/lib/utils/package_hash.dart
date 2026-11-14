import 'dart:convert';

import 'package:crypto/crypto.dart';

String computePackageHash(Map<String, dynamic> document) {
  final paquete = document['paquete'] is Map
      ? Map<String, dynamic>.from(document['paquete'] as Map)
      : document;
  final nucleo = paquete['nucleo'];
  if (nucleo is! Map) return '';

  final canonical = canonicalJsonEncode({
    'extras': paquete['extras'] ?? const <String, dynamic>{},
    'nucleo': nucleo,
  });
  return 'sha256:${sha256.convert(utf8.encode(canonical))}';
}

String computePackageHashFromRaw(String rawJson) {
  final root = _JsonReader(rawJson).parse();
  if (root is! Map<String, Object?>) return '';
  final paquete = root['paquete'] is Map<String, Object?>
      ? root['paquete'] as Map<String, Object?>
      : root;
  final nucleo = paquete['nucleo'];
  if (nucleo is! Map<String, Object?>) return '';

  final buffer = StringBuffer();
  _writeNode({
    'extras': paquete['extras'] ?? <String, Object?>{},
    'nucleo': nucleo,
  }, buffer);
  return 'sha256:${sha256.convert(utf8.encode(buffer.toString()))}';
}

bool verifyPackageIntegrity(
  Map<String, dynamic> document,
  String expectedHash,
) {
  if (expectedHash.isEmpty) return false;
  final computed = computePackageHash(document);
  return computed.isNotEmpty && computed == expectedHash;
}

bool verifyPackageIntegrityRaw(String rawJson, String expectedHash) {
  if (expectedHash.isEmpty) return false;
  final computed = computePackageHashFromRaw(rawJson);
  return computed.isNotEmpty && computed == expectedHash;
}

String shortPackageHash(String hash) {
  if (hash.length <= 18) return hash;
  final value = hash.startsWith('sha256:') ? hash.substring(7) : hash;
  return 'sha256:${value.substring(0, 10)}…';
}

/// Canonical JSON: sorted keys, no whitespace and doubles that keep their
/// decimal representation. This is the same representation the backend hashes,
/// and avoids dart2js turning `135.0` into `135`.
String canonicalJsonEncode(Object? value) {
  final buffer = StringBuffer();
  _writeNode(value, buffer);
  return buffer.toString();
}

void _writeNode(Object? value, StringBuffer buffer) {
  if (value == null) {
    buffer.write('null');
    return;
  }
  if (value is _JsonNumber) {
    buffer.write(value.raw);
    return;
  }
  if (value is bool) {
    buffer.write(value ? 'true' : 'false');
    return;
  }
  if (value is int) {
    buffer.write(value.toString());
    return;
  }
  if (value is double) {
    if (value.isNaN || value.isInfinite) {
      buffer.write('null');
    } else if (value == value.truncateToDouble()) {
      buffer.write(value.toStringAsFixed(1));
    } else {
      buffer.write(value.toString());
    }
    return;
  }
  if (value is String) {
    buffer.write(jsonEncode(value));
    return;
  }
  if (value is List) {
    buffer.write('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) buffer.write(',');
      _writeNode(value[i], buffer);
    }
    buffer.write(']');
    return;
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    buffer.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(jsonEncode(keys[i]));
      buffer.write(':');
      _writeNode(value[keys[i]], buffer);
    }
    buffer.write('}');
    return;
  }

  buffer.write(jsonEncode(value.toString()));
}

class _JsonNumber {
  const _JsonNumber(this.raw);

  final String raw;
}

class _JsonReader {
  _JsonReader(this.source);

  final String source;
  int _index = 0;

  Object? parse() {
    _skipWhitespace();
    final value = _readValue();
    _skipWhitespace();
    if (_index != source.length) {
      throw const FormatException('JSON con contenido extra.');
    }
    return value;
  }

  Object? _readValue() {
    _skipWhitespace();
    if (_index >= source.length) {
      throw const FormatException('JSON incompleto.');
    }
    final char = source[_index];
    switch (char) {
      case '{':
        return _readObject();
      case '[':
        return _readArray();
      case '"':
        return _readString();
      case 't':
        _expect('true');
        return true;
      case 'f':
        _expect('false');
        return false;
      case 'n':
        _expect('null');
        return null;
      default:
        return _readNumber();
    }
  }

  Map<String, Object?> _readObject() {
    _index++; // {
    _skipWhitespace();
    final map = <String, Object?>{};
    if (_peek('}')) {
      _index++;
      return map;
    }
    while (true) {
      _skipWhitespace();
      final key = _readString();
      _skipWhitespace();
      if (!_peek(':')) throw const FormatException('Falta ":" en JSON.');
      _index++;
      _skipWhitespace();
      map[key] = _readValue();
      _skipWhitespace();
      if (_peek(',')) {
        _index++;
        _skipWhitespace();
        continue;
      }
      if (_peek('}')) {
        _index++;
        return map;
      }
      throw const FormatException('Objeto JSON inválido.');
    }
  }

  List<Object?> _readArray() {
    _index++; // [
    _skipWhitespace();
    final list = <Object?>[];
    if (_peek(']')) {
      _index++;
      return list;
    }
    while (true) {
      _skipWhitespace();
      list.add(_readValue());
      _skipWhitespace();
      if (_peek(',')) {
        _index++;
        _skipWhitespace();
        continue;
      }
      if (_peek(']')) {
        _index++;
        return list;
      }
      throw const FormatException('Arreglo JSON inválido.');
    }
  }

  String _readString() {
    if (!_peek('"')) throw const FormatException('Se esperaba una cadena.');
    final start = _index;
    _index++;
    while (_index < source.length) {
      final char = source[_index];
      if (char == '\\') {
        _index += 2;
        continue;
      }
      _index++;
      if (char == '"') {
        final raw = source.substring(start, _index);
        final decoded = jsonDecode(raw);
        if (decoded is! String) {
          throw const FormatException('Cadena JSON inválida.');
        }
        return decoded;
      }
    }
    throw const FormatException('Cadena JSON sin cierre.');
  }

  _JsonNumber _readNumber() {
    final start = _index;
    while (_index < source.length) {
      final code = source.codeUnitAt(_index);
      final isNumber =
          code == 45 || // -
          code == 43 || // +
          code == 46 || // .
          code == 69 || // E
          code == 101 || // e
          (code >= 48 && code <= 57); // 0-9
      if (!isNumber) break;
      _index++;
    }
    if (_index == start) {
      throw const FormatException('Número JSON inválido.');
    }
    return _JsonNumber(source.substring(start, _index));
  }

  void _expect(String token) {
    if (!source.startsWith(token, _index)) {
      throw const FormatException('Literal JSON inválido.');
    }
    _index += token.length;
  }

  bool _peek(String char) => _index < source.length && source[_index] == char;

  void _skipWhitespace() {
    while (_index < source.length) {
      final char = source[_index];
      if (char != ' ' && char != '\n' && char != '\r' && char != '\t') return;
      _index++;
    }
  }
}

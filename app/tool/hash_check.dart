import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Object? sortValue(Object? value) {
  if (value is List) return value.map(sortValue).toList();
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {for (final key in keys) key: sortValue(value[key])};
  }
  return value;
}

void main(List<String> args) {
  final raw = jsonDecode(File(args.first).readAsStringSync()) as Map;
  final paquete = (raw['paquete'] ?? raw) as Map;
  final meta = (paquete['meta'] ?? const {}) as Map;
  final canonical = jsonEncode(
    sortValue({
      'extras': paquete['extras'] ?? const {},
      'nucleo': paquete['nucleo'],
    }),
  );
  final hash = 'sha256:${sha256.convert(utf8.encode(canonical))}';
  stdout.writeln('expected: ${meta['hash']}');
  stdout.writeln('computed: $hash');
  stdout.writeln('match: ${hash == meta['hash']}');
  stdout.writeln(
    'types: lluvia=${paquete['nucleo']['calendario'][0]['lluvia_mm'].runtimeType} mes=${paquete['nucleo']['calendario'][0]['mes'].runtimeType}',
  );
}

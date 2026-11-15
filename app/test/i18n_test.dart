import 'package:flutter_test/flutter_test.dart';
import 'package:muyuy/data/soil_profiles.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/services/agrovision/agrovision_service.dart';

void main() {
  test('AgroVision y suelo tienen texto en inglés', () {
    final keys = [
      ...leafLabels,
      'agro.title',
      'agro.intro',
      'agro.takePhoto',
      'agro.result',
      'agro.err.camera',
      'soil.msg.qualityFail',
      'soil.check.light',
      'soil.check.light.hint',
    ];
    for (final key in keys) {
      final en = tr(AppLang.en, key);
      expect(en, isNot(key), reason: 'falta la clave $key');
      expect(en, isNot(tr(AppLang.es, key)), reason: '$key sin traducir');
    }
  });

  test('perfil de suelo en el idioma elegido', () {
    expect(soilProfileFor(2, AppLang.en).label, 'Clay soil');
    expect(soilProfileFor(2).label, 'Suelo arcilloso');
    expect(soilProfileFor(2, AppLang.en).key, soilProfileFor(2).key);
  });
}

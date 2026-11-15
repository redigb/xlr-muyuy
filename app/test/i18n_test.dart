import 'package:flutter_test/flutter_test.dart';
import 'package:muyuy/data/crop_diseases.dart';
import 'package:muyuy/data/soil_profiles.dart';
import 'package:muyuy/l10n/strings.dart';
import 'package:muyuy/services/agrovision/agrovision_service.dart';

void main() {
  test('AgroVision y suelo tienen texto en inglés', () {
    final keys = [
      ...leafLabels,
      'agro.title',
      'agro.intro',
      'agro.camera',
      'agro.err.camera',
      'agro.subtitle',
      'agro.causes',
      'agro.treatment',
      'agro.prevention',
      'agro.symptoms',
      'agro.tip',
      'agro.disclaimer',
      'agro.risk.low',
      'agro.risk.medium',
      'agro.risk.high',
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

  test('ficha de enfermedad completa en ambos idiomas', () {
    expect(cropDiseases.length, leafLabels.length);
    expect(cropDiseasesEn.length, leafLabels.length);
    for (var i = 0; i < leafLabels.length; i++) {
      final es = cropDiseaseFor(i);
      final en = cropDiseaseFor(i, AppLang.en);
      expect(es.index, i);
      expect(en.index, i);
      expect(es.key, en.key);
      for (final list in [
        es.symptoms,
        es.causes,
        es.treatment,
        es.prevention,
        en.symptoms,
        en.causes,
        en.treatment,
        en.prevention,
      ]) {
        expect(list, isNotEmpty, reason: 'clase $i sin contenido');
      }
      expect(es.summary, isNot(en.summary));
    }
    expect(cropDiseaseFor(9).healthy, isTrue);
    expect(cropDiseaseFor(9, AppLang.en).healthy, isTrue);
  });
}

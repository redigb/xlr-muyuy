import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'package_repository.dart';

enum ShareOutcome { shared, copied }

class ShareService {
  ShareService(this._repository);

  final PackageRepository _repository;

  Future<ShareBundle> prepare(Paquete paquete) {
    return _repository.prepareShare(paquete);
  }

  Future<ShareOutcome> sharePackage(Paquete paquete) async {
    final bundle = await _repository.prepareShare(paquete);
    if (!kIsWeb && bundle.filePath != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(bundle.filePath!)],
          subject: 'Paquete MUYUY · ${paquete.zona.nombre}',
          title: 'Compartir paquete MUYUY',
          text:
              'Paquete de datos MUYUY para ${paquete.zona.nombre}. '
              'Ábrelo en la app para ver calendario y rotaciones sin señal.',
        ),
      );
      return ShareOutcome.shared;
    }
    await Clipboard.setData(ClipboardData(text: bundle.json));
    return ShareOutcome.copied;
  }

  String qrPayload(Paquete paquete) {
    return 'muyuy://paquete?zona=${paquete.zona.id}'
        '&version=${paquete.packageVersion}'
        '&hash=${Uri.encodeComponent(paquete.hash)}';
  }
}

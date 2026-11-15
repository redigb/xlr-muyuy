import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'package_repository.dart';

enum ShareOutcome { shared, copied }

class ShareService {
  ShareService(this._repository);

  final PackageRepository _repository;

  Future<ShareBundle> prepare(Paquete paquete, {required String compartidoPor}) {
    return _repository.prepareShare(paquete, compartidoPor: compartidoPor);
  }

  /// Envía el archivo (Quick Share / Bluetooth). En web lo copia al portapapeles.
  Future<ShareOutcome> sharePackage(
    Paquete paquete, {
    required String compartidoPor,
    String subject = 'MUYUY',
    String text = '',
  }) async {
    final bundle = await prepare(paquete, compartidoPor: compartidoPor);
    if (!kIsWeb && bundle.filePath != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(bundle.filePath!, mimeType: 'application/json')],
          subject: subject,
          title: subject,
          // share_plus rechaza text vacío ("cannot be empty"): solo si hay.
          text: text.isEmpty ? null : text,
        ),
      );
      return ShareOutcome.shared;
    }
    await Clipboard.setData(ClipboardData(text: bundle.json));
    return ShareOutcome.copied;
  }

  /// QR = solo `{zona|celda, version, hash corto, compartido_por}` (spec 3.5).
  String qrPayload(Paquete paquete, {required String compartidoPor}) {
    final params = {
      if (paquete.meta.celda.isNotEmpty)
        'celda': paquete.meta.celda
      else
        'zona': paquete.clave,
      'v': '${paquete.packageVersion}',
      'h': _hexCorto(paquete.hash),
      'de': compartidoPor,
    };
    return Uri(scheme: 'muyuy', host: 'paquete', queryParameters: params)
        .toString();
  }

  static String _hexCorto(String hash) {
    final hex = hash.startsWith('sha256:') ? hash.substring(7) : hash;
    return hex.length <= 12 ? hex : hex.substring(0, 12);
  }
}

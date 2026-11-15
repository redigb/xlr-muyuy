import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../models/community.dart';
import '../models/models.dart';
import '../models/soil_analysis.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/package_repository.dart';
import '../services/share_service.dart';

/// Estado de "Usar mi ubicación" (spec 10.1).
enum LocationStatus { idle, locating, calculating, done, fallback }

class AppState extends ChangeNotifier {
  AppState({
    PackageRepository? repository,
    Connectivity? connectivity,
    ShareService? shareService,
    LocationService? locationService,
    AppLang? initialLang,
  }) : _repo = repository ?? PackageRepository(),
       _connectivity = connectivity ?? Connectivity(),
       _location = locationService ?? LocationService(),
       _lang = initialLang ?? _deviceLang() {
    _sharing = shareService ?? ShareService(_repo);
  }

  final PackageRepository _repo;
  final Connectivity _connectivity;
  final LocationService _location;
  late final ShareService _sharing;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  bool _initializing = true;
  bool _online = true;
  bool _apiHealthy = false;
  bool _loadingPackage = false;
  bool _downloading = false;
  bool _syncingCommunity = false;
  String? _lastError;
  String? _notice;
  String? _communityMessage;

  AppLang _lang;
  String _localId = '';
  List<Zona> _zonas = List<Zona>.of(DemoData.zonas);
  Zona? _zona;
  Paquete? _paquete;
  PackageOrigin? _origin;
  String? _cultivoInicial;
  int _pendingObservations = 0;
  int _pendingConexiones = 0;
  List<Reporte> _reportes = const [];
  SoilRecord? _lastSoil;
  LocationStatus _locationStatus = LocationStatus.idle;

  Set<String> _prioridades = {'riesgo', 'ingresos'};
  bool _riego = false;

  // ---------------------------------------------------------------- getters

  bool get initializing => _initializing;
  bool get online => _online;
  bool get apiHealthy => _apiHealthy;
  bool get loadingPackage => _loadingPackage;
  bool get downloading => _downloading;
  bool get syncingCommunity => _syncingCommunity;
  String? get lastError => _lastError;
  String? get notice => _notice;
  String? get communityMessage => _communityMessage;

  /// Idioma de la interfaz (es / en / qu).
  AppLang get lang => _lang;

  /// Traduce una clave de `lib/l10n/strings.dart` al idioma actual.
  String t(String key, [Map<String, Object?> args = const {}]) =>
      tr(_lang, key, args);

  /// `true` en la demo web para el jurado (observaciones con `demo: true`).
  bool get isDemo => kIsWeb;

  /// ID anónimo de este celular (va en el `sobre` y en las conexiones).
  String get localId => _localId;

  List<Zona> get zonas => _zonas;
  Zona? get zona => _zona;
  Paquete? get paquete => _paquete;
  PackageOrigin? get origin => _origin;
  String? get cultivoInicial => _cultivoInicial;
  int get pendingObservations => _pendingObservations;
  int get pendingConexiones => _pendingConexiones;

  /// Historial de reportes con su estado (⏳ / ✅), más nuevos primero.
  List<Reporte> get reportes => _reportes;
  SoilRecord? get lastSoil => _lastSoil;
  LocationStatus get locationStatus => _locationStatus;
  bool get locating =>
      _locationStatus == LocationStatus.locating ||
      _locationStatus == LocationStatus.calculating;
  Set<String> get prioridades => Set.unmodifiable(_prioridades);
  bool get riego => _riego;
  bool get canContinue => _prioridades.length == 2;
  bool get hasPackage => _paquete != null;
  bool get hasZona => _zona != null;
  String get apiBaseUrl => _repo.apiBaseUrl;
  ShareService get sharing => _sharing;
  List<Alerta> get alertas => _paquete?.alertas ?? const [];

  /// `false` para paquetes por coordenada: mostrar aviso 🟡.
  bool get validadaLocalmente => _paquete?.validadaLocalmente ?? true;

  /// Vigencia por sección (`calendario`, `condiciones`, `alertas`).
  Map<String, ValidityState> get vigencias => _paquete?.vigencias ?? const {};

  bool seccionVencida(String seccion) =>
      vigencias[seccion] == ValidityState.expired;

  List<String> get cultivosIniciales {
    final current = _zona;
    if (current != null && current.cultivosIniciales.isNotEmpty) {
      return current.cultivosIniciales;
    }
    final seen = <String>{};
    for (final rotation in _paquete?.rotaciones ?? const <Rotacion>[]) {
      if (rotation.cultivoInicial.isNotEmpty) {
        seen.add(rotation.cultivoInicial);
      }
    }
    return seen.toList();
  }

  Rotacion? get rotacionActual {
    final data = _paquete;
    if (data == null) return null;
    final candidatas = _filtradas(data);
    for (final rotacion in candidatas) {
      if (rotacion.esPracticaComun) return rotacion;
    }
    final practice = _zona?.practicaComun ?? const <String>[];
    if (practice.isNotEmpty) {
      for (final rotation in candidatas) {
        if (_sameSequence(rotation.secuencia, practice)) return rotation;
      }
    }
    return null;
  }

  /// Todas las candidatas del cultivo actual, ordenadas por prioridades.
  List<Rotacion> get rotacionesTodas {
    final data = _paquete;
    if (data == null) return const [];
    return Scoring.ordenar(_filtradas(data), _prioridades);
  }

  List<Rotacion> get rotacionesOrdenadas => rotacionesTodas;

  /// Las 3 que se muestran (spec 4.4): práctica común (si existe) + 2 mejores.
  List<Rotacion> get rotacionesRecomendadas {
    final todas = rotacionesTodas;
    final actual = rotacionActual;
    if (actual == null) return todas.take(3).toList();
    return [
      actual,
      ...todas.where((item) => item.id != actual.id).take(2),
    ];
  }

  double puntaje(Rotacion rotacion) => rotacion.puntajeFinal(_prioridades);

  // ------------------------------------------------------------ ciclo de vida

  /// En el APK el splash se ve al menos esto: sin parpadeo si los datos cargan en milisegundos.
  static const minSplash = Duration(milliseconds: 900);

  Future<void> initialize() async {
    final reloj = Stopwatch()..start();
    try {
      final storedLang = await _repo.readLang();
      if (storedLang != null) _lang = AppLangInfo.fromCode(storedLang);
      _localId = await _ensureLocalId();

      final storedZone = await _repo.readZonaId();
      final storedPrioridades = await _repo.readPrioridades();
      final storedCrop = await _repo.readCultivoId();
      if (storedPrioridades.length == 2) {
        _prioridades = LinkedHashSet<String>.of(storedPrioridades);
      }

      final targetId = storedZone.isNotEmpty
          ? storedZone
          : PackageRepository.fallbackZona;
      await _openZona(targetId);
      _resolveInitialCrop(storedCrop);
      await _reloadPendingCounts();
      _reportes = await _repo.readReportes();
    } finally {
      final falta = minSplash - reloj.elapsed;
      if (kReleaseMode && falta > Duration.zero) await Future<void>.delayed(falta);
      _initializing = false;
      notifyListeners();
    }

    unawaited(_watchConnectivity());
    unawaited(_syncInBackground());
  }

  Future<void> setLang(AppLang value) async {
    if (_lang == value) return;
    final cambiaApi = _lang.apiLang != value.apiLang;
    _lang = value;
    notifyListeners();
    await _repo.saveLang(value.code);
    // Las explicaciones del paquete vienen en el idioma pedido (es / en).
    if (cambiaApi && _online) unawaited(_refreshSilently(_zona?.id ?? ''));
  }

  /// El paquete instalado está al día si es la versión del servidor y en el idioma actual.
  bool _alDia(Paquete? current, int remoteVersion) =>
      current != null &&
      current.meta.idioma == _lang.apiLang &&
      current.packageVersion >= remoteVersion;

  Future<void> selectZona(Zona zona) async {
    if (_zona?.id == zona.id && _paquete != null) return;
    _loadingPackage = true;
    _lastError = null;
    _notice = null;
    _paquete = null;
    _origin = null;
    _zona = zona;
    notifyListeners();

    await _repo.saveZonaId(zona.id);
    await _openZona(zona.id, zonaHint: zona);
    _resolveInitialCrop(null);

    _loadingPackage = false;
    notifyListeners();

    if (_online) unawaited(_refreshSilently(zona.id));
  }

  Future<bool> downloadCurrent() async {
    final target = _zona;
    if (target == null || _downloading) return false;
    if (_paquete?.esCoordenada ?? false) return false;

    _downloading = true;
    _lastError = null;
    notifyListeners();

    try {
      final remoteInfo = await _repo.fetchVersion(
        target.id,
        lang: _lang.apiLang,
      );
      _apiHealthy = true;
      final current = _paquete;
      if (_alDia(current, remoteInfo.version)) {
        _notice = t('pkg.latest', {'version': current!.packageVersion});
        return true;
      }

      final remote = await _repo.fetchRemote(target.id, lang: _lang.apiLang);
      if (_zona?.id == target.id) {
        _paquete = remote;
        _origin = PackageOrigin.api;
        _notice = t('pkg.downloaded', {'version': remote.packageVersion});
        _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
      }
      return true;
    } on ApiException catch (error) {
      _lastError = error.messageIn(_lang);
      _notice = null;
      return false;
    } catch (_) {
      _lastError = t('pkg.downloadFailed');
      return false;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------- "Mi chacra"

  void togglePrioridad(String factor) {
    if (_prioridades.contains(factor)) {
      if (_prioridades.length == 1) return;
      _prioridades.remove(factor);
    } else {
      if (_prioridades.length >= 2) {
        _prioridades.remove(_prioridades.first);
      }
      _prioridades.add(factor);
    }
    notifyListeners();
    unawaited(_repo.savePrioridades(_prioridades));
  }

  void setRiego(bool value) {
    if (_riego == value) return;
    _riego = value;
    notifyListeners();
    final zonaId = _zona?.id;
    if (zonaId != null) unawaited(_repo.saveRiego(zonaId, value));
    // Paquete de ubicación: con riego entran cultivos que la lluvia sola descartaba.
    final actual = _paquete;
    if (actual != null && actual.esCoordenada && _online) {
      unawaited(_refetchCoordenada(actual, value));
    }
  }

  Future<void> _refetchCoordenada(Paquete actual, bool riego) async {
    try {
      final nuevo = await _repo.fetchCoordenada(
        lat: actual.zona.lat,
        lon: actual.zona.lon,
        lang: _lang.apiLang,
        riego: riego,
      );
      if (_paquete?.clave != actual.clave || _riego != riego) return;
      _installActive(nuevo, PackageOrigin.location);
      _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
      notifyListeners();
    } catch (_) {
      // Sin señal o servidor caído: se queda el paquete actual.
    }
  }

  void setCultivoInicial(String cultivoId) {
    if (_cultivoInicial == cultivoId) return;
    _cultivoInicial = cultivoId;
    notifyListeners();
    unawaited(_repo.saveCultivoId(cultivoId));
  }

  // --------------------------------------------- "Usar mi ubicación" (P1)

  /// Pide la ubicación, calcula un paquete para esa celda y, si algo falla
  /// (permiso, señal, servidor o > 30 s), vuelve a Huánuco sin pantalla de error.
  Future<void> useMyLocation() async {
    if (locating) return;
    _locationStatus = LocationStatus.locating;
    _lastError = null;
    _notice = null;
    notifyListeners();

    if (!_online) {
      await _fallbackToHuanuco('location.fallback.offline');
      return;
    }

    final result = await _location.current();
    final position = result.position;
    if (position == null) {
      await _fallbackToHuanuco(switch (result.issue) {
        LocationIssue.serviceOff => 'location.fallback.gpsOff',
        LocationIssue.denied => 'location.fallback.denied',
        _ => 'location.fallback.noFix',
      });
      return;
    }

    _locationStatus = LocationStatus.calculating;
    notifyListeners();

    try {
      final paquete = await _repo
          .fetchCoordenada(
            lat: position.lat,
            lon: position.lon,
            lang: _lang.apiLang,
            riego: _riego,
          )
          .timeout(ApiService.coordenadaTimeout);
      _installActive(paquete, PackageOrigin.location);
      await _repo.saveZonaId(paquete.clave);
      _riego = await _repo.readRiego(paquete.clave) ?? paquete.zona.riego;
      _lastSoil = await _repo.readSoil(paquete.clave);
      _resolveInitialCrop(null);
      _apiHealthy = true;
      _locationStatus = LocationStatus.done;
      _notice = paquete.esCoordenada
          ? t('location.ok')
          : t('location.official', {'zona': _zona?.nombre ?? paquete.zona.nombre});
      notifyListeners();
    } catch (_) {
      await _fallbackToHuanuco('location.fallback.failed');
    }
  }

  Future<void> _fallbackToHuanuco(String noticeKey) async {
    final huanuco =
        _findZona(PackageRepository.fallbackZona) ?? DemoData.zonas.first;
    _paquete = null;
    _zona = huanuco;
    await _repo.saveZonaId(huanuco.id);
    await _openZona(huanuco.id, zonaHint: huanuco);
    _resolveInitialCrop(null);
    _locationStatus = LocationStatus.fallback;
    _notice = t(noticeKey);
    notifyListeners();
  }

  // --------------------------------------------------------- "Reiniciar demo"

  /// Borra el estado local (menos el idioma) y vuelve a Huánuco.
  Future<void> resetDemo() async {
    await _repo.clearAll();
    _localId = await _ensureLocalId();
    _prioridades = {'riesgo', 'ingresos'};
    _reportes = const [];
    _pendingObservations = 0;
    _pendingConexiones = 0;
    _communityMessage = null;
    _lastError = null;
    _locationStatus = LocationStatus.idle;
    _zonas = List<Zona>.of(DemoData.zonas);
    await _openZona(PackageRepository.fallbackZona);
    _resolveInitialCrop(null);
    _notice = t('demo.reset.done');
    notifyListeners();
  }

  // --------------------------------------------------------------- comunidad

  Future<bool> reportObservation(String tipo, {double? valor}) async {
    final currentZone = _zona;
    final data = _paquete;
    if (currentZone == null) return false;
    final now = DateTime.now();
    final celda = (data?.esCoordenada ?? false) ? data!.meta.celda : null;
    final observation = Observacion(
      idLocal: const Uuid().v4(),
      zonaId: currentZone.id,
      celda: celda,
      // Centro de la zona/celda: nunca la ubicación exacta (spec 15).
      latAprox: currentZone.lat,
      lonAprox: currentZone.lon,
      tipo: tipo,
      fechaEvento:
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}',
      demo: isDemo,
      creado: now.toUtc().toIso8601String(),
      valor: valor,
    );

    final pending = [...await _repo.readObservaciones(), observation];
    await _repo.writeObservaciones(pending);
    _reportes = [
      Reporte(
        idLocal: observation.idLocal,
        tipo: tipo,
        fechaEvento: observation.fechaEvento,
        estado: 'por_enviar',
      ),
      ..._reportes,
    ];
    await _repo.writeReportes(_reportes);
    _pendingObservations = pending.length;
    _communityMessage = t(
      _online ? 'community.savedOnline' : 'community.savedOffline',
    );
    notifyListeners();

    if (_online) unawaited(syncCommunity(silent: true));
    return true;
  }

  /// `POST /api/dispositivos` (1.ª vez) + `POST /api/sync` con observaciones
  /// y conexiones guardadas offline.
  Future<void> syncCommunity({bool silent = false}) async {
    if (_syncingCommunity) return;
    final pending = await _repo.readObservaciones();
    final conexiones = await _repo.readConexiones();
    _pendingObservations = pending.length;
    _pendingConexiones = conexiones.length;
    if (pending.isEmpty && conexiones.isEmpty && !_hayReportesEnRevision) {
      if (!silent) {
        _communityMessage = t('community.nothing');
        notifyListeners();
      }
      return;
    }

    _syncingCommunity = true;
    if (!silent) _communityMessage = t('community.syncing');
    notifyListeners();

    try {
      var device = await _repo.readDevice();
      if (device == null) {
        device = await _repo.registerDevice(demo: isDemo, idLocal: _localId);
        await _repo.saveDevice(device);
      }

      SyncSummary summary;
      try {
        summary = await _repo.sync(
          token: device.token,
          observaciones: pending,
          conexiones: conexiones,
        );
      } on ApiAuthException {
        await _repo.clearDevice();
        device = await _repo.registerDevice(demo: isDemo, idLocal: _localId);
        await _repo.saveDevice(device);
        summary = await _repo.sync(
          token: device.token,
          observaciones: pending,
          conexiones: conexiones,
        );
      }

      await _repo.writeObservaciones(const []);
      await _repo.writeConexiones(const []);
      _pendingObservations = 0;
      _pendingConexiones = 0;
      await _applySyncDetalle(summary);
      _apiHealthy = true;
      if (pending.isNotEmpty || !silent) {
        _communityMessage = t('community.synced', {
          'ok': summary.aceptadas,
          'bad': summary.rechazadas,
        });
      }
      notifyListeners();
      unawaited(_refreshSilently(_zona?.id ?? ''));
    } on ApiException catch (error) {
      if (!silent) _communityMessage = error.messageIn(_lang);
      notifyListeners();
    } catch (_) {
      if (!silent) _communityMessage = t('community.retry');
      notifyListeners();
    } finally {
      _syncingCommunity = false;
      notifyListeners();
    }
  }

  void clearCommunityMessage() {
    if (_communityMessage == null) return;
    _communityMessage = null;
    notifyListeners();
  }

  // --------------------------------------------------------- compartir

  Future<ShareOutcome> sharePackage() async {
    final data = _paquete;
    if (data == null) return ShareOutcome.copied;
    return _sharing.sharePackage(data, compartidoPor: _localId);
  }

  String qrPayload() {
    final data = _paquete;
    if (data == null) return '';
    return _sharing.qrPayload(data, compartidoPor: _localId);
  }

  /// Importa un archivo recibido: verifica hash → compara versión →
  /// instala o descarta → registra la conexión `COMPARTIO`.
  Future<bool> importPackage(String rawJson) async {
    try {
      final result = await _repo.importJson(rawJson);
      await _recordConexion(result);

      final imported = result.paquete;
      if (result.outcome == ImportOutcome.installed) {
        final zona = _findZona(imported.clave) ?? imported.zona;
        if (!_zonas.any((item) => item.id == zona.id)) {
          _zonas = [..._zonas, zona];
        }
        _zona = zona;
        _installActive(
          imported,
          imported.esCoordenada
              ? PackageOrigin.location
              : PackageOrigin.imported,
        );
        await _repo.saveZonaId(imported.clave);
        _riego = await _repo.readRiego(imported.clave) ?? zona.riego;
        _lastSoil = await _repo.readSoil(imported.clave);
        _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
        _notice = t('import.ok', {'version': imported.packageVersion});
      } else if (result.outcome == ImportOutcome.older) {
        _notice = t('import.older', {
          'installed': result.installedVersion,
          'incoming': _incomingVersion(rawJson),
        });
      } else {
        _notice = t('import.same', {'version': imported.packageVersion});
      }
      _lastError = null;
      notifyListeners();
      if (_online) unawaited(syncCommunity(silent: true));
      return true;
    } on ImportException catch (error) {
      _lastError = t(error.code);
      _notice = null;
      notifyListeners();
      return false;
    } catch (_) {
      _lastError = t('import.unreadable');
      _notice = null;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_lastError == null && _notice == null) return;
    _lastError = null;
    _notice = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------ suelo

  Future<void> saveSoilAnalysis(SoilRecord record) async {
    _lastSoil = record;
    await _repo.writeSoil(record);
    notifyListeners();
  }

  Future<void> correctSoil(int correctedIndex) async {
    final current = _lastSoil;
    if (current == null || current.effectiveIndex == correctedIndex) return;
    final updated = current.withCorrection(correctedIndex);
    _lastSoil = updated;
    await _repo.writeSoil(updated);
    notifyListeners();
    await reportObservation('otro', valor: correctedIndex.toDouble());
  }

  // ---------------------------------------------------------------- privado

  static AppLang _deviceLang() {
    // APK: inglés por defecto (jurado internacional); el agricultor cambia a ES/QU en Inicio.
    if (!kIsWeb) return AppLang.en;
    // En la web (jurado): idioma del navegador; español solo si lo pide.
    final code = PlatformDispatcher.instance.locale.languageCode;
    if (code == 'es') return AppLang.es;
    if (code == 'qu') return AppLang.qu;
    return AppLang.en;
  }

  Future<String> _ensureLocalId() async {
    final stored = await _repo.readLocalId();
    if (stored != null && stored.isNotEmpty) return stored;
    final id = 'disp-${const Uuid().v4()}';
    await _repo.saveLocalId(id);
    return id;
  }

  Future<void> _openZona(String zonaId, {Zona? zonaHint}) async {
    final local = await _repo.loadLocal(zonaId);
    if (local == null) {
      _zona = zonaHint ?? _findZona(zonaId) ?? DemoData.zonas.first;
      _paquete = null;
      _origin = null;
    } else {
      _zona = zonaHint ?? _findZona(local.paquete.clave) ?? local.paquete.zona;
      if (!_zonas.any((item) => item.id == _zona!.id)) {
        _zonas = [..._zonas, _zona!];
      }
      _paquete = local.paquete;
      _origin = local.origin;
    }
    final id = _zona!.id;
    _riego = await _repo.readRiego(id) ?? _zona!.riego;
    _lastSoil = await _repo.readSoil(id);
  }

  void _installActive(Paquete paquete, PackageOrigin origin) {
    _paquete = paquete;
    _origin = origin;
    if (paquete.esCoordenada) {
      _zona = paquete.zona;
      if (!_zonas.any((item) => item.id == paquete.clave)) {
        _zonas = [..._zonas, paquete.zona];
      }
    } else if (origin == PackageOrigin.location) {
      // Cerca de una zona oficial el servidor entrega el paquete validado de esa zona.
      _zona = _findZona(paquete.clave) ?? paquete.zona;
    }
  }

  Future<void> _recordConexion(ImportResult result) async {
    final origen = result.compartidoPor;
    if (origen == null || origen.isEmpty || origen == _localId) return;
    final conexion = Conexion(
      origen: origen,
      destino: _localId,
      paquete: result.paquete.etiquetaVersion,
      fecha: DateTime.now().toUtc().toIso8601String(),
      demo: isDemo,
    );
    final existing = await _repo.readConexiones();
    if (existing.any((item) => item.sameAs(conexion))) return;
    final updated = [...existing, conexion];
    await _repo.writeConexiones(updated);
    _pendingConexiones = updated.length;
  }

  /// Versión del archivo descartado (solo para el mensaje).
  int? _incomingVersion(String rawJson) {
    final match = RegExp(r'"version"\s*:\s*(\d+)').firstMatch(rawJson);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Reportes enviados que el consenso todavía puede cambiar.
  bool get _hayReportesEnRevision =>
      _reportes.any((r) => r.estado == 'pendiente' || r.estado == 'sospechosa');

  Future<void> _applySyncDetalle(SyncSummary summary) async {
    if (_reportes.isEmpty) return;
    // `estados` = estado ACTUAL en el servidor; `detalle` = lo recién enviado (gana).
    final byId = {
      for (final item in summary.estados) item.idLocal: item,
      for (final item in summary.detalle) item.idLocal: item,
    };
    _reportes = [
      for (final reporte in _reportes)
        if (byId[reporte.idLocal] case final detalle?)
          reporte.withEstado(
            detalle.aceptada
                ? _normalizeEstado(detalle.estado)
                : 'rechazada',
            puntaje: detalle.puntaje,
          )
        else if (!reporte.enviado)
          reporte.withEstado('pendiente')
        else
          reporte,
    ];
    await _repo.writeReportes(_reportes);
  }

  String _normalizeEstado(String raw) {
    switch (raw.toLowerCase()) {
      case 'validada':
      case 'validated':
        return 'validada';
      case 'sospechosa':
      case 'suspicious':
        return 'sospechosa';
      default:
        return 'pendiente';
    }
  }

  Future<void> _reloadPendingCounts() async {
    _pendingObservations = (await _repo.readObservaciones()).length;
    _pendingConexiones = (await _repo.readConexiones()).length;
  }

  Future<void> _syncInBackground() async {
    if (!_online) return;

    _apiHealthy = await _repo.checkHealth();
    notifyListeners();

    try {
      final remoteZonas = await _repo.fetchZonas();
      if (remoteZonas.isNotEmpty) {
        _zonas = _mergeZonas(_zonas, remoteZonas);
        notifyListeners();
      }
    } catch (_) {
      // La lista incluida mantiene la app usable sin señal.
    }

    final target = _zona;
    if (target != null) await _refreshSilently(target.id);
    if (_pendingObservations > 0 ||
        _pendingConexiones > 0 ||
        _hayReportesEnRevision) {
      unawaited(syncCommunity(silent: true));
    }
  }

  /// Con señal: `GET /version` y descarga solo si hay una versión MAYOR.
  Future<void> _refreshSilently(String zonaId) async {
    if (zonaId.isEmpty || (_paquete?.esCoordenada ?? false)) return;
    try {
      final info = await _repo.fetchVersion(zonaId, lang: _lang.apiLang);
      _apiHealthy = true;
      if (_alDia(_paquete, info.version)) {
        notifyListeners();
        return;
      }
      final remote = await _repo.fetchRemote(zonaId, lang: _lang.apiLang);
      if (_zona?.id != zonaId) return;
      _paquete = remote;
      _origin = PackageOrigin.api;
      _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
      notifyListeners();
    } catch (_) {
      _apiHealthy = false;
      notifyListeners();
    }
  }

  Future<void> _watchConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _setOnline(!results.contains(ConnectivityResult.none));
    } catch (_) {
      _setOnline(true);
    }

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = !results.contains(ConnectivityResult.none);
      _setOnline(isOnline);
      if (isOnline) unawaited(_syncInBackground());
    });
  }

  void _setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
  }

  List<Rotacion> _filtradas(Paquete data) {
    final crop = _cultivoInicial;
    if (crop == null || crop.isEmpty) return data.rotaciones;
    final filtered = data.rotaciones
        .where((item) => item.cultivoInicial == crop)
        .toList();
    return filtered.isEmpty ? data.rotaciones : filtered;
  }

  void _resolveInitialCrop(String? stored, {bool keepCurrent = false}) {
    final available = cultivosIniciales;
    if (available.isEmpty) {
      _cultivoInicial = null;
      return;
    }
    if (keepCurrent &&
        _cultivoInicial != null &&
        available.contains(_cultivoInicial)) {
      return;
    }
    if (stored != null && available.contains(stored)) {
      _cultivoInicial = stored;
      unawaited(_repo.saveCultivoId(stored));
      return;
    }
    _cultivoInicial = available.first;
    unawaited(_repo.saveCultivoId(available.first));
  }

  bool _sameSequence(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<Zona> _mergeZonas(List<Zona> current, List<Zona> remote) {
    final byId = <String, Zona>{for (final zona in current) zona.id: zona};
    for (final zona in remote) {
      byId[zona.id] = zona;
    }
    return byId.values.toList();
  }

  Zona? _findZona(String id) {
    for (final zona in _zonas) {
      if (zona.id == id) return zona;
    }
    return DemoData.zona(id);
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _repo.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado en el árbol de widgets.');
    return scope!.notifier!;
  }
}

/// Atajo para la UI: `context.tr('clave')`.
extension AppTr on BuildContext {
  String tr(String key, [Map<String, Object?> args = const {}]) =>
      AppScope.of(this).t(key, args);
}

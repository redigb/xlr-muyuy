import 'dart:async';
import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../data/demo_data.dart';
import '../models/community.dart';
import '../models/models.dart';
import '../models/soil_analysis.dart';
import '../services/api_service.dart';
import '../services/package_repository.dart';
import '../services/share_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    PackageRepository? repository,
    Connectivity? connectivity,
    ShareService? shareService,
  }) : _repo = repository ?? PackageRepository(),
       _connectivity = connectivity ?? Connectivity() {
    _sharing = shareService ?? ShareService(_repo);
  }

  final PackageRepository _repo;
  final Connectivity _connectivity;
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

  List<Zona> _zonas = List<Zona>.of(DemoData.zonas);
  Zona? _zona;
  Paquete? _paquete;
  PackageOrigin? _origin;
  String? _cultivoInicial;
  int _pendingObservations = 0;
  SoilRecord? _lastSoil;

  Set<String> _prioridades = {'riesgo', 'ingresos'};
  bool _riego = false;

  bool get initializing => _initializing;
  bool get online => _online;
  bool get apiHealthy => _apiHealthy;
  bool get loadingPackage => _loadingPackage;
  bool get downloading => _downloading;
  bool get syncingCommunity => _syncingCommunity;
  String? get lastError => _lastError;
  String? get notice => _notice;
  String? get communityMessage => _communityMessage;
  List<Zona> get zonas => _zonas;
  Zona? get zona => _zona;
  Paquete? get paquete => _paquete;
  PackageOrigin? get origin => _origin;
  String? get cultivoInicial => _cultivoInicial;
  int get pendingObservations => _pendingObservations;
  SoilRecord? get lastSoil => _lastSoil;
  Set<String> get prioridades => Set.unmodifiable(_prioridades);
  bool get riego => _riego;
  bool get canContinue => _prioridades.length == 2;
  bool get hasPackage => _paquete != null;
  bool get hasZona => _zona != null;
  String get apiBaseUrl => _repo.apiBaseUrl;
  ShareService get sharing => _sharing;
  List<Alerta> get alertas => _paquete?.alertas ?? const [];

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
    for (final rotacion in data.rotaciones) {
      if (rotacion.esPracticaComun) return rotacion;
    }
    final practice = _zona?.practicaComun ?? const <String>[];
    if (practice.isNotEmpty) {
      for (final rotation in data.rotaciones) {
        if (_sameSequence(rotation.secuencia, practice)) return rotation;
      }
    }
    return data.rotaciones.isEmpty ? null : data.rotaciones.first;
  }

  List<Rotacion> get rotacionesTodas {
    final data = _paquete;
    if (data == null) return const [];
    final crop = _cultivoInicial;
    final filtered = crop == null || crop.isEmpty
        ? data.rotaciones
        : data.rotaciones.where((item) => item.cultivoInicial == crop).toList();
    return Scoring.ordenar(
      filtered.isEmpty ? data.rotaciones : filtered,
      _prioridades,
    );
  }

  List<Rotacion> get rotacionesOrdenadas => rotacionesTodas;

  double puntaje(Rotacion rotacion) {
    return rotacion.puntajeFinal(_prioridades);
  }

  Future<void> initialize() async {
    try {
      final storedZone = await _repo.readZonaId();
      final storedPrioridades = await _repo.readPrioridades();
      final storedCrop = await _repo.readCultivoId();
      if (storedPrioridades.length == 2) {
        _prioridades = LinkedHashSet<String>.of(storedPrioridades);
      }

      final targetId = storedZone.isNotEmpty ? storedZone : 'huanuco-sierra';
      _zona = _findZona(targetId) ?? DemoData.zonas.first;
      await _loadLocal(_zona!.id);
      await _loadSoil(_zona!.id);
      _riego = _zona?.riego ?? await _repo.readRiego();
      _resolveInitialCrop(storedCrop);
      _pendingObservations = (await _repo.readObservaciones()).length;
    } finally {
      _initializing = false;
      notifyListeners();
    }

    unawaited(_watchConnectivity());
    unawaited(_syncInBackground());
    if (_pendingObservations > 0) {
      unawaited(syncCommunity(silent: true));
    }
  }

  Future<void> selectZona(Zona zona) async {
    if (_zona?.id == zona.id && _paquete != null) return;
    _zona = zona;
    _paquete = null;
    _origin = null;
    _loadingPackage = true;
    _lastError = null;
    _notice = null;
    notifyListeners();

    await _repo.saveZonaId(zona.id);
    await _loadLocal(zona.id);
    await _loadSoil(zona.id);
    _riego = zona.riego;
    _resolveInitialCrop(null);

    _loadingPackage = false;
    notifyListeners();

    if (_online) {
      unawaited(_refreshSilently(zona.id));
    }
  }

  Future<bool> downloadCurrent() async {
    final target = _zona;
    if (target == null || _downloading) return false;

    _downloading = true;
    _lastError = null;
    notifyListeners();

    try {
      final remoteInfo = await _repo.fetchVersion(target.id);
      _apiHealthy = true;
      final current = _paquete;
      if (current != null &&
          current.packageVersion == remoteInfo.version &&
          current.hash == remoteInfo.hash) {
        _notice = 'Ya tienes la última versión (v${remoteInfo.version}).';
        return true;
      }

      final remote = await _repo.fetchRemote(target.id);
      if (_zona?.id == target.id) {
        _paquete = remote;
        _origin = PackageOrigin.api;
        _notice =
            'Paquete v${remote.packageVersion} verificado y guardado en el celular.';
        _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
      }
      return true;
    } on ApiException catch (error) {
      _lastError = error.message;
      _notice = null;
      return false;
    } catch (_) {
      _lastError = 'No se pudo descargar el paquete. Usando la copia local.';
      return false;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

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
    unawaited(_repo.saveRiego(value));
  }

  void setCultivoInicial(String cultivoId) {
    if (_cultivoInicial == cultivoId) return;
    _cultivoInicial = cultivoId;
    notifyListeners();
    unawaited(_repo.saveCultivoId(cultivoId));
  }

  Future<bool> reportObservation(String tipo, {double? valor}) async {
    final currentZone = _zona;
    if (currentZone == null) return false;
    final now = DateTime.now();
    final observation = Observacion(
      idLocal: const Uuid().v4(),
      zonaId: currentZone.id,
      tipo: tipo,
      fechaEvento:
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}',
      demo: kIsWeb,
      creado: now.toUtc().toIso8601String(),
      valor: valor,
    );

    final pending = [...await _repo.readObservaciones(), observation];
    await _repo.writeObservaciones(pending);
    _pendingObservations = pending.length;
    _communityMessage = _online
        ? 'Reporte guardado. Enviando a la comunidad…'
        : 'Reporte guardado. Se enviará cuando vuelva la señal.';
    notifyListeners();

    if (_online) {
      unawaited(syncCommunity(silent: true));
    }
    return true;
  }

  Future<void> syncCommunity({bool silent = false}) async {
    if (_syncingCommunity) return;
    final pending = await _repo.readObservaciones();
    _pendingObservations = pending.length;
    if (pending.isEmpty) {
      if (!silent) {
        _communityMessage = 'No hay reportes pendientes de enviar.';
        notifyListeners();
      }
      return;
    }

    _syncingCommunity = true;
    if (!silent) {
      _communityMessage = 'Sincronizando reportes…';
    }
    notifyListeners();

    try {
      var device = await _repo.readDevice();
      if (device == null) {
        device = await _repo.registerDevice(demo: kIsWeb);
        await _repo.saveDevice(device);
      }

      SyncSummary summary;
      try {
        summary = await _repo.sync(token: device.token, observaciones: pending);
      } on ApiAuthException {
        await _repo.clearDevice();
        device = await _repo.registerDevice(demo: kIsWeb);
        await _repo.saveDevice(device);
        summary = await _repo.sync(token: device.token, observaciones: pending);
      }

      await _repo.writeObservaciones(const []);
      _pendingObservations = 0;
      _apiHealthy = true;
      _communityMessage =
          '${summary.aceptadas} reporte(s) enviados. '
          '${summary.rechazadas} rechazado(s).';
      notifyListeners();
      unawaited(_refreshSilently(_zona?.id ?? ''));
    } on ApiException catch (error) {
      _communityMessage = error.message;
      notifyListeners();
    } catch (_) {
      _communityMessage = 'No se pudieron enviar los reportes. Se reintentará.';
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

  Future<bool> importPackage(String rawJson) async {
    try {
      final imported = await _repo.importJson(rawJson);
      _paquete = imported;
      _origin = PackageOrigin.imported;
      _zona = _findZona(imported.zona.id) ?? imported.zona;
      if (!_zonas.any((item) => item.id == imported.zona.id)) {
        _zonas = [..._zonas, imported.zona];
      }
      await _repo.saveZonaId(imported.zona.id);
      await _loadSoil(imported.zona.id);
      _riego = imported.zona.riego;
      _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
      _lastError = null;
      _notice = 'Paquete importado y verificado. Ya funciona sin señal.';
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = error is FormatException
          ? error.message
          : 'No se pudo leer el archivo del paquete.';
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

  Future<void> _loadSoil(String zonaId) async {
    _lastSoil = await _repo.readSoil(zonaId);
  }

  Future<void> _loadLocal(String zonaId) async {
    final local = await _repo.loadLocal(zonaId);
    if (local == null) {
      _paquete = null;
      _origin = null;
      return;
    }
    _paquete = local.paquete;
    _origin = local.origin;
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
      // The bundled zone list keeps the app fully usable offline.
    }

    final target = _zona;
    if (target == null || _origin == PackageOrigin.imported) return;
    await _refreshSilently(target.id);
    if (_pendingObservations > 0) {
      unawaited(syncCommunity(silent: true));
    }
  }

  Future<void> _refreshSilently(String zonaId) async {
    if (zonaId.isEmpty) return;
    try {
      final info = await _repo.fetchVersion(zonaId);
      _apiHealthy = true;
      final current = _paquete;
      if (current != null &&
          current.packageVersion == info.version &&
          current.hash == info.hash) {
        notifyListeners();
        return;
      }
    } catch (_) {
      _apiHealthy = false;
      notifyListeners();
      return;
    }

    final remote = await _repo.fetchRemoteSilently(zonaId);
    if (remote == null || _zona?.id != zonaId) return;
    _paquete = remote;
    _origin = PackageOrigin.api;
    _resolveInitialCrop(_cultivoInicial, keepCurrent: true);
    notifyListeners();
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
      if (isOnline) {
        unawaited(_syncInBackground());
      }
    });
  }

  void _setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
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

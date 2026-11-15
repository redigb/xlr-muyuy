import 'package:material_ui/material_ui.dart';

import '../../data/soil_profiles.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import '../../widgets/crop_icon.dart';
import '../../widgets/soft_card.dart';
import 'parcel_scene.dart';
import 'rotation_sim.dart';

/// Tu chacra en 3D: los 3 sectores son las 3 campañas de la rotación
/// recomendada (como las aynoqas andinas: cada año los cultivos avanzan un
/// sector). El deslizador recorre los meses desde la siembra con el clima NASA.
class FarmParcelView extends StatefulWidget {
  const FarmParcelView({super.key});

  @override
  State<FarmParcelView> createState() => _FarmParcelViewState();
}

class _FarmParcelViewState extends State<FarmParcelView>
    with SingleTickerProviderStateMixin {
  static const _angle0 = -0.5, _tilt0 = 0.6;

  double _angle = _angle0;
  double _tilt = _tilt0;
  double _zoom = 1;
  double _startZoom = 1;
  Offset _lastFocal = Offset.zero;
  int? _sector;
  int _year = 0;
  int _month = 4; // meses desde la siembra

  ParcelScene? _scene;
  String? _sceneKey;

  // Simulación de 3 años: animación continua (60 fps), ~1,1 s por mes.
  static const _months = RotationSim.years * 12;
  late final AnimationController _sim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _months * 1100),
  )..addListener(_onSimTick);
  double _lastSimValue = 0;
  double _frac = 0;
  bool _simDone = false;
  bool _manual = true; // el usuario mueve año/mes: la animación no manda

  bool get _playing => _sim.isAnimating;

  void _onSimTick() {
    if (_manual) return;
    final v = _sim.value;
    final t = v * _months;
    final m = t.floor().clamp(0, _months - 1);
    setState(() {
      // La cámara gira despacio mientras corre: movimiento continuo y suave.
      _angle += (v - _lastSimValue) * _months * 0.1;
      _lastSimValue = v;
      _year = m ~/ 12;
      _month = m % 12;
      _frac = (t - m).clamp(0.0, 1.0);
      if (v >= 1) _simDone = true;
    });
  }

  void _play() {
    final restart = _manual || _simDone || _sim.value >= 1;
    _manual = false;
    _simDone = false;
    _sector = null;
    if (restart) {
      _lastSimValue = 0;
      _sim.forward(from: 0);
    } else {
      _sim.forward();
    }
    setState(() {});
  }

  void _pause() {
    _sim.stop();
    setState(() {});
  }

  /// El usuario toma el control (año/mes): la simulación se detiene.
  void _stopSim() {
    _sim.stop();
    _manual = true;
    _simDone = false;
    _frac = 0;
  }

  @override
  void dispose() {
    _sim.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _angle = _angle0;
    _tilt = _tilt0;
    _zoom = 1;
    _sector = null;
  });

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final model = _ParcelModel.of(state, _year, _month, _frac);
    final key = model.key;
    if (key != _sceneKey) {
      _sceneKey = key;
      _scene = ParcelScene(model.setup);
    }
    final theme = Theme.of(context).textTheme;
    final selected = _sector;

    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('farm.parcel.title'),
                  style: theme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: context.tr('farm.parcel.reset'),
                onPressed: _reset,
                icon: const Icon(Icons.threesixty_rounded),
              ),
            ],
          ),
          Text(context.tr('farm.parcel.hint'), style: theme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          _RotationPicker(
            current: _ParcelModel._recommended(state)?.id,
            onPick: (id) {
              setState(() {
                _stopSim();
                _year = 0;
              });
              state.elegirRotacion(id);
            },
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _sky(model.climate),
                ),
              ),
              child: AspectRatio(
                aspectRatio: 1.38,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (d) {
                        _lastFocal = d.localFocalPoint;
                        _startZoom = _zoom;
                      },
                      onScaleUpdate: (d) {
                        final delta = d.localFocalPoint - _lastFocal;
                        _lastFocal = d.localFocalPoint;
                        setState(() {
                          if (d.pointerCount > 1) {
                            _zoom = (_startZoom * d.scale).clamp(0.75, 1.8);
                          } else {
                            _angle += delta.dx * 0.012;
                            _tilt = (_tilt - delta.dy * 0.01).clamp(0.3, 1.1);
                          }
                        });
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: ParcelPainter(
                            scene: _scene!,
                            angle: _angle,
                            tilt: _tilt,
                            zoom: _zoom,
                            selected: selected,
                          ),
                        ),
                      ),
                    ),
                    if (_playing || _simDone)
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: _SimProgress(year: _year, value: _sim.value),
                      ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _ClimatePill(
                        month: model.calendarMonth,
                        climate: model.climate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              key: const ValueKey('sim-play'),
              onPressed: _playing ? _pause : _play,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(
                context.tr(
                  _playing
                      ? 'farm.sim.pause'
                      : (!_manual && !_simDone && _sim.value > 0)
                      ? 'farm.sim.resume'
                      : 'farm.sim.play',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Año de la rotación: los cultivos avanzan un sector por año.
          Row(
            children: [
              for (var y = 0; y < 3; y++) ...[
                Expanded(
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        context.tr('farm.parcel.year', {'n': y + 1}),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: _year == y,
                    onSelected: (_) => setState(() {
                      _stopSim();
                      _year = y;
                    }),
                  ),
                ),
                if (y < 2) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                context.tr('farm.parcel.month', {
                  'n': _month + 1,
                  'mes': monthShortName(context, model.calendarMonth),
                }),
                style: theme.labelMedium,
              ),
              Expanded(
                child: Slider(
                  value: _month.toDouble(),
                  max: 11,
                  divisions: 11,
                  label: monthShortName(context, model.calendarMonth),
                  onChanged: (v) => setState(() {
                    _stopSim();
                    _month = v.round();
                  }),
                ),
              ),
            ],
          ),
          for (var i = 0; i < model.sectors.length; i++)
            _SectorTile(
              index: i,
              sector: model.sectors[i],
              cycle: model.cycles[i],
              sowMonth: model.sowMonth,
              soil: model.sim.soilAt(i, _year, _month + _frac),
              selected: selected == i,
              onTap: () => setState(() => _sector = selected == i ? null : i),
            ),
          if (_simDone)
            _SimSummary(
              sim: model.sim,
              common: model.commonSim,
              onReplay: _play,
            ),
          if (model.soilLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.tr('farm.parcel.soil', {'label': model.soilLabel}),
              style: theme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _sky(MesEstado climate) => switch (climate) {
    MesEstado.helada => const [Color(0xFFDDEAF5), Color(0xFFF3F8FB)],
    MesEstado.seco => const [Color(0xFFF7EBCF), Color(0xFFFBF6EA)],
    MesEstado.bueno => const [Color(0xFFE2F3E6), Color(0xFFF5FBF4)],
  };
}

/// Datos de la escena a partir del paquete, la rotación, el suelo y el mes.
class _ParcelModel {
  _ParcelModel({
    required this.setup,
    required this.sectors,
    required this.cycles,
    required this.sowMonth,
    required this.calendarMonth,
    required this.soilLabel,
    required this.sim,
    required this.commonSim,
  });

  final RotationSim sim;
  final RotationSim? commonSim;

  final ParcelSetup setup;
  final List<ParcelSector> sectors;
  final List<int> cycles;
  final int sowMonth;
  final int calendarMonth;
  final String? soilLabel;

  MesEstado get climate => setup.climate;

  String get key => [
    for (final s in sectors)
      '${s.crop}:${s.growth.toStringAsFixed(2)}:${s.harvested}',
    setup.soil.toARGB32(),
    setup.slope,
    setup.climate.name,
  ].join('|');

  static const _demo = ['papa', 'haba', 'avena_forrajera'];

  static _ParcelModel of(
    AppState state,
    int year,
    int month, [
    double frac = 0,
  ]) {
    final paquete = state.paquete;
    final rotation = _recommended(state);
    final crops = [...(rotation?.secuencia ?? _demo)];
    while (crops.length < 3) {
      crops.add('descanso');
    }

    final sow = (paquete?.inicioSiembraMes ?? 10).clamp(1, 12);
    final calendarMonth = (sow - 1 + month) % 12 + 1;
    final climate = paquete?.mes(calendarMonth)?.estado ?? MesEstado.bueno;

    final sectors = <ParcelSector>[];
    final cycles = <int>[];
    for (var s = 0; s < 3; s++) {
      final crop = crops[(s + year) % 3];
      final cycle = crop == 'descanso'
          ? 12
          : (paquete?.cultivoPorId(crop)?.cicloMeses ?? 5).clamp(1, 12);
      cycles.add(cycle);
      sectors.add(
        ParcelSector(
          crop: crop,
          growth: month >= cycle
              ? 1
              : (((month + 1 + frac) / cycle) * 40).round() / 40,
          harvested: crop != 'descanso' && month >= cycle,
        ),
      );
    }

    MesEstado climateOf(int m) => paquete?.mes(m)?.estado ?? MesEstado.bueno;
    final sim = RotationSim.run(
      crops,
      cultivo: paquete?.cultivoPorId,
      climate: climateOf,
      sowMonth: sow,
    );
    final common = state.rotacionActual;
    final commonSim = common == null || common.id == rotation?.id
        ? null
        : RotationSim.run(
            common.secuencia,
            cultivo: paquete?.cultivoPorId,
            climate: climateOf,
            sowMonth: sow,
          );

    final zona = state.zona;
    final soil = state.lastSoil;
    final hasSoil = soil != null && soil.zonaId == (zona?.id ?? '');
    final profile = hasSoil
        ? soilProfileFor(soil.effectiveIndex, state.lang)
        : null;

    return _ParcelModel(
      setup: ParcelSetup(
        sectors: sectors,
        soil: _soilColor(profile?.key),
        slope: _slope(zona),
        climate: climate,
      ),
      sectors: sectors,
      cycles: cycles,
      sowMonth: sow,
      calendarMonth: calendarMonth,
      soilLabel: profile?.label,
      sim: sim,
      commonSim: commonSim,
    );
  }

  /// La mejor rotación según las prioridades del agricultor (no la práctica común).
  static Rotacion? _recommended(AppState state) {
    if (state.rotacionElegidaPorUsuario) return state.rotacionElegida;
    final all = state.rotacionesTodas;
    for (final r in all) {
      if (!r.esPracticaComun) return r;
    }
    return all.isEmpty ? state.rotacionActual : all.first;
  }

  static Color _soilColor(String? key) => switch (key) {
    'aluvial' => const Color(0xFF8E6A47),
    'negro' => const Color(0xFF55402F),
    'arcilloso' => const Color(0xFFA0674A),
    'rojo' => const Color(0xFFA4502F),
    _ => const Color(0xFF8B6544),
  };

  static double _slope(Zona? zona) {
    if (zona == null) return 0.06;
    switch (zona.region) {
      case 'sierra':
        return 0.1;
      case 'valle':
        return 0.06;
      case 'selva':
        return 0.02;
    }
    final e = zona.elevacionM;
    return e > 2500 ? 0.09 : (e > 1000 ? 0.05 : 0.02);
  }
}

class _ClimatePill extends StatelessWidget {
  const _ClimatePill({required this.month, required this.climate});

  final int month;
  final MesEstado climate;

  @override
  Widget build(BuildContext context) {
    final (icon, color, key) = switch (climate) {
      MesEstado.helada => (
        Icons.ac_unit_rounded,
        AppColors.helada,
        'cal.state.frost',
      ),
      MesEstado.seco => (
        Icons.wb_sunny_rounded,
        AppColors.seco,
        'cal.state.dry',
      ),
      MesEstado.bueno => (
        Icons.eco_rounded,
        AppColors.verdePrincipal,
        'cal.state.good',
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey('$month-$climate'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              '${monthName(context, month)} · ${context.tr(key)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectorTile extends StatelessWidget {
  const _SectorTile({
    required this.index,
    required this.sector,
    required this.cycle,
    required this.sowMonth,
    required this.soil,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final ParcelSector sector;
  final int cycle;
  final int sowMonth;
  final double soil;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final harvestMonth = (sowMonth - 1 + cycle - 1) % 12 + 1;
    final status = sector.fallow
        ? context.tr('farm.parcel.fallow')
        : sector.harvested
        ? context.tr('farm.parcel.harvested')
        : sector.growth >= 0.99
        ? context.tr('farm.parcel.ready')
        : context.tr('farm.parcel.growing', {
            'pct': (sector.growth * 100).round(),
          });
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.buenoSoft : AppColors.superficie,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: selected
                      ? AppColors.verdePrincipal
                      : AppColors.line,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.white
                          : AppColors.verdePrincipal,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CropIcon(sector.crop, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropName(context, sector.crop),
                        style: theme.titleSmall,
                      ),
                      Text(
                        sector.fallow
                            ? status
                            : '$status · ${context.tr('farm.parcel.cycle', {'sow': monthShortName(context, sowMonth), 'harvest': monthShortName(context, harvestMonth)})}',
                        style: theme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      _SoilBar(value: soil),
                    ],
                  ),
                ),
                if (!sector.fallow && !sector.harvested)
                  SizedBox(
                    width: 38,
                    child: LinearProgressIndicator(
                      value: sector.growth,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(5),
                      color: AppColors.verdeSecundario,
                      backgroundColor: AppColors.line,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector rápido de las rotaciones recomendadas, sobre la chacra 3D.
class _RotationPicker extends StatelessWidget {
  const _RotationPicker({required this.current, required this.onPick});

  final String? current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final options = [...state.rotacionesRecomendadas];
    final chosen = state.rotacionElegida;
    if (state.rotacionElegidaPorUsuario &&
        chosen != null &&
        options.every((r) => r.id != chosen.id)) {
      options.add(chosen);
    }
    if (options.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('rot.pick'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in options)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      key: ValueKey('rot-pick-${r.id}'),
                      selected: r.id == current,
                      showCheckmark: false,
                      onSelected: (_) => onPick(r.id),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in r.secuencia.take(3))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: CropIcon(c, size: 22),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Salud del suelo estimada del sector (0–100).
class _SoilBar extends StatelessWidget {
  const _SoilBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final color = value >= 55
        ? AppColors.verdeSecundario
        : value >= 40
        ? AppColors.seco
        : AppColors.helada;
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      children: [
        Text(
          context.tr('farm.sim.soil'),
          style: TextStyle(fontSize: 10.5, color: muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value / 100),
            duration: const Duration(milliseconds: 250),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
              color: color,
              backgroundColor: AppColors.line,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value.round().toString(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SimProgress extends StatelessWidget {
  const _SimProgress({required this.year, required this.value});

  final int year;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Text(
            context.tr('farm.parcel.year', {'n': year + 1}),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.verdePrincipal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
              color: AppColors.verdePrincipal,
              backgroundColor: AppColors.line,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen al terminar: tu rotación vs. la práctica común.
class _SimSummary extends StatelessWidget {
  const _SimSummary({
    required this.sim,
    required this.common,
    required this.onReplay,
  });

  final RotationSim sim;
  final RotationSim? common;
  final VoidCallback onReplay;

  static String _pct(double v) => '${v >= 0 ? '+' : ''}${v.round()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final other = common;
    return Container(
      key: const ValueKey('sim-summary'),
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.buenoSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('farm.sim.title'), style: theme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.tr('farm.sim.result', {
              'h': sim.harvests,
              'soil': _pct(sim.soilChangePct),
              'risk': sim.riskMonths,
            }),
            style: theme.bodyMedium,
          ),
          if (other != null) ...[
            const SizedBox(height: 4),
            Text(
              context.tr('farm.sim.vsCommon', {
                'soil': _pct(other.soilChangePct),
                'risk': other.riskMonths,
              }),
              style: theme.bodySmall,
            ),
          ],
          const SizedBox(height: 4),
          Text(context.tr('farm.sim.note'), style: theme.bodySmall),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onReplay,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(context.tr('farm.sim.replay')),
            ),
          ),
        ],
      ),
    );
  }
}

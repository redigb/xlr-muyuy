import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/soft_card.dart';

class FarmParcelView extends StatefulWidget {
  const FarmParcelView({super.key});

  @override
  State<FarmParcelView> createState() => _FarmParcelViewState();
}

class _FarmParcelViewState extends State<FarmParcelView> {
  double _angle = -0.52;
  double _tilt = 0.57;
  double _zoom = 1;
  double _startZoom = 1;
  Offset _lastFocalPoint = Offset.zero;
  int? _sector;

  void _reset() => setState(() {
    _angle = -0.52;
    _tilt = 0.57;
    _zoom = 1;
    _sector = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('farm.parcel.title'), style: theme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(context.tr('farm.parcel.hint'), style: theme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: ColoredBox(
              color: const Color(0xFFEAF2E8),
              child: AspectRatio(
                aspectRatio: 1.45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (details) {
                        _lastFocalPoint = details.localFocalPoint;
                        _startZoom = _zoom;
                      },
                      onScaleUpdate: (details) {
                        final delta = details.localFocalPoint - _lastFocalPoint;
                        _lastFocalPoint = details.localFocalPoint;
                        setState(() {
                          if (details.pointerCount > 1) {
                            _zoom = (_startZoom * details.scale).clamp(
                              0.75,
                              1.8,
                            );
                          } else {
                            _angle += delta.dx * 0.012;
                            _tilt = (_tilt - delta.dy * 0.01).clamp(0.25, 1.15);
                          }
                        });
                      },
                      child: CustomPaint(
                        painter: _ParcelPainter(_angle, _tilt, _zoom, _sector),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: context.tr('farm.parcel.zoomOut'),
                            onPressed: _zoom <= 0.75
                                ? null
                                : () => setState(
                                    () =>
                                        _zoom = (_zoom - 0.2).clamp(0.75, 1.8),
                                  ),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          IconButton(
                            tooltip: context.tr('farm.parcel.zoomIn'),
                            onPressed: _zoom >= 1.8
                                ? null
                                : () => setState(
                                    () =>
                                        _zoom = (_zoom + 0.2).clamp(0.75, 1.8),
                                  ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          IconButton(
                            tooltip: context.tr('farm.parcel.reset'),
                            onPressed: _reset,
                            icon: const Icon(Icons.restart_alt_rounded),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var sector = 0; sector < 3; sector++)
                ChoiceChip(
                  label: Text(
                    context.tr('farm.parcel.sector', {'n': sector + 1}),
                  ),
                  selected: _sector == sector,
                  onSelected: (selected) =>
                      setState(() => _sector = selected ? sector : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef _Point = ({double x, double y, double z});
typedef _Face = ({List<_Point> vertices, Color color, int? sector});

_Point _point(double x, double y, double z) => (x: x, y: y, z: z);

final _faces = _buildParcel();

List<_Face> _buildParcel() {
  final random = math.Random(27);
  final faces = <_Face>[];

  void face(List<_Point> vertices, int color, [int? sector]) {
    faces.add((vertices: vertices, color: Color(color), sector: sector));
  }

  double surface(double x, double z) => 0.022 * x - 0.038 * z;

  final corners = [
    for (final (x, z) in [(-6.2, -4.2), (6.2, -4.2), (6.2, 4.2), (-6.2, 4.2)])
      _point(x, surface(x, z), z),
  ];
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % corners.length];
    face([
      a,
      b,
      _point(b.x, b.y - 0.52, b.z),
      _point(a.x, a.y - 0.52, a.z),
    ], i.isEven ? 0xFF69452E : 0xFF805B3C);
  }

  // Small ground tiles keep furrows and plants correctly ordered during rotation.
  const soils = [0xFF9A7451, 0xFF99724F, 0xFFA07956, 0xFF9D7854];
  for (var i = 0; i < 31; i++) {
    for (var j = 0; j < 21; j++) {
      final x = -6.2 + i * 0.4;
      final z = -4.2 + j * 0.4;
      face([
        _point(x, surface(x, z), z),
        _point(x + 0.4, surface(x + 0.4, z), z),
        _point(x + 0.4, surface(x + 0.4, z + 0.4), z + 0.4),
        _point(x, surface(x, z + 0.4), z + 0.4),
      ], soils[random.nextInt(soils.length)]);
    }
  }

  const leaves = [0xFF30582A, 0xFF467635, 0xFF629242, 0xFF80A74B, 0xFF527C36];
  double rowX(int row, double z) =>
      -5.25 + row * 0.87 + (row ~/ 4) * 0.48 + 0.35 * math.sin(z * 0.37);

  for (var row = 0; row < 12; row++) {
    for (var step = 0; step < 21; step++) {
      final z = -3.65 + step * 0.355;
      final x = rowX(row, z);
      final nextX = rowX(row, z + 0.355);
      final y = surface(x, z);
      face(
        [
          _point(x - 0.31, y + 0.08, z),
          _point(x + 0.31, y + 0.08, z),
          _point(nextX + 0.31, y + 0.068, z + 0.355),
          _point(nextX - 0.31, y + 0.068, z + 0.355),
        ],
        0xFF795031,
        row ~/ 4,
      );

      final plantX = x + (random.nextDouble() - 0.5) * 0.18;
      final plantZ = z + 0.14;
      final height = 0.28 + random.nextDouble() * 0.20;
      for (var leaf = 0; leaf < 5; leaf++) {
        final direction = leaf * math.pi * 0.8 + random.nextDouble() * 0.6;
        final dx = math.cos(direction);
        final dz = math.sin(direction);
        final reach = 0.22 + random.nextDouble() * 0.16;
        final centerY = y + height;
        face(
          [
            _point(plantX, centerY - 0.14, plantZ),
            _point(
              plantX + dx * reach * 0.58 - dz * 0.105,
              centerY,
              plantZ + dz * reach * 0.58 + dx * 0.105,
            ),
            _point(plantX + dx * reach, centerY - 0.085, plantZ + dz * reach),
            _point(
              plantX + dx * reach * 0.55 + dz * 0.105,
              centerY - 0.025,
              plantZ + dz * reach * 0.55 - dx * 0.105,
            ),
          ],
          leaves[random.nextInt(leaves.length)],
          row ~/ 4,
        );
      }
    }
  }
  return faces;
}

class _ParcelPainter extends CustomPainter {
  const _ParcelPainter(this.angle, this.tilt, this.zoom, this.sector);

  final double angle;
  final double tilt;
  final double zoom;
  final int? sector;

  @override
  void paint(Canvas canvas, Size size) {
    final cosAngle = math.cos(angle);
    final sinAngle = math.sin(angle);
    final cosTilt = math.cos(tilt);
    final sinTilt = math.sin(tilt);
    final scale = math.min(size.width / 16, size.height / 10.2) * zoom;
    final center = Offset(size.width / 2, size.height * 0.56);
    final paint = Paint()..color = const Color(0x1F294329);

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, 10 * zoom),
        width: 12.7 * scale,
        height: (4 + sinTilt * 3) * scale,
      ),
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    paint.maskFilter = null;

    final projected = _faces.map((face) {
      var depth = 0.0;
      final polygon = <Offset>[];
      for (final vertex in face.vertices) {
        final x = vertex.x * cosAngle - vertex.z * sinAngle;
        final z = vertex.x * sinAngle + vertex.z * cosAngle;
        depth += z * cosTilt + vertex.y * sinTilt;
        polygon.add(
          center + Offset(x, z * sinTilt - vertex.y * cosTilt) * scale,
        );
      }
      return (
        points: polygon,
        depth: depth / polygon.length,
        color: face.color,
        sector: face.sector,
      );
    }).toList()..sort((a, b) => a.depth.compareTo(b.depth));

    for (final polygon in projected) {
      final isDimmed =
          sector != null && polygon.sector != null && polygon.sector != sector;
      paint.color = isDimmed
          ? Color.lerp(polygon.color, const Color(0xFF928467), 0.65)!
          : polygon.color;
      canvas.drawPath(Path()..addPolygon(polygon.points, true), paint);
    }
  }

  @override
  bool shouldRepaint(_ParcelPainter oldDelegate) =>
      angle != oldDelegate.angle ||
      tilt != oldDelegate.tilt ||
      zoom != oldDelegate.zoom ||
      sector != oldDelegate.sector;
}

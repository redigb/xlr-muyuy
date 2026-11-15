import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show VertexMode, Vertices;

import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../widgets/crop_icon.dart';

/// Estado de un sector de la parcela: qué cultivo tiene y en qué etapa está.
class ParcelSector {
  const ParcelSector({
    required this.crop,
    required this.growth,
    this.harvested = false,
  });

  final String crop;

  /// 0 = recién sembrado, 1 = listo para cosechar.
  final double growth;
  final bool harvested;

  bool get fallow => crop == 'descanso';
}

/// Todo lo que define la escena (si no cambia, la geometría no se recalcula).
class ParcelSetup {
  const ParcelSetup({
    required this.sectors,
    required this.soil,
    required this.slope,
    required this.climate,
  });

  final List<ParcelSector> sectors;
  final Color soil;

  /// Pendiente del terreno: ~0 en selva, ~0.1 en sierra.
  final double slope;
  final MesEstado climate;
}

typedef ParcelPoint = ({double x, double y, double z});

class ParcelFace {
  const ParcelFace(this.v, this.color, this.sector);

  final List<ParcelPoint> v;
  final Color color;
  final int? sector;
}

// ------------------------------------------------------------------ geometría

const _x0 = -6.0, _x1 = 6.0, _z0 = -4.0, _z1 = 4.0, _step = 0.5;
const _base = -1.15;

/// Límites en x de cada sector (deja un camino entre sectores).
const sectorBounds = [(-5.5, -2.5), (-1.5, 1.5), (2.5, 5.5)];
const _sz0 = -3.4, _sz1 = 3.4;

ParcelPoint _p(double x, double y, double z) => (x: x, y: y, z: z);

/// Luz fija en el mundo (arriba, izquierda, al fondo): el color de cada cara se
/// calcula una vez al construir la escena, no en cada cuadro.
const _light = (x: -0.42, y: 0.82, z: -0.39);

Color _lit(Color c, List<ParcelPoint> v) {
  final a = v[0], b = v[1], d = v[2];
  final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  final vx = d.x - a.x, vy = d.y - a.y, vz = d.z - a.z;
  var nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  final len = math.sqrt(nx * nx + ny * ny + nz * nz);
  if (len == 0) return c;
  nx /= len;
  ny /= len;
  nz /= len;
  final dot = (nx * _light.x + ny * _light.y + nz * _light.z).abs();
  final k = 0.56 + 0.44 * dot;
  return Color.from(
    alpha: c.a,
    red: (c.r * k).clamp(0, 1),
    green: (c.g * k).clamp(0, 1),
    blue: (c.b * k).clamp(0, 1),
  );
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0, 1))!;

Color _tone(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

class ParcelScene {
  ParcelScene(this.setup) : faces = _build(setup);

  final ParcelSetup setup;
  final List<ParcelFace> faces;

  /// Altura del terreno: más alto al fondo según la pendiente, con ondulación suave.
  static double height(ParcelSetup s, double x, double z) =>
      -s.slope * z + 0.05 * math.sin(x * 0.8) * math.cos(z * 0.6);

  static List<ParcelFace> _build(ParcelSetup s) {
    final faces = <ParcelFace>[];
    final rnd = math.Random(11);
    double h(double x, double z) => height(s, x, z);

    void face(List<ParcelPoint> v, Color c, [int? sector]) =>
        faces.add(ParcelFace(v, _lit(c, v), sector));

    var soil = s.soil;
    if (s.climate == MesEstado.seco) soil = _tone(soil, 0.07);
    if (s.climate == MesEstado.helada) {
      soil = _mix(soil, const Color(0xFFDCE6EC), 0.22);
    }
    final grass = switch (s.climate) {
      MesEstado.helada => const Color(0xFFB9CFC4),
      MesEstado.seco => const Color(0xFFB4B061),
      MesEstado.bueno => const Color(0xFF7DB04F),
    };
    final path = _tone(_mix(soil, const Color(0xFFD8C3A0), 0.45), 0.04);

    int? sectorAt(double x, double z) {
      if (z < _sz0 || z > _sz1) return null;
      for (var i = 0; i < sectorBounds.length; i++) {
        final (a, b) = sectorBounds[i];
        if (x >= a && x <= b) return i;
      }
      return null;
    }

    // Superficie: borde de pasto, caminos entre sectores y tierra.
    final nx = ((_x1 - _x0) / _step).round();
    final nz = ((_z1 - _z0) / _step).round();
    for (var i = 0; i < nx; i++) {
      for (var j = 0; j < nz; j++) {
        final x = _x0 + i * _step, z = _z0 + j * _step;
        final cx = x + _step / 2, cz = z + _step / 2;
        final rim = i == 0 || j == 0 || i == nx - 1 || j == nz - 1;
        final sector = sectorAt(cx, cz);
        final fallow = sector != null && s.sectors[sector].fallow;
        Color c;
        if (rim) {
          c = _tone(grass, (rnd.nextDouble() - 0.5) * 0.06);
        } else if (sector == null) {
          c = path;
        } else if (fallow) {
          c = _mix(soil, grass, 0.45 + rnd.nextDouble() * 0.15);
        } else {
          c = _tone(soil, (rnd.nextDouble() - 0.5) * 0.05);
        }
        face(
          [
            _p(x, h(x, z), z),
            _p(x + _step, h(x + _step, z), z),
            _p(x + _step, h(x + _step, z + _step), z + _step),
            _p(x, h(x, z + _step), z + _step),
          ],
          c,
          sector,
        );
      }
    }

    // Costados del bloque: pasto, tierra oscura y subsuelo.
    final topsoil = _tone(soil, -0.03);
    const subsoil = Color(0xFFB98F60);
    void side(double ax, double az, double bx, double bz) {
      final ha = h(ax, az), hb = h(bx, bz);
      for (final (top, bottom, color) in [
        (0.0, 0.1, grass),
        (0.1, 0.55, topsoil),
        (0.55, null, subsoil),
      ]) {
        face([
          _p(ax, ha - top, az),
          _p(bx, hb - top, bz),
          _p(bx, bottom == null ? _base : hb - bottom, bz),
          _p(ax, bottom == null ? _base : ha - bottom, az),
        ], color);
      }
    }

    for (var i = 0; i < nx; i++) {
      final x = _x0 + i * _step;
      side(x, _z0, x + _step, _z0);
      side(x, _z1, x + _step, _z1);
    }
    for (var j = 0; j < nz; j++) {
      final z = _z0 + j * _step;
      side(_x0, z, _x0, z + _step);
      side(_x1, z, _x1, z + _step);
    }

    // Sectores: surcos y plantas.
    for (var si = 0; si < s.sectors.length && si < sectorBounds.length; si++) {
      final sector = s.sectors[si];
      final (a, b) = sectorBounds[si];
      final plantRnd = math.Random(100 + si * 7 + sector.crop.hashCode % 50);
      if (sector.fallow) {
        for (var k = 0; k < 46; k++) {
          final x = a + 0.25 + plantRnd.nextDouble() * (b - a - 0.5);
          final z = _sz0 + 0.2 + plantRnd.nextDouble() * (_sz1 - _sz0 - 0.4);
          _tuft(faces, x, h(x, z), z, 0.2, 3, grass, plantRnd, si);
        }
        continue;
      }
      const rows = 4;
      final width = (b - a) / rows;
      final ridge = _tone(soil, -0.04);
      for (var r = 0; r < rows; r++) {
        final x = a + width * (r + 0.5);
        for (var z = _sz0; z < _sz1 - 0.01; z += 0.55) {
          final z2 = math.min(z + 0.55, _sz1);
          final y1 = h(x, z), y2 = h(x, z2);
          face(
            [
              _p(x - 0.27, y1 + 0.01, z),
              _p(x, y1 + 0.15, z),
              _p(x, y2 + 0.15, z2),
              _p(x - 0.27, y2 + 0.01, z2),
            ],
            ridge,
            si,
          );
          face(
            [
              _p(x, y1 + 0.15, z),
              _p(x + 0.27, y1 + 0.01, z),
              _p(x + 0.27, y2 + 0.01, z2),
              _p(x, y2 + 0.15, z2),
            ],
            ridge,
            si,
          );
          final pz = z + 0.27 + (plantRnd.nextDouble() - 0.5) * 0.1;
          final px = x + (plantRnd.nextDouble() - 0.5) * 0.08;
          _plant(
            faces,
            sector,
            s.climate,
            px,
            h(px, pz) + 0.15,
            pz,
            plantRnd,
            si,
          );
        }
      }
    }
    return faces;
  }
}

// ------------------------------------------------------------------ plantas

enum _Shape { bush, tall, tuft, root }

_Shape _shapeOf(String id) => switch (id) {
  'maiz' ||
  'maiz_amilaceo' ||
  'maiz_duro' ||
  'sorgo' ||
  'girasol' => _Shape.tall,
  'yuca' => _Shape.root,
  'trigo' ||
  'cebada' ||
  'avena_forrajera' ||
  'arroz' ||
  'mijo' ||
  'quinua' ||
  'tarwi' ||
  'colza' ||
  'cebolla' => _Shape.tuft,
  _ => _Shape.bush,
};

/// Flores o frutos que aparecen al madurar (null = sin adorno).
Color? _accent(String id) => switch (id) {
  'papa' => const Color(0xFFE9E1F7),
  'haba' || 'arveja' || 'garbanzo' || 'lenteja' => const Color(0xFFF5F2FA),
  'frijol' || 'soya' || 'caupi' || 'mucuna' => const Color(0xFFB98BD9),
  'tomate' => const Color(0xFFE2463A),
  'oca' || 'olluco' || 'mani' => const Color(0xFFF2C94C),
  'camote' => const Color(0xFFE29BC2),
  _ => null,
};

void _addFace(List<ParcelFace> out, List<ParcelPoint> v, Color c, int sector) =>
    out.add(ParcelFace(v, _lit(c, v), sector));

Color _leafColor(
  String crop,
  double growth,
  MesEstado climate,
  math.Random rnd,
) {
  var c = _tone(const Color(0xFF4E9A3F), (rnd.nextDouble() - 0.5) * 0.1);
  // Cereales y quinua toman su color al madurar.
  if (_shapeOf(crop) == _Shape.tuft && crop != 'cebolla' && growth > 0.7) {
    c = _mix(c, cropColor(crop), (growth - 0.7) / 0.3 * 0.75);
  }
  if (climate == MesEstado.seco) c = _mix(c, const Color(0xFFB8A75C), 0.38);
  if (climate == MesEstado.helada) c = _mix(c, const Color(0xFFE4EDF3), 0.42);
  return c;
}

void _plant(
  List<ParcelFace> out,
  ParcelSector s,
  MesEstado climate,
  double x,
  double y,
  double z,
  math.Random rnd,
  int sector,
) {
  if (s.harvested) {
    const straw = Color(0xFFC9A86A);
    for (var i = 0; i < 5; i++) {
      final dx = (rnd.nextDouble() - 0.5) * 0.22,
          dz = (rnd.nextDouble() - 0.5) * 0.22;
      _blade(out, x + dx, y, z + dz, 0.2, 0.035, 0, straw, sector);
    }
    return;
  }
  final g = s.growth.clamp(0.08, 1.0);
  final scale = (0.25 + 0.75 * g) * 1.35;
  final leaf = _leafColor(s.crop, g, climate, rnd);
  final accent = g > 0.6 ? _accent(s.crop) : null;

  switch (_shapeOf(s.crop)) {
    case _Shape.bush:
      final r = 0.3 * scale, top = 0.42 * scale;
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + rnd.nextDouble() * 0.5;
        _leaf(
          out,
          x,
          y + top * 0.35,
          z,
          a,
          r,
          top * 0.95,
          0.13 * scale + 0.04,
          leaf,
          sector,
        );
      }
      for (var i = 0; i < 3; i++) {
        final a = i * 2.1 + rnd.nextDouble();
        _leaf(
          out,
          x,
          y + top * 0.6,
          z,
          a,
          r * 0.55,
          top * 1.2,
          0.1 * scale + 0.03,
          _tone(leaf, 0.04),
          sector,
        );
      }
      if (accent != null) {
        for (var i = 0; i < 2; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          _gem(
            out,
            x + math.cos(a) * r * 0.4,
            y + top * 1.25,
            z + math.sin(a) * r * 0.4,
            0.06,
            accent,
            sector,
          );
        }
      }
    case _Shape.tall:
      final hgt = (s.crop == 'sorgo' ? 1.0 : 1.2) * scale;
      _stalk(out, x, y, z, hgt, const Color(0xFF6E9A3E), sector);
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + rnd.nextDouble() * 0.6;
        final at = hgt * (0.3 + i * 0.15);
        _leaf(
          out,
          x,
          y + at,
          z,
          a,
          0.38 * scale,
          at + 0.12 * scale,
          0.08,
          leaf,
          sector,
          droop: 0.22 * scale,
        );
      }
      if (g > 0.55) {
        final head = cropColor(s.crop);
        if (s.crop == 'girasol') {
          _disc(
            out,
            x,
            y + hgt + 0.02,
            z,
            0.16 * scale,
            const Color(0xFFF5B82E),
            const Color(0xFF6B4423),
            sector,
          );
        } else if (s.crop == 'sorgo') {
          _gem(out, x, y + hgt + 0.1, z, 0.11 * scale, head, sector);
        } else {
          _blade(
            out,
            x,
            y + hgt,
            z,
            0.16 * scale,
            0.03,
            0,
            const Color(0xFFE2C46A),
            sector,
          );
          if (g > 0.7) {
            _gem(
              out,
              x + 0.07,
              y + hgt * 0.55,
              z,
              0.07,
              _tone(head, -0.05),
              sector,
            );
          }
        }
      }
    case _Shape.root:
      final hgt = 0.95 * scale;
      _stalk(out, x, y, z, hgt, const Color(0xFF8B6A4A), sector);
      for (var i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5 + rnd.nextDouble() * 0.3;
        _leaf(
          out,
          x,
          y + hgt,
          z,
          a,
          0.3 * scale,
          hgt + 0.05,
          0.09,
          leaf,
          sector,
          droop: 0.12 * scale,
        );
      }
    case _Shape.tuft:
      final hgt = (s.crop == 'cebolla' ? 0.42 : 0.68) * scale;
      _tuft(out, x, y, z, hgt, 6, leaf, rnd, sector);
      if (s.crop != 'cebolla' && g > 0.5) {
        final head = cropColor(s.crop);
        final big =
            s.crop == 'quinua' || s.crop == 'tarwi' || s.crop == 'colza';
        for (var i = 0; i < (big ? 2 : 4); i++) {
          final dx = (rnd.nextDouble() - 0.5) * 0.16,
              dz = (rnd.nextDouble() - 0.5) * 0.16;
          _gem(
            out,
            x + dx,
            y + hgt + (big ? 0.08 : 0.02),
            z + dz,
            big ? 0.1 * scale : 0.05,
            head,
            sector,
          );
        }
      }
  }
}

/// Hoja: rombo desde el tallo hacia afuera; `droop` la arquea hacia abajo.
void _leaf(
  List<ParcelFace> out,
  double x,
  double y,
  double z,
  double angle,
  double reach,
  double tipY,
  double width,
  Color c,
  int sector, {
  double droop = 0,
}) {
  final dx = math.cos(angle), dz = math.sin(angle);
  final px = -dz * width, pz = dx * width;
  final mid = (
    x: x + dx * reach * 0.55,
    y: (y + tipY) / 2 + droop * 0.3,
    z: z + dz * reach * 0.55,
  );
  _addFace(
    out,
    [
      _p(x, y, z),
      _p(mid.x + px, mid.y, mid.z + pz),
      _p(x + dx * reach, tipY - droop, z + dz * reach),
      _p(mid.x - px, mid.y, mid.z - pz),
    ],
    c,
    sector,
  );
}

void _blade(
  List<ParcelFace> out,
  double x,
  double y,
  double z,
  double hgt,
  double w,
  double lean,
  Color c,
  int sector,
) {
  _addFace(
    out,
    [
      _p(x - w, y, z),
      _p(x + w, y, z),
      _p(x + lean, y + hgt, z + lean * 0.5),
      _p(x + lean - 0.001, y + hgt, z + lean * 0.5),
    ],
    c,
    sector,
  );
}

void _tuft(
  List<ParcelFace> out,
  double x,
  double y,
  double z,
  double hgt,
  int blades,
  Color c,
  math.Random rnd,
  int sector,
) {
  for (var i = 0; i < blades; i++) {
    final a = i * math.pi * 2 / blades + rnd.nextDouble() * 0.5;
    final lean = 0.12 * hgt;
    final w = 0.035;
    final tip = (x: x + math.cos(a) * lean, z: z + math.sin(a) * lean);
    _addFace(
      out,
      [
        _p(x - math.sin(a) * w, y, z + math.cos(a) * w),
        _p(x + math.sin(a) * w, y, z - math.cos(a) * w),
        _p(tip.x, y + hgt * (0.85 + rnd.nextDouble() * 0.15), tip.z),
        _p(tip.x + 0.001, y + hgt * 0.85, tip.z),
      ],
      _tone(c, (rnd.nextDouble() - 0.5) * 0.08),
      sector,
    );
  }
}

void _stalk(
  List<ParcelFace> out,
  double x,
  double y,
  double z,
  double hgt,
  Color c,
  int sector,
) {
  const w = 0.035;
  _addFace(
    out,
    [
      _p(x - w, y, z),
      _p(x + w, y, z),
      _p(x + w * 0.6, y + hgt, z),
      _p(x - w * 0.6, y + hgt, z),
    ],
    c,
    sector,
  );
  _addFace(
    out,
    [
      _p(x, y, z - w),
      _p(x, y, z + w),
      _p(x, y + hgt, z + w * 0.6),
      _p(x, y + hgt, z - w * 0.6),
    ],
    _tone(c, -0.05),
    sector,
  );
}

/// Flor o fruto: pequeño octaedro (se ve con volumen desde cualquier ángulo).
void _gem(
  List<ParcelFace> out,
  double x,
  double y,
  double z,
  double r,
  Color c,
  int sector,
) {
  final top = _p(x, y + r, z), bottom = _p(x, y - r, z);
  final ring = [
    for (var i = 0; i < 4; i++)
      _p(
        x + math.cos(i * math.pi / 2) * r,
        y,
        z + math.sin(i * math.pi / 2) * r,
      ),
  ];
  for (var i = 0; i < 4; i++) {
    final a = ring[i], b = ring[(i + 1) % 4];
    _addFace(out, [top, a, b], c, sector);
    _addFace(out, [bottom, b, a], _tone(c, -0.08), sector);
  }
}

void _disc(
  List<ParcelFace> out,
  double x,
  double y,
  double z,
  double r,
  Color petals,
  Color center,
  int sector,
) {
  final ring = [
    for (var i = 0; i < 8; i++)
      _p(
        x + math.cos(i * math.pi / 4) * r,
        y + math.sin(i * math.pi / 4) * r * 0.5 + r * 0.5,
        z - 0.02 + math.sin(i * math.pi / 4) * r * 0.3,
      ),
  ];
  final c = _p(x, y + r * 0.5, z);
  for (var i = 0; i < 8; i++) {
    _addFace(
      out,
      [c, ring[i], ring[(i + 1) % 8]],
      i.isEven ? petals : _tone(petals, -0.05),
      sector,
    );
  }
  _gem(out, x, y + r * 0.5, z - 0.01, r * 0.45, center, sector);
}

// ------------------------------------------------------------------ dibujo

class ParcelPainter extends CustomPainter {
  ParcelPainter({
    required this.scene,
    required this.angle,
    required this.tilt,
    required this.zoom,
    this.selected,
  });

  final ParcelScene scene;
  final double angle;
  final double tilt;
  final double zoom;
  final int? selected;

  static const _dim = Color(0xFFC9C3B2);

  @override
  void paint(Canvas canvas, Size size) {
    final cosA = math.cos(angle), sinA = math.sin(angle);
    final cosT = math.cos(tilt), sinT = math.sin(tilt);
    final scale = math.min(size.width / 15.5, size.height / 10.5) * zoom;
    final center = Offset(size.width / 2, size.height * 0.5);

    // Sombra suave del bloque sobre el fondo.
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, (1.4 + sinT * 0.6) * scale),
        width: 14 * scale,
        height: (4.2 + sinT * 3.4) * scale,
      ),
      Paint()
        ..color = const Color(0x2A1F3A28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    Offset project(ParcelPoint v) {
      final x = v.x * cosA - v.z * sinA;
      final z = v.x * sinA + v.z * cosA;
      return center + Offset(x, z * sinT - v.y * cosT) * scale;
    }

    double depth(ParcelPoint v) {
      final z = v.x * sinA + v.z * cosA;
      return z * cosT + v.y * sinT;
    }

    final faces = scene.faces;
    final order = List<int>.generate(faces.length, (i) => i);
    final depths = Float64List(faces.length);
    for (var i = 0; i < faces.length; i++) {
      var d = 0.0;
      for (final v in faces[i].v) {
        d += depth(v);
      }
      depths[i] = d / faces[i].v.length;
    }
    order.sort((a, b) => depths[a].compareTo(depths[b]));

    var triangles = 0;
    for (final f in faces) {
      triangles += f.v.length - 2;
    }
    final positions = Float32List(triangles * 6);
    final colors = Int32List(triangles * 3);
    var p = 0, c = 0;
    for (final i in order) {
      final f = faces[i];
      var color = f.color;
      if (selected != null && f.sector != null && f.sector != selected) {
        color = Color.lerp(color, _dim, 0.6)!;
      }
      final argb = color.toARGB32();
      final pts = [for (final v in f.v) project(v)];
      for (var t = 1; t < pts.length - 1; t++) {
        for (final q in [pts[0], pts[t], pts[t + 1]]) {
          positions[p++] = q.dx;
          positions[p++] = q.dy;
          colors[c++] = argb;
        }
      }
    }
    canvas.drawVertices(
      Vertices.raw(VertexMode.triangles, positions, colors: colors),
      BlendMode.dst,
      Paint(),
    );

    // Número de cada sector, flotando sobre el fondo del sector.
    for (var i = 0; i < sectorBounds.length; i++) {
      final (a, b) = sectorBounds[i];
      final cx = (a + b) / 2;
      final at = project(
        _p(cx, ParcelScene.height(scene.setup, cx, _sz0) + 1.5, _sz0 + 0.4),
      );
      final active = selected == null || selected == i;
      canvas.drawCircle(
        at + const Offset(0, 1.5),
        12,
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        at,
        11.5,
        Paint()
          ..color = active ? const Color(0xFFFFFFFF) : const Color(0xCCFFFFFF),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF14532D) : const Color(0xFF8A9A90),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(ParcelPainter old) =>
      old.scene != scene ||
      old.angle != angle ||
      old.tilt != tilt ||
      old.zoom != zoom ||
      old.selected != selected;
}

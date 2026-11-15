import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Ícono propio de cada cultivo, dibujado en código (sin imágenes ni emojis):
/// se ve igual en todos los celulares y pesa casi nada. Estilo "casi 3D":
/// volumen con brillo arriba a la izquierda y sombra suave en el suelo.
class CropIcon extends StatelessWidget {
  const CropIcon(this.id, {super.key, this.size = 24});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: CropIconPainter(id)),
    );
  }
}

/// Color principal de cada cultivo (también lo usa la parcela 3D).
Color cropColor(String id) => _spec(id).color;

class CropIconPainter extends CustomPainter {
  const CropIconPainter(this.id);

  final String id;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final spec = _spec(id);
    _groundShadow(canvas);
    spec.draw(canvas, spec.color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CropIconPainter oldDelegate) => oldDelegate.id != id;
}

// ------------------------------------------------------------------ catálogo

typedef _Draw = void Function(Canvas canvas, Color color);

class _Spec {
  const _Spec(this.color, this.draw);
  final Color color;
  final _Draw draw;
}

_Spec _spec(String id) => switch (id) {
  'papa' => _Spec(const Color(0xFFC79A62), (c, k) => _tuber(c, k, eyes: true)),
  'oca' => _Spec(
    const Color(0xFFEF7D57),
    (c, k) => _tuber(c, k, long: true, rings: true),
  ),
  'olluco' => _Spec(const Color(0xFFF2C14E), _olluco),
  'camote' => _Spec(const Color(0xFFB0507A), _sweetPotato),
  'yuca' => _Spec(const Color(0xFF8D6A4A), _cassava),
  'cebolla' => _Spec(const Color(0xFF9B4F96), _onion),
  'tomate' => _Spec(const Color(0xFFE2463A), _tomato),
  'maiz' => _Spec(const Color(0xFFF2C230), (c, k) => _cob(c, k, 6)),
  'maiz_amilaceo' => _Spec(const Color(0xFFEFE0AE), (c, k) => _cob(c, k, 5)),
  'maiz_duro' => _Spec(const Color(0xFFF08A1C), (c, k) => _cob(c, k, 7)),
  'trigo' => _Spec(const Color(0xFFDDAA45), (c, k) => _spike(c, k)),
  'cebada' => _Spec(
    const Color(0xFFD9B95A),
    (c, k) => _spike(c, k, awns: true),
  ),
  'avena_forrajera' => _Spec(const Color(0xFF9DB55A), _oat),
  'arroz' => _Spec(const Color(0xFFE3C979), _rice),
  'mijo' => _Spec(const Color(0xFFC9A55B), _millet),
  'sorgo' => _Spec(const Color(0xFFB4562E), _sorghum),
  'quinua' => _Spec(const Color(0xFFC2306E), _quinoa),
  'haba' => _Spec(const Color(0xFF6FA346), (c, k) => _pod(c, k, seeds: 3)),
  'arveja' => _Spec(const Color(0xFF7DBB4A), _peaPod),
  'soya' => _Spec(
    const Color(0xFFB9A26B),
    (c, k) => _pod(c, k, seeds: 3, fuzzy: true),
  ),
  'caupi' => _Spec(const Color(0xFF8FAF55), _cowpea),
  'mucuna' => _Spec(
    const Color(0xFF5B3A5E),
    (c, k) => _pod(c, k, seeds: 4, fuzzy: true, curved: true),
  ),
  'frijol' => _Spec(const Color(0xFFB2392E), _beans),
  'garbanzo' => _Spec(const Color(0xFFE0BE85), _chickpea),
  'lenteja' => _Spec(const Color(0xFFD27A3A), _lentils),
  'mani' => _Spec(const Color(0xFFCFA672), _peanut),
  'tarwi' => _Spec(const Color(0xFF6E6BC4), _lupin),
  'girasol' => _Spec(const Color(0xFFF5B82E), _sunflower),
  'colza' => _Spec(const Color(0xFFF1D53B), _rapeseed),
  'descanso' => _Spec(const Color(0xFF8A6A4C), _fallow),
  _ => _Spec(const Color(0xFF5E9B49), _sprout),
};

// ------------------------------------------------------------------ utilidades

const _leaf = Color(0xFF4E9A3F);
const _stem = Color(0xFF5E8A3A);

Color _tone(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Relleno con volumen: luz arriba a la izquierda, sombra abajo a la derecha.
Paint _volume(Rect bounds, Color c) => Paint()
  ..shader = RadialGradient(
    center: const Alignment(-0.45, -0.55),
    radius: 1.05,
    colors: [_tone(c, 0.2), c, _tone(c, -0.16)],
    stops: const [0, 0.55, 1],
  ).createShader(bounds);

void _blob(Canvas canvas, Rect r, Color c) => canvas.drawOval(r, _volume(r, c));

void _groundShadow(Canvas canvas) {
  canvas.drawOval(
    const Rect.fromLTWH(18, 84, 64, 10),
    Paint()
      ..color = const Color(0x24000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
}

void _shine(Canvas canvas, Offset at, double r) {
  canvas.drawCircle(at, r, Paint()..color = const Color(0x66FFFFFF));
}

void _stroke(Canvas canvas, Path p, Color c, double w) {
  canvas.drawPath(
    p,
    Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

void _leafShape(
  Canvas canvas,
  Offset base,
  double angle,
  double len,
  double width, [
  Color color = _leaf,
]) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.rotate(angle);
  final p = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(width, -len * 0.5, 0, -len)
    ..quadraticBezierTo(-width, -len * 0.5, 0, 0)
    ..close();
  canvas.drawPath(
    p,
    _volume(Rect.fromLTWH(-width, -len, width * 2, len), color),
  );
  _stroke(
    canvas,
    Path()
      ..moveTo(0, -2)
      ..lineTo(0, -len * 0.85),
    _tone(color, -0.12),
    1.2,
  );
  canvas.restore();
}

// ------------------------------------------------------------------ tubérculos y raíces

void _tuber(
  Canvas c,
  Color k, {
  bool eyes = false,
  bool long = false,
  bool rings = false,
}) {
  final r = long
      ? const Rect.fromLTWH(20, 38, 62, 38)
      : const Rect.fromLTWH(18, 34, 66, 48);
  c.save();
  c.translate(50, 58);
  c.rotate(-0.25);
  c.translate(-50, -58);
  _blob(c, r, k);
  if (eyes) {
    final eye = Paint()..color = _tone(k, -0.28);
    for (final o in const [
      Offset(38, 50),
      Offset(58, 46),
      Offset(66, 64),
      Offset(44, 68),
    ]) {
      c.drawOval(Rect.fromCenter(center: o, width: 5, height: 3), eye);
    }
  }
  if (rings) {
    for (var x = 32.0; x <= 70; x += 9) {
      _stroke(
        c,
        Path()
          ..moveTo(x, r.top + 5)
          ..quadraticBezierTo(x + 4, r.center.dy, x, r.bottom - 5),
        _tone(k, -0.18),
        1.6,
      );
    }
  }
  _shine(c, Offset(r.left + r.width * 0.3, r.top + r.height * 0.28), 4);
  c.restore();
}

void _olluco(Canvas c, Color k) {
  final spot = Paint()..color = const Color(0xFFC2185B);
  for (final (r, dots) in [
    (
      const Rect.fromLTWH(46, 40, 38, 38),
      const [Offset(60, 52), Offset(72, 64), Offset(56, 68)],
    ),
    (
      const Rect.fromLTWH(16, 46, 40, 38),
      const [Offset(30, 58), Offset(42, 70), Offset(26, 74)],
    ),
  ]) {
    _blob(c, r, k);
    for (final d in dots) {
      c.drawCircle(d, 2.2, spot);
    }
    _shine(c, Offset(r.left + 11, r.top + 10), 3.5);
  }
}

void _sweetPotato(Canvas c, Color k) {
  final p = Path()
    ..moveTo(14, 66)
    ..quadraticBezierTo(30, 34, 62, 40)
    ..quadraticBezierTo(90, 46, 88, 62)
    ..quadraticBezierTo(70, 80, 40, 76)
    ..quadraticBezierTo(22, 74, 14, 66)
    ..close();
  c.drawPath(p, _volume(p.getBounds(), k));
  _stroke(
    c,
    Path()
      ..moveTo(88, 60)
      ..lineTo(95, 64),
    _tone(k, -0.2),
    2,
  );
  _shine(c, const Offset(46, 48), 4);
}

void _cassava(Canvas c, Color k) {
  c.save();
  c.translate(50, 56);
  c.rotate(-0.5);
  final r = Rect.fromCenter(center: Offset.zero, width: 78, height: 26);
  c.drawRRect(
    RRect.fromRectAndRadius(r, const Radius.circular(13)),
    _volume(r, k),
  );
  c.drawOval(
    Rect.fromCenter(center: const Offset(-36, 0), width: 10, height: 22),
    Paint()..color = const Color(0xFFF7F1E3),
  );
  for (var x = -20.0; x <= 24; x += 11) {
    _stroke(
      c,
      Path()
        ..moveTo(x, -11)
        ..lineTo(x + 3, 11),
      _tone(k, -0.15),
      1.2,
    );
  }
  c.restore();
}

void _onion(Canvas c, Color k) {
  _leafShape(c, const Offset(46, 34), -0.15, 26, 4, const Color(0xFF6DAA48));
  _leafShape(c, const Offset(54, 34), 0.2, 22, 4, const Color(0xFF6DAA48));
  final p = Path()
    ..moveTo(50, 28)
    ..cubicTo(86, 44, 86, 84, 50, 84)
    ..cubicTo(14, 84, 14, 44, 50, 28)
    ..close();
  c.drawPath(p, _volume(p.getBounds(), k));
  for (final dx in const [-12.0, 0.0, 12.0]) {
    _stroke(
      c,
      Path()
        ..moveTo(50 + dx * 0.3, 34)
        ..quadraticBezierTo(50 + dx * 1.6, 58, 50 + dx * 0.6, 82),
      _tone(k, 0.14),
      1.3,
    );
  }
  _shine(c, const Offset(38, 52), 4);
}

void _tomato(Canvas c, Color k) {
  const r = Rect.fromLTWH(18, 34, 64, 52);
  _blob(c, r, k);
  final calyx = Paint()..color = const Color(0xFF3E8A35);
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 5;
    c.drawOval(
      Rect.fromCenter(
        center: Offset(50 + math.cos(a) * 8, 38 + math.sin(a) * 4),
        width: 13,
        height: 5,
      ),
      calyx,
    );
  }
  _stroke(
    c,
    Path()
      ..moveTo(50, 36)
      ..lineTo(51, 26),
    const Color(0xFF3E8A35),
    3,
  );
  _shine(c, const Offset(34, 50), 5);
}

// ------------------------------------------------------------------ cereales

void _cob(Canvas c, Color k, int columns) {
  c.save();
  c.translate(50, 54);
  c.rotate(0.35);
  const body = Rect.fromLTWH(-15, -34, 30, 66);
  c.drawRRect(
    RRect.fromRectAndRadius(body, const Radius.circular(15)),
    _volume(body, k),
  );
  final kernel = Paint()..color = _tone(k, -0.1);
  for (var row = 0; row < 9; row++) {
    for (var col = 0; col < 3; col++) {
      c.drawCircle(Offset(-8 + col * 8.0, -26 + row * 7.0), 1.4, kernel);
    }
  }
  // Panca (hojas que envuelven la mazorca).
  for (final side in const [-1.0, 1.0]) {
    final p = Path()
      ..moveTo(0, 32)
      ..quadraticBezierTo(side * 26, 18, side * 20, -18)
      ..quadraticBezierTo(side * 12, 8, 0, 32)
      ..close();
    c.drawPath(p, _volume(p.getBounds(), const Color(0xFF7DB04B)));
  }
  _shine(c, const Offset(-6, -24), 3.5);
  c.restore();
}

void _stalk(Canvas c, {double top = 22, double bend = 0}) {
  _stroke(
    c,
    Path()
      ..moveTo(50, 86)
      ..quadraticBezierTo(50, 60, 50 + bend, top),
    _stem,
    3.6,
  );
}

void _spike(Canvas c, Color k, {bool awns = false}) {
  _stalk(c, top: 20);
  _leafShape(c, const Offset(50, 80), -0.7, 30, 4, const Color(0xFF8DAF4E));
  for (var i = 0; i < 6; i++) {
    final y = 26.0 + i * 8;
    for (final side in const [-1.0, 1.0]) {
      final center = Offset(50 + side * 6, y);
      c.save();
      c.translate(center.dx, center.dy);
      c.rotate(side * 0.45);
      const g = Rect.fromLTWH(-4.5, -7, 9, 14);
      c.drawOval(g, _volume(g, k));
      if (awns) {
        _stroke(
          c,
          Path()
            ..moveTo(0, -6)
            ..lineTo(side * 4, -24),
          _tone(k, -0.08),
          1,
        );
      }
      c.restore();
    }
  }
  const tip = Rect.fromLTWH(45.5, 12, 9, 14);
  c.drawOval(tip, _volume(tip, k));
}

void _oat(Canvas c, Color k) {
  _stalk(c, top: 18);
  for (var i = 0; i < 6; i++) {
    final y = 22.0 + i * 9;
    final side = i.isEven ? -1.0 : 1.0;
    final end = Offset(50 + side * 20, y + 10);
    _stroke(
      c,
      Path()
        ..moveTo(50, y)
        ..quadraticBezierTo(50 + side * 14, y - 2, end.dx, end.dy),
      _stem,
      2.4,
    );
    final g = Rect.fromCenter(
      center: end + const Offset(0, 6),
      width: 11,
      height: 17,
    );
    c.drawOval(g, _volume(g, k));
  }
}

void _rice(Canvas c, Color k) {
  final stem = Path()
    ..moveTo(40, 88)
    ..quadraticBezierTo(44, 30, 74, 30)
    ..quadraticBezierTo(84, 34, 82, 60);
  _stroke(c, stem, _stem, 2.4);
  for (var i = 0; i < 7; i++) {
    final t = i / 6;
    final x = 58 + t * 24;
    final y = 32 + math.pow(t, 1.6) * 30;
    for (final side in const [-1.0, 1.0]) {
      final g = Rect.fromCenter(
        center: Offset(x + side * 5, y.toDouble() + 3),
        width: 6,
        height: 10,
      );
      c.drawOval(g, _volume(g, k));
    }
  }
  _leafShape(c, const Offset(40, 86), -0.35, 40, 4);
}

void _millet(Canvas c, Color k) {
  _stalk(c, top: 30);
  const head = Rect.fromLTWH(41, 12, 18, 46);
  c.drawRRect(
    RRect.fromRectAndRadius(head, const Radius.circular(9)),
    _volume(head, k),
  );
  final dot = Paint()..color = _tone(k, -0.12);
  for (var y = 18.0; y < 54; y += 5) {
    for (final x in const [45.0, 50.0, 55.0]) {
      c.drawCircle(Offset(x, y + (x == 50 ? 2.5 : 0)), 1.3, dot);
    }
  }
  _leafShape(c, const Offset(50, 78), 0.7, 30, 4);
}

void _sorghum(Canvas c, Color k) {
  _stalk(c, top: 40);
  _leafShape(c, const Offset(50, 74), -0.8, 32, 5);
  _leafShape(c, const Offset(50, 64), 0.8, 28, 5);
  final rnd = math.Random(4);
  for (var i = 0; i < 26; i++) {
    final a = rnd.nextDouble() * math.pi * 2;
    final d = rnd.nextDouble();
    final center = Offset(50 + math.cos(a) * d * 14, 30 + math.sin(a) * d * 18);
    c.drawCircle(
      center,
      5,
      _volume(Rect.fromCircle(center: center, radius: 5), k),
    );
  }
}

void _quinoa(Canvas c, Color k) {
  _stalk(c, top: 42);
  _leafShape(c, const Offset(50, 76), -0.9, 22, 7, const Color(0xFF5E9B49));
  _leafShape(c, const Offset(50, 68), 0.9, 20, 7, const Color(0xFF5E9B49));
  final rnd = math.Random(9);
  final colors = [k, _tone(k, 0.08), const Color(0xFFE5753A)];
  for (var i = 0; i < 34; i++) {
    final t = rnd.nextDouble();
    final spread = 4 + (1 - t) * 16;
    final center = Offset(
      50 + (rnd.nextDouble() - 0.5) * spread * 2,
      12 + t * 38,
    );
    final col = colors[rnd.nextInt(colors.length)];
    c.drawCircle(
      center,
      4.2,
      _volume(Rect.fromCircle(center: center, radius: 4.2), col),
    );
  }
}

// ------------------------------------------------------------------ leguminosas

void _pod(
  Canvas c,
  Color k, {
  int seeds = 3,
  bool fuzzy = false,
  bool curved = false,
}) {
  c.save();
  c.translate(50, 56);
  c.rotate(-0.45);
  final p = Path()
    ..moveTo(-38, 4)
    ..quadraticBezierTo(-20, curved ? -26 : -18, 10, -16)
    ..quadraticBezierTo(38, -14, 40, -4)
    ..quadraticBezierTo(30, curved ? 2 : 16, 0, 16)
    ..quadraticBezierTo(-28, 18, -38, 4)
    ..close();
  c.drawPath(p, _volume(p.getBounds(), k));
  final bump = _tone(k, 0.1);
  for (var i = 0; i < seeds; i++) {
    final x = -22.0 + i * (52 / seeds);
    final r = Rect.fromCenter(
      center: Offset(x, curved ? -6 : 0),
      width: 14,
      height: 13,
    );
    c.drawOval(r, _volume(r, bump));
  }
  if (fuzzy) {
    final hair = Paint()
      ..color = _tone(k, 0.22).withValues(alpha: 0.7)
      ..strokeWidth = 0.8;
    final rnd = math.Random(3);
    for (var i = 0; i < 40; i++) {
      final x = -34 + rnd.nextDouble() * 70;
      final y = -14 + rnd.nextDouble() * 28;
      c.drawLine(Offset(x, y), Offset(x + 1.5, y - 2), hair);
    }
  }
  _stroke(
    c,
    Path()
      ..moveTo(-38, 4)
      ..lineTo(-46, 10),
    _stem,
    2.4,
  );
  c.restore();
}

void _peaPod(Canvas c, Color k) {
  c.save();
  c.translate(50, 58);
  c.rotate(-0.35);
  final shell = Path()
    ..moveTo(-40, 0)
    ..quadraticBezierTo(0, 30, 40, 0)
    ..quadraticBezierTo(0, 8, -40, 0)
    ..close();
  c.drawPath(shell, _volume(shell.getBounds(), _tone(k, -0.05)));
  for (var i = 0; i < 5; i++) {
    final center = Offset(-24 + i * 12.0, 2);
    c.drawCircle(
      center,
      6.5,
      _volume(Rect.fromCircle(center: center, radius: 6.5), _tone(k, 0.08)),
    );
  }
  final lid = Path()
    ..moveTo(-40, 0)
    ..quadraticBezierTo(0, -22, 40, 0)
    ..quadraticBezierTo(0, -10, -40, 0)
    ..close();
  c.drawPath(lid, _volume(lid.getBounds(), k));
  c.restore();
}

void _cowpea(Canvas c, Color k) {
  _pod(c, k, seeds: 4);
  const eye = Rect.fromLTWH(56, 66, 26, 18);
  _blob(c, eye, const Color(0xFFF1E6CF));
  c.drawOval(
    const Rect.fromLTWH(64, 71, 9, 7),
    Paint()..color = const Color(0xFF2B2B2B),
  );
}

void _bean(Canvas c, Rect r, Color k, double angle) {
  c.save();
  c.translate(r.center.dx, r.center.dy);
  c.rotate(angle);
  final p = Path()
    ..moveTo(-r.width / 2, 0)
    ..cubicTo(
      -r.width / 2,
      -r.height / 2,
      r.width / 2,
      -r.height / 2,
      r.width / 2,
      0,
    )
    ..cubicTo(r.width / 2, r.height / 2, 4, r.height / 3, 0, r.height / 6)
    ..cubicTo(-4, r.height / 3, -r.width / 2, r.height / 2, -r.width / 2, 0)
    ..close();
  c.drawPath(p, _volume(p.getBounds(), k));
  _shine(c, Offset(-r.width * 0.2, -r.height * 0.18), 2.6);
  c.restore();
}

void _beans(Canvas c, Color k) {
  _bean(c, const Rect.fromLTWH(14, 52, 40, 26), k, -0.3);
  _bean(c, const Rect.fromLTWH(46, 50, 40, 26), _tone(k, 0.04), 0.35);
  _bean(c, const Rect.fromLTWH(30, 30, 40, 26), _tone(k, -0.03), 0.05);
}

void _chickpea(Canvas c, Color k) {
  for (final (center, r) in const [
    (Offset(36, 62), 16.0),
    (Offset(64, 64), 15.0),
    (Offset(50, 40), 15.0),
  ]) {
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawOval(rect, _volume(rect, k));
    _stroke(
      c,
      Path()
        ..moveTo(center.dx + r * 0.5, center.dy - r * 0.6)
        ..lineTo(center.dx + r * 0.85, center.dy - r * 0.95),
      _tone(k, -0.18),
      2,
    );
  }
}

void _lentils(Canvas c, Color k) {
  const discs = [
    Offset(30, 66),
    Offset(52, 70),
    Offset(72, 62),
    Offset(40, 48),
    Offset(62, 46),
    Offset(50, 30),
  ];
  for (var i = 0; i < discs.length; i++) {
    final r = Rect.fromCenter(center: discs[i], width: 22, height: 13);
    c.drawOval(r, _volume(r, i.isEven ? k : _tone(k, -0.06)));
  }
}

void _peanut(Canvas c, Color k) {
  c.save();
  c.translate(50, 56);
  c.rotate(-0.6);
  final p = Path()
    ..addOval(const Rect.fromLTWH(-34, -16, 34, 32))
    ..addOval(const Rect.fromLTWH(-6, -15, 34, 30))
    ..addRect(const Rect.fromLTWH(-14, -10, 16, 20));
  c.drawPath(p, _volume(p.getBounds(), k));
  final net = _tone(k, -0.14);
  for (var x = -28.0; x <= 22; x += 7) {
    _stroke(
      c,
      Path()
        ..moveTo(x, -10)
        ..lineTo(x + 3, 10),
      net,
      1,
    );
  }
  c.restore();
}

void _lupin(Canvas c, Color k) {
  _stalk(c, top: 18);
  for (final (angle, base) in const [
    (-1.0, Offset(50, 80)),
    (1.0, Offset(50, 80)),
  ]) {
    for (var i = 0; i < 4; i++) {
      _leafShape(
        c,
        base,
        angle * (0.5 + i * 0.25),
        18,
        3.2,
        const Color(0xFF5E9B49),
      );
    }
  }
  for (var i = 0; i < 7; i++) {
    final y = 18.0 + i * 7;
    final col = i < 2
        ? const Color(0xFFF4F1FB)
        : (i.isEven ? k : _tone(k, 0.12));
    for (final side in const [-1.0, 1.0]) {
      final r = Rect.fromCenter(
        center: Offset(50 + side * (4 + i * 0.6), y),
        width: 9,
        height: 7,
      );
      c.drawOval(r, _volume(r, col));
    }
  }
}

// ------------------------------------------------------------------ flores y otros

void _sunflower(Canvas c, Color k) {
  _stalk(c, top: 46);
  _leafShape(c, const Offset(50, 76), -1.0, 22, 8);
  _leafShape(c, const Offset(50, 70), 1.0, 20, 8);
  const center = Offset(50, 36);
  for (var i = 0; i < 14; i++) {
    final a = i * math.pi * 2 / 14;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(a);
    const petal = Rect.fromLTWH(-4.5, -28, 9, 18);
    c.drawOval(petal, _volume(petal, k));
    c.restore();
  }
  final disc = Rect.fromCircle(center: center, radius: 12);
  c.drawOval(disc, _volume(disc, const Color(0xFF6B4423)));
  final seed = Paint()..color = const Color(0xFF4A2E17);
  for (var i = 0; i < 12; i++) {
    final a = i * 2.4;
    final d = math.sqrt(i + 1) * 2.6;
    c.drawCircle(center + Offset(math.cos(a) * d, math.sin(a) * d), 1, seed);
  }
}

void _rapeseed(Canvas c, Color k) {
  for (final (base, top) in const [
    (Offset(50, 88), Offset(50, 30)),
    (Offset(50, 80), Offset(30, 42)),
    (Offset(50, 80), Offset(70, 40)),
  ]) {
    _stroke(
      c,
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx, top.dy + 20, top.dx, top.dy),
      _stem,
      2,
    );
  }
  for (final center in const [
    Offset(50, 24),
    Offset(30, 36),
    Offset(70, 34),
    Offset(42, 18),
    Offset(60, 20),
  ]) {
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      final r = Rect.fromCenter(
        center: center + Offset(math.cos(a) * 4, math.sin(a) * 4),
        width: 7,
        height: 7,
      );
      c.drawOval(r, _volume(r, k));
    }
    c.drawCircle(center, 1.6, Paint()..color = const Color(0xFFD08A12));
  }
}

void _fallow(Canvas c, Color k) {
  final mound = Path()
    ..moveTo(10, 84)
    ..quadraticBezierTo(50, 40, 90, 84)
    ..close();
  c.drawPath(mound, _volume(mound.getBounds(), k));
  for (final x in const [32.0, 50.0, 68.0]) {
    for (final a in const [-0.5, 0.0, 0.5]) {
      _leafShape(
        c,
        Offset(x, x == 50 ? 62 : 70),
        a,
        14,
        2.2,
        const Color(0xFF7DB04B),
      );
    }
  }
}

void _sprout(Canvas c, Color k) {
  _stalk(c, top: 40);
  _leafShape(c, const Offset(50, 44), -0.9, 26, 9, k);
  _leafShape(c, const Offset(50, 44), 0.9, 26, 9, k);
}

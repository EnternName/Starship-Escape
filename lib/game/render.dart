part of 'starship_game.dart';

// ---------- drawing helpers ----------
const _display = 'Bungee';
const _body = 'ChakraPetch';

Color hex(int v, [double a = 1]) => Color(0xFF000000 | v).withValues(alpha: a.clamp(0.0, 1.0));
Color rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a.clamp(0.0, 1.0));
Paint fill(Color c) => Paint()..color = c;
Paint glow(Color c) => Paint()
  ..color = c
  ..blendMode = BlendMode.plus;
Paint stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;
Paint shaderPaint(Shader s, {bool add = false}) => Paint()
  ..shader = s
  ..blendMode = add ? BlendMode.plus : BlendMode.srcOver;
Shader linear(Offset a, Offset b, List<Color> colors, [List<double>? stops]) => ui.Gradient.linear(a, b, colors, stops);
Shader radial(Offset c, double r, List<Color> colors, [List<double>? stops]) => ui.Gradient.radial(c, r, colors, stops);

void rr(Canvas c, double x, double y, double w, double h, double r, Paint p) =>
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p);
void rect(Canvas c, double x, double y, double w, double h, Paint p) => c.drawRect(Rect.fromLTWH(x, y, w, h), p);
void line(Canvas c, double x0, double y0, double x1, double y1, Paint p) => c.drawLine(Offset(x0, y0), Offset(x1, y1), p);

final Map<String, TextPainter> _textCache = {};

/// Draws text with its baseline at [y], like canvas fillText.
void drawText(Canvas c, String s, double x, double y,
    {double size = 14, Color color = const Color(0xFFF4EFFC), String family = _body, FontWeight weight = FontWeight.w400, TextAlign align = TextAlign.left}) {
  final key = '$s|$size|${color.toARGB32()}|$family|${weight.value}';
  var tp = _textCache[key];
  if (tp == null) {
    if (_textCache.length > 400) _textCache.clear();
    tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    _textCache[key] = tp;
  }
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = align == TextAlign.center ? x - tp.width / 2 : align == TextAlign.right ? x - tp.width : x;
  tp.paint(c, Offset(dx, y - base));
}

double textWidth(String s, double size, String family, FontWeight weight) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
}

// ---------- background data ----------
final _bgRand = math.Random(42);
final List<Star> _stars = List.generate(
    140, (_) => Star(_bgRand.nextDouble() * stageW, _bgRand.nextDouble() * stageH * 0.7, _bgRand.nextDouble() * 1.4 + 0.3, _bgRand.nextDouble() * 6));

List<SkyBuilding> _makeSkyline(int seed, int count, double minH, double maxH, double spacing) {
  final r = math.Random(seed);
  final out = <SkyBuilding>[];
  var x = -40.0;
  for (var i = 0; i < count; i++) {
    final w = 30 + r.nextDouble() * 70, h = minH + r.nextDouble() * (maxH - minH);
    final wins = <SkyWindow>[];
    for (var yy = 10.0; yy < h - 8; yy += 12) {
      for (var xx = 6.0; xx < w - 6; xx += 10) {
        if (r.nextDouble() < 0.22) wins.add(SkyWindow(xx, yy, r.nextDouble() * 10));
      }
    }
    out.add(SkyBuilding(x, w, h, r.nextDouble() < 0.4, r.nextDouble() * 20, wins, r.nextDouble() < 0.25));
    x += w + r.nextDouble() * spacing;
  }
  return out;
}

final List<SkyBuilding> _far = _makeSkyline(7, 70, 60, 170, 20);
final List<SkyBuilding> _mid = _makeSkyline(19, 80, 70, 220, 60);
final List<Ember> _embers = List.generate(60, (i) {
  final r = math.Random(100 + i);
  return Ember(r.nextDouble() * stageW, r.nextDouble() * stageH, r.nextDouble() * 2 + 0.6, 10 + r.nextDouble() * 30, i % 3 == 0);
});

Color _mix(int a, int b, double p) {
  int ch(int v, int k) => (v >> k) & 255;
  int c(int k) => lerpD(ch(a, k).toDouble(), ch(b, k).toDouble(), p).round();
  return Color.fromARGB(255, c(16), c(8), c(0));
}

extension Render on StarshipGame {
  void renderScene(Canvas c, double dt) {
    final sx = shake > 0 ? rand(-shake, shake) : 0.0, sy = shake > 0 ? rand(-shake, shake) : 0.0;
    c.save();
    c.translate(sx * 0.4, sy * 0.4);
    drawBackground(c);
    c.restore();

    c.save();
    c.translate((-cam.dx + sx).roundToDouble(), (-cam.dy + sy).roundToDouble());
    drawChasm(c);
    drawCrane(c);
    for (final r in rockets) {
      drawRocket(c, r);
    }
    drawTower(c);
    for (final l in lavas) {
      drawLava(c, l);
    }
    for (final s in solids) {
      drawSolid(c, s);
    }
    drawLamps(c);
    for (final v in vents) {
      drawVent(c, v);
    }
    for (final b in birds) {
      drawBird(c, b);
    }
    for (final d in debris) {
      drawDebris(c, d);
    }
    if (state != GameState.title) drawPlayer(c);
    drawParticles(c);
    for (final tx in texts) {
      final a = (tx.life / tx.max * 2).clamp(0.0, 1.0);
      drawText(c, tx.text, tx.x + 2, tx.y + 2, size: 16, family: _display, color: hex(0x1A0F22, a), align: TextAlign.center);
      drawText(c, tx.text, tx.x, tx.y, size: 16, family: _display, color: tx.color.withValues(alpha: a), align: TextAlign.center);
    }
    c.restore();

    drawEmbers(c, dt);
    // Vignette.
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(radial(const Offset(stageW / 2, stageH / 2), stageH, [const Color(0x00000000), const Color(0x00000000), hex(0x080410, 0.6)], [0, 0.4, 1])));
    if (state == GameState.play) {
      drawHud(c);
      drawBanner(c);
    }
    if (state == GameState.title) drawTitle(c);
    if (state == GameState.won || state == GameState.lost) drawEnd(c);
  }

  // ---------- background ----------
  void drawBackground(Canvas c) {
    final pr = (t / 62).clamp(0.0, 1.0);
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(linear(Offset.zero, const Offset(0, stageH), [_mix(0x0D0A24, 0x1E0814, pr), _mix(0x2B1446, 0x4A1022, pr), _mix(0x8A3446, 0xC4381E, pr)], [0, 0.55, 1])));
    final yOff = -cam.dy * 0.08;
    // Stars dim as the sky burns.
    for (final s in _stars) {
      final a = (0.4 + 0.6 * math.sin(real * 1.3 + s.tw).abs()) * (1 - pr * 0.75);
      rect(c, (s.x - cam.dx * 0.02 + stageW * 4) % stageW, s.y + yOff * 0.5, s.s, s.s, fill(rgba(255, 240, 255, a)));
    }
    // Broken moon with a ring of debris.
    final mx = 760 - cam.dx * 0.015, my = 110 + yOff * 0.4;
    c.drawCircle(Offset(mx, my), 48, shaderPaint(radial(Offset(mx - 14, my - 14), 62, [hex(0xFBE9E0), hex(0xB58AA0)])));
    final crack = Path()
      ..moveTo(mx - 30, my - 20)
      ..lineTo(mx - 6, my - 2)
      ..lineTo(mx - 12, my + 14)
      ..lineTo(mx + 10, my + 30)
      ..moveTo(mx - 6, my - 2)
      ..lineTo(mx + 22, my - 12);
    c.drawPath(crack, stroke(rgba(70, 20, 50, 0.55), 2));
    c.save();
    c.translate(mx, my);
    c.rotate(-0.35);
    for (var i = 0; i < 46; i++) {
      final a = i / 46 * math.pi * 2 + real * 0.05;
      final rx = math.cos(a) * 92, ry = math.sin(a) * 18;
      if (ry < 0 && rx.abs() < 46) continue;
      rect(c, rx, ry, 2.0 + (i % 2), 2, fill(rgba(230, 200, 220, 0.35 + (i % 3) * 0.15)));
    }
    c.restore();
    // Volcano with a glowing plume.
    final vx = 300 - cam.dx * 0.03, vy = 360 + yOff;
    c.drawPath(
        Path()
          ..moveTo(vx - 260, vy + 60)
          ..lineTo(vx - 40, vy - 90)
          ..lineTo(vx + 40, vy - 90)
          ..lineTo(vx + 280, vy + 60)
          ..close(),
        fill(hex(0x2A1128)));
    rect(c, vx - 140, vy - 210, 280, 240,
        shaderPaint(radial(Offset(vx, vy - 90), 120, [rgba(255, 140, 60, 0.55), rgba(255, 60, 40, 0)]), add: true));
    for (var i = 0; i < 30; i++) {
      final o = i / 30, r = 20.0 + i * 4;
      final k = (o + real * 0.03) % 1;
      c.drawCircle(Offset(vx + math.sin(k * 6 + r) * 30 + k * 160, vy - 100 - k * 260), r * (0.4 + k), fill(rgba(40, 18, 40, 0.22 * (1 - k))));
    }
    final lava = Path()
      ..moveTo(vx - 10, vy - 88)
      ..quadraticBezierTo(vx - 50, vy - 20, vx - 90, vy + 50)
      ..moveTo(vx + 12, vy - 88)
      ..quadraticBezierTo(vx + 40, vy, vx + 70, vy + 55);
    c.drawPath(lava, stroke(rgba(255, 110, 50, 0.7), 2));
    // Distant launches.
    for (final b in bgRockets) {
      final n = b.trail.length;
      for (var i = 0; i < n; i++) {
        final tp = b.trail[i];
        final a = i / n;
        c.drawCircle(Offset(tp.dx - cam.dx * 0.06, tp.dy + yOff), 1 + (1 - a) * 5, glow(rgba(255, 190, 120, a * 0.25)));
      }
      c.drawCircle(Offset(b.x - cam.dx * 0.06, b.y + yOff), 2.5, glow(hex(0xFFF3C4)));
    }
    drawSkyline(c, _far, 0.12, 400 + yOff * 1.2, hex(0x24102E), 0.5);
    // Horizon fire glow.
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(linear(Offset(0, 330 + yOff * 1.5), const Offset(0, stageH), [rgba(255, 90, 40, 0), rgba(255, 90, 40, 0.18 + pr * 0.2 + quake * 0.05)]), add: true));
    drawSkyline(c, _mid, 0.35, 470 + yOff * 2.2, hex(0x180A20), 1);
  }

  void drawSkyline(Canvas c, List<SkyBuilding> list, double par, double base, Color color, double winA) {
    final span = list.last.x + 200;
    final off = (cam.dx * par) % span;
    for (var rep = 0; rep < 2; rep++) {
      for (final b in list) {
        final x = b.x - off + rep * span;
        if (x > stageW + 20 || x + b.w < -20) continue;
        final top = base - b.h;
        final cut = b.broken ? b.cut : 0.0;
        final path = Path()
          ..moveTo(x, base + 200)
          ..lineTo(x, top + cut);
        if (b.broken) {
          path
            ..lineTo(x + b.w * 0.3, top + b.cut * 0.4)
            ..lineTo(x + b.w * 0.45, top + b.cut + 10)
            ..lineTo(x + b.w * 0.7, top);
        } else {
          path.lineTo(x + b.w, top);
        }
        path
          ..lineTo(x + b.w, top + (b.broken ? 6 : 0))
          ..lineTo(x + b.w, base + 200)
          ..close();
        c.drawPath(path, fill(color));
        for (final w in b.wins) {
          final f = math.sin(real * 3 + w.f) > -0.6 ? 1.0 : 0.3;
          rect(c, x + w.x, top + w.y + cut, 3, 4, fill(rgba(255, 150 + (w.f * 10).floor(), 80, 0.55 * winA * f)));
        }
        if (b.fire) {
          final fy = top + cut;
          rect(c, x + b.w / 2 - 40, fy - 40, 80, 80,
              shaderPaint(radial(Offset(x + b.w / 2, fy), 40, [rgba(255, 150, 60, 0.5 * winA + math.sin(real * 9 + b.x) * 0.08), rgba(255, 80, 40, 0)]), add: true));
        }
      }
    }
  }

  // ---------- world ----------
  void drawChasm(Canvas c) {
    // Darken the gap so the drop reads as a hole in the city.
    rect(c, 4500, ground - 20, 800, 180,
        shaderPaint(linear(const Offset(0, ground), const Offset(0, 640), [rgba(10, 6, 18, 0.55), rgba(10, 6, 18, 0.9), rgba(120, 30, 30, 0.9)], [0, 0.8, 1])));
  }

  void drawSolid(Canvas c, Solid s) {
    if (!s.alive && !s.falling) return;
    if (s.x > cam.dx + stageW + 40 || s.x + s.w < cam.dx - 40) return;
    final r = math.Random(s.seed);
    final alpha = s.fadeIn > 0 ? 1 - s.fadeIn / 0.5 : 1.0;
    if (alpha < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    switch (s.kind) {
      case Kind.ground:
      case Kind.pitfloor:
        final x0 = math.max(s.x, cam.dx - 20), x1 = math.min(s.x + s.w, cam.dx + stageW + 20);
        rect(c, x0, s.y, x1 - x0, s.h, shaderPaint(linear(Offset(0, s.y), Offset(0, s.y + 200), [hex(0x2A1D38), hex(0x0C0814)])));
        rect(c, x0, s.y, x1 - x0, 4, fill(hex(0x4A3560)));
        rect(c, x0, s.y, x1 - x0, 1.5, fill(rgba(255, 140, 80, 0.35)));
        // Glowing fissures, pulsing harder during quakes.
        const step = 110.0;
        for (var fx = (x0 / step).floor() * step; fx < x1; fx += step) {
          final fr = math.Random(fx.toInt());
          if (fr.nextDouble() < 0.45) continue;
          final a = 0.35 + 0.25 * math.sin(real * 2 + fx) + quake * 0.3;
          var cx = fx + fr.nextDouble() * 60, cy = s.y + 3;
          final path = Path()..moveTo(cx, cy);
          for (var i = 0; i < 4; i++) {
            cx += fr.nextDouble() * 16 - 8;
            cy += 6 + fr.nextDouble() * 10;
            path.lineTo(cx, cy);
          }
          c.drawPath(path, stroke(rgba(255, 110 + (fr.nextDouble() * 60).floor(), 50, a), 1.6)..blendMode = BlendMode.plus);
        }
      case Kind.building:
        rect(c, s.x, s.y, s.w, s.h, shaderPaint(linear(Offset(s.x, 0), Offset(s.x + s.w, 0), [hex(0x2F2045), hex(0x1F1530)])));
        rect(c, s.x - 4, s.y, s.w + 8, 6, fill(hex(0x4B3666)));
        for (var yy = s.y + 18; yy < s.y + s.h - 10; yy += 22) {
          for (var xx = s.x + 12; xx < s.x + s.w - 14; xx += 22) {
            final lit = r.nextDouble() < 0.35;
            final f = lit && math.sin(real * 6 + xx) > -0.8;
            rect(c, xx, yy, 10, 12, fill(f ? rgba(255, 170, 90, 0.75) : hex(0x140D20)));
          }
        }
      case Kind.rubble:
      case Kind.rock:
      case Kind.hill:
        final path = Path()
          ..moveTo(s.x, s.y + s.h)
          ..lineTo(s.x, s.y + 4);
        final n = math.max(3, (s.w / 30).floor());
        for (var i = 1; i < n; i++) {
          path.lineTo(s.x + s.w * i / n, s.y + r.nextDouble() * 6 - 2);
        }
        path
          ..lineTo(s.x + s.w, s.y + 4)
          ..lineTo(s.x + s.w, s.y + s.h)
          ..close();
        c.drawPath(path, fill(s.kind == Kind.hill ? hex(0x2D1F3E) : hex(0x33244A)));
        rect(c, s.x + 2, s.y, s.w - 4, 3, fill(hex(0x4E3A68)));
        final crackPaint = stroke(rgba(0, 0, 0, 0.3), 1);
        for (var i = 0; i < s.w * s.h / 1800; i++) {
          final px = s.x + r.nextDouble() * s.w, py = s.y + 8 + r.nextDouble() * (s.h - 10);
          line(c, px, py, px + r.nextDouble() * 14 - 7, py + r.nextDouble() * 10, crackPaint);
        }
      case Kind.wall:
        rect(c, s.x, s.y, s.w, s.h, fill(hex(0x3D2C52)));
        final mortar = stroke(hex(0x21162E), 1);
        for (var yy = s.y; yy < s.y + s.h; yy += 10) {
          line(c, s.x, yy, s.x + s.w, yy, mortar);
        }
        c.drawPath(
            Path()
              ..moveTo(s.x + 6, s.y + 4)
              ..lineTo(s.x + 14, s.y + 22)
              ..lineTo(s.x + 8, s.y + 38),
            stroke(rgba(255, 220, 180, 0.25), 1));
      case Kind.deck:
        if (s.alive) {
          final leg = stroke(hex(0x5B4A74), 4);
          for (final lx in [s.x + 20, s.x + s.w - 20]) {
            line(c, lx, s.y + s.h, lx, ground, leg);
          }
          final brace = stroke(hex(0x5B4A74), 2);
          for (var yy = s.y + s.h; yy < ground - 20; yy += 40) {
            line(c, s.x + 20, yy, s.x + s.w - 20, yy + 40, brace);
            line(c, s.x + s.w - 20, yy, s.x + 20, yy + 40, brace);
          }
        }
        rect(c, s.x, s.y, s.w, s.h, fill(hex(0x4A3A62)));
        for (var xx = s.x; xx < s.x + s.w; xx += 24) {
          rect(c, xx, s.y + 4, 12, 5, fill(((xx - s.x) / 24).floor().isEven ? hex(0xFFC94D) : hex(0x2A2038)));
        }
        if (s.alive) {
          for (final lx in [s.x + 4, s.x + s.w - 8]) {
            rect(c, lx, s.y - 6, 4, 6, fill(math.sin(real * 5) > 0 ? hex(0xFF4B3A) : hex(0x5A2A2A)));
          }
        }
      case Kind.ledge:
        final metal = hex(0x5A4A72);
        rect(c, s.x, s.y, s.w, 4, fill(metal));
        final grate = stroke(metal, 1.5);
        for (var xx = s.x + 4; xx < s.x + s.w; xx += 8) {
          line(c, xx, s.y + 4, xx + 4, s.y + 12, grate);
        }
        c.drawPath(
            Path()
              ..moveTo(s.x, s.y)
              ..lineTo(s.x, s.y - 14)
              ..lineTo(s.x + s.w, s.y - 14)
              ..lineTo(s.x + s.w, s.y),
            grate);
      case Kind.pad:
        rect(c, s.x, s.y, s.w, s.h, fill(hex(0x3C3150)));
        for (var xx = s.x; xx < s.x + s.w; xx += 20) {
          rect(c, xx, s.y + 2, 10, 4, fill(((xx - s.x) / 20).floor().isEven ? hex(0xFFC94D) : hex(0x2A2038)));
        }
        for (final lx in [s.x + 2, s.x + s.w - 6]) {
          rect(c, lx, s.y - 5, 4, 5, fill(math.sin(real * 6 + lx) > 0 ? hex(0x7CF0FF) : hex(0x28485A)));
        }
      case Kind.stone:
        rect(c, s.x, s.y, s.w, s.h, fill(hex(0x231A2E)));
        rect(c, s.x, s.y, s.w, 4, fill(hex(0x3E2F52)));
        rect(c, s.x, s.y + s.h - 40, s.w, 40, glow(rgba(255, 100, 40, 0.3)));
      case Kind.slab:
        c.save();
        if (s.crumble > 0 && !s.falling) c.translate(math.sin(real * 80) * 1.5, 0);
        rr(c, s.x, s.y, s.w, s.h, 3, fill(hex(0x4A3A62)));
        rect(c, s.x + 3, s.y, s.w - 6, 3, fill(hex(0x6B5888)));
        line(c, s.x + s.w * 0.4, s.y, s.x + s.w * 0.5, s.y + s.h, stroke(rgba(0, 0, 0, 0.4), 1));
        c.restore();
      case Kind.cliff:
        rect(c, s.x, s.y, s.w, s.h, fill(hex(0x160E20)));
      case Kind.bridge:
      case Kind.girder:
        // Drawn by the water tower and the crane.
        break;
    }
    if (alpha < 1) c.restore();
  }

  void drawTower(Canvas c) {
    c.save();
    c.translate(tower.px, tower.py);
    c.rotate(tower.ang);
    // Legs (local x -40..0, y 0..-270).
    final leg = stroke(hex(0x6A5788), 3);
    line(c, -36, 0, -30, -150, leg);
    line(c, -4, 0, -10, -150, leg);
    final brace = stroke(hex(0x6A5788), 1.5);
    for (var y = 0.0; y > -150; y -= 30) {
      line(c, -35, y, -6, y - 30, brace);
      line(c, -5, y, -34, y - 30, brace);
    }
    rr(c, -44, -260, 48, 112, 8, shaderPaint(linear(const Offset(-44, 0), const Offset(4, 0), [hex(0x5C4A7A), hex(0x7C68A0), hex(0x3E3054)], [0, 0.5, 1])));
    c.drawPath(
        Path()
          ..moveTo(-48, -258)
          ..lineTo(-20, -284)
          ..lineTo(8, -258)
          ..close(),
        fill(hex(0x3B2D50)));
    c.save();
    c.translate(-14, -200);
    c.rotate(-math.pi / 2);
    drawText(c, 'H2O', 0, 4, size: 10, family: _display, color: rgba(255, 220, 180, 0.7), align: TextAlign.center);
    c.restore();
    if (!tower.falling) {
      c.drawPath(
          Path()
            ..moveTo(-36, -2)
            ..lineTo(-30, -18)
            ..lineTo(-34, -30),
          stroke(rgba(255, 230, 200, 0.45), 1));
    }
    c.restore();
  }

  void drawCrane(Canvas c) {
    const bx = 4400.0, top = -260.0;
    final steel = stroke(hex(0x5D4A78), 3);
    line(c, bx, ground, bx, top, steel);
    line(c, bx + 30, ground, bx + 30, top, steel);
    final thin = stroke(hex(0x5D4A78), 1.5);
    for (var y = ground; y > top; y -= 34) {
      line(c, bx, y, bx + 30, y - 34, thin);
    }
    line(c, bx - 120, top, 5320, top, steel);
    line(c, bx - 120, top + 18, 5320, top + 18, steel);
    final lattice = stroke(hex(0x5D4A78), 1.2);
    for (var x = bx - 120; x < 5320; x += 30) {
      line(c, x, top, x + 30, top + 18, lattice);
    }
    rect(c, bx - 130, top - 6, 60, 34, fill(hex(0x3A2C50)));
    rect(c, 5316, top - 6, 6, 6, fill(math.sin(real * 4) > 0 ? hex(0xFF4B3A) : hex(0x5A2A2A)));
    // Cables and girder.
    final gy = girder.y;
    final cable = stroke(hex(0x8A7AA6), 1);
    line(c, 4700, top + 18, 4700, gy, cable);
    line(c, 5100, top + 18, 5100, gy, cable);
    rect(c, 4500, gy, 800, 16, fill(hex(0xA3332E)));
    rect(c, 4500, gy, 800, 3, fill(hex(0xC94A3A)));
    final truss = stroke(hex(0x6E1F20), 1.5);
    for (var x = 4500.0; x < 5300; x += 20) {
      line(c, x, gy + 3, x + 20, gy + 16, truss);
    }
    // Control box on the scaffold.
    rect(c, 4318, 330, 26, 30, fill(hex(0x2F243F)));
    rect(c, 4324, 338, 6, 6, fill(triggers[2].fired ? hex(0x59F08A) : hex(0xFF5A3A)));
  }

  void drawLamps(Canvas c) {
    for (final tr in triggers) {
      if (tr.fired) continue;
      // A broken light that flickers in an uneven rhythm.
      final on = math.sin(real * 23 + tr.zone.x) * math.sin(real * 7.3) > 0.1 || _rng.nextDouble() < 0.05;
      if (!on) continue;
      rect(c, tr.lamp.dx - 46, tr.lamp.dy - 46, 92, 92,
          shaderPaint(radial(tr.lamp, 46, [rgba(190, 235, 255, 0.65), rgba(120, 190, 255, 0)]), add: true));
    }
    final post = fill(hex(0x5A4A72));
    for (final tr in triggers) {
      if (tr.name == 'tunnel') {
        rect(c, tr.lamp.dx - 1, tr.lamp.dy, 3, ground - tr.lamp.dy, post);
        rect(c, tr.lamp.dx - 6, tr.lamp.dy - 3, 12, 4, post);
      } else {
        rect(c, tr.lamp.dx - 4, tr.lamp.dy - 2, 8, 4, post);
      }
    }
  }

  void drawLava(Canvas c, Box l) {
    final path = Path()..moveTo(l.x, l.y + l.h);
    for (var x = l.x; x <= l.x + l.w; x += 8) {
      path.lineTo(x, l.y + math.sin(real * 3 + x * 0.08) * 3);
    }
    path
      ..lineTo(l.x + l.w, l.y + l.h)
      ..close();
    c.drawPath(path, shaderPaint(linear(Offset(0, l.y), Offset(0, l.y + l.h), [hex(0xFFD36B), hex(0xFF6A2A), hex(0x8A1414)], [0, 0.3, 1])));
    rect(c, l.x - 160, l.y - 160, l.w + 320, 240,
        shaderPaint(radial(Offset(l.x + l.w / 2, l.y), 160, [rgba(255, 120, 50, 0.45), rgba(255, 60, 30, 0)]), add: true));
  }

  void drawVent(Canvas c, Vent v) {
    rect(c, v.x - 2, v.y - 6, v.w + 4, 6, fill(hex(0x4A3A62)));
    rect(c, v.x + 4, v.y - 5, v.w - 8, 3, fill(v.on ? hex(0xFFB46B) : v.warm ? hex(0xC4603A) : hex(0x1A1224)));
    if (v.on) {
      rect(c, v.x - 70, v.y - 140, v.w + 140, 150,
          shaderPaint(radial(Offset(v.x + v.w / 2, v.y - 50), 80, [rgba(255, 150, 60, 0.5), rgba(255, 80, 40, 0)]), add: true));
    }
  }

  void drawRocket(Canvas c, Rocket r) {
    if (r.phase == RocketPhase.gone) return;
    final x = r.x, by = r.padY + r.y;
    if (x < cam.dx - 120 || x > cam.dx + stageW + 120) return;
    // Gantry arm next to waiting rockets.
    if (r.phase == RocketPhase.wait) {
      final arm = stroke(hex(0x4E3E68), 3);
      line(c, x + 46, r.padY, x + 46, r.padY - 175, arm);
      line(c, x + 46, r.padY - 120, x + 22, r.padY - 120, arm);
      final thin = stroke(hex(0x4E3E68), 1);
      for (var y = r.padY; y > r.padY - 175; y -= 20) {
        line(c, x + 40, y, x + 52, y - 20, thin);
      }
      final left = r.launchT - t;
      if (left < 6) {
        rect(c, x + 43, r.padY - 182, 7, 7, fill(math.sin(real * (left < 3 ? 24 : 10)) > 0 ? hex(0xFF3B30) : hex(0x4A1A1A)));
      }
    }
    c.save();
    if (r.phase == RocketPhase.launch && r.t < 1.5) c.translate(math.sin(real * 70) * 1.5, 0);
    if (r.phase == RocketPhase.launch) {
      final fl = 60 + _rng.nextDouble() * 40 + r.t * 30;
      c.drawPath(
          Path()
            ..moveTo(x - 14, by)
            ..quadraticBezierTo(x, by + fl * 1.3, x + 14, by)
            ..close(),
          shaderPaint(linear(Offset(0, by), Offset(0, by + fl), [rgba(255, 255, 220, 0.95), rgba(255, 190, 80, 0.8), rgba(255, 60, 30, 0)], [0, 0.3, 1]), add: true));
      rect(c, x - 140, by - 130, 280, 280,
          shaderPaint(radial(Offset(x, by + 10), 140, [rgba(255, 180, 90, 0.6), rgba(255, 90, 40, 0)]), add: true));
    }
    final red = fill(hex(0xC23A33));
    c.drawPath(
        Path()
          ..moveTo(x - 20, by - 50)
          ..lineTo(x - 36, by)
          ..lineTo(x - 20, by - 8)
          ..close(),
        red);
    c.drawPath(
        Path()
          ..moveTo(x + 20, by - 50)
          ..lineTo(x + 36, by)
          ..lineTo(x + 20, by - 8)
          ..close(),
        red);
    rr(c, x - 20, by - 150, 40, 146, 6, shaderPaint(linear(Offset(x - 20, 0), Offset(x + 20, 0), [hex(0x9C93B4), hex(0xF3EEFC), hex(0x7D7396)], [0, 0.4, 1])));
    c.drawPath(
        Path()
          ..moveTo(x - 20, by - 148)
          ..quadraticBezierTo(x - 18, by - 190, x, by - 210)
          ..quadraticBezierTo(x + 18, by - 190, x + 20, by - 148)
          ..close(),
        fill(hex(0xD8453B)));
    rect(c, x - 20, by - 70, 40, 5, fill(hex(0x2A2140)));
    rect(c, x - 20, by - 18, 40, 10, fill(hex(0xD8453B)));
    for (final wy in [by - 125, by - 100]) {
      c.drawCircle(Offset(x, wy), 7, fill(hex(0x2A2140)));
      c.drawCircle(Offset(x, wy), 5, fill(r.withPlayer && wy == by - 100 ? hex(0xFFD36B) : hex(0x7CD6FF)));
    }
    drawText(c, 'ARK-${r.id}', x, by - 40, size: 9, family: _display, color: hex(0x2A2140), align: TextAlign.center);
    if (r.phase == RocketPhase.wait) rr(c, x - 9, by - 62, 18, 34, 4, stroke(hex(0x4A4060), 1.5));
    c.restore();
  }

  void drawBird(Canvas c, Bird b) {
    final dark = hex(0x120A18);
    final y = b.y - (b.hopUp > 0 ? 3 : 0);
    if (b.flying) {
      final w = math.sin(b.flap) * 6;
      c.drawPath(
          Path()
            ..moveTo(b.x - 7, y - 4 - w)
            ..lineTo(b.x, y - 2)
            ..lineTo(b.x + 7, y - 4 - w),
          stroke(dark, 2, cap: StrokeCap.round));
    } else {
      c.drawOval(Rect.fromCenter(center: Offset(b.x, y - 5), width: 10, height: 8), fill(dark));
      c.drawCircle(Offset(b.x + 4, y - 9), 2.6, fill(dark));
      rect(c, b.x + 6, y - 9, 2, 1.5, fill(hex(0xFFB46B)));
    }
  }

  void drawDebris(Canvas c, Debris d) {
    // Ground shadow grows as the rock gets closer.
    final k = (1 - (d.landY - d.y) / 620).clamp(0.0, 1.0);
    c.drawOval(Rect.fromCenter(center: Offset(d.x, d.landY - 1), width: d.r * (0.6 + k) * 2, height: (3 + k * 2) * 2),
        fill(rgba(255, 70, 40, 0.15 + k * 0.4)));
    c.save();
    c.translate(d.x, d.y);
    c.rotate(d.spin);
    rect(c, -d.r * 2.4, -d.r * 2.4, d.r * 4.8, d.r * 4.8,
        shaderPaint(radial(Offset.zero, d.r * 2.4, [rgba(255, 140, 60, 0.6), rgba(255, 80, 40, 0)]), add: true));
    final path = Path();
    for (var i = 0; i < 7; i++) {
      final a = i / 7 * math.pi * 2, r2 = d.r * (0.75 + ((i * 37) % 10) / 30);
      if (i == 0) {
        path.moveTo(math.cos(a) * r2, math.sin(a) * r2);
      } else {
        path.lineTo(math.cos(a) * r2, math.sin(a) * r2);
      }
    }
    path.close();
    c.drawPath(path, fill(hex(0x3D2A44)));
    c.drawPath(path, stroke(hex(0xFF9B54), 1.5));
    c.restore();
  }

  void drawPlayer(Canvas c) {
    if (p.boarded != null) return;
    final cx = p.x + p.w / 2, fy = p.y + p.h;
    // Scarf.
    final scarf = Path()..moveTo(p.scarf[0].x, p.scarf[0].y);
    for (final s in p.scarf) {
      scarf.lineTo(s.x, s.y);
    }
    c.drawPath(scarf, stroke(hex(0xFF5B3A), 4, cap: StrokeCap.round));
    c.save();
    c.translate(cx, fy);
    var rot = 0.0;
    if (p.stagger > 0) rot = math.sin(real * 14) * 0.18;
    if (p.stun > 0) rot = -p.face * 0.3;
    c.rotate(rot);
    c.scale(p.face * (2 - p.sq), p.sq);
    final running = p.onGround && p.vx.abs() > 20;
    final ph = p.run;
    final air = !p.onGround && p.climb == null;
    // Legs.
    final legPaint = stroke(hex(0xD9D1EA), 5);
    final legA = running ? math.sin(ph) * 0.7 : air ? 0.5 : 0.0;
    final legB = running ? math.sin(ph + math.pi) * 0.7 : air ? -0.3 : 0.0;
    for (final (a, dx) in [(legA, -3.0), (legB, 3.0)]) {
      final ex = dx + math.sin(a) * 12, ey = -14 + math.cos(a) * 12;
      line(c, dx, -14, ex, ey, legPaint);
      rect(c, ex - 3, ey - 2, 7, 4, fill(hex(0x3B2C52)));
    }
    final bob = running ? math.sin(ph).abs() * -2 : 0.0;
    c.translate(0, bob);
    // Backpack.
    rr(c, -14, -32, 8, 16, 2, fill(hex(0x6D6288)));
    rect(c, -13, -22, 2, 4, fill(hex(0xFFB36B)));
    // Body.
    rr(c, -8, -33, 16, 21, 5, fill(hex(0xEFE9FA)));
    rect(c, -8, -24, 16, 3, fill(hex(0xFF7A3D)));
    // Arms.
    final armPaint = stroke(hex(0xEFE9FA), 4, cap: StrokeCap.round);
    if (p.climb != null) {
      line(c, -3, -28, 4, -46, armPaint);
      line(c, 3, -28, 10, -44, armPaint);
    } else {
      final arm = running ? math.sin(ph + math.pi) * 0.9 : air ? -2.2 : 0.2;
      line(c, 0, -28, math.sin(arm) * 10, -28 + math.cos(arm) * 10, armPaint);
    }
    // Helmet with a visor that reflects the burning sky.
    c.drawCircle(const Offset(1, -40), 9, fill(hex(0xF7F3FF)));
    rr(c, 1, -45, 9, 9, 3, shaderPaint(linear(const Offset(0, -46), const Offset(0, -34), [hex(0xFFB36B), hex(0x4A2A7A)])));
    rect(c, 4, -43, 2, 3, fill(rgba(255, 255, 255, 0.8)));
    c.restore();
    if (p.stagger > 0) {
      for (var i = 0; i < 3; i++) {
        final a = real * 6 + i * 2.1;
        c.save();
        c.translate(cx + math.cos(a) * 12, p.y - 6 + math.sin(a) * 4);
        c.rotate(a);
        rect(c, -2, -2, 4, 4, fill(hex(0xFFD36B)));
        c.restore();
      }
    }
    if (p.stun > 0 && math.sin(real * 40) > 0) rect(c, p.x - 4, p.y - 10, p.w + 8, p.h + 10, glow(rgba(255, 150, 100, 0.35)));
  }

  void drawParticles(Canvas c) {
    for (final pt in parts) {
      final a = (pt.life / pt.max).clamp(0.0, 1.0);
      switch (pt.type) {
        case PartType.flame:
        case PartType.spark:
          c.drawCircle(Offset(pt.x, pt.y), pt.size * (pt.type == PartType.flame ? a : 1), glow(pt.color.withValues(alpha: a)));
        case PartType.smoke:
          c.drawCircle(Offset(pt.x, pt.y), pt.size, fill(pt.color.withValues(alpha: a * 0.45)));
        case PartType.chunk:
        case PartType.grain:
          rect(c, pt.x, pt.y, pt.size, pt.size, fill(pt.color.withValues(alpha: a)));
      }
    }
  }

  /// Floating embers and ash in screen space.
  void drawEmbers(Canvas c, double dt) {
    for (final e in _embers) {
      e.y += (e.ash ? e.v * 0.6 : -e.v) * dt;
      e.x += math.sin(real + e.v) * 8 * dt - 6 * dt;
      if (e.y < -5) e.y = stageH + 5;
      if (e.y > stageH + 5) e.y = -5;
      if (e.x < -5) e.x = stageW + 5;
      if (e.ash) {
        rect(c, e.x, e.y, e.s, e.s, fill(rgba(200, 190, 210, 0.35)));
      } else {
        rect(c, e.x, e.y, e.s, e.s, glow(rgba(255, 140 + (e.v * 2).floor(), 70, 0.4 + math.sin(real * 4 + e.v) * 0.3)));
      }
    }
  }

  // ---------- HUD and screens ----------
  Rocket? get nextRocket {
    for (final r in rockets) {
      if (r.phase == RocketPhase.wait) return r;
    }
    return null;
  }

  void drawHud(Canvas c) {
    final r = nextRocket;
    rr(c, 16, 14, 210, 76, 8, fill(rgba(14, 10, 28, 0.6)));
    final label = hex(0xB3A9C9);
    drawText(c, 'NEXT LAUNCH', 30, 34, size: 11, color: label, weight: FontWeight.w600);
    drawText(c, 'ROCKETS LEFT', 130, 34, size: 11, color: label, weight: FontWeight.w600);
    if (r != null) {
      final left = r.launchT - t;
      final urgent = left < 5 && math.sin(real * 14) > 0;
      drawText(c, fmtTime(left), 30, 70, size: 28, family: _display, color: urgent ? hex(0xFF5A3A) : hex(0xFFD36B));
    } else {
      drawText(c, 'NONE', 30, 68, size: 20, family: _display, color: hex(0xFF5A3A));
    }
    drawText(c, r != null ? '?' : '0', 130, 70, size: 28, family: _display);
    // Pad direction and distance.
    if (r != null && p.boarded == null) {
      final dx = r.x - (p.x + p.w / 2);
      final m = (dx.abs() / 20).round();
      final txt = m < 4 ? 'BOARD NOW' : (dx > 0 ? 'PAD $m m  ▶' : '◀  PAD $m m');
      final tw = textWidth(txt, 14, _body, FontWeight.w600);
      rr(c, stageW - 32 - tw, 14, tw + 26, 30, 8, fill(rgba(14, 10, 28, 0.6)));
      drawText(c, txt, stageW - 19, 34, size: 14, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.right);
    }
    drawText(c, sfx.muted ? 'SOUND OFF (M)' : 'SOUND ON (M)', stageW - 19, 62,
        size: 11, color: rgba(179, 169, 201, 0.8), weight: FontWeight.w600, align: TextAlign.right);
  }

  void drawBanner(Canvas c) {
    final b = banner;
    if (b == null) return;
    final a = math.min(1.0, math.min(b.t * 4, (b.dur - b.t) * 3)).clamp(0.0, 1.0);
    final double y = 150 - (1 - math.min(1.0, b.t * 4)) * 20;
    rect(c, 0, y - 40, stageW, 70, fill(rgba(14, 10, 28, 0.55 * a)));
    drawText(c, b.title, stageW / 2, y, size: 30, family: _display, color: hex(0xFFD36B, a), align: TextAlign.center);
    drawText(c, b.sub, stageW / 2, y + 22, size: 15, color: hex(0xF4EFFC, a), align: TextAlign.center);
  }

  void drawTitle(Canvas c) {
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(linear(Offset.zero, const Offset(0, stageH), [rgba(14, 10, 28, 0.25), rgba(14, 10, 28, 0.55), rgba(14, 10, 28, 0.85)], [0, 0.5, 1])));
    final wob = reduceMotion ? 0.0 : math.sin(real * 2) * 3;
    const mid = stageW / 2;
    drawText(c, 'EARTH  ·  FINAL EVACUATION', mid, 170, size: 13, color: hex(0xFF9A6A), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, 'STARSHIP', mid + 4, 254 + wob, size: 76, family: _display, color: hex(0xFF5B3A), align: TextAlign.center);
    drawText(c, 'STARSHIP', mid, 250 + wob, size: 76, family: _display, color: hex(0xF4EFFC), align: TextAlign.center);
    drawText(c, 'ESCAPE', mid + 4, 330 + wob, size: 76, family: _display, color: hex(0xFF5B3A), align: TextAlign.center);
    drawText(c, 'ESCAPE', mid, 326 + wob, size: 76, family: _display, color: hex(0xFFD36B), align: TextAlign.center);
    drawText(c, 'The rockets are leaving one by one. Nobody knows how many are left.', mid, 372, size: 17, align: TextAlign.center);
    if (math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS SPACE OR TAP TO RUN', mid, 430, size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }

  void drawEnd(Canvas c) {
    final a = (endT * 1.5).clamp(0.0, 1.0);
    rect(c, 0, 0, stageW, stageH, fill(rgba(14, 10, 28, 0.72 * a)));
    final won = state == GameState.won;
    const mid = stageW / 2;
    drawText(c, won ? 'LIFTOFF CONFIRMED' : 'EVACUATION OVER', mid, 180,
        size: 13, color: (won ? hex(0x9FE3FF) : hex(0xFF9A6A)).withValues(alpha: a), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, won ? 'YOU MADE IT' : 'LEFT BEHIND', mid, 250,
        size: 56, family: _display, color: (won ? hex(0xFFD36B) : hex(0xFF5B3A)).withValues(alpha: a), align: TextAlign.center);
    final total = rockets.length;
    final line1 = won
        ? 'You escaped on rocket $wonRocket of $total, ${fmtTime(endTime)} after the ground started to go.'
        : 'The last rocket is gone. There were $total rockets.';
    drawText(c, line1, mid, 300, size: 18, color: hex(0xF4EFFC, a), align: TextAlign.center);
    drawText(c, 'Hidden shortcuts found: $shortcuts of ${triggers.length}', mid, 330, size: 18, color: hex(0xB3A9C9, a), align: TextAlign.center);
    if (endT > 1.2 && math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS SPACE OR TAP TO RUN AGAIN', mid, 400, size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }
}

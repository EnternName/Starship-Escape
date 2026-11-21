part of 'workshop_game.dart';

// Studio layout.
const double _mirX0 = 70, _mirX1 = 890; // mirror wall
const double _mirTop = 64, _seam = 292; // mirror top, wall meets floor
const double _ringX = 150, _ribbonY = 100; // hit ring on the light ribbon
const double _ribbonX1 = 880;
const double _speed = (_ribbonX1 - _ringX) / leadTime;

const _colA = 0xB78CFF; // A's accent (purple)
const _colB = 0xFF9A4D; // B's accent (orange)
const _colBoth = 0xFFD166; // together (gold)

ui.Offset _dir(double a) => ui.Offset(math.sin(a), math.cos(a));

final _sky = math.Random(23);
final List<List<double>> _stars = List.generate(110, (_) => [_sky.nextDouble() * _sw, _sky.nextDouble() * 240, _sky.nextDouble() * 1.4 + 0.4, _sky.nextDouble() * 6]);

final Map<String, TextPainter> _wrapCache = {};
TextPainter _wrapped(String s, double size, String family, ui.Color color, double maxW, {FontWeight weight = FontWeight.w600}) {
  final key = '$s|$size|$family|${color.toARGB32()}|$maxW';
  return _wrapCache.putIfAbsent(key, () {
    if (_wrapCache.length > 120) _wrapCache.clear();
    return TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, color: color, fontWeight: weight, height: 1.2)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxW);
  });
}

/// Colors and proportions of each performer, seen from the front.
class _Style {
  const _Style(this.skin, this.top, this.topD, this.legs, this.shoe, this.hair, this.leg, this.torso, this.head, this.width);
  final int skin, top, topD, legs, shoe, hair;
  final double leg, torso, head, width;
}

const Map<Look, _Style> _styles = {
  Look.a: _Style(0xF0C6A8, 0x6A34A0, 0x3A1A62, 0x2A1A4A, 0x1A1020, 0x9A2E1E, 50, 54, 14, 13),
  Look.b: _Style(0xE6B58E, 0xF08A3E, 0xC85E22, 0xC85E22, 0x5A4A5A, 0x5A3A22, 36, 40, 12.5, 12),
  Look.juggler: _Style(0x8A5A3C, 0x2BB3A8, 0x1A7A74, 0xEDE6F2, 0x2A2030, 0x1A1218, 44, 46, 12.5, 11),
  Look.alien: _Style(0x7CD36B, 0xFFC94A, 0xD69A20, 0x3A2A5A, 0x2A2030, 0x4E9A44, 40, 46, 13, 12),
  Look.mime: _Style(0xF6F2F4, 0xF4F0F6, 0x22202A, 0x22202A, 0x101014, 0x22202A, 44, 46, 12.5, 11),
  Look.acrobat: _Style(0xD9A07A, 0x24306A, 0x161E48, 0x24306A, 0x2A2030, 0xFF4FA0, 48, 48, 12, 10),
};

extension WorkshopRender on WorkshopGame {
  void renderStudio(ui.Canvas c, double dt) {
    final ox = shake > 0 && !reduceMotion ? rand(-shake, shake) * 0.5 : 0.0;
    c.save();
    c.translate(ox, 0);
    drawWall(c);
    drawMirror(c);
    drawFloor(c);
    drawSpeakers(c);
    final cast = everyone..sort((p, q) => p.y.compareTo(q.y));
    for (final d in cast) {
      drawDancer(c, d);
    }
    drawCoach(c);
    drawParticles(c);
    if (phase == WsPhase.play || phase == WsPhase.intro) drawRibbon(c);
    drawPopups(c);
    drawCoachLine(c);
    c.restore();
    // Lights: the studio dims on the title screen.
    if (lights < 1) rect(c, 0, 0, _sw, _sh, fill(hex(0x05020C, (1 - lights) * 0.7)));
    if (flash > 0) rect(c, 0, 0, _sw, _sh, glow(rgba(255, 230, 180, flash * 0.14)));
    rect(c, 0, 0, _sw, _sh,
        shaderPaint(radial(const ui.Offset(_sw / 2, _sh / 2), _sh * 1.05, [const ui.Color(0x00000000), const ui.Color(0x00000000), hex(0x05020C, 0.55)], [0, 0.55, 1])));
    if (phase == WsPhase.play || phase == WsPhase.outro) drawHud(c);
    if (phase == WsPhase.title) drawTitle(c);
    if (phase == WsPhase.results) drawResults(c);
  }

  /// 0..1 pulse that peaks on every beat.
  double get pulse {
    final ph = phase == WsPhase.play ? beat : real / 0.62;
    final f = ph - ph.floorToDouble();
    return math.pow(1 - f, 3).toDouble();
  }

  // ---------- room ----------
  void drawWall(ui.Canvas c) {
    rect(c, 0, 0, _sw, _seam, shaderPaint(linear(ui.Offset.zero, const ui.Offset(0, _seam), [hex(0x1A0F2E), hex(0x2A1640), hex(0x3A1C46)])));
    // Ceiling with a light track and an LED strip that pulses on the beat.
    rect(c, 0, 0, _sw, 44, shaderPaint(linear(ui.Offset.zero, const ui.Offset(0, 44), [hex(0x0C0716), hex(0x1C1230)])));
    rect(c, 0, 40, _sw, 6, fill(hex(0x2B2140)));
    final p = pulse;
    for (var i = 0; i < 24; i++) {
      final x = 20.0 + i * 40;
      final hue = [_colA, 0xFF6B9A, _colB, 0x9FE3FF][i % 4];
      c.drawCircle(ui.Offset(x, 43), 2.2, fill(hex(hue, 0.5 + 0.5 * p)));
      c.drawCircle(ui.Offset(x, 43), 9, glow(hex(hue, 0.12 + 0.2 * p)));
    }
    // Hanging lamps, swaying a little.
    for (final (i, x) in const [240.0, 480.0, 720.0].indexed) {
      final sw = math.sin(real * 0.9 + i * 1.3) * 0.05;
      c.save();
      c.translate(x, 0);
      c.rotate(sw);
      line(c, 0, 0, 0, 30, stroke(hex(0x6A5A80), 1.4));
      c.drawPath(
          ui.Path()
            ..moveTo(-14, 42)
            ..lineTo(-6, 28)
            ..lineTo(6, 28)
            ..lineTo(14, 42)
            ..close(),
          fill(hex(0x3A2E52)));
      c.drawOval(const ui.Rect.fromLTWH(-12, 39, 24, 7), fill(hex(0xFFE6B0, 0.9)));
      c.restore();
      final lx = x + math.sin(sw) * 42;
      c.drawPath(
          ui.Path()
            ..moveTo(lx - 12, 46)
            ..lineTo(lx + 12, 46)
            ..lineTo(lx + 110, 520)
            ..lineTo(lx - 110, 520)
            ..close(),
          shaderPaint(linear(const ui.Offset(0, 46), const ui.Offset(0, 520), [rgba(255, 220, 160, 0.1 * lights), rgba(255, 220, 160, 0)]), add: true));
    }
  }

  void drawMirror(ui.Canvas c) {
    const r = ui.Rect.fromLTRB(_mirX0, _mirTop, _mirX1, _seam);
    // Frame.
    rr(c, _mirX0 - 8, _mirTop - 8, _mirX1 - _mirX0 + 16, _seam - _mirTop + 8, 4, fill(hex(0x4C3D66)));
    c.save();
    c.clipRect(r);
    // The mirror shows the room behind the camera: a big window onto space.
    rect(c, _mirX0, _mirTop, _mirX1 - _mirX0, _seam - _mirTop, shaderPaint(linear(const ui.Offset(0, _mirTop), const ui.Offset(0, _seam), [hex(0x150C28), hex(0x231238)])));
    const wx0 = 150.0, wx1 = 810.0, wy0 = 86.0, wy1 = 236.0;
    rr(c, wx0, wy0, wx1 - wx0, wy1 - wy0, 30, shaderPaint(linear(const ui.Offset(0, wy0), const ui.Offset(0, wy1), [hex(0x070418), hex(0x1C0E3A)])));
    c.save();
    c.clipRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTRB(wx0, wy0, wx1, wy1), const ui.Radius.circular(30)));
    // Nebula clouds drift slowly.
    for (final (i, n) in const [(300.0, 140.0, 140.0, 0xC04AFF), (560.0, 120.0, 170.0, 0xFF4F9A), (700.0, 200.0, 120.0, 0x4AB8FF)].indexed) {
      final dx = math.sin(real * 0.05 + i) * 20;
      c.drawCircle(ui.Offset(n.$1 + dx, n.$2), n.$3, shaderPaint(radial(ui.Offset(n.$1 + dx, n.$2), n.$3, [hex(n.$4, 0.32), hex(n.$4, 0)]), add: true));
    }
    for (final s in _stars) {
      final x = (s[0] - real * (3 + s[2] * 3)) % (wx1 - wx0) + wx0;
      final y = wy0 + s[1] * (wy1 - wy0) / 240;
      final a = 0.3 + 0.7 * math.sin(real * 1.3 + s[3]).abs();
      rect(c, x, y, s[2], s[2], fill(rgba(255, 245, 255, a)));
    }
    // A ringed planet, slowly turning.
    const px = 640.0, py = 170.0, pr = 34.0;
    c.drawCircle(const ui.Offset(px, py), pr * 1.6, shaderPaint(radial(const ui.Offset(px, py), pr * 1.6, [hex(0x9FE3FF, 0.25), hex(0x9FE3FF, 0)]), add: true));
    c.drawCircle(const ui.Offset(px, py), pr,
        shaderPaint(radial(const ui.Offset(px - 12, py - 14), pr * 1.4, [hex(0xBFF0FF), hex(0x4A8AD8), hex(0x241A5A)], [0, 0.5, 1])));
    c.save();
    c.translate(px, py);
    c.rotate(-0.35);
    c.drawOval(ui.Rect.fromCenter(center: ui.Offset.zero, width: pr * 3.6, height: pr * 0.8), stroke(hex(0xFFE6B0, 0.7), 3));
    c.drawOval(ui.Rect.fromCenter(center: ui.Offset.zero, width: pr * 3.1, height: pr * 0.62), stroke(hex(0xFFB3D1, 0.4), 2));
    c.restore();
    // A shooting star now and then.
    final ss = (real % 7) / 7;
    if (ss < 0.12) {
      final k = ss / 0.12;
      final sx = lerpD(260, 520, k), sy = lerpD(100, 150, k);
      line(c, sx - 40, sy - 8, sx, sy, stroke(rgba(255, 255, 255, (1 - k) * 0.8), 1.6, cap: StrokeCap.round));
    }
    c.restore();
    // Window frame and mullions, as reflected.
    c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTRB(wx0, wy0, wx1, wy1), const ui.Radius.circular(30)), stroke(hex(0x4C3D66), 6));
    for (final x in const [370.0, 590.0]) {
      rect(c, x - 3, wy0, 6, wy1 - wy0, fill(hex(0x4C3D66)));
    }
    // Reflections of the class, seen from behind. The front row is farther away in the mirror.
    final refl = everyone..sort((p, q) => q.y.compareTo(p.y));
    c.saveLayer(r, Paint()..color = const ui.Color(0x8CFFFFFF));
    rect(c, _mirX0, 236, _mirX1 - _mirX0, _seam - 236, fill(hex(0x3A1C46)));
    for (final d in refl) {
      final dist = d.y - _seam;
      final s = d.scale * (1 - dist * 0.0022);
      drawDancer(c, d, back: true, at: ui.Offset(d.x, _seam - dist * 0.3), size: s * 0.8);
    }
    c.restore();
    // Barre.
    rect(c, _mirX0, 246, _mirX1 - _mirX0, 7, shaderPaint(linear(const ui.Offset(0, 246), const ui.Offset(0, 253), [hex(0xD9A066), hex(0x8A5A30)])));
    for (var x = 120.0; x < _mirX1; x += 200) {
      rect(c, x - 2, 252, 4, 14, fill(hex(0x8C7AA8)));
    }
    // Panel seams and sheen streaks.
    for (var k = 1; k < 4; k++) {
      final x = _mirX0 + k * (_mirX1 - _mirX0) / 4;
      line(c, x, _mirTop, x, _seam, stroke(hex(0x0C0716, 0.6), 2));
    }
    for (var k = 0; k < 4; k++) {
      final x0 = 120.0 + k * 220 + math.sin(real * 0.25 + k) * 12;
      c.drawPath(
          ui.Path()
            ..moveTo(x0, _mirTop)
            ..lineTo(x0 + 34, _mirTop)
            ..lineTo(x0 - 50, _seam)
            ..lineTo(x0 - 84, _seam)
            ..close(),
          glow(rgba(200, 220, 255, 0.05)));
    }
    c.restore();
  }

  void drawFloor(ui.Canvas c) {
    rect(c, 0, _seam, _sw, _sh - _seam, shaderPaint(linear(const ui.Offset(0, _seam), const ui.Offset(0, _sh), [hex(0x5A3424), hex(0x8A5232), hex(0x6A3A26)])));
    rect(c, 0, _seam, _sw, 8, fill(hex(0x2A1A20)));
    // Planks converge toward the mirror.
    const vx = _sw / 2, vy = -260.0;
    for (var i = -14; i <= 14; i++) {
      final xb = _sw / 2 + i * 70.0;
      final k = (_seam + 8 - vy) / (_sh - vy);
      final xt = vx + (xb - vx) * k;
      line(c, xt, _seam + 8, xb, _sh, stroke(hex(0x3A2018, 0.55), 1.2));
    }
    for (var y = _seam + 22.0, gap = 14.0; y < _sh; y += gap, gap *= 1.18) {
      line(c, 0, y, _sw, y, stroke(hex(0x3A2018, 0.22), 1));
    }
    // Glossy reflections of the lamps.
    for (final x in const [240.0, 480.0, 720.0]) {
      c.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, 330), width: 160, height: 30), glow(rgba(255, 220, 160, 0.06 * lights)));
    }
    // Floor spots under each dancer pulse with the beat.
    final p = pulse;
    for (final d in everyone) {
      final col = identical(d, a) ? _colA : identical(d, b) ? _colB : 0x9FE3FF;
      final w = 90 * d.scale * (1 + p * 0.12);
      c.drawOval(ui.Rect.fromCenter(center: ui.Offset(d.x, d.y + 2), width: w, height: w * 0.26), glow(hex(col, 0.1 + 0.16 * p)));
    }
  }

  void drawSpeakers(ui.Canvas c) {
    final p = pulse;
    for (final x in const [6.0, 904.0]) {
      rr(c, x, 300, 50, 120, 6, shaderPaint(linear(ui.Offset(x, 0), ui.Offset(x + 50, 0), [hex(0x1A1226), hex(0x2E2240), hex(0x1A1226)])));
      for (final (i, y) in const [330.0, 385.0].indexed) {
        final r = (i == 0 ? 12.0 : 18.0) * (1 + p * 0.1);
        c.drawCircle(ui.Offset(x + 25, y), r + 3, fill(hex(0x0C0814)));
        c.drawCircle(ui.Offset(x + 25, y), r, shaderPaint(radial(ui.Offset(x + 22, y - 3), r, [hex(0x4C3D66), hex(0x1A1226)])));
        c.drawCircle(ui.Offset(x + 25, y), r * 0.3, fill(hex(0x8C7AA8)));
      }
      c.drawCircle(ui.Offset(x + 25, 308), 2, fill(hex(0x7CF29A, 0.4 + 0.6 * p)));
    }
  }

  /// The coach: a little hovering drone with a screen for a face.
  void drawCoach(ui.Canvas c) {
    final bob = math.sin(real * 2.4) * 4 - pulse * 3;
    final x = 880.0, y = 214.0 + bob;
    c.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, 296), width: 50 - bob, height: 9), fill(hex(0x000000, 0.25)));
    c.drawCircle(ui.Offset(x, y + 30), 16, glow(hex(0x9FE3FF, 0.15 + 0.15 * pulse)));
    // Rotor.
    final ro = math.sin(real * 40) * 22;
    line(c, x - ro, y - 30, x + ro, y - 30, stroke(hex(0xDDF6FF, 0.6), 2, cap: StrokeCap.round));
    line(c, x, y - 30, x, y - 24, stroke(hex(0x8C7AA8), 2));
    rr(c, x - 28, y - 24, 56, 44, 14, shaderPaint(linear(ui.Offset(0, y - 24), ui.Offset(0, y + 20), [hex(0xE8E4F2), hex(0x8C7AA8)])));
    rr(c, x - 22, y - 18, 44, 30, 9, fill(hex(0x0E0A1C)));
    // The screen shows the next move, or a smile.
    final n = phase == WsPhase.play && next < notes.length && notes[next].time - t < leadTime ? notes[next] : null;
    if (n != null) {
      _arrow(c, x, y - 3, 20, n.move, fill(_ownerColor(n.owner)));
    } else {
      c.drawCircle(ui.Offset(x - 8, y - 6), 2.5, fill(hex(0x9FE3FF)));
      c.drawCircle(ui.Offset(x + 8, y - 6), 2.5, fill(hex(0x9FE3FF)));
      c.drawArc(ui.Rect.fromCenter(center: ui.Offset(x, y + 1), width: 14, height: 9), 0.2, math.pi - 0.4, false, stroke(hex(0x9FE3FF), 2, cap: StrokeCap.round));
    }
    // Little arms that conduct.
    final sw = math.sin((phase == WsPhase.play ? beat : real) * math.pi) * 0.6;
    for (final s in const [-1.0, 1.0]) {
      final a0 = ui.Offset(x + s * 28, y);
      final tip = a0 + ui.Offset(s * 14, -6 - sw * s * 10);
      line(c, a0.dx, a0.dy, tip.dx, tip.dy, stroke(hex(0xB8B8C8), 3, cap: StrokeCap.round));
      c.drawCircle(tip, 3.5, fill(hex(0xE8E4F2)));
    }
  }

  void drawCoachLine(ui.Canvas c) {
    final s = coachLine;
    if (s == null || coachT <= 0) return;
    final a = math.min(1.0, coachT * 3);
    final tp = _wrapped(s, 14, fontBody, hex(0x1A1226), 200);
    final w = tp.width + 24, h = tp.height + 14;
    final x = 836 - w, y = 160.0;
    c.saveLayer(null, Paint()..color = ui.Color.fromRGBO(255, 255, 255, a));
    rr(c, x, y, w, h, 10, fill(hex(0xF4EFFC)));
    c.drawPath(
        ui.Path()
          ..moveTo(x + w - 4, y + h * 0.4)
          ..lineTo(x + w + 14, y + h * 0.55)
          ..lineTo(x + w - 4, y + h * 0.75)
          ..close(),
        fill(hex(0xF4EFFC)));
    tp.paint(c, ui.Offset(x + 12, y + 7));
    c.restore();
  }

  // ---------- performers ----------
  /// Draws a performer seen from the front, or from behind in the mirror.
  void drawDancer(ui.Canvas c, Dancer d, {bool back = false, ui.Offset? at, double? size}) {
    final st = _styles[d.look]!;
    final s = size ?? d.scale;
    final pos = at ?? ui.Offset(d.x, d.y);
    final amt = math.min(1.0, d.k * 1.7);
    final sharp = d.sharp ? 1.15 : 1.0;
    final m = d.move;
    final cheer = math.min(1.0, d.cheer * 2);

    // Groove: everyone dips a little on every beat.
    final dip = pulse * 4 * (1 - amt);
    var lean = 0.0, hipDx = 0.0, hop = 0.0, crouch = dip;
    var armL = -0.22 + math.sin(real * 1.6 + d.phase) * 0.06, armR = 0.22 - math.sin(real * 1.6 + d.phase) * 0.06;
    var footL = -st.width * 0.75, footR = st.width * 0.75;
    switch (m) {
      case Move.left:
        lean = -0.2 * amt * sharp;
        hipDx = -12 * amt;
        armL = lerpD(armL, -1.6, amt);
        armR = lerpD(armR, -2.5, amt);
        footL -= 18 * amt;
      case Move.right:
        lean = 0.2 * amt * sharp;
        hipDx = 12 * amt;
        armL = lerpD(armL, 2.5, amt);
        armR = lerpD(armR, 1.6, amt);
        footR += 18 * amt;
      case Move.up:
        hop = 18 * amt * sharp;
        armL = lerpD(armL, -2.7, amt);
        armR = lerpD(armR, 2.7, amt);
        footL += 4 * amt;
        footR -= 4 * amt;
      case Move.down:
        crouch += 18 * amt * sharp;
        armL = lerpD(armL, -0.95, amt);
        armR = lerpD(armR, 0.95, amt);
        footL -= 10 * amt;
        footR += 10 * amt;
    }
    if (cheer > 0) {
      armL = lerpD(armL, -2.8 + math.sin(real * 14) * 0.2, cheer);
      armR = lerpD(armR, 2.8 - math.sin(real * 14) * 0.2, cheer);
      hop = math.max(hop, math.sin(real * 12).abs() * 6 * cheer);
    }
    if (d.wobble > 0) {
      // Stumbling the wrong way: flailing arms and a lean.
      final w = math.min(1.0, d.wobble * 1.6);
      final side = d.wobbleTo == Move.left ? -1.0 : d.wobbleTo == Move.right ? 1.0 : (d.phase > 1 ? 1.0 : -1.0);
      lean = lerpD(lean, side * 0.32 + math.sin(real * 18) * 0.08, w);
      hipDx = lerpD(hipDx, side * 8, w);
      armL = lerpD(armL, -2.2 + math.sin(real * 20) * 0.6, w);
      armR = lerpD(armR, 2.2 + math.sin(real * 17) * 0.6, w);
    }
    if (d.bow > 0) {
      crouch += 8 * d.bow;
      armL = lerpD(armL, -0.1, d.bow);
      armR = lerpD(armR, 0.1, d.bow);
    }
    if (back) {
      // Seen from behind, left and right stay where they are on screen.
    }

    c.save();
    c.translate(pos.dx, pos.dy);
    if (!back) {
      c.save();
      c.scale(1, 0.24);
      c.drawCircle(ui.Offset.zero, 30 * s * (1 - hop / 60), fill(hex(0x000000, 0.4)));
      c.restore();
    }
    c.scale(s);
    final hipY = -st.leg - hop + crouch;
    final hip = ui.Offset(hipDx, hipY);

    // Legs, with knees bending outward when the hips drop.
    void leg(double fx, double side) {
      final foot = ui.Offset(fx, -hop);
      final hp = hip + ui.Offset(side * st.width * 0.4, 0);
      final dist = (foot - hp).distance;
      final bend = math.sqrt(math.max(0, st.leg * st.leg - dist * dist)) * 0.5;
      final knee = (hp + foot) / 2 + ui.Offset(side * bend, 0);
      c.drawPath(
          ui.Path()
            ..moveTo(hp.dx, hp.dy)
            ..lineTo(knee.dx, knee.dy)
            ..lineTo(foot.dx, foot.dy),
          stroke(hex(st.legs), st.width * 0.75, cap: StrokeCap.round));
      rr(c, foot.dx - 7 + side * 2, foot.dy - 4, 14, 7, 3, fill(hex(st.shoe)));
    }

    leg(footL, -1);
    leg(footR, 1);

    c.save();
    c.translate(hip.dx, hip.dy);
    c.rotate(lean);
    final tw = st.width * 2;
    final shY = -st.torso + 6;
    final skin = hex(st.skin);

    void arm(double ang, double side) {
      final sh0 = ui.Offset(side * tw * 0.5, shY);
      final ua = st.torso * 0.38, fa = st.torso * 0.36;
      final el = sh0 + _dir(ang) * ua;
      final hd = el + _dir(ang + side * 0.25) * fa;
      c.drawPath(
          ui.Path()
            ..moveTo(sh0.dx, sh0.dy)
            ..lineTo(el.dx, el.dy)
            ..lineTo(hd.dx, hd.dy),
          stroke(hex(st.topD), 7, cap: StrokeCap.round));
      c.drawCircle(hd, 4.2, fill(d.look == Look.mime ? hex(0xFFFFFF) : skin));
    }

    // Behind the body: A's cape.
    if (d.look == Look.a) {
      final fl = math.sin(real * 2.4 + d.phase) * 3 - lean * 30;
      c.drawPath(
          ui.Path()
            ..moveTo(-tw * 0.5, shY)
            ..quadraticBezierTo(-tw * 0.9 + fl, shY + 30, -tw * 0.7 + fl, 10)
            ..lineTo(tw * 0.7 + fl, 10)
            ..quadraticBezierTo(tw * 0.9 + fl, shY + 30, tw * 0.5, shY)
            ..close(),
          shaderPaint(linear(ui.Offset(0, shY), const ui.Offset(0, 10), [hex(0x8E1E3A), hex(0x5A0E26)])));
    }
    if (back) {
      arm(armL, -1);
      arm(armR, 1);
    }

    // Torso.
    final torso = ui.Path()
      ..moveTo(-tw * 0.5, shY - 2)
      ..lineTo(tw * 0.5, shY - 2)
      ..lineTo(tw * 0.42, 4)
      ..lineTo(-tw * 0.42, 4)
      ..close();
    c.drawPath(torso, shaderPaint(linear(ui.Offset(0, shY), const ui.Offset(0, 4), [hex(st.top), hex(st.topD)])));
    if (!back) {
      switch (d.look) {
        case Look.a:
          rect(c, -tw * 0.44, -8, tw * 0.88, 4, fill(hex(0xE8B84A)));
          for (var k = 0; k < 3; k++) {
            c.drawCircle(ui.Offset(0, shY + 9 + k * 10.0), 1.6, fill(hex(0xFFD166)));
          }
          rr(c, -9, shY - 6, 18, 5, 2.5, fill(hex(0xE8B84A)));
        case Look.b:
          rect(c, -tw * 0.44, -6, tw * 0.88, 4, fill(hex(0x5A4A5A)));
          c.drawCircle(ui.Offset(5, shY + 10), 3.5, fill(hex(0x9FE3FF)));
          c.drawCircle(ui.Offset(5, shY + 10), 7, glow(hex(0x9FE3FF, 0.2 + pulse * 0.3)));
          line(c, 0, shY, 0, -6, stroke(hex(0xB04E1C), 1.2));
        case Look.juggler:
          for (var k = 0; k < 3; k++) {
            line(c, -tw * 0.5, shY + 6 + k * 12.0, tw * 0.5, shY + 14 + k * 12.0, stroke(hex(0xFFD166, 0.8), 3));
          }
        case Look.alien:
          c.drawCircle(ui.Offset(0, shY + 16), 5, fill(hex(0xFF6B9A)));
        case Look.mime:
          for (var k = 0; k < 5; k++) {
            rect(c, -tw * 0.48, shY + 2 + k * 8.0, tw * 0.96, 4, fill(hex(0x22202A)));
          }
        case Look.acrobat:
          _star(c, 0, shY + 16, 6, hex(0xFFD166));
      }
    }

    // Head.
    final hr = st.head;
    final nod = (d.glance > 0 ? ((d.glanceX - d.x).sign * 0.12) : 0) + d.bow * 0.3 + math.sin(real * 2 + d.phase) * 0.03;
    c.save();
    c.translate(0, shY - hr - 2);
    c.rotate(nod);
    rect(c, -3, hr - 4, 6, 7, fill(skin));
    if (back) {
      // From behind: hair or helmet over the head.
      c.drawCircle(ui.Offset.zero, hr, fill(hex(d.look == Look.alien ? st.skin : st.hair)));
      if (d.look == Look.a) {
        c.drawPath(
            ui.Path()
              ..moveTo(-hr, 0)
              ..quadraticBezierTo(-hr - 2, hr + 12, -hr + 4, hr + 16)
              ..lineTo(hr - 4, hr + 16)
              ..quadraticBezierTo(hr + 2, hr + 12, hr, 0)
              ..close(),
            fill(hex(0x7A2418)));
      }
    } else {
      if (d.look == Look.a) {
        // Long hair behind the face.
        c.drawPath(
            ui.Path()
              ..moveTo(-hr - 1, -2)
              ..quadraticBezierTo(-hr - 6, hr + 8, -hr - 1, hr + 16)
              ..lineTo(hr + 1, hr + 16)
              ..quadraticBezierTo(hr + 6, hr + 8, hr + 1, -2)
              ..close(),
            fill(hex(0x7A2418)));
      }
      c.drawCircle(ui.Offset.zero, hr, fill(skin));
      _face(c, d, hr);
    }
    _headwear(c, d, hr, back);
    if (d.wobble > 0.2) {
      for (var k = 0; k < 3; k++) {
        final an = real * 6 + k * math.pi * 2 / 3;
        _star(c, math.cos(an) * 18, -hr - 8 + math.sin(an) * 5, 3.2, hex(0xFFD166, math.min(1, d.wobble * 1.5)));
      }
    }
    c.restore();

    if (!back) {
      arm(armL, -1);
      arm(armR, 1);
    }
    c.restore();
    if (identical(d, a) || identical(d, b)) {
      if (!back && amt > 0 && d.sharp) {
        c.drawCircle(ui.Offset(0, hipY - 30), 70, shaderPaint(radial(ui.Offset(0, hipY - 30), 70, [rgba(255, 220, 140, 0.3 * amt), rgba(255, 220, 140, 0)]), add: true));
      }
    }
    c.restore();
  }

  void _face(ui.Canvas c, Dancer d, double hr) {
    final ink = hex(0x2A1A2A);
    final look = d.glance > 0 ? ((d.glanceX - d.x) / 120).clamp(-1.0, 1.0) * 1.6 : 0.0;
    final eyeH = 3.6 * (1 - d.blink);
    final ex = hr * 0.36;
    if (d.look == Look.alien) {
      // One big eye.
      c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(0, -2), width: 11, height: math.max(1, eyeH * 2.6)), fill(hex(0xFFFFFF)));
      if (eyeH > 1) c.drawCircle(ui.Offset(look, -2), 3, fill(ink));
    } else {
      for (final x in [-ex, ex]) {
        if (d.wobble > 0.3) {
          final p = stroke(ink, 1.6, cap: StrokeCap.round);
          line(c, x - 2, -4, x + 2, 0, p);
          line(c, x - 2, 0, x + 2, -4, p);
        } else {
          c.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, -2), width: 5, height: math.max(0.6, eyeH + 1.4)), fill(hex(0xFFFFFF)));
          if (eyeH > 1) c.drawCircle(ui.Offset(x + look, -2), 1.6, fill(ink));
        }
      }
      final browCol = d.look == Look.mime ? ink : d.look == Look.a ? hex(0x5A1A12) : hex(0x4A3020);
      final up = d.wobble > 0 ? 2.5 : d.glance > 0 ? 1.5 : 0.0;
      line(c, -ex - 3, -7 - up, -ex + 2, -8 - up, stroke(browCol, 1.4, cap: StrokeCap.round));
      line(c, ex - 2, -8 - up, ex + 3, -7 - up, stroke(browCol, 1.4, cap: StrokeCap.round));
    }
    if (d.blush > 0) {
      for (final x in [-ex - 2, ex + 2]) {
        c.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, 3.5), width: 6, height: 3), fill(rgba(255, 90, 130, 0.55 * math.min(1, d.blush))));
      }
    }
    final lip = d.look == Look.mime ? hex(0x1A1218) : hex(0x7A2A2A);
    if (d.wobble > 0.3 || d.giggle > 0) {
      c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(0, 6), width: 5, height: d.giggle > 0 ? 2 + (math.sin(real * 20)).abs() * 2 : 4), fill(hex(0x5A1A2A)));
    } else {
      final wide = d.smile > 0 || d.cheer > 0 ? 9.0 : 6.0;
      c.drawArc(ui.Rect.fromCenter(center: const ui.Offset(0, 4), width: wide, height: 5), 0.2, math.pi - 0.4, false, stroke(lip, 1.4, cap: StrokeCap.round));
    }
  }

  void _headwear(ui.Canvas c, Dancer d, double hr, bool back) {
    switch (d.look) {
      case Look.a:
        if (!back) {
          c.drawPath(
              ui.Path()
                ..moveTo(-hr, -1)
                ..quadraticBezierTo(-hr, -hr - 2, 0, -hr)
                ..quadraticBezierTo(hr, -hr - 2, hr, -1)
                ..quadraticBezierTo(4, -8, 0, -6)
                ..quadraticBezierTo(-4, -8, -hr, -1)
                ..close(),
              fill(hex(0x9A2E1E)));
        }
        final hat = ui.Path()
          ..moveTo(-19, -hr + 2)
          ..quadraticBezierTo(0, -hr - 18, 19, -hr + 2)
          ..quadraticBezierTo(0, -hr - 4, -19, -hr + 2)
          ..close();
        c.drawPath(hat, fill(hex(0x1E1A3A)));
        c.drawPath(hat, stroke(hex(0xE8B84A), 1.5));
        if (!back) c.drawCircle(ui.Offset(0, -hr - 7), 2.4, fill(hex(0xFFD166)));
      case Look.b:
        if (!back) {
          for (var k = 0; k < 5; k++) {
            c.drawCircle(ui.Offset(-8 + k * 4.0, -hr + 2 + (k.isEven ? 0 : -1)), 4, fill(hex(0x5A3A22)));
          }
        }
        final hh = hr + 7;
        c.drawCircle(const ui.Offset(0, -1), hh, fill(hex(0x9FE3FF, 0.12)));
        c.drawCircle(const ui.Offset(0, -1), hh, stroke(hex(0xDDF6FF, 0.75), 1.6));
        if (!back) c.drawArc(ui.Rect.fromCircle(center: const ui.Offset(0, -1), radius: hh - 4), -2.6, 0.9, false, stroke(hex(0xFFFFFF, 0.8), 2, cap: StrokeCap.round));
        final aw = math.sin(real * 4 + d.phase) * 0.25 + (d.wobble > 0 ? math.sin(real * 30) * 0.5 : 0);
        final tip = ui.Offset(-6 + math.sin(-0.3 + aw) * 14, -1 - hh - math.cos(-0.3 + aw) * 14);
        line(c, -6, -hh, tip.dx, tip.dy, stroke(hex(0xB8B8C8), 1.4));
        c.drawCircle(tip, 3, fill(hex(0xFF5A7A)));
        c.drawCircle(tip, 7, glow(rgba(255, 90, 122, 0.25 + 0.2 * math.sin(real * 6))));
      case Look.juggler:
        c.drawCircle(ui.Offset(0, -hr - 3), 6, fill(hex(0x1A1218)));
        if (!back) c.drawArc(ui.Rect.fromCircle(center: ui.Offset.zero, radius: hr), math.pi, math.pi, true, fill(hex(0x1A1218)));
      case Look.alien:
        for (final s in const [-1.0, 1.0]) {
          final sw = math.sin(real * 3 + d.phase + s) * 0.2;
          final tip = ui.Offset(s * 8 + math.sin(sw) * 12, -hr - 12);
          line(c, s * 5, -hr + 3, tip.dx, tip.dy, stroke(hex(0x4E9A44), 2.4, cap: StrokeCap.round));
          c.drawCircle(tip, 3.5, fill(hex(0xFFD166)));
        }
      case Look.mime:
        c.drawOval(ui.Rect.fromCenter(center: ui.Offset(3, -hr + 1), width: hr * 2.2, height: 9), fill(hex(0xD8344A)));
        c.drawCircle(ui.Offset(3, -hr - 3), 2, fill(hex(0xD8344A)));
      case Look.acrobat:
        for (var k = 0; k < 5; k++) {
          c.drawCircle(ui.Offset(0, -hr - 2 + k * 3.0 - 6), 4.5 - k * 0.3, fill(hex(0xFF4FA0)));
        }
        if (!back) c.drawArc(ui.Rect.fromCircle(center: ui.Offset.zero, radius: hr), math.pi + 0.5, math.pi - 1, false, stroke(hex(0x8A2A5A), 3));
    }
  }

  void _star(ui.Canvas c, double x, double y, double r, ui.Color col) {
    final p = ui.Path();
    for (var i = 0; i < 10; i++) {
      final an = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = ui.Offset(x + math.cos(an) * rr, y + math.sin(an) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    c.drawPath(p, fill(col));
  }

  // ---------- prompts ----------
  ui.Color _ownerColor(Owner o) => hex(o == Owner.a ? _colA : o == Owner.b ? _colB : _colBoth);

  /// An arrow pointing in the direction of [m], centered at x, y.
  void _arrow(ui.Canvas c, double x, double y, double s, Move m, Paint p) {
    c.save();
    c.translate(x, y);
    c.rotate(switch (m) { Move.up => 0, Move.right => math.pi / 2, Move.down => math.pi, Move.left => -math.pi / 2 });
    final h = s / 2;
    c.drawPath(
        ui.Path()
          ..moveTo(0, -h)
          ..lineTo(h * 0.95, 0)
          ..lineTo(h * 0.38, 0)
          ..lineTo(h * 0.38, h)
          ..lineTo(-h * 0.38, h)
          ..lineTo(-h * 0.38, 0)
          ..lineTo(-h * 0.95, 0)
          ..close(),
        p);
    c.restore();
  }

  void drawRibbon(ui.Canvas c) {
    final show = phase == WsPhase.play ? 1.0 : math.min(1.0, phaseT / 0.8);
    c.saveLayer(null, Paint()..color = ui.Color.fromRGBO(255, 255, 255, show));
    const y0 = _ribbonY - 28, y1 = _ribbonY + 28;
    rr(c, 90, y0, _ribbonX1 - 90 + 20, y1 - y0, 28, fill(hex(0x0E0A1C, 0.72)));
    rr(c, 90, y0, _ribbonX1 - 90 + 20, y1 - y0, 28, stroke(hex(0x9FE3FF, 0.35), 1.5));
    // Beat lines scroll toward the ring.
    final bt = beat;
    for (var k = 0; k < 9; k++) {
      final bb = bt.floorToDouble() + k;
      final x = _ringX + (bb * spb - t) * _speed;
      if (x < _ringX || x > _ribbonX1) continue;
      final strong = bb.round() % 4 == 0;
      line(c, x, y0 + 8, x, y1 - 8, stroke(hex(0xFFFFFF, strong ? 0.22 : 0.09), strong ? 2 : 1));
    }
    // The ring.
    final rb = 1 + ringBump * 0.12;
    final rc = ringFlash > 0 ? _judgeColor(ringJudge) : hex(0xF4EFFC);
    c.drawCircle(const ui.Offset(_ringX, _ribbonY), 34 * rb, glow(rc.withValues(alpha: 0.12 + ringFlash * 0.35)));
    c.drawCircle(const ui.Offset(_ringX, _ribbonY), 24 * rb, stroke(rc.withValues(alpha: 0.85), 3));
    if (ringFlash > 0) c.drawCircle(const ui.Offset(_ringX, _ribbonY), 24 + (1 - ringFlash) * 26, stroke(rc.withValues(alpha: ringFlash * 0.7), 2));
    // Notes, latest first so the next one is on top.
    for (var i = notes.length - 1; i >= 0; i--) {
      final n = notes[i];
      final dt = n.time - t;
      if (dt > leadTime + 0.1) continue;
      final hit = n.judge != null && n.judge != Judge.miss;
      if (hit) continue;
      var x = _ringX + dt * _speed;
      final missed = n.judge == Judge.miss;
      if (x < 40) continue;
      final edge = ((_ribbonX1 + 10 - x) / 60).clamp(0.0, 1.0);
      final fade = missed ? (1 - (-dt) / 0.6).clamp(0.0, 1.0) : 1.0;
      if (fade <= 0) continue;
      final col = missed ? hex(0xFF6B6B) : _ownerColor(n.owner);
      final near = (1 - dt.abs() / 0.4).clamp(0.0, 1.0);
      final sz = 38 + near * 6;
      if (missed) x -= 0;
      c.saveLayer(null, Paint()..color = ui.Color.fromRGBO(255, 255, 255, edge * fade));
      rr(c, x - sz / 2, _ribbonY - sz / 2, sz, sz, 10, fill(hex(0x1A1226)));
      rr(c, x - sz / 2, _ribbonY - sz / 2, sz, sz, 10, stroke(col, 2.5));
      c.drawCircle(ui.Offset(x, _ribbonY), sz * 0.8, glow(col.withValues(alpha: 0.12 + near * 0.15)));
      _arrow(c, x, _ribbonY, sz * 0.62, n.move, fill(col));
      if (n.owner == Owner.both && !missed) {
        _star(c, x + sz / 2 - 4, _ribbonY - sz / 2 + 4, 5, hex(0xFFFFFF));
      }
      c.restore();
    }
    c.restore();
  }

  ui.Color _judgeColor(Judge j) => switch (j) {
        Judge.perfect => hex(0xFFD166),
        Judge.good => hex(0x7CF29A),
        Judge.ok => hex(0x9FE3FF),
        Judge.miss => hex(0xFF6B6B),
      };

  void drawParticles(ui.Canvas c) {
    for (final p in parts) {
      final a = (p.life / p.max).clamp(0.0, 1.0);
      final col = p.color.withValues(alpha: a);
      switch (p.kind) {
        case PartKind.spark:
          c.drawCircle(ui.Offset(p.x, p.y), p.size * (0.5 + a * 0.5), glow(col));
        case PartKind.star:
          _star(c, p.x, p.y, p.size, col);
        case PartKind.confetti:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.life * 6 + p.size);
          rect(c, -p.size / 2, -p.size / 4, p.size, p.size / 2, fill(col));
          c.restore();
        case PartKind.heart:
          final s = p.size;
          c.drawPath(
              ui.Path()
                ..moveTo(p.x, p.y + s * 0.8)
                ..cubicTo(p.x - s * 1.4, p.y - s * 0.2, p.x - s * 0.6, p.y - s * 1.2, p.x, p.y - s * 0.4)
                ..cubicTo(p.x + s * 0.6, p.y - s * 1.2, p.x + s * 1.4, p.y - s * 0.2, p.x, p.y + s * 0.8)
                ..close(),
              fill(col));
      }
    }
  }

  void drawPopups(ui.Canvas c) {
    for (final p in popups) {
      final a = math.min(1.0, p.life * 2.5);
      drawText(c, p.text, p.x, p.y,
          size: p.big ? 30 : p.small ? 14 : 18,
          color: p.color.withValues(alpha: a),
          family: p.small ? fontBody : fontDisplay,
          weight: FontWeight.w600,
          align: TextAlign.center);
    }
  }

  // ---------- HUD and screens ----------
  void drawHud(ui.Canvas c) {
    drawText(c, def.number, 24, 30, size: 12, color: hex(0xB3A9C9), family: fontDisplay);
    drawText(c, 'SCORE $score', _sw - 24, 30, size: 16, color: hex(0xF4EFFC), family: fontDisplay, align: TextAlign.right);
    if (combo >= 3) {
      drawText(c, '$combo COMBO', _ringX, _ribbonY + 52, size: 14, color: hex(0xFFD166, 0.6 + pulse * 0.4), family: fontDisplay, align: TextAlign.center);
    }
    // Progress through the session.
    final total = notes.isEmpty ? 1.0 : notes.last.time;
    final f = (t / total).clamp(0.0, 1.0);
    rr(c, 300, 22, 360, 5, 2.5, fill(hex(0xFFFFFF, 0.12)));
    rr(c, 300, 22, 360 * f, 5, 2.5, fill(hex(together ? _colBoth : _colA)));
    if (together) {
      drawText(c, 'A', a.x, a.y + 30, size: 12, color: hex(_colA), family: fontDisplay, align: TextAlign.center);
      drawText(c, 'B', b.x, b.y + 30, size: 12, color: hex(_colB), family: fontDisplay, align: TextAlign.center);
    } else {
      drawText(c, 'YOU (A)', a.x, a.y + 30, size: 12, color: hex(_colA), family: fontDisplay, align: TextAlign.center);
      drawText(c, 'B', b.x, b.y + 30, size: 12, color: hex(_colB, 0.7), family: fontDisplay, align: TextAlign.center);
    }
  }

  void drawTitle(ui.Canvas c) {
    rect(c, 0, 0, _sw, _sh, fill(hex(0x0E0A1C, 0.55)));
    final bob = math.sin(real * 1.8) * 3;
    drawText(c, 'WORKSHOP', _sw / 2 + 3, 128 + bob + 3, size: 64, color: hex(0x000000, 0.4), family: fontDisplay, align: TextAlign.center);
    drawText(c, 'WORKSHOP', _sw / 2, 128 + bob, size: 64, color: hex(0xFFD166), family: fontDisplay, align: TextAlign.center);
    drawText(c, 'Hit the arrow as it reaches the ring. Move with the class.', _sw / 2, 170, size: 16, color: hex(0xF4EFFC), align: TextAlign.center);
    drawText(c, 'Arrow keys or WASD', _sw / 2, 196, size: 13, color: hex(0xB3A9C9), align: TextAlign.center);
    for (var i = 0; i < sessions.length; i++) {
      final r = WorkshopGame.sessionCard(i);
      final on = i == session;
      final sd = sessions[i];
      final lift = on ? -4 - pulse * 2 : 0.0;
      final rr0 = r.shift(ui.Offset(0, lift));
      c.drawRRect(ui.RRect.fromRectAndRadius(rr0, const ui.Radius.circular(12)), fill(hex(on ? 0x2A1A44 : 0x1A1226, 0.92)));
      c.drawRRect(ui.RRect.fromRectAndRadius(rr0, const ui.Radius.circular(12)), stroke(on ? hex(sd.together ? _colBoth : _colA) : hex(0xFFFFFF, 0.15), on ? 2.5 : 1));
      drawText(c, sd.number, rr0.center.dx, rr0.top + 26, size: 11, color: hex(0xB3A9C9), family: fontDisplay, align: TextAlign.center);
      drawText(c, sd.title, rr0.center.dx, rr0.top + 52, size: 20, color: on ? hex(0xF4EFFC) : hex(0xB3A9C9), family: fontDisplay, align: TextAlign.center);
      final tp = _wrapped(sd.blurb, 12, fontBody, hex(0xB3A9C9), r.width - 28, weight: FontWeight.w400);
      tp.paint(c, ui.Offset(rr0.center.dx - tp.width / 2, rr0.top + 64));
    }
    final a = 0.55 + 0.45 * math.sin(real * 4);
    drawText(c, 'Space or tap to start  ·  ← → pick a session', _sw / 2, 428, size: 15, color: hex(0xF4EFFC, a), weight: FontWeight.w600, align: TextAlign.center);
  }

  void drawResults(ui.Canvas c) {
    final k = math.min(1.0, phaseT / 0.5);
    rect(c, 0, 0, _sw, _sh, fill(hex(0x0E0A1C, 0.6 * k)));
    final y0 = 120 + (1 - k) * 30;
    rr(c, 280, y0, 400, 300, 16, fill(hex(0x1A1226, 0.95 * k)));
    rr(c, 280, y0, 400, 300, 16, stroke(hex(together ? _colBoth : _colA, k), 2));
    final acc = accuracy;
    final grade = acc >= 0.95 ? 'S' : acc >= 0.85 ? 'A' : acc >= 0.7 ? 'B' : acc >= 0.5 ? 'C' : 'D';
    drawText(c, '${def.number} COMPLETE', _sw / 2, y0 + 40, size: 14, color: hex(0xB3A9C9, k), family: fontDisplay, align: TextAlign.center);
    drawText(c, grade, _sw / 2, y0 + 120, size: 72, color: hex(0xFFD166, k), family: fontDisplay, align: TextAlign.center);
    final hits = notes.where((n) => n.judge != null && n.judge != Judge.miss).length;
    final rows = [
      'Score  $score / $maxScore',
      'Moves  $hits / ${notes.length}   ·   Best combo  $bestCombo',
      together ? 'Moves together  ${notes.where((n) => n.owner == Owner.both && n.judge != Judge.miss).length}' : 'B looked over  $glances ${glances == 1 ? 'time' : 'times'}',
    ];
    for (final (i, s) in rows.indexed) {
      drawText(c, s, _sw / 2, y0 + 170 + i * 26, size: 15, color: hex(0xF4EFFC, k), weight: FontWeight.w600, align: TextAlign.center);
    }
    final note = together
        ? (acc >= 0.7 ? 'In sync. Ready for the duet.' : 'Still finding each other\'s rhythm.')
        : (glances >= 3 ? 'B is starting to notice you.' : glances >= 1 ? 'B glanced over. Progress!' : 'B didn\'t notice. Next time.');
    drawText(c, note, _sw / 2, y0 + 258, size: 14, color: hex(0xFFB3D1, k), align: TextAlign.center);
    if (phaseT > 1.2) {
      drawText(c, 'Space or tap: next session  ·  R: again', _sw / 2, y0 + 330, size: 14, color: hex(0xF4EFFC, 0.5 + 0.5 * math.sin(real * 4)), align: TextAlign.center);
    }
  }
}

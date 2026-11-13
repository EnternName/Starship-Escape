part of 'stage_game.dart';

// Stage layout.
const double _px0 = 70, _px1 = 890; // proscenium sides
const double _ptop = 36; // proscenium top
const double _lip = 446; // front edge of the stage floor
const double _floorTop = 366; // back edge of the stage floor

const _colA = 0xB78CFF; // A's accent (purple)
const _colB = 0xFF9A4D; // B's accent (orange)

ui.Offset _dir(double a) => ui.Offset(math.sin(a), math.cos(a));
double _backOut(double k) {
  const c1 = 1.70158, c3 = c1 + 1;
  final x = k - 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

final _starRand = math.Random(11);
final List<List<double>> _stars = List.generate(130, (_) => [_starRand.nextDouble() * _sw, _starRand.nextDouble() * 420, _starRand.nextDouble() * 1.5 + 0.4, _starRand.nextDouble() * 6]);
final List<List<double>> _cracks = List.generate(9, (i) {
  final r = math.Random(30 + i);
  return List.generate(7, (k) => k.isEven ? r.nextDouble() * math.pi * 2 : 0.25 + r.nextDouble() * 0.7);
});

final Map<String, TextPainter> _wrapCache = {};
TextPainter _wrapped(String s, double size, String family, ui.Color color, double maxW, {FontWeight weight = FontWeight.w600}) {
  final key = '$s|$size|$family|${color.toARGB32()}|$maxW';
  return _wrapCache.putIfAbsent(key, () {
    if (_wrapCache.length > 120) _wrapCache.clear();
    return TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, color: color, fontWeight: weight, height: 1.15)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxW);
  });
}

extension StageRender on StageGame {
  double get progress => cues.isEmpty ? 0 : (t / (cues.last + 3)).clamp(0.0, 1.0);

  void renderStage(ui.Canvas c, double dt) {
    final shk = shake + rumble * 3.5;
    final ox = shk > 0 && !reduceMotion ? rand(-shk, shk) * 0.5 : 0.0;
    final oy = shk > 0 && !reduceMotion ? rand(-shk, shk) * 0.5 : 0.0;
    c.save();
    c.translate(ox, oy);
    drawBackdrop(c, dt);
    drawSet(c);
    drawFloor(c);
    drawSpots(c);
    final back = [actA, actB].where((a) => a.z > 0.6).toList();
    final front = [actA, actB].where((a) => a.z <= 0.6).toList()..sort((a, b) => b.z.compareTo(a.z));
    for (final a in back) {
      drawActor(c, a);
    }
    drawCrates(c);
    for (final a in front) {
      drawActor(c, a);
    }
    drawOrb(c);
    drawParticles(c);
    drawMood(c, dt);
    drawCurtains(c);
    drawFrame(c);
    drawApron(c);
    drawAudience(c);
    drawFlyingRoses(c);
    if (phase == StagePhase.play || phase == StagePhase.outro || phase == StagePhase.intro) {
      for (final a in [actA, actB]) {
        drawBubble(c, a);
      }
      drawNameTags(c);
    }
    drawPopups(c);
    c.restore();
    if (flash > 0) rect(c, 0, 0, _sw, _sh, glow(rgba(255, 230, 180, flash * 0.18)));
    rect(c, 0, 0, _sw, _sh,
        shaderPaint(radial(const ui.Offset(_sw / 2, _sh / 2), _sh * 1.05, [const ui.Color(0x00000000), const ui.Color(0x00000000), hex(0x05020C, 0.55)], [0, 0.5, 1])));
    drawHud(c);
    if (phase == StagePhase.title) drawTitle(c);
    if (phase == StagePhase.results) drawResults(c);
  }

  // ---------- backdrop: the real window behind the stage ----------
  void drawBackdrop(ui.Canvas c, double dt) {
    final pr = progress;
    final finale = mood == 3 ? 1.0 : 0.0;
    rect(c, 0, 0, _sw, _sh, fill(hex(0x140A22)));
    c.save();
    c.clipRect(const ui.Rect.fromLTWH(_px0, _ptop, _px1 - _px0, _floorTop - _ptop + 4));
    rect(c, _px0, _ptop, _px1 - _px0, _floorTop - _ptop,
        shaderPaint(linear(const ui.Offset(0, _ptop), const ui.Offset(0, _floorTop), [hex(0x050314), hex(0x170B33), hex(0x3A1240)], [0, 0.6, 1])));
    // Stars stream downward: the ship is climbing.
    final speed = phase == StagePhase.title ? 4.0 : 10 + rumble * 40 + finale * 150 + (results.isNotEmpty && results.last != null ? 260 : 0);
    starScroll += dt * speed;
    for (final s in _stars) {
      final y = (s[1] + starScroll * (0.4 + s[2] * 0.4)) % 420 + _ptop - 20;
      final a = 0.35 + 0.65 * math.sin(real * 1.4 + s[3]).abs();
      final len = math.min(40.0, speed * 0.05 * s[2]);
      if (len > 2) {
        line(c, s[0], y - len, s[0], y, stroke(rgba(220, 230, 255, a * 0.8), s[2] * 0.8, cap: StrokeCap.round));
      } else {
        rect(c, s[0], y, s[2], s[2], fill(rgba(255, 245, 255, a)));
      }
    }
    // The home planet falls away below.
    final rad = lerpD(250, 120, pr) * (1 - (results.isNotEmpty && results.last != null ? math.min(1, (t - cues.last) / 3) * 0.5 : 0));
    final cx = lerpD(300, 330, pr), cy = _floorTop + lerpD(70, 150, pr) + rad * 0.4;
    c.drawCircle(ui.Offset(cx, cy), rad * 1.35, shaderPaint(radial(ui.Offset(cx, cy), rad * 1.35, [hex(0xFF5A2A, 0.35), hex(0xFF5A2A, 0.12), hex(0xFF5A2A, 0)], [0.6, 0.78, 1]), add: true));
    c.drawCircle(ui.Offset(cx, cy), rad,
        shaderPaint(radial(ui.Offset(cx - rad * 0.3, cy - rad * 0.4), rad * 1.3, [hex(0xFFB27A), hex(0xC4381E), hex(0x4A1022), hex(0x1A0812)], [0, 0.35, 0.75, 1])));
    c.save();
    c.translate(cx, cy);
    c.rotate(real * 0.03);
    for (final cr in _cracks) {
      final path = ui.Path();
      for (var k = 0; k < cr.length - 1; k += 2) {
        final p = ui.Offset(math.cos(cr[k]) * rad * cr[k + 1], math.sin(cr[k]) * rad * cr[k + 1]);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      final pulse = 0.5 + 0.5 * math.sin(real * 2 + cr[0]);
      c.drawPath(path, stroke(rgba(255, 200, 90, 0.35 + pulse * 0.4), 2.2, cap: StrokeCap.round)..blendMode = BlendMode.plus);
    }
    c.restore();
    // Window struts with rivets and a glass sheen.
    final strut = shaderPaint(linear(ui.Offset.zero, const ui.Offset(12, 0), [hex(0x2B2140), hex(0x4C3D66), hex(0x241A36)], [0, 0.5, 1]));
    for (final x in const [343.0, 617.0]) {
      c.save();
      c.translate(x - 6, 0);
      rect(c, 0, _ptop, 12, _floorTop - _ptop, strut);
      c.restore();
      for (var y = _ptop + 20; y < _floorTop; y += 38) {
        c.drawCircle(ui.Offset(x, y), 1.6, fill(hex(0x8C7AA8)));
      }
    }
    rect(c, _px0, 168, _px1 - _px0, 10, shaderPaint(linear(const ui.Offset(0, 168), const ui.Offset(0, 178), [hex(0x4C3D66), hex(0x241A36)])));
    for (var k = 0; k < 3; k++) {
      final x0 = 160.0 + k * 270 + math.sin(real * 0.2) * 10;
      c.drawPath(
          ui.Path()
            ..moveTo(x0, _ptop)
            ..lineTo(x0 + 40, _ptop)
            ..lineTo(x0 - 60, _floorTop)
            ..lineTo(x0 - 90, _floorTop)
            ..close(),
          glow(rgba(180, 200, 255, 0.035)));
    }
    c.restore();
  }

  // ---------- the play's set: cardboard rocket, hanging moon ----------
  void drawSet(ui.Canvas c) {
    // Cardboard rocket, slightly crooked, with its wooden brace showing.
    c.save();
    c.translate(178, _floorTop + 4);
    c.rotate(-0.04 + math.sin(real * 0.8) * 0.006 + rumble * math.sin(real * 30) * 0.02);
    line(c, 14, -70, 34, 0, stroke(hex(0x6B4A2E), 4));
    final body = ui.Path()
      ..moveTo(0, -150)
      ..quadraticBezierTo(22, -128, 22, -90)
      ..lineTo(22, -26)
      ..lineTo(36, 0)
      ..lineTo(-36, 0)
      ..lineTo(-22, -26)
      ..lineTo(-22, -90)
      ..quadraticBezierTo(-22, -128, 0, -150)
      ..close();
    c.drawPath(body, fill(hex(0xD9C4A0)));
    c.drawPath(body, stroke(hex(0x8A6E4A), 2));
    c.drawCircle(const ui.Offset(0, -92), 10, fill(hex(0x6FB7D9)));
    c.drawCircle(const ui.Offset(0, -92), 10, stroke(hex(0x8A6E4A), 2.5));
    rect(c, -22, -60, 44, 8, fill(hex(0xC4381E)));
    drawText(c, 'HOPE I', 0, -34, size: 9, family: fontDisplay, color: hex(0x7A4A2A), align: TextAlign.center);
    c.restore();
    // A painted moon on a string, swinging when the ship shudders.
    final sw = math.sin(real * 1.3) * 0.05 + rumble * math.sin(real * 9) * 0.25;
    c.save();
    c.translate(800, 80);
    c.rotate(sw);
    line(c, 0, 0, 0, 62, stroke(hex(0xD8D0C0, 0.6), 1));
    c.drawCircle(const ui.Offset(0, 84), 22, fill(hex(0xF2E3B3)));
    c.drawCircle(const ui.Offset(10, 78), 18, fill(hex(0x170B33)));
    c.drawCircle(const ui.Offset(0, 84), 22, stroke(hex(0xA88F5A), 2));
    c.restore();
  }

  void drawFloor(ui.Canvas c) {
    final floor = ui.Path()
      ..moveTo(_px0 + 50, _floorTop)
      ..lineTo(_px1 - 50, _floorTop)
      ..lineTo(_px1, _lip)
      ..lineTo(_px0, _lip)
      ..close();
    c.drawPath(floor, shaderPaint(linear(const ui.Offset(0, _floorTop), const ui.Offset(0, _lip), [hex(0x4A2A1E), hex(0x7A4428), hex(0x5A3020)], [0, 0.6, 1])));
    c.save();
    c.clipPath(floor);
    for (var i = -10; i <= 10; i++) {
      final xb = 480 + i * 37.0, xf = 480 + i * 45.0;
      line(c, xb, _floorTop, xf, _lip, stroke(hex(0x2A140C, 0.5), 1));
    }
    for (final y in const [384.0, 404.0, 426.0]) {
      line(c, 0, y, _sw, y, stroke(hex(0x2A140C, 0.25), 1));
    }
    rect(c, 0, 400, _sw, 14, glow(rgba(255, 200, 150, 0.04)));
    // Spike tape marks where the actors stand.
    for (final b in beats) {
      for (final xz in [
        [b.ax, b.az],
        [b.bx, b.bz]
      ]) {
        final y = lerpD(_floorFront, _floorBack, xz[1]) + 2;
        final p = stroke(hex(0xFFD166, 0.35), 2);
        line(c, xz[0] - 5, y - 2, xz[0] + 5, y + 2, p);
        line(c, xz[0] - 5, y + 2, xz[0] + 5, y - 2, p);
      }
    }
    c.restore();
    line(c, _px0 + 50, _floorTop, _px1 - 50, _floorTop, stroke(hex(0x1A0C08), 2));
    // Roses that landed stay on stage.
    for (final r in roses) {
      if (r.k >= 1) _rose(c, r.x1, r.y1, r.rot, 1);
    }
  }

  void _rose(ui.Canvas c, double x, double y, double rot, double s) {
    c.save();
    c.translate(x, y);
    c.rotate(rot);
    c.scale(s);
    line(c, 0, 0, 14, 2, stroke(hex(0x2E7D4A), 2, cap: StrokeCap.round));
    c.drawCircle(const ui.Offset(7, -1), 2.5, fill(hex(0x3FA35E)));
    c.drawCircle(const ui.Offset(-2, 0), 5, fill(hex(0xB0123A)));
    c.drawCircle(const ui.Offset(-3, -1), 3, fill(hex(0xE8325A)));
    c.drawCircle(const ui.Offset(-3.5, -1.5), 1.2, fill(hex(0x7A0A26)));
    c.restore();
  }

  void drawSpots(ui.Canvas c) {
    for (final a in [actA, actB]) {
      final isA = identical(a, actA);
      final col = isA ? const [255, 220, 255] : const [255, 225, 190];
      final miss = a.bonk;
      final r = (col[0] - miss * 0).round(), g = (col[1] - miss * 120).round(), b = (col[2] - miss * 120).round();
      final top = ui.Offset(a.x + (isA ? -70 : 70), _ptop);
      final w = 62 * a.scale;
      final fy = a.feetY;
      final boost = 1 + a.glow * 0.8 + (phase == StagePhase.outro ? 0.4 : 0);
      final cone = ui.Path()
        ..moveTo(top.dx - 8, top.dy)
        ..lineTo(top.dx + 8, top.dy)
        ..lineTo(a.x + w, fy)
        ..lineTo(a.x - w, fy)
        ..close();
      c.drawPath(cone, shaderPaint(linear(top, ui.Offset(a.x, fy), [rgba(r, g, b, 0.02), rgba(r, g, b, 0.13 * boost)]), add: true));
      c.save();
      c.translate(a.x, fy);
      c.scale(1, 0.22);
      c.drawCircle(ui.Offset.zero, w * 1.1, shaderPaint(radial(ui.Offset.zero, w * 1.1, [rgba(r, g, b, 0.35 * boost), rgba(r, g, b, 0)]), add: true));
      c.restore();
      // Dust drifting in the beam.
      for (var k = 0; k < 7; k++) {
        final ph = (real * 0.05 + k * 0.143) % 1;
        final yy = lerpD(top.dy + 30, fy - 10, ph);
        final ww = lerpD(8, w, ph);
        final xx = lerpD(top.dx, a.x, ph) + math.sin(real * 0.7 + k * 2.1) * ww * 0.7;
        c.drawCircle(ui.Offset(xx, yy), 1.1, glow(rgba(255, 240, 220, 0.25 * math.sin(ph * math.pi))));
      }
    }
  }

  void drawCrates(ui.Canvas c) {
    final y = lerpD(_floorFront, _floorBack, 0.55);
    final s = 1 - 0.55 * 0.14;
    final vis = actA.sit > 0.01 || actB.sit > 0.01 || (next >= 7 && next <= 10);
    if (!vis && phase != StagePhase.title) {
      // Crates wait at the back until the sunset scene.
    }
    for (var i = 0; i < crates.length; i++) {
      final h = (i == 0 ? 34.0 * 0.55 : 50.0 * 0.55) * s;
      final w = 46.0 * s;
      final x = crates[i];
      c.save();
      c.translate(x, y);
      rr(c, -w / 2 - 2, -2, w + 4, 6, 3, fill(hex(0x000000, 0.35)));
      rr(c, -w / 2, -h, w, h, 2, fill(hex(0x9A6A3A)));
      rect(c, -w / 2, -h, w, 3, fill(hex(0xC08A50)));
      for (var k = 1; k < 3; k++) {
        line(c, -w / 2, -h + h * k / 3, w / 2, -h + h * k / 3, stroke(hex(0x5A3A1E), 1));
      }
      line(c, -w / 2 + 3, -h + 2, w / 2 - 3, -2, stroke(hex(0x6B4524), 2));
      c.drawCircle(ui.Offset(-w / 2 + 3, -h + 4), 1, fill(hex(0xD8C8B0)));
      c.drawCircle(ui.Offset(w / 2 - 3, -h + 4), 1, fill(hex(0xD8C8B0)));
      c.restore();
    }
  }

  // ---------- actors ----------
  void drawActor(ui.Canvas c, Actor a) {
    final isA = identical(a, actA);
    final s = a.scale;
    c.save();
    c.translate(a.x, a.feetY);
    // Shadow.
    c.save();
    c.scale(1, 0.25);
    c.drawCircle(ui.Offset.zero, 26 * s, fill(hex(0x000000, 0.45)));
    c.restore();
    c.scale(s * a.faceS.sign * math.max(0.2, a.faceS.abs()), s);

    final th = isA ? 26.0 : 18.0, sh = isA ? 26.0 : 18.0;
    final torsoH = isA ? 56.0 : 40.0;
    final bob = math.sin(a.walk * 2).abs() * 2.5 * a.moving + math.sin(real * 2.2 + (isA ? 0 : 1.7)) * 0.8;
    final hipY = -a.hipH - bob + (a.bonk > 0 ? math.sin(real * 25) * a.bonk * 1.5 : 0);
    final stand = (1 - a.sit - a.kneel).clamp(0.0, 1.0);

    final pantsC = isA ? hex(0x2A1A4A) : hex(0xC85E22);
    final pantsD = isA ? hex(0x1C1033) : hex(0x9A4416);
    final bootC = isA ? hex(0x1A1020) : hex(0x5A4A5A);

    void leg(int l, ui.Color col) {
      final ph = a.walk + l * math.pi;
      final sa1 = math.sin(ph) * 0.55 * a.moving;
      final sa2 = math.max(0.0, -math.sin(ph + 0.6)) * 0.9 * a.moving;
      final ka1 = l == 0 ? math.pi / 2 - 0.15 : -0.08;
      final a1 = sa1 * stand + (math.pi / 2 - 0.08 - l * 0.12) * a.sit + ka1 * a.kneel;
      final a2 = sa2 * stand + (math.pi / 2) * a.sit + (math.pi / 2) * a.kneel;
      final hip = ui.Offset(l == 0 ? 3 : -3, hipY);
      final knee = hip + _dir(a1) * th;
      final foot = knee + _dir(a1 - a2) * sh;
      final p = stroke(col, isA ? 9 : 10, cap: StrokeCap.round);
      c.drawPath(
          ui.Path()
            ..moveTo(hip.dx, hip.dy)
            ..lineTo(knee.dx, knee.dy)
            ..lineTo(foot.dx, foot.dy),
          p);
      rr(c, foot.dx - 4, foot.dy - 5, isA ? 14 : 15, isA ? 6 : 8, 3, fill(bootC));
    }

    leg(1, pantsD);
    leg(0, pantsC);

    // Upper body rotates around the hips.
    c.save();
    c.translate(0, hipY);
    final lean = a.bow * 0.85 + a.moving * 0.07 - a.sit * 0.04 + a.kneel * 0.08 + (a.bonk > 0 ? -0.15 * a.bonk : 0) + math.sin(real * 6) * 0.03 * math.min(1, a.talk);
    c.rotate(lean);
    final sx = 0.0, sy = -torsoH + 6;

    // Arm angles: 0 hangs down, positive swings forward.
    final idle = 0.12 + math.sin(real * 1.6 + (isA ? 0 : 2)) * 0.05;
    final talkW = math.min(1.0, a.talk * 2);
    var front = idle;
    front = lerpD(front, 1.5 + math.sin(real * 5) * 0.35, talkW * 0.8);
    front = lerpD(front, 1.35, a.ready);
    front += math.sin(a.swing * math.pi) * 1.3;
    var backA = -math.sin(a.walk) * 0.45 * a.moving + 0.05 - a.ready * 0.2;
    front = lerpD(front, 0.6, a.sit * (1 - a.ready) * (1 - talkW));
    if (a.bonk > 0) {
      final f = math.min(1.0, a.bonk * 2);
      front = lerpD(front, 2.7 + math.sin(real * 22) * 0.4, f);
      backA = lerpD(backA, -2.6 + math.sin(real * 19) * 0.4, f);
    }
    if (a.bow > 0) {
      front = lerpD(front, 0.2, a.bow);
      backA = lerpD(backA, -0.3, a.bow);
    }
    final skin = isA ? hex(0xF0C6A8) : hex(0xE6B58E);
    final sleeve = isA ? hex(0x4A2478) : hex(0xE8772E);
    final sleeveD = isA ? hex(0x341858) : hex(0xB8561C);
    final ua = isA ? 20.0 : 15.0, fa = isA ? 19.0 : 14.0;

    void arm(double ang, ui.Color col, double bend) {
      final sh0 = ui.Offset(sx, sy);
      final el = sh0 + _dir(ang) * ua;
      final hd = el + _dir(ang + bend) * fa;
      c.drawPath(
          ui.Path()
            ..moveTo(sh0.dx, sh0.dy)
            ..lineTo(el.dx, el.dy)
            ..lineTo(hd.dx, hd.dy),
          stroke(col, isA ? 7 : 8, cap: StrokeCap.round));
      c.drawCircle(hd, isA ? 4 : 4.5, fill(skin));
    }

    // Cape (A) or backpack (B) behind everything.
    if (isA) {
      final flare = (a.capeVel.abs() / 150).clamp(0.0, 1.0) * 18 + math.sin(real * 2.4) * 3 + a.bonk * 6;
      final cape = ui.Path()
        ..moveTo(-6, sy - 2)
        ..quadraticBezierTo(-16 - flare * 0.5, sy + 30, -18 - flare, 8 + math.sin(real * 3) * 3)
        ..lineTo(-2 - flare * 0.4, 12)
        ..quadraticBezierTo(2, sy + 30, 6, sy)
        ..close();
      c.drawPath(cape, shaderPaint(linear(ui.Offset(0, sy), const ui.Offset(0, 12), [hex(0x8E1E3A), hex(0x5A0E26)])));
    } else {
      rr(c, -16, sy + 2, 10, 24, 4, fill(hex(0x6A6A80)));
      rr(c, -15, sy + 4, 4, 18, 2, fill(hex(0x9FE3FF, 0.6)));
    }
    arm(backA, sleeveD, 0.25 + a.bow * 0.3);

    // Torso.
    if (isA) {
      final coat = ui.Path()
        ..moveTo(-10, sy - 4)
        ..lineTo(10, sy - 4)
        ..lineTo(12, -14)
        ..lineTo(17, 6)
        ..lineTo(-15, 6)
        ..lineTo(-11, -14)
        ..close();
      c.drawPath(coat, shaderPaint(linear(ui.Offset(0, sy), const ui.Offset(0, 6), [hex(0x6A34A0), hex(0x3A1A62)])));
      rect(c, -11, -18, 23, 4, fill(hex(0xE8B84A)));
      for (var k = 0; k < 3; k++) {
        c.drawCircle(ui.Offset(6, sy + 10 + k * 10.0), 1.6, fill(hex(0xFFD166)));
      }
      rr(c, -9, sy - 7, 18, 6, 3, fill(hex(0xE8B84A)));
      line(c, -6, sy - 1, -8, sy + 6, stroke(hex(0xFFD166), 1.4));
      line(c, -3, sy - 1, -4, sy + 6, stroke(hex(0xFFD166), 1.4));
    } else {
      rr(c, -11, sy - 2, 23, torsoH - 4, 9, shaderPaint(linear(ui.Offset(0, sy), const ui.Offset(0, 0), [hex(0xF08A3E), hex(0xC85E22)])));
      rect(c, -11, -10, 23, 4, fill(hex(0x5A4A5A)));
      c.drawCircle(ui.Offset(5, sy + 10), 3.5, fill(hex(0x9FE3FF)));
      c.drawCircle(ui.Offset(5, sy + 10), 3.5, stroke(hex(0xFFFFFF, 0.7), 1));
      line(c, 0, sy, 0, -10, stroke(hex(0xB04E1C), 1.2));
    }

    // Head.
    final hr = isA ? 14.0 : 12.5;
    final nod = math.sin(real * 9) * 0.07 * talkW + (a.bonk > 0 ? math.sin(real * 18) * 0.2 * a.bonk : 0) + a.blush * 0.08;
    c.save();
    c.translate(2, sy - hr - 2);
    c.rotate(nod);
    if (isA) {
      // Long hair behind.
      final sway = math.sin(real * 2) * 2 + a.capeVel / 60;
      c.drawPath(
          ui.Path()
            ..moveTo(-hr + 1, -4)
            ..quadraticBezierTo(-hr - 6 - sway, 18, -hr + 2 - sway, 28)
            ..lineTo(4, 14)
            ..lineTo(hr - 2, 0)
            ..close(),
          fill(hex(0x7A2418)));
    }
    rect(c, -3, hr - 4, 7, 7, fill(skin));
    c.drawCircle(ui.Offset.zero, hr, fill(skin));
    // Eyes look toward where the actor is looking.
    final look = (((a.lookTarget - a.x) * a.face) / 160).clamp(-1.0, 1.0);
    final eyeH = 3.6 * (1 - a.blink);
    for (final ex in const [3.0, 9.5]) {
      if (a.bonk > 0.25) {
        final p = stroke(hex(0x2A1A2A), 1.6, cap: StrokeCap.round);
        line(c, ex - 2, -4, ex + 2, 0, p);
        line(c, ex - 2, 0, ex + 2, -4, p);
      } else {
        c.drawOval(ui.Rect.fromCenter(center: ui.Offset(ex, -2), width: 5, height: math.max(0.6, eyeH + 1.4)), fill(hex(0xFFFFFF)));
        if (eyeH > 1) c.drawCircle(ui.Offset(ex + 0.8 + look * 1.2, -2), 1.6, fill(hex(0x2A1A2A)));
      }
    }
    // Brows.
    final browUp = a.bonk > 0 ? 2.5 : talkW * 1.2;
    line(c, 1, -7 - browUp, 6, -8 - browUp, stroke(isA ? hex(0x5A1A12) : hex(0x4A3020), 1.4, cap: StrokeCap.round));
    line(c, 8, -8 - browUp, 12, -7 - browUp, stroke(isA ? hex(0x5A1A12) : hex(0x4A3020), 1.4, cap: StrokeCap.round));
    // Cheeks.
    if (a.blush > 0) {
      c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(9, 3.5), width: 7, height: 3.5), fill(rgba(255, 90, 130, 0.55 * math.min(1, a.blush))));
      c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(0, 3.5), width: 5, height: 3), fill(rgba(255, 90, 130, 0.4 * math.min(1, a.blush))));
    }
    // Mouth.
    if (a.talk > 0 || a.bonk > 0.3) {
      final open = a.bonk > 0.3 ? 4.0 : 1 + (math.sin(real * 15)).abs() * 3.2;
      c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(7, 6.5), width: 5, height: open), fill(hex(0x5A1A2A)));
    } else {
      c.drawArc(const ui.Rect.fromLTWH(4, 3, 7, 5), 0.2, math.pi - 0.4, false, stroke(hex(0x7A2A2A), 1.3, cap: StrokeCap.round));
    }
    if (isA) {
      // Bangs and captain's hat.
      c.drawPath(
          ui.Path()
            ..moveTo(-hr, -2)
            ..quadraticBezierTo(-hr + 2, -hr - 2, 4, -hr)
            ..quadraticBezierTo(hr + 1, -hr + 2, hr, -5)
            ..quadraticBezierTo(4, -9, -2, -4)
            ..close(),
          fill(hex(0x9A2E1E)));
      c.save();
      c.translate(0, -hr + 1);
      c.rotate(-0.12);
      final hat = ui.Path()
        ..moveTo(-18, 0)
        ..quadraticBezierTo(0, -16, 18, 0)
        ..quadraticBezierTo(0, -5, -18, 0)
        ..close();
      c.drawPath(hat, fill(hex(0x1E1A3A)));
      c.drawPath(hat, stroke(hex(0xE8B84A), 1.5));
      c.drawCircle(const ui.Offset(0, -7), 2.4, fill(hex(0xFFD166)));
      c.restore();
    } else {
      // Messy hair, then the glass helmet and its antenna.
      for (var k = 0; k < 4; k++) {
        c.drawCircle(ui.Offset(-6 + k * 4.0, -hr + 2 + (k.isEven ? 0 : -1)), 4, fill(hex(0x5A3A22)));
      }
      final hh = hr + 7;
      c.drawCircle(const ui.Offset(1, -1), hh, fill(hex(0x9FE3FF, 0.12)));
      c.drawCircle(const ui.Offset(1, -1), hh, stroke(hex(0xDDF6FF, 0.75), 1.6));
      c.drawArc(ui.Rect.fromCircle(center: const ui.Offset(1, -1), radius: hh - 4), -2.6, 0.9, false, stroke(hex(0xFFFFFF, 0.8), 2, cap: StrokeCap.round));
      final aw = math.sin(real * 4 + a.walk) * 0.25 + (a.bonk > 0 ? math.sin(real * 30) * 0.5 : 0);
      final tip = ui.Offset(-4 + math.sin(-0.3 + aw) * 14, -1 - hh - math.cos(-0.3 + aw) * 14);
      line(c, -4, -hh, tip.dx, tip.dy, stroke(hex(0xB8B8C8), 1.4));
      c.drawCircle(tip, 3, fill(hex(0xFF5A7A)));
      c.drawCircle(tip, 7, glow(rgba(255, 90, 122, 0.25 + 0.2 * math.sin(real * 6))));
    }
    // Dizzy stars after a miss.
    if (a.bonk > 0.2) {
      for (var k = 0; k < 3; k++) {
        final an = real * 6 + k * math.pi * 2 / 3;
        _star(c, math.cos(an) * 16, -hr - 6 + math.sin(an) * 5, 3.2, hex(0xFFD166, math.min(1, a.bonk * 1.5)));
      }
    }
    c.restore();

    arm(front, sleeve, 0.35 - a.ready * 0.3 + talkW * 0.2);
    c.restore();
    // Perfect hit aura.
    if (a.glow > 0) {
      c.drawCircle(ui.Offset(0, hipY - 20), 60, shaderPaint(radial(ui.Offset(0, hipY - 20), 60, [rgba(255, 220, 140, 0.35 * a.glow), rgba(255, 220, 140, 0)]), add: true));
    }
    c.restore();
  }

  void _star(ui.Canvas c, double x, double y, double r, ui.Color col) {
    final p = ui.Path();
    for (var i = 0; i < 10; i++) {
      final an = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final pt = ui.Offset(x + math.cos(an) * rr, y + math.sin(an) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(p..close(), fill(col));
  }

  // ---------- the cue orb ----------
  void drawOrb(ui.Canvas c) {
    // Ring at the receiving hand, with a shrinking approach ring.
    if (phase == StagePhase.play && next < cues.length) {
      final dtc = cues[next] - t;
      if (dtc < 1.4) {
        final h = target(next).hand;
        final k = (dtc / 1.4).clamp(0.0, 1.0);
        final a = (1 - k).clamp(0.0, 1.0);
        final hot = dtc.abs() < winGood ? 1.0 : 0.0;
        final col = identical(target(next), actA) ? _colA : _colB;
        c.drawCircle(h, 15, stroke(hex(0xFFFFFF, 0.25 + a * 0.6), 2.5));
        c.drawCircle(h, 15, stroke(hex(col, a * 0.8), 6)..blendMode = BlendMode.plus);
        if (dtc > 0) c.drawCircle(h, 15 + 70 * k, stroke(hex(col, a * 0.9), 2));
        for (var i = 0; i < 4; i++) {
          final an = real * 3 + i * math.pi / 2;
          c.drawArc(ui.Rect.fromCircle(center: h, radius: 21), an, 0.6, false, stroke(hex(0xFFD166, a * 0.7), 1.5));
        }
        if (hot > 0) c.drawCircle(h, 26, shaderPaint(radial(h, 26, [hex(0xFFFFFF, 0.4), hex(0xFFFFFF, 0)]), add: true));
      }
    }
    final o = orb;
    if (o == null) {
      trail.clear();
      return;
    }
    trail.add(o);
    if (trail.length > 14) trail.removeAt(0);
    for (var i = 0; i < trail.length - 1; i++) {
      final k = i / trail.length;
      line(c, trail[i].dx, trail[i].dy, trail[i + 1].dx, trail[i + 1].dy, stroke(rgba(160, 235, 255, k * 0.6), 2 + k * 7, cap: StrokeCap.round)..blendMode = BlendMode.plus);
    }
    // Shadow on the floor.
    final fy = lerpD(_floorFront, _floorBack, (actA.z + actB.z) / 2) + 4;
    final hgt = ((fy - o.dy) / 200).clamp(0.0, 1.0);
    c.save();
    c.translate(o.dx, fy);
    c.scale(1, 0.3);
    c.drawCircle(ui.Offset.zero, 9 * (1 - hgt * 0.5), fill(hex(0x000000, 0.4 * (1 - hgt * 0.6))));
    c.restore();
    c.drawCircle(o, 28, shaderPaint(radial(o, 28, [rgba(170, 240, 255, 0.55), rgba(120, 180, 255, 0)]), add: true));
    c.drawCircle(o, 8, fill(hex(0xF4FFFF)));
    c.drawCircle(o, 8, stroke(hex(0x9FE3FF), 2));
    final sp = real * 8;
    line(c, o.dx + math.cos(sp) * 12, o.dy + math.sin(sp) * 12, o.dx - math.cos(sp) * 12, o.dy - math.sin(sp) * 12, glow(hex(0xFFFFFF, 0.6))..strokeWidth = 1.2);
  }

  void drawParticles(ui.Canvas c) {
    for (final p in parts) {
      final a = (p.life / p.max).clamp(0.0, 1.0);
      switch (p.kind) {
        case PartKind.spark:
          c.drawCircle(ui.Offset(p.x, p.y), p.size * a + 0.5, glow(p.color.withValues(alpha: a)));
        case PartKind.star:
          _star(c, p.x, p.y, p.size * (0.5 + a * 0.5), p.color.withValues(alpha: a));
        case PartKind.confetti:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.life * 6 + p.size);
          rect(c, -p.size / 2, -p.size / 4, p.size, p.size / 2 * (0.3 + math.sin(p.life * 9).abs()), fill(p.color.withValues(alpha: math.min(1, a * 3))));
          c.restore();
        case PartKind.dust:
          c.drawCircle(ui.Offset(p.x, p.y), p.size, fill(p.color.withValues(alpha: a * 0.6)));
      }
    }
  }

  void drawMood(ui.Canvas c, double dt) {
    const moods = [
      [0.0, 0.0, 0.0, 0.0],
      [255.0, 120.0, 40.0, 0.14],
      [30.0, 50.0, 150.0, 0.22],
      [255.0, 210.0, 140.0, 0.06],
    ];
    final m = moods[phase == StagePhase.play || phase == StagePhase.outro ? mood : 0];
    final k = math.min(1.0, dt * 1.5);
    moodR = lerpD(moodR, m[0], k);
    moodG = lerpD(moodG, m[1], k);
    moodB = lerpD(moodB, m[2], k);
    moodA = lerpD(moodA, m[3], k);
    if (moodA > 0.005) rect(c, _px0, _ptop, _px1 - _px0, _lip - _ptop, fill(rgba(moodR.round(), moodG.round(), moodB.round(), moodA)));
  }

  // ---------- curtains and frame ----------
  void drawCurtains(ui.Canvas c) {
    final o = ease(curtain);
    const half = (_px1 - _px0) / 2;
    for (final side in const [-1, 1]) {
      final w = lerpD(half + 4, 58, o);
      final edge = side < 0 ? _px0 : _px1;
      final inner = edge - side * w;
      final swag = o * 26;
      final p = ui.Path()
        ..moveTo(edge, _ptop)
        ..lineTo(inner, _ptop)
        ..quadraticBezierTo(inner + side * swag * 2.2, 260, inner + side * swag, _lip)
        ..lineTo(edge, _lip)
        ..close();
      final fw = lerpD(46, 12, o);
      final sway = math.sin(real * 0.9 + side) * 3 + rumble * math.sin(real * 20) * 4;
      c.drawPath(
          p,
          shaderPaint(ui.Gradient.linear(ui.Offset(edge + sway, 0), ui.Offset(edge + sway + fw, 0),
              [hex(0x4A0616), hex(0xA0142E), hex(0xD8344E), hex(0x8A0E26), hex(0x4A0616)], [0, 0.35, 0.5, 0.7, 1], TileMode.repeated)));
      c.drawPath(p, shaderPaint(linear(const ui.Offset(0, _ptop), const ui.Offset(0, _lip), [hex(0x000000, 0.45), hex(0x000000, 0), hex(0x000000, 0.25)], [0, 0.4, 1])));
      // Gold hem.
      line(c, edge, _lip - 4, inner + side * swag, _lip - 4, stroke(hex(0xE8B84A), 4));
      if (o > 0.5) {
        // Tie-back rope with a tassel.
        final ty = 300.0;
        final tx = edge - side * (w * 0.55 + swag * 1.5);
        c.drawPath(
            ui.Path()
              ..moveTo(edge, ty - 6)
              ..quadraticBezierTo(tx, ty + 8, tx - side * 4, ty - 4),
            stroke(hex(0xFFD166, (o - 0.5) * 2), 4, cap: StrokeCap.round));
        rr(c, tx - side * 4 - 3, ty - 4, 6, 18, 3, fill(hex(0xE8B84A, (o - 0.5) * 2)));
      }
    }
    // Valance with a scalloped edge and fringe.
    final v = ui.Path()
      ..moveTo(_px0, _ptop)
      ..lineTo(_px1, _ptop)
      ..lineTo(_px1, 66);
    const n = 10;
    const sw = (_px1 - _px0) / n;
    for (var i = n - 1; i >= 0; i--) {
      final x0 = _px0 + i * sw;
      v.quadraticBezierTo(x0 + sw / 2, 92, x0, 66);
    }
    v.close();
    c.drawPath(
        v,
        shaderPaint(ui.Gradient.linear(const ui.Offset(_px0, 0), const ui.Offset(_px0 + 41, 0), [hex(0x5A0A1C), hex(0xB01A36), hex(0x5A0A1C)], [0, 0.5, 1],
            TileMode.repeated)));
    for (var i = 0; i < n; i++) {
      final x0 = _px0 + i * sw;
      final p = ui.Path()
        ..moveTo(x0, 66)
        ..quadraticBezierTo(x0 + sw / 2, 92, x0 + sw, 66);
      c.drawPath(p, stroke(hex(0xE8B84A), 3));
      for (var k = 1; k < 8; k++) {
        final u = k / 8;
        final x = x0 + sw * u, y = 66 + 26 * 4 * u * (1 - u) * 0.5 * 2 / 2 * 2;
        line(c, x, y - 2, x + math.sin(real * 2 + x) * 1.2, y + 5, stroke(hex(0xFFD166, 0.8), 1));
      }
    }
  }

  void drawFrame(ui.Canvas c) {
    final wall = fill(hex(0x1C1030));
    rect(c, 0, 0, _sw, _ptop, wall);
    rect(c, 0, 0, _px0, _lip, wall);
    rect(c, _px1, 0, _sw - _px1, _lip, wall);
    // Ship panels and rivets.
    for (final x in const [0.0, 900.0]) {
      for (var y = 60.0; y < _lip; y += 70) {
        rr(c, x + 6, y, 58, 60, 4, stroke(hex(0x2E2048), 1.5));
        c.drawCircle(ui.Offset(x + 12, y + 6), 1.4, fill(hex(0x4A3A66)));
        c.drawCircle(ui.Offset(x + 58, y + 54), 1.4, fill(hex(0x4A3A66)));
      }
    }
    // Side portholes.
    for (final x in const [35.0, 925.0]) {
      const y = 250.0;
      c.drawCircle(ui.Offset(x, y), 20, fill(hex(0x070414)));
      for (var k = 0; k < 6; k++) {
        final yy = (y - 16 + ((k * 7 + starScroll * 0.6) % 32));
        c.drawCircle(ui.Offset(x - 10 + k * 4.0, yy), 0.9, fill(hex(0xFFFFFF, 0.8)));
      }
      c.drawCircle(ui.Offset(x, y), 20, stroke(hex(0x8C7AA8), 4));
      c.drawArc(ui.Rect.fromCircle(center: ui.Offset(x, y), radius: 14), -2.4, 0.9, false, stroke(hex(0xFFFFFF, 0.35), 2));
    }
    // Gold proscenium.
    final gold = shaderPaint(linear(const ui.Offset(0, 0), const ui.Offset(0, _lip), [hex(0xFFE08A), hex(0xC08A2A), hex(0xFFD166), hex(0x8A5A1A)], [0, 0.3, 0.6, 1]));
    rect(c, _px0 - 8, _ptop - 8, 8, _lip - _ptop + 8, gold);
    rect(c, _px1, _ptop - 8, 8, _lip - _ptop + 8, gold);
    rect(c, _px0 - 8, _ptop - 8, _px1 - _px0 + 16, 8, gold);
    line(c, _px0 - 2, _ptop - 2, _px0 - 2, _lip, stroke(hex(0x5A3A10), 1));
    line(c, _px1 + 2, _ptop - 2, _px1 + 2, _lip, stroke(hex(0x5A3A10), 1));
  }

  void drawApron(ui.Canvas c) {
    rect(c, 0, _lip, _sw, 30, shaderPaint(linear(const ui.Offset(0, _lip), const ui.Offset(0, _lip + 30), [hex(0x3A1E14), hex(0x150A10)])));
    line(c, 0, _lip, _sw, _lip, stroke(hex(0xC08A50), 2));
    for (var x = 90.0; x < 880; x += 40) {
      final f = 0.75 + 0.25 * math.sin(real * 7 + x);
      c.drawCircle(ui.Offset(x, _lip + 7), 3, fill(hex(0xFFE9B0)));
      c.drawCircle(ui.Offset(x, _lip + 5), 18, shaderPaint(radial(ui.Offset(x, _lip + 5), 18, [rgba(255, 220, 150, 0.35 * f), rgba(255, 220, 150, 0)]), add: true));
      rr(c, x - 7, _lip + 9, 14, 5, 2, fill(hex(0x1A0E10)));
    }
  }

  void drawAudience(ui.Canvas c) {
    for (final f in fans) {
      final s = f.size * (f.row == 0 ? 0.85 : 1.0);
      final cheer = math.sin(math.min(1, f.cheer) * math.pi);
      final dy = -cheer * 10 - f.bob * 2 + math.sin(real * 1.2 + f.phase) * 1;
      final dx = f.laugh > 0 ? math.sin(real * 30 + f.phase) * 2 : 0.0;
      final base = f.row == 0 ? hex(0x24142E) : hex(0x120A18);
      final rim = rgba(255, 200, 150, f.row == 0 ? 0.35 : 0.25);
      c.save();
      c.translate(f.x + dx, f.y + dy);
      c.scale(s);
      c.rotate(f.laugh > 0 ? math.sin(real * 14 + f.phase) * 0.08 : 0);
      if (f.cheer > 0) {
        final p = stroke(base, 6, cap: StrokeCap.round);
        line(c, -16, -26, -22 - cheer * 4, -58, p);
        line(c, 16, -26, 22 + cheer * 4, -58, p);
      }
      rr(c, -24, -30, 48, 40, 18, fill(base));
      c.drawCircle(const ui.Offset(0, -44), 15, fill(base));
      c.drawArc(ui.Rect.fromCircle(center: const ui.Offset(0, -44), radius: 15), -2.6, 2.2, false, stroke(rim, 2));
      switch (f.look) {
        case 1:
          c.drawCircle(const ui.Offset(0, -62), 7, fill(base));
        case 2:
          line(c, -6, -56, -12, -72, stroke(base, 2));
          line(c, 6, -56, 12, -72, stroke(base, 2));
          c.drawCircle(const ui.Offset(-12, -72), 3, fill(hex(0x7CF29A, 0.7)));
          c.drawCircle(const ui.Offset(12, -72), 3, fill(hex(0x7CF29A, 0.7)));
        case 3:
          rect(c, -10, -76, 20, 18, fill(base));
          rect(c, -15, -59, 30, 4, fill(base));
        default:
      }
      c.restore();
    }
  }

  void drawFlyingRoses(ui.Canvas c) {
    for (final r in roses) {
      if (r.k < 1) {
        final p = r.pos;
        _rose(c, p.dx, p.dy, r.rot + r.spin, 1.2);
      }
    }
  }

  // ---------- speech ----------
  void drawBubble(ui.Canvas c, Actor a) {
    final b = a.bubble;
    if (b == null) return;
    final isA = identical(a, actA);
    final s = a.scale;
    final headTop = ui.Offset(a.x + a.face * 4, a.feetY - (a.hipH + (isA ? 56 : 40) + (isA ? 40 : 46)) * s);
    final tp = b.off
        ? _wrapped(b.text, 14, fontDisplay, hex(0xC4142E), 190, weight: FontWeight.w400)
        : _wrapped(b.text, 15, fontBody, hex(0x22142E), 200);
    final w = tp.width + (b.off ? 34 : 26), h = tp.height + (b.off ? 26 : 16);
    // Keep the two bubbles apart: A's sits a little higher.
    var cy = headTop.dy - 18 - h / 2 - (isA ? 0 : 0);
    var cx = headTop.dx;
    final other = isA ? actB : actA;
    if (other.bubble != null && (other.x - a.x).abs() < w) cx += (a.x < other.x ? -1 : 1) * (w - (other.x - a.x).abs()) / 2;
    cx = cx.clamp(_px0 + w / 2 + 6, _px1 - w / 2 - 6);
    cy = math.max(cy, 98 + h / 2);
    final k = (b.age / 0.25).clamp(0.0, 1.0);
    final sc = _backOut(k);
    final fade = ((b.life - b.age) / 0.3).clamp(0.0, 1.0);
    final jitter = b.off && b.age < 0.5 ? math.sin(b.age * 70) * 3 * (0.5 - b.age) * 2 : 0.0;
    c.save();
    c.translate(cx + jitter, cy);
    c.scale(sc);
    final alpha = fade;
    if (b.off) {
      final p = ui.Path();
      const n = 22;
      for (var i = 0; i < n; i++) {
        final an = i / n * math.pi * 2;
        final r = i.isEven ? 1.0 : 0.8;
        final pt = ui.Offset(math.cos(an) * (w / 2 + 10) * r, math.sin(an) * (h / 2 + 10) * r);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
      c.drawPath(p.shift(const ui.Offset(3, 4)), fill(hex(0x000000, 0.3 * alpha)));
      c.drawPath(p, fill(hex(0xFFE45A, alpha)));
      c.drawPath(p, stroke(hex(0xC4142E, alpha), 3));
    } else {
      final tail = ui.Path()
        ..moveTo(-8, h / 2 - 2)
        ..lineTo(headTop.dx - cx, headTop.dy - cy + 6)
        ..lineTo(8, h / 2 - 2)
        ..close();
      rr(c, -w / 2 + 3, -h / 2 + 4, w, h, 14, fill(hex(0x000000, 0.25 * alpha)));
      c.drawPath(tail, fill(hex(0xFFFDF6, alpha)));
      rr(c, -w / 2, -h / 2, w, h, 14, fill(hex(0xFFFDF6, alpha)));
      rr(c, -w / 2, -h / 2, w, h, 14, stroke(hex(isA ? _colA : _colB, alpha), 2.5));
    }
    c.saveLayer(null, Paint()..color = hex(0xFFFFFF, alpha));
    tp.paint(c, ui.Offset(-tp.width / 2, -tp.height / 2));
    c.restore();
    // Speaker tag.
    final tx = -w / 2 - (b.off ? 4 : 0), ty = -h / 2 - (b.off ? 8 : 0);
    c.drawCircle(ui.Offset(tx, ty), 10, fill(hex(isA ? _colA : _colB, alpha)));
    drawText(c, isA ? 'A' : 'B', tx, ty + 5, size: 12, family: fontDisplay, color: hex(0x1A0F22, alpha), align: TextAlign.center);
    c.restore();
  }

  void drawNameTags(ui.Canvas c) {
    final a = phase == StagePhase.intro ? 1.0 : (1 - (t - (cues.isEmpty ? 0 : cues[0])) / 2).clamp(0.0, 1.0);
    if (a <= 0) return;
    for (final act in [actA, actB]) {
      final isA = identical(act, actA);
      final x = act.x, y = act.feetY + 14;
      rr(c, x - 12, y - 12, 24, 18, 6, fill(hex(isA ? _colA : _colB, a)));
      drawText(c, isA ? 'A' : 'B', x, y + 2, size: 12, family: fontDisplay, color: hex(0x1A0F22, a), align: TextAlign.center);
    }
  }

  void drawPopups(ui.Canvas c) {
    for (final p in popups) {
      final a = (p.life * 2).clamp(0.0, 1.0);
      final size = p.big ? 26.0 : p.small ? 13.0 : 16.0;
      final fam = p.small ? fontBody : fontDisplay;
      drawText(c, p.text, p.x + 2, p.y + 2, size: size, family: fam, color: hex(0x1A0F22, a * 0.8), align: TextAlign.center, weight: FontWeight.w600);
      drawText(c, p.text, p.x, p.y, size: size, family: fam, color: p.color.withValues(alpha: a), align: TextAlign.center, weight: FontWeight.w600);
    }
  }

  // ---------- HUD ----------
  void drawHud(ui.Canvas c) {
    // Marquee with a bulb for every cue.
    const mx = 330.0, mw = 300.0;
    rr(c, mx, 4, mw, 48, 8, fill(hex(0x150A20)));
    rr(c, mx, 4, mw, 48, 8, stroke(hex(0xE8B84A), 2));
    drawText(c, 'THE LAST LAUNCH', _sw / 2, 26, size: 15, family: fontDisplay, color: hex(0xFFD166), align: TextAlign.center);
    for (var i = 0; i < cues.length; i++) {
      final x = mx + 30 + i * (mw - 60) / (cues.length - 1);
      final r = results[i];
      var col = hex(0x4A3A5A);
      var lit = 0.0;
      if (r == Judge.perfect) {
        col = hex(0xFFD166);
        lit = 1;
      } else if (r == Judge.good) {
        col = hex(0x7CF29A);
        lit = 0.8;
      } else if (r == Judge.ok) {
        col = hex(0x9FE3FF);
        lit = 0.6;
      } else if (r == Judge.miss) {
        col = hex(0xFF5A6A);
        lit = 0.5;
      } else if (i == next && phase == StagePhase.play) {
        col = hex(0xFFFFFF, 0.5 + 0.5 * math.sin(real * 8));
      }
      c.drawCircle(ui.Offset(x, 41), 4, fill(col));
      if (lit > 0) c.drawCircle(ui.Offset(x, 41), 9, shaderPaint(radial(ui.Offset(x, 41), 9, [col.withValues(alpha: 0.5 * lit), col.withValues(alpha: 0)]), add: true));
    }
    if (phase == StagePhase.title) return;
    // Applause score.
    drawText(c, 'APPLAUSE', 18, 22, size: 10, family: fontBody, color: hex(0xB3A9C9), weight: FontWeight.w600);
    drawText(c, '$score', 18, 46, size: 22, family: fontDisplay, color: hex(0xFFF1D6));
    // Chemistry heart fills with the combo.
    final fillK = (combo / 10).clamp(0.0, 1.0);
    final pulse = 1 + (combo > 0 ? math.sin(real * 8).abs() * 0.08 * fillK : 0.0);
    c.save();
    c.translate(_sw - 46, 30);
    c.scale(pulse);
    final heart = ui.Path()
      ..moveTo(0, 12)
      ..cubicTo(-20, -2, -14, -20, 0, -9)
      ..cubicTo(14, -20, 20, -2, 0, 12)
      ..close();
    c.drawPath(heart, fill(hex(0x3A1A2E)));
    c.save();
    c.clipPath(heart);
    rect(c, -20, 12 - 26 * fillK, 40, 26 * fillK, fill(hex(0xFF5A8A)));
    c.restore();
    c.drawPath(heart, stroke(hex(0xFF8FB8), 2));
    if (fillK >= 1) c.drawCircle(ui.Offset.zero, 26, shaderPaint(radial(ui.Offset.zero, 26, [hex(0xFF5A8A, 0.4), hex(0xFF5A8A, 0)]), add: true));
    c.restore();
    drawText(c, combo > 1 ? 'x$combo' : 'CHEMISTRY', _sw - 76, 34, size: combo > 1 ? 16 : 10, family: combo > 1 ? fontDisplay : fontBody, color: hex(0xFFB3D1), align: TextAlign.right, weight: FontWeight.w600);
    if (phase == StagePhase.play && hintT < 9) {
      final a = (math.min(hintT, 9 - hintT) / 0.6).clamp(0.0, 1.0);
      rr(c, _sw / 2 - 190, 104, 380, 30, 15, fill(hex(0x0E0A1C, 0.7 * a)));
      drawText(c, 'Tap or press Space as the orb meets the ring', _sw / 2, 124, size: 14, color: hex(0xF4EFFC, a), align: TextAlign.center, weight: FontWeight.w600);
    }
  }

  void drawTitle(ui.Canvas c) {
    final y = 200.0;
    drawText(c, 'STAGE FRIGHT', _sw / 2 + 3, y + 3, size: 48, family: fontDisplay, color: hex(0x1A0F22, 0.8), align: TextAlign.center);
    drawText(c, 'STAGE FRIGHT', _sw / 2, y, size: 48, family: fontDisplay, color: hex(0xFFD166), align: TextAlign.center);
    drawText(c, 'A and B in "The Last Launch", live aboard the escape ship', _sw / 2, y + 38, size: 16, color: hex(0xFFE9D6), align: TextAlign.center, weight: FontWeight.w600);
    drawText(c, 'The cue orb bounces between them. Tap as it meets the ring.', _sw / 2, y + 72, size: 14, color: hex(0xF4EFFC, 0.85), align: TextAlign.center);
    drawText(c, 'Miss, and someone goes off script.', _sw / 2, y + 94, size: 14, color: hex(0xF4EFFC, 0.85), align: TextAlign.center);
    final a = 0.55 + 0.45 * math.sin(real * 3);
    drawText(c, 'TAP TO RAISE THE CURTAIN', _sw / 2, y + 150, size: 16, family: fontDisplay, color: hex(0xFFFFFF, a), align: TextAlign.center);
  }

  void drawResults(ui.Canvas c) {
    final k = _backOut((phaseT / 0.45).clamp(0.0, 1.0));
    final ratio = maxScore == 0 ? 0.0 : score / maxScore;
    final title = ratio >= 0.8
        ? 'STANDING OVATION'
        : ratio >= 0.55
            ? 'WARM APPLAUSE'
            : ratio >= 0.3
                ? 'POLITE CLAPPING'
                : 'A NIGHT TO REMEMBER';
    final stars = ratio >= 0.8 ? 3 : ratio >= 0.55 ? 2 : 1;
    c.save();
    c.translate(_sw / 2, 260);
    c.scale(k);
    rr(c, -230, -170, 460, 330, 18, fill(hex(0x0E0A1C, 0.86)));
    rr(c, -230, -170, 460, 330, 18, stroke(hex(0xE8B84A), 2));
    drawText(c, title, 0, -124, size: 28, family: fontDisplay, color: hex(0xFFD166), align: TextAlign.center);
    for (var i = 0; i < 3; i++) {
      final on = i < stars;
      final pop = on ? _backOut(((phaseT - 0.4 - i * 0.2) / 0.3).clamp(0.0, 1.0)) : 1.0;
      c.save();
      c.translate(-50 + i * 50.0, -86);
      c.scale(pop);
      _star(c, 0, 0, 18, on ? hex(0xFFD166) : hex(0x3A2E4A));
      c.restore();
    }
    drawText(c, '$score', 0, -32, size: 34, family: fontDisplay, color: hex(0xFFF1D6), align: TextAlign.center);
    drawText(c, 'APPLAUSE', 0, -12, size: 11, color: hex(0xB3A9C9), align: TextAlign.center, weight: FontWeight.w600);
    final counts = [Judge.perfect, Judge.good, Judge.ok, Judge.miss].map((j) => results.where((r) => r == j).length).toList();
    const labels = ['PERFECT', 'GOOD', 'CLOSE', 'OFF SCRIPT'];
    const cols = [0xFFD166, 0x7CF29A, 0x9FE3FF, 0xFF6B6B];
    for (var i = 0; i < 4; i++) {
      final x = -165 + i * 110.0;
      drawText(c, '${counts[i]}', x, 26, size: 20, family: fontDisplay, color: hex(cols[i]), align: TextAlign.center);
      drawText(c, labels[i], x, 44, size: 10, color: hex(0xB3A9C9), align: TextAlign.center, weight: FontWeight.w600);
    }
    drawText(c, 'Best run: $bestCombo in a row', 0, 74, size: 13, color: hex(0xF4EFFC), align: TextAlign.center, weight: FontWeight.w600);
    if (bloopers.isNotEmpty) {
      final bl = bloopers[(bloopers.length * 0.6).floor().clamp(0, bloopers.length - 1)];
      final tp = _wrapped('Blooper reel: $bl', 12, fontBody, hex(0xFFE08A), 400, weight: FontWeight.w400);
      tp.paint(c, ui.Offset(-tp.width / 2, 86));
    }
    final a = phaseT > 1.2 ? 0.55 + 0.45 * math.sin(real * 3) : 0.0;
    drawText(c, 'TAP TO PERFORM AGAIN', 0, 146, size: 13, family: fontDisplay, color: hex(0xFFFFFF, a), align: TextAlign.center);
    c.restore();
    // Hearts drift up when the chemistry was good.
    if (ratio >= 0.55) {
      for (var i = 0; i < 8; i++) {
        final ph = (real * 0.25 + i / 8) % 1;
        final x = _sw / 2 + math.sin(real + i * 1.7) * 280 + (i - 4) * 20;
        final y = 470 - ph * 420;
        final al = math.sin(ph * math.pi) * 0.6;
        c.save();
        c.translate(x, y);
        c.scale(0.6 + (i % 3) * 0.2);
        c.drawPath(
            ui.Path()
              ..moveTo(0, 8)
              ..cubicTo(-13, -1, -9, -13, 0, -6)
              ..cubicTo(9, -13, 13, -1, 0, 8)
              ..close(),
            fill(hex(0xFF5A8A, al)));
        c.restore();
      }
    }
  }
}

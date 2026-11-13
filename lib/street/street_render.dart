part of 'street_game.dart';

// Deterministic per-tile noise so the city looks the same every frame.
double _h(int c, int r, [int k = 0]) {
  var n = c * 374761393 + r * 668265263 + k * 2147483647;
  n = (n ^ (n >> 13)) * 1274126177;
  return ((n ^ (n >> 16)) & 0xFFFF) / 0xFFFF;
}

final List<Offset> _smoke = List.generate(14, (i) {
  final r = math.Random(300 + i);
  return Offset(r.nextDouble() * stageW, r.nextDouble() * stageH);
});

final List<Offset> _embers = List.generate(50, (i) {
  final r = math.Random(500 + i);
  return Offset(r.nextDouble() * stageW, r.nextDouble() * stageH);
});

extension StreetRender on StreetGame {
  bool _bld(int c, int r) {
    final k = at(c, r);
    return k == '#' || k == 'x';
  }

  void renderScene(Canvas c, double dt) {
    final sx = shake > 0 ? rand(-shake, shake) : 0.0, sy = shake > 0 ? rand(-shake, shake) : 0.0;
    rect(c, 0, 0, stageW, stageH, fill(hex(0x0E0A1C)));
    c.save();
    c.translate((-cam.dx + sx).roundToDouble(), (-cam.dy + sy).roundToDouble());

    final c0 = math.max(0, (cam.dx / tile).floor() - 1), c1 = math.min(cols - 1, ((cam.dx + stageW) / tile).ceil() + 1);
    final r0 = math.max(0, (cam.dy / tile).floor() - 1), r1 = math.min(rows - 1, ((cam.dy + stageH + bldH) / tile).ceil() + 1);

    for (var r = r0; r <= r1; r++) {
      for (var col = c0; col <= c1; col++) {
        drawGround(c, col, r);
      }
    }
    drawPad(c);
    for (var r = r0; r <= r1; r++) {
      for (var col = c0; col <= c1; col++) {
        final k = grid[r][col];
        if (k == '~') drawLava(c, col, r);
        if (_bld(col, r) || k == 'r') {
          // Cast shadow toward the lower right.
          rect(c, col * tile + 10, r * tile + 8, tile, tile, fill(rgba(8, 4, 16, 0.35)));
        }
      }
    }
    for (final v in vents) {
      drawVent(c, v);
    }
    for (final rk in rocks) {
      drawRockShadow(c, rk);
    }
    // Row by row, so buildings in front cover what is behind them.
    final pr = (p.y / tile).floor();
    final rr0 = (rocket.y / tile).floor();
    for (var r = r0; r <= r1; r++) {
      for (var col = c0; col <= c1; col++) {
        final k = grid[r][col];
        if (_bld(col, r)) drawBuilding(c, col, r);
        if (k == 'r') drawWreck(c, col, r);
      }
      if (r == rr0) drawRocket(c);
      if (r == pr && state != StreetState.title) drawWalker(c);
    }
    drawParticles(c);
    for (final rk in rocks) {
      drawRock(c, rk);
    }
    for (final tx in texts) {
      final a = (tx.life / 1.2 * 2).clamp(0.0, 1.0);
      drawText(c, tx.text, tx.x + 2, tx.y + 2, size: 16, family: fontDisplay, color: hex(0x1A0F22, a), align: TextAlign.center);
      drawText(c, tx.text, tx.x, tx.y, size: 16, family: fontDisplay, color: tx.color.withValues(alpha: a), align: TextAlign.center);
    }
    c.restore();

    drawSky(c, dt);
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(radial(const Offset(stageW / 2, stageH / 2), stageH,
            [const Color(0x00000000), const Color(0x00000000), hex(0x080410, 0.65)], [0, 0.45, 1])));
    if (state == StreetState.play) {
      drawHud(c);
      drawBanner(c);
    }
    if (state == StreetState.title) drawTitle(c);
    if (state == StreetState.won) drawEnd(c);
  }

  // ---------- ground ----------
  void drawGround(Canvas c, int col, int r) {
    final x = col * tile, y = r * tile;
    final n = _h(col, r);
    rect(c, x, y, tile, tile, fill(Color.lerp(hex(0x241A36), hex(0x2B2040), n)!));
    // Curb strips along building edges.
    if (_bld(col, r - 1)) rect(c, x, y, tile, 5, fill(hex(0x3A2D4E)));
    if (_bld(col - 1, r)) rect(c, x, y, 4, tile, fill(hex(0x34284A)));
    if (_bld(col + 1, r)) rect(c, x + tile - 4, y, 4, tile, fill(hex(0x34284A)));
    // Cracks and lane paint.
    if (n > 0.82) {
      final p = Path()
        ..moveTo(x + 6, y + tile * _h(col, r, 1))
        ..lineTo(x + tile * 0.4, y + tile * 0.5)
        ..lineTo(x + tile * 0.7, y + tile * _h(col, r, 2))
        ..lineTo(x + tile - 4, y + tile * 0.6);
      c.drawPath(p, stroke(hex(0x150F22), 1.5));
    }
    if (!_bld(col, r - 1) && !_bld(col, r + 1) && r.isEven && col % 3 == 0 && n < 0.5) {
      rect(c, x + 8, y + tile / 2 - 1.5, 18, 3, fill(rgba(255, 220, 160, 0.12)));
    }
    if (n < 0.06) {
      // A manhole cover.
      c.drawCircle(Offset(x + tile / 2, y + tile / 2), 8, fill(hex(0x1A1228)));
      c.drawCircle(Offset(x + tile / 2, y + tile / 2), 8, stroke(hex(0x3A2D4E), 1.5));
    }
  }

  void drawLava(Canvas c, int col, int r) {
    final x = col * tile, y = r * tile;
    final pulse = 0.6 + math.sin(real * 3 + col) * 0.2;
    rect(c, x - 20, y - 20, tile + 40, tile + 40,
        shaderPaint(radial(Offset(x + tile / 2, y + tile / 2), 44, [rgba(255, 110, 40, 0.35 * pulse), rgba(255, 60, 30, 0)]), add: true));
    final p = Path()
      ..moveTo(x + 2, y + tile * 0.3 + _h(col, r, 3) * 8)
      ..lineTo(x + tile * 0.35, y + tile * 0.55)
      ..lineTo(x + tile * 0.6, y + tile * 0.35)
      ..lineTo(x + tile - 2, y + tile * 0.6 + _h(col, r, 4) * 8)
      ..lineTo(x + tile - 2, y + tile * 0.8)
      ..lineTo(x + tile * 0.6, y + tile * 0.6)
      ..lineTo(x + tile * 0.35, y + tile * 0.8)
      ..lineTo(x + 2, y + tile * 0.55)
      ..close();
    c.drawPath(p, fill(hex(0x1A0A12)));
    c.drawPath(p.shift(const Offset(0, 2)), shaderPaint(linear(Offset(x, y), Offset(x + tile, y + tile), [hex(0xFFD36B), hex(0xFF5A2A)])));
    c.drawPath(p, stroke(rgba(255, 220, 120, pulse), 1.2));
  }

  void drawPad(Canvas c) {
    final pc = pad.center;
    rect(c, pad.left, pad.top, pad.width, pad.height, fill(hex(0x2E2440)));
    c.drawCircle(pc, pad.shortestSide * 0.42, fill(hex(0x3A2F52)));
    c.drawCircle(pc, pad.shortestSide * 0.42, stroke(hex(0xFFD36B, 0.6), 3));
    // Hazard stripes along the edge.
    for (var i = 0.0; i < pad.width; i += 20) {
      rect(c, pad.left + i, pad.bottom - 6, 10, 6, fill(hex(0xFFB36B, 0.8)));
      rect(c, pad.left + i, pad.top, 10, 6, fill(hex(0xFFB36B, 0.8)));
    }
    // Landing lights blink in a ring.
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      final on = ((real * 6).floor() % 12) == i;
      final o = pc + Offset(math.cos(a), math.sin(a)) * pad.shortestSide * 0.42;
      c.drawCircle(o, on ? 5 : 3, glow(on ? hex(0x9FE3FF) : hex(0x9FE3FF, 0.35)));
    }
    if (!rocket.launching) {
      final a = 0.25 + math.sin(real * 3) * 0.15;
      rect(c, pad.left - 30, pad.top - 30, pad.width + 60, pad.height + 60,
          shaderPaint(radial(pc, pad.longestSide * 0.7, [rgba(159, 227, 255, a), rgba(159, 227, 255, 0)]), add: true));
    }
  }

  void drawVent(Canvas c, Vent v) {
    final heat = v.on ? 1.0 : v.warm ? 0.5 : 0.0;
    rr(c, v.cx - 16, v.cy - 12, 32, 24, 4, fill(hex(0x1A1228)));
    for (var i = 0; i < 4; i++) {
      rect(c, v.cx - 12, v.cy - 9 + i * 5.5, 24, 2.5, fill(Color.lerp(hex(0x4A3B5C), hex(0xFFB36B), heat)!));
    }
    if (heat > 0) {
      rect(c, v.cx - 40, v.cy - 40, 80, 80,
          shaderPaint(radial(Offset(v.cx, v.cy), 40, [rgba(255, 120, 50, 0.4 * heat), rgba(255, 80, 40, 0)]), add: true));
    }
  }

  // ---------- buildings ----------
  void drawBuilding(Canvas c, int col, int r) {
    final x = col * tile, y = r * tile;
    final cracked = at(col, r) == 'x';
    final roofY = y - bldH;
    // Front face, only where the street is visible below.
    if (!_bld(col, r + 1)) {
      rect(c, x, roofY + tile, tile, bldH, fill(cracked ? hex(0x2A1F38) : hex(0x1E1430)));
      for (var i = 0; i < 3; i++) {
        final f = _h(col, r, 10 + i);
        if (f < 0.45) continue;
        final lit = math.sin(real * (1 + f * 3) + f * 20) > -0.7;
        rect(c, x + 5 + i * 12, roofY + tile + 8, 7, 9, fill(lit ? rgba(255, 190, 110, 0.45 + f * 0.4) : hex(0x140C20)));
        rect(c, x + 5 + i * 12, roofY + tile + 21, 7, 8, fill(rgba(255, 160, 90, f > 0.8 ? 0.6 : 0.15)));
      }
      if (cracked) _crackLines(c, x, roofY + tile, bldH, col, r);
    }
    // Roof.
    final n = _h(col, r, 5);
    rect(c, x, roofY, tile, tile, fill(cracked ? hex(0x4A3A5E) : Color.lerp(hex(0x34264A), hex(0x3D2C55), n)!));
    final edge = stroke(cracked ? hex(0x7A6690) : hex(0x5A4876), 2);
    if (!_bld(col, r - 1)) line(c, x, roofY + 1, x + tile, roofY + 1, edge);
    if (!_bld(col - 1, r)) line(c, x + 1, roofY, x + 1, roofY + tile, edge);
    if (!_bld(col + 1, r)) line(c, x + tile - 1, roofY, x + tile - 1, roofY + tile, edge);
    if (!_bld(col, r + 1)) line(c, x, roofY + tile - 1, x + tile, roofY + tile - 1, stroke(hex(0x6A5688), 2));
    if (cracked) {
      _crackLines(c, x, roofY, tile, col, r);
      return;
    }
    // Rooftop details: vents, water tanks, small fires.
    if (n > 0.7) {
      rr(c, x + 8 + _h(col, r, 6) * 12, roofY + 8 + _h(col, r, 7) * 12, 12, 10, 2, fill(hex(0x52436A)));
    } else if (n < 0.12) {
      final fx = x + tile / 2, fy = roofY + tile / 2;
      rect(c, fx - 30, fy - 30, 60, 60, shaderPaint(radial(Offset(fx, fy), 30, [rgba(255, 120, 50, 0.45), rgba(255, 80, 40, 0)]), add: true));
      if (rng.nextDouble() < 0.4) {
        addPart(SParticle(fx + rand(-8, 8), y - 2, rand(-10, 10), rand(-6, 2), rand(0.3, 0.6), rand(5, 10),
            const Color(0xFFFF7A3D), SPart.flame, z: bldH + 4, vz: rand(60, 120)));
      }
      if (rng.nextDouble() < 0.08) {
        addPart(SParticle(fx, y - 2, rand(-5, 5), rand(-20, -5), rand(1.5, 2.5), rand(10, 18), const Color(0xFF3A2D48), SPart.smoke,
            z: bldH + 20, vz: rand(30, 60)));
      }
    }
  }

  void _crackLines(Canvas c, double x, double y, double h, int col, int r) {
    final p = Path()
      ..moveTo(x + tile * 0.2, y)
      ..lineTo(x + tile * 0.45, y + h * 0.4)
      ..lineTo(x + tile * 0.3, y + h * 0.7)
      ..lineTo(x + tile * 0.55, y + h)
      ..moveTo(x + tile * 0.45, y + h * 0.4)
      ..lineTo(x + tile * 0.8, y + h * 0.3);
    c.drawPath(p, stroke(hex(0x120A1C), 2));
    final f = math.sin(real * 9 + col) > 0.6 ? 0.8 : 0.3;
    c.drawCircle(Offset(x + tile * 0.45, y + h * 0.4), 3, glow(rgba(191, 233, 255, f)));
  }

  void drawWreck(Canvas c, int col, int r) {
    final x = col * tile, y = r * tile;
    final burning = _h(col, r, 8) > 0.5;
    // A wrecked car, seen from above and in front.
    rr(c, x + 3, y + 8, tile - 6, tile - 12, 6, fill(hex(0x4A2E3E)));
    rr(c, x + 3, y + tile - 14, tile - 6, 10, 4, fill(hex(0x2E1C2A)));
    rr(c, x + 9, y + 4, tile - 18, 16, 4, fill(hex(0x5E3C50)));
    rect(c, x + 11, y + 7, tile - 22, 6, fill(hex(0x1A1228)));
    rect(c, x + 6, y + tile - 10, 6, 3, fill(hex(0xFFB36B, 0.7)));
    rect(c, x + tile - 12, y + tile - 10, 6, 3, fill(hex(0xFFB36B, 0.3)));
    if (burning) {
      rect(c, x - 10, y - 20, tile + 20, tile + 20,
          shaderPaint(radial(Offset(x + tile / 2, y + 12), 34, [rgba(255, 120, 50, 0.4), rgba(255, 80, 40, 0)]), add: true));
      if (rng.nextDouble() < 0.35) {
        addPart(SParticle(x + tile / 2 + rand(-8, 8), y + 12, rand(-8, 8), rand(-4, 2), rand(0.3, 0.55), rand(4, 9),
            const Color(0xFFFF8C4A), SPart.flame, z: 12, vz: rand(50, 100)));
      }
    }
  }

  // ---------- rocket ----------
  void drawRocket(Canvas c) {
    final r = rocket;
    final x = r.x, base = r.y - r.lift;
    if (r.lift > 0) {
      final s = (1 - r.lift / 1500).clamp(0.2, 1.0);
      c.drawOval(Rect.fromCenter(center: Offset(x, r.y), width: 60 * s, height: 20 * s), fill(rgba(8, 4, 16, 0.4 * s)));
    } else {
      c.drawOval(Rect.fromCenter(center: Offset(x, r.y), width: 60, height: 20), fill(rgba(8, 4, 16, 0.5)));
    }
    // Gantry arm that swings away at launch.
    if (r.t < 0.9) {
      rect(c, x + 26, base - 120, 8, 120, fill(hex(0x3A2D4E)));
      for (var i = 0; i < 6; i++) {
        line(c, x + 26, base - i * 20, x + 34, base - i * 20 - 20, stroke(hex(0x5A4876), 1.5));
      }
    }
    // Fins.
    final fin = Path()
      ..moveTo(x - 14, base - 30)
      ..lineTo(x - 28, base)
      ..lineTo(x - 14, base - 6)
      ..moveTo(x + 14, base - 30)
      ..lineTo(x + 28, base)
      ..lineTo(x + 14, base - 6);
    c.drawPath(fin, fill(hex(0xFF5B3A)));
    // Body and nose.
    rr(c, x - 14, base - 110, 28, 106, 8, shaderPaint(linear(Offset(x - 14, 0), Offset(x + 14, 0), [hex(0xFFFFFF), hex(0xB8AEC8)])));
    final nose = Path()
      ..moveTo(x - 14, base - 104)
      ..quadraticBezierTo(x, base - 150, x + 14, base - 104)
      ..close();
    c.drawPath(nose, fill(hex(0xFF7A3D)));
    rect(c, x - 14, base - 60, 28, 6, fill(hex(0xFF7A3D)));
    c.drawCircle(Offset(x, base - 84), 6, fill(hex(0x4A2A7A)));
    c.drawCircle(Offset(x - 2, base - 86), 2, fill(rgba(255, 255, 255, 0.8)));
    if (r.t >= 0.9) {
      rect(c, x - 40, base - 20, 80, 80,
          shaderPaint(radial(Offset(x, base + 6), 40, [rgba(255, 220, 140, 0.9), rgba(255, 120, 50, 0)]), add: true));
    }
  }

  // ---------- player ----------
  void drawWalker(Canvas c) {
    if (p.boarded) return;
    final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
    final running = speed > 20;
    final ph = p.run;
    final bob = running ? -math.sin(ph).abs() * 2.5 : math.sin(real * 2) * 0.6;
    final x = p.x, y = p.y;
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 22, height: 9), fill(rgba(8, 4, 16, 0.45)));
    if (p.safe > 0 && math.sin(real * 30) > 0.3) return;
    final side = p.fx.abs() > p.fy.abs() * 0.9;
    final back = !side && p.fy < 0;
    final dir = p.fx >= 0 ? 1.0 : -1.0;
    // Scarf behind the body when facing down or sideways.
    void scarf() {
      final path = Path()..moveTo(p.scarf[0].dx, p.scarf[0].dy);
      for (final s in p.scarf) {
        path.lineTo(s.dx, s.dy);
      }
      c.drawPath(path, stroke(hex(0xFF5B3A), 4, cap: StrokeCap.round));
    }

    if (!back) scarf();
    c.save();
    c.translate(x, y);
    if (p.stun > 0) c.rotate(math.sin(real * 30) * 0.15);
    // Legs.
    final legPaint = stroke(hex(0xD9D1EA), 5);
    for (final (o, k) in [(-3.5, 0.0), (3.5, math.pi)]) {
      final swing = running ? math.sin(ph + k) : 0.0;
      if (side) {
        final ex = o * 0.3 + swing * 7 * dir;
        line(c, o * 0.3, -14, ex, -2, legPaint);
        rect(c, ex - 3, -4, 7, 4, fill(hex(0x3B2C52)));
      } else {
        final lift = swing * 3;
        line(c, o, -14, o, -2 - lift, legPaint);
        rect(c, o - 3.5, -4 - lift, 7, 4, fill(hex(0x3B2C52)));
      }
    }
    c.translate(0, bob);
    // Backpack, visible from behind or the side.
    if (side) rr(c, dir > 0 ? -14 : 6, -32, 8, 15, 2, fill(hex(0x6D6288)));
    // Body.
    rr(c, -8, -33, 16, 21, 5, fill(hex(0xEFE9FA)));
    rect(c, -8, -24, 16, 3, fill(hex(0xFF7A3D)));
    // Arms swing with the stride.
    final armPaint = stroke(hex(0xEFE9FA), 4, cap: StrokeCap.round);
    final sw = running ? math.sin(ph + math.pi) : 0.0;
    if (side) {
      line(c, 0, -28, sw * 9 * dir, -19, armPaint);
    } else {
      line(c, -8, -29, -10, -19 + sw * 3, armPaint);
      line(c, 8, -29, 10, -19 - sw * 3, armPaint);
    }
    if (back) {
      rr(c, -8, -32, 16, 15, 3, fill(hex(0x6D6288)));
      rect(c, -2, -26, 4, 3, fill(hex(0xFFB36B)));
    }
    // Helmet and visor.
    c.drawCircle(const Offset(0, -40), 9, fill(hex(0xF7F3FF)));
    final visor = shaderPaint(linear(const Offset(0, -46), const Offset(0, -34), [hex(0xFFB36B), hex(0x4A2A7A)]));
    if (side) {
      rr(c, dir > 0 ? 1 : -10, -45, 9, 9, 3, visor);
      rect(c, dir > 0 ? 4 : -6, -43, 2, 3, fill(rgba(255, 255, 255, 0.8)));
    } else if (!back) {
      rr(c, -6, -45, 12, 9, 3, visor);
      rect(c, -3, -43, 2, 3, fill(rgba(255, 255, 255, 0.8)));
    }
    c.restore();
    if (back) scarf();
  }

  // ---------- falling rocks ----------
  void drawRockShadow(Canvas c, Rock rk) {
    final k = (1 - rk.z / 520).clamp(0.0, 1.0);
    c.drawOval(Rect.fromCenter(center: Offset(rk.x, rk.y), width: rk.r * (0.6 + k) * 2.2, height: rk.r * (0.6 + k) * 1.2),
        fill(rgba(255, 70, 40, 0.15 + k * 0.45)));
    c.drawOval(Rect.fromCenter(center: Offset(rk.x, rk.y), width: rk.r * 3.2, height: rk.r * 1.8),
        stroke(rgba(255, 140, 80, 0.2 + k * 0.5), 1.5));
  }

  void drawRock(Canvas c, Rock rk) {
    c.save();
    c.translate(rk.x, rk.y - rk.z - rk.r);
    c.rotate(rk.spin);
    rect(c, -rk.r * 2.4, -rk.r * 2.4, rk.r * 4.8, rk.r * 4.8,
        shaderPaint(radial(Offset.zero, rk.r * 2.4, [rgba(255, 140, 60, 0.6), rgba(255, 80, 40, 0)]), add: true));
    final path = Path();
    for (var i = 0; i < 7; i++) {
      final a = i / 7 * math.pi * 2, r2 = rk.r * (0.75 + ((i * 37) % 10) / 30);
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

  void drawParticles(Canvas c) {
    for (final pt in parts) {
      final a = (pt.life / pt.max).clamp(0.0, 1.0);
      final y = pt.y - pt.z;
      switch (pt.type) {
        case SPart.flame:
        case SPart.spark:
          c.drawCircle(Offset(pt.x, y), pt.size * (pt.type == SPart.flame ? a : 1), glow(pt.color.withValues(alpha: a)));
        case SPart.smoke:
          c.drawCircle(Offset(pt.x, y), pt.size, fill(pt.color.withValues(alpha: a * 0.45)));
        case SPart.chunk:
        case SPart.grain:
          rect(c, pt.x, y, pt.size, pt.size, fill(pt.color.withValues(alpha: a)));
      }
    }
  }

  /// Drifting smoke shadows and embers in screen space.
  void drawSky(Canvas c, double dt) {
    for (var i = 0; i < _smoke.length; i++) {
      final s = _smoke[i];
      final x = (s.dx - cam.dx * 0.3 + real * (8 + i)) % (stageW + 300) - 150;
      final y = (s.dy - cam.dy * 0.3) % (stageH + 300) - 150;
      c.drawCircle(Offset(x, y), 90 + (i % 4) * 30, fill(rgba(10, 4, 18, 0.12)));
    }
    for (var i = 0; i < _embers.length; i++) {
      final e = _embers[i];
      final x = (e.dx - cam.dx * 1.2 + real * 14 + stageW * 10) % stageW;
      final y = (e.dy - cam.dy * 1.2 - real * (12 + i % 5 * 6) + stageH * 40) % stageH;
      if (i % 3 == 0) {
        rect(c, x, y, 2, 2, fill(rgba(200, 190, 210, 0.3)));
      } else {
        rect(c, x, y, 2, 2, glow(rgba(255, 150, 70, 0.4 + math.sin(real * 4 + i) * 0.3)));
      }
    }
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(linear(Offset.zero, const Offset(0, stageH), [rgba(255, 90, 40, 0.06 + quake * 0.04), rgba(255, 90, 40, 0)]), add: true));
  }

  // ---------- HUD and screens ----------
  void drawHud(Canvas c) {
    final label = hex(0xB3A9C9);
    rr(c, 16, 14, 150, 76, 8, fill(rgba(14, 10, 28, 0.6)));
    drawText(c, 'TIME', 30, 34, size: 11, color: label, weight: FontWeight.w600);
    drawText(c, fmtTime(t), 30, 70, size: 28, family: fontDisplay, color: hex(0xFFD36B));
    if (!p.boarded) {
      final dx = pad.center.dx - p.x, dy = pad.center.dy - p.y;
      final m = (math.sqrt(dx * dx + dy * dy) / 20).round();
      final txt = m < 3 ? 'BOARD NOW' : 'PAD $m m';
      final tw = textWidth(txt, 14, fontBody, FontWeight.w600);
      rr(c, stageW - 60 - tw, 14, tw + 54, 34, 8, fill(rgba(14, 10, 28, 0.6)));
      drawText(c, txt, stageW - 19, 36, size: 14, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.right);
      // Compass arrow pointing at the pad.
      c.save();
      c.translate(stageW - 38 - tw, 31);
      c.rotate(math.atan2(dy, dx));
      final arrow = Path()
        ..moveTo(9, 0)
        ..lineTo(-6, -6)
        ..lineTo(-3, 0)
        ..lineTo(-6, 6)
        ..close();
      c.drawPath(arrow, fill(hex(0x9FE3FF)));
      c.restore();
    }
    drawText(c, sfx.muted ? 'SOUND OFF (M)' : 'SOUND ON (M)', stageW - 19, 66,
        size: 11, color: rgba(179, 169, 201, 0.8), weight: FontWeight.w600, align: TextAlign.right);
  }

  void drawBanner(Canvas c) {
    final b = banner;
    if (b == null) return;
    final a = math.min(1.0, math.min(b.t * 4, (b.dur - b.t) * 3)).clamp(0.0, 1.0);
    final double y = 150 - (1 - math.min(1.0, b.t * 4)) * 20;
    rect(c, 0, y - 40, stageW, 70, fill(rgba(14, 10, 28, 0.55 * a)));
    drawText(c, b.title, stageW / 2, y, size: 30, family: fontDisplay, color: hex(0xFFD36B, a), align: TextAlign.center);
    drawText(c, b.sub, stageW / 2, y + 22, size: 15, color: hex(0xF4EFFC, a), align: TextAlign.center);
  }

  void drawTitle(Canvas c) {
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(linear(Offset.zero, const Offset(0, stageH), [rgba(14, 10, 28, 0.35), rgba(14, 10, 28, 0.6), rgba(14, 10, 28, 0.88)], [0, 0.5, 1])));
    final wob = reduceMotion ? 0.0 : math.sin(real * 2) * 3;
    const mid = stageW / 2;
    drawText(c, 'THE CITY  ·  ON FOOT', mid, 170, size: 13, color: hex(0xFF9A6A), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, 'STREET', mid + 4, 254 + wob, size: 76, family: fontDisplay, color: hex(0xFF5B3A), align: TextAlign.center);
    drawText(c, 'STREET', mid, 250 + wob, size: 76, family: fontDisplay, color: hex(0xF4EFFC), align: TextAlign.center);
    drawText(c, 'ESCAPE', mid + 4, 330 + wob, size: 76, family: fontDisplay, color: hex(0xFF5B3A), align: TextAlign.center);
    drawText(c, 'ESCAPE', mid, 326 + wob, size: 76, family: fontDisplay, color: hex(0xFFD36B), align: TextAlign.center);
    drawText(c, 'Find your way through the burning streets to the launch pad.', mid, 372, size: 17, align: TextAlign.center);
    if (math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS AN ARROW KEY OR TAP TO START', mid, 430, size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }

  void drawEnd(Canvas c) {
    final a = (endT * 1.5).clamp(0.0, 1.0);
    rect(c, 0, 0, stageW, stageH, fill(rgba(14, 10, 28, 0.72 * a)));
    const mid = stageW / 2;
    drawText(c, 'LIFTOFF CONFIRMED', mid, 180, size: 13, color: hex(0x9FE3FF, a), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, 'YOU MADE IT', mid, 250, size: 56, family: fontDisplay, color: hex(0xFFD36B, a), align: TextAlign.center);
    drawText(c, 'You reached the pad in ${fmtTime(endTime)}.', mid, 300, size: 18, color: hex(0xF4EFFC, a), align: TextAlign.center);
    drawText(c, 'Cracked walls broken: $shortcuts of ${cracks.length}', mid, 330, size: 18, color: hex(0xB3A9C9, a), align: TextAlign.center);
    if (endT > 1.2 && math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS SPACE OR TAP TO RUN AGAIN  ·  ESC FOR MENU', mid, 400,
          size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }
}

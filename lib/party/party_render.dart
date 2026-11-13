part of 'party_game.dart';

double _n(int c, int r, [int k = 0]) {
  var n = c * 374761393 + r * 668265263 + k * 2147483647;
  n = (n ^ (n >> 13)) * 1274126177;
  return ((n ^ (n >> 16)) & 0xFFFF) / 0xFFFF;
}

Color _hue(double h, double s, double l, [double a = 1]) => HSLColor.fromAHSL(a, h % 360, s, l).toColor();

extension PartyRender on PartyGame {
  void renderScene(Canvas c, double dt) {
    final sx = shake > 0 ? rand(-shake, shake) : 0.0, sy = shake > 0 ? rand(-shake, shake) : 0.0;
    rect(c, 0, 0, stageW, stageH, fill(hex(0x0E0A1C)));
    c.save();
    c.translate((-cam.dx + sx).roundToDouble(), (-cam.dy + sy).roundToDouble());
    final c0 = math.max(0, (cam.dx / tile).floor() - 1), c1 = math.min(cols - 1, ((cam.dx + stageW) / tile).ceil() + 1);
    final r0 = math.max(0, (cam.dy / tile).floor() - 1), r1 = math.min(rows - 1, ((cam.dy + stageH) / tile).ceil() + 2);

    for (var r = r0; r <= r1; r++) {
      for (var col = c0; col <= c1; col++) {
        drawFloor(c, col, r);
      }
    }
    drawSpotlights(c);
    if (state == PartyState.met) drawMeetGlow(c);

    // Row by row so that people and furniture overlap in the right order.
    final people = <Person>[...guests, if (state != PartyState.title) a, if (state != PartyState.title) b]
      ..sort((p, q) => p.y.compareTo(q.y));
    var pi = 0;
    for (var r = r0; r <= r1; r++) {
      for (var col = c0; col <= c1; col++) {
        drawFixture(c, col, r);
      }
      final rowEnd = (r + 1) * tile;
      while (pi < people.length && people[pi].y < rowEnd) {
        drawPerson(c, people[pi]);
        pi++;
      }
    }
    while (pi < people.length) {
      drawPerson(c, people[pi++]);
    }
    for (final p in <Person>[...guests, a, b]) {
      if (p.bubble > 0) drawBubble(c, p);
    }
    if (state != PartyState.title) {
      drawLabel(c, a);
      drawLabel(c, b);
    }
    if (state == PartyState.met && metT < 1.4) drawEyeContact(c);
    drawParticles(c);
    for (final tx in texts) {
      final al = (tx.life / 1.2 * 2).clamp(0.0, 1.0);
      drawText(c, tx.text, tx.x + 2, tx.y + 2, size: tx.size, family: fontDisplay, color: hex(0x1A0F22, al), align: TextAlign.center);
      drawText(c, tx.text, tx.x, tx.y, size: tx.size, family: fontDisplay, color: tx.color.withValues(alpha: al), align: TextAlign.center);
    }
    c.restore();

    // Soft purple haze and a vignette.
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(radial(const Offset(stageW / 2, stageH / 2), stageH,
            [const Color(0x00000000), const Color(0x00000000), hex(0x0A0414, 0.7)], [0, 0.5, 1])));
    if (state == PartyState.play) {
      drawFinder(c);
      drawHud(c);
      drawBanner(c);
    }
    if (state == PartyState.title) drawTitle(c);
    if (state == PartyState.met) drawEnd(c);
  }

  // ---------- venue ----------
  void drawFloor(Canvas c, int col, int r) {
    final x = col * tile, y = r * tile;
    final k = at(col, r);
    if (k == 'D') {
      // Dance floor tiles pulse to the beat.
      final beat = (math.sin(real * 4 + (col + r) * 0.9) * 0.5 + 0.5);
      final h = (col * 37 + r * 53 + real * 40) % 360;
      rect(c, x + 1, y + 1, tile - 2, tile - 2, fill(_hue(h, 0.6, 0.18 + beat * 0.2)));
      rect(c, x + 1, y + 1, tile - 2, tile - 2, glow(_hue(h, 0.8, 0.5, 0.08 + beat * 0.12)));
      return;
    }
    // Dark wooden floor with a soft sheen.
    final n = _n(col, r);
    rect(c, x, y, tile, tile, fill(Color.lerp(hex(0x1E1530), hex(0x251A3A), n)!));
    line(c, x, y + tile / 2, x + tile, y + tile / 2, stroke(hex(0x18102A), 1));
    line(c, x + (r.isEven ? tile * 0.3 : tile * 0.7), y, x + (r.isEven ? tile * 0.3 : tile * 0.7), y + tile / 2, stroke(hex(0x18102A), 1));
  }

  void drawSpotlights(Canvas c) {
    // Three sweeping lights from the stage rig.
    const colors = [0xFF6B8F, 0x9FE3FF, 0xFFD36B];
    for (var i = 0; i < 3; i++) {
      final x = worldW * (0.25 + i * 0.25) + math.sin(real * (0.3 + i * 0.13) + i * 2) * 360;
      final y = worldH * 0.5 + math.cos(real * (0.25 + i * 0.1) + i) * 240;
      final col = colors[i];
      final r = (col >> 16) & 255, g = (col >> 8) & 255, bl = col & 255;
      rect(c, x - 160, y - 110, 320, 220, shaderPaint(radial(Offset(x, y), 150, [rgba(r, g, bl, 0.16), rgba(r, g, bl, 0)]), add: true));
    }
  }

  void drawMeetGlow(Canvas c) {
    final mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2;
    final k = math.min(1.0, metT * 1.5);
    // The room dims and a warm light finds them.
    rect(c, cam.dx - 20, cam.dy - 40, stageW + 40, stageH + 80, fill(rgba(10, 4, 20, 0.45 * k)));
    rect(c, mx - 200, my - 160, 400, 320, shaderPaint(radial(Offset(mx, my - 10), 160, [rgba(255, 190, 200, 0.4 * k), rgba(255, 120, 150, 0)]), add: true));
  }

  void drawFixture(Canvas c, int col, int r) {
    final k = at(col, r);
    final x = col * tile, y = r * tile;
    switch (k) {
      case '#':
        rect(c, x, y - 20, tile, tile + 20, fill(hex(0x140C22)));
        if (r == 0 && col > 0 && col < cols - 1 && col % 5 != 0) drawWindow(c, col, x, y);
        if (at(col, r + 1) != '#') {
          rect(c, x, y + tile - 20, tile, 20, fill(hex(0x2A1F3E)));
          // Little wall lamps.
          if (col % 4 == 0) {
            c.drawCircle(Offset(x + tile / 2, y + tile - 12), 3, glow(hex(0xFFD3A0)));
            rect(c, x - 10, y + tile - 30, tile + 20, 50,
                shaderPaint(radial(Offset(x + tile / 2, y + tile - 10), 30, [rgba(255, 200, 150, 0.25), rgba(255, 200, 150, 0)]), add: true));
          }
        }
      case 'S':
        drawStageTile(c, col, r, x, y);
      case 'B':
        final front = at(col, r + 1) != 'B';
        rect(c, x, y - 22, tile, tile, fill(hex(0x4A2E3E)));
        line(c, x + tile - 2, y - 22, x + tile - 2, y + tile - 22, stroke(hex(0x8C5A6E), 3));
        if (col == 2) {
          // Glasses on the counter.
          for (var i = 0; i < 2; i++) {
            c.drawCircle(Offset(x + 12 + i * 14, y - 6 + _n(col, r, i) * 10), 3, fill(rgba(200, 230, 255, 0.6)));
          }
        }
        if (col == 1) {
          // Bottles on the shelf behind the bar glow softly.
          for (var i = 0; i < 3; i++) {
            final h = _n(col, r, i + 5) * 360;
            rr(c, x + 4 + i * 6, y - 18 + i * 10, 5, 9, 2, glow(_hue(h, 0.7, 0.55, 0.7)));
          }
        }
        if (front) rect(c, x, y + tile - 22, tile, 22, fill(hex(0x2E1C2A)));
      case 'T':
        c.drawOval(Rect.fromCenter(center: Offset(x + tile / 2 + 4, y + tile / 2 + 6), width: 36, height: 22), fill(rgba(8, 4, 16, 0.4)));
        rect(c, x + tile / 2 - 2, y + tile / 2 - 8, 4, 14, fill(hex(0x3A2D4E)));
        c.drawOval(Rect.fromCenter(center: Offset(x + tile / 2, y + tile / 2 - 10), width: 34, height: 22), fill(hex(0x5A4876)));
        c.drawOval(Rect.fromCenter(center: Offset(x + tile / 2, y + tile / 2 - 10), width: 34, height: 22), stroke(hex(0x7A6690), 1.5));
        // A candle flickers.
        final f = 0.6 + math.sin(real * 13 + col) * 0.2 + math.sin(real * 7 + r) * 0.15;
        c.drawCircle(Offset(x + tile / 2, y + tile / 2 - 13), 2.5, glow(rgba(255, 200, 120, f)));
        rect(c, x, y - 10, tile, tile, shaderPaint(radial(Offset(x + tile / 2, y + tile / 2 - 12), 22, [rgba(255, 180, 100, 0.25 * f), rgba(255, 180, 100, 0)]), add: true));
      case 'P':
        c.drawOval(Rect.fromCenter(center: Offset(x + tile / 2 + 6, y + tile / 2 + 6), width: 30, height: 16), fill(rgba(8, 4, 16, 0.45)));
        rect(c, x + 8, y - 50, tile - 16, tile + 40, shaderPaint(linear(Offset(x + 8, 0), Offset(x + tile - 8, 0), [hex(0x3A2D4E), hex(0x5A4876), hex(0x2A1F3E)])));
        // Neon ring.
        final h = (real * 30 + col * 40) % 360;
        rect(c, x + 6, y - 20, tile - 12, 4, glow(_hue(h, 0.9, 0.6, 0.8)));
      case 'L':
        final top = at(col, r - 1) != 'L';
        rect(c, x, y - 10, tile, tile, fill(hex(0x6A2A48)));
        if (top) rr(c, x, y - 22, tile, 16, 4, fill(hex(0x8C3D5A)));
        if (at(col, r + 1) != 'L') rect(c, x, y + tile - 12, tile, 12, fill(hex(0x4A1E34)));
        if (_n(col, r) > 0.5) rr(c, x + 10, y - 2, 18, 12, 4, fill(hex(0xE0B8D0, 0.8)));
    }
  }

  /// Windows along the back wall. The colony outside is on fire as usual,
  /// and nobody inside seems to mind.
  void drawWindow(Canvas c, int col, double x, double y) {
    final top = y - 14, h = tile - 8;
    final r = Rect.fromLTWH(x + 2, top, tile - 4, h);
    c.save();
    c.clipRect(r);
    rect(c, r.left, r.top, r.width, r.height,
        shaderPaint(linear(Offset(0, top), Offset(0, top + h), [hex(0x2B1446), hex(0x8A3446), hex(0xFF7A3D)], [0, 0.6, 1])));
    for (var i = 0; i < 3; i++) {
      final sx = x + 6 + _n(col, i, 9) * (tile - 12);
      c.drawRect(Rect.fromLTWH(sx, top + 3 + i * 4, 1.5, 1.5), fill(rgba(255, 240, 255, 0.4 + math.sin(real * 2 + i + col) * 0.3)));
    }
    // A meteor streaks past now and then.
    final k = (real * 0.35 + _n(col, 0, 3)) % 1;
    if (k < 0.12) {
      final mx = x + tile - k / 0.12 * (tile + 20), my = top + k / 0.12 * h;
      line(c, mx, my, mx + 10, my - 6, stroke(rgba(255, 220, 160, 0.9), 2, cap: StrokeCap.round));
      c.drawCircle(Offset(mx, my), 2.5, glow(hex(0xFFF3C4)));
    }
    c.restore();
    c.drawRect(r, stroke(hex(0x3A2D4E), 2));
    line(c, r.center.dx, r.top, r.center.dx, r.bottom, stroke(hex(0x3A2D4E), 1.5));
  }

  void drawStageTile(Canvas c, int col, int r, double x, double y) {
    const lift = 18.0;
    final front = at(col, r + 1) != 'S';
    rect(c, x, y - lift, tile, tile, fill(Color.lerp(hex(0x3A2850), hex(0x44305E), _n(col, r))!));
    line(c, x, y - lift, x, y + tile - lift, stroke(hex(0x2E2040), 1));
    if (front) {
      rect(c, x, y + tile - lift, tile, lift, fill(hex(0x22162E)));
      // Footlights along the edge.
      final f = 0.5 + math.sin(real * 3 + col) * 0.3;
      c.drawCircle(Offset(x + tile / 2, y + tile - lift + 2), 3, glow(rgba(255, 220, 160, f)));
    }
    // Stage props after the show: a mic stand, a drum kit, speakers.
    if (r == 1 && col == 19) {
      line(c, x + 20, y + 20 - lift, x + 20, y - 10 - lift, stroke(hex(0xB3A9C9), 2));
      c.drawCircle(Offset(x + 20, y - 12 - lift), 4, fill(hex(0x2A1F3E)));
    }
    if (r == 1 && col == 15) {
      for (final (dx, dy, rad) in const [(8.0, 10.0, 9.0), (26.0, 6.0, 7.0), (32.0, 20.0, 10.0)]) {
        c.drawCircle(Offset(x + dx, y + dy - lift), rad, fill(hex(0xE0D8F0)));
        c.drawCircle(Offset(x + dx, y + dy - lift), rad, stroke(hex(0xE0456A), 2));
      }
    }
    if (r == 1 && (col == 11 || col == 26)) {
      rr(c, x + 6, y - 6 - lift, 28, 34, 3, fill(hex(0x140C22)));
      final pulse = math.sin(real * 8).abs();
      c.drawCircle(Offset(x + 20, y + 14 - lift), 8 + pulse * 2, fill(hex(0x2A1F3E)));
      c.drawCircle(Offset(x + 20, y + 14 - lift), 8 + pulse * 2, stroke(hex(0x6D6288), 1.5));
    }
  }

  // ---------- people ----------
  void drawPerson(Canvas c, Person p) {
    final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
    final moving = speed > 15;
    final ph = p.run;
    final dancer = p is Guest && p.kind == GuestKind.dance;
    final hero = p is Seeker;
    var bob = moving ? -math.sin(ph).abs() * 2 : math.sin(real * 2 + p.x) * 0.5;
    if (dancer) bob = -math.sin(real * 8 + p.x).abs() * 4;
    final x = p.x, y = p.y;
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 20, height: 8), fill(rgba(8, 4, 16, 0.5)));
    final side = p.fx.abs() > p.fy.abs() * 0.9;
    final back = !side && p.fy < 0;
    final dir = p.fx >= 0 ? 1.0 : -1.0;
    c.save();
    c.translate(x, y);
    if (p is Seeker && p.stun > 0) c.rotate(math.sin(real * 30) * 0.12);
    // Legs.
    final legPaint = stroke(hex(0x1A1228), 4.5);
    for (final (o, k) in [(-3.0, 0.0), (3.0, math.pi)]) {
      final swing = moving ? math.sin(ph + k) : 0.0;
      if (side) {
        final ex = o * 0.3 + swing * 6 * dir;
        line(c, o * 0.3, -12, ex, -2, legPaint);
      } else {
        line(c, o, -12, o, -2 - swing * 2.5, legPaint);
      }
    }
    c.translate(0, bob);
    // Body.
    rr(c, -7.5, -30, 15, 19, 5, fill(p.outfit));
    rect(c, -7.5, -16, 15, 2, fill(rgba(0, 0, 0, 0.18)));
    // Arms: dancers wave them up.
    final arm = stroke(p.outfit, 3.5, cap: StrokeCap.round);
    if (dancer) {
      final w = math.sin(real * 8 + p.x);
      line(c, -7, -27, -12, -38 - w * 3, arm);
      line(c, 7, -27, 12, -38 + w * 3, arm);
    } else if (side) {
      final sw = moving ? math.sin(ph + math.pi) : 0.0;
      line(c, 0, -26, sw * 8 * dir, -17, arm);
    } else {
      final sw = moving ? math.sin(ph + math.pi) * 3 : 0.0;
      line(c, -7, -27, -9, -17 + sw, arm);
      line(c, 7, -27, 9, -17 - sw, arm);
    }
    // Head and hair.
    c.drawCircle(const Offset(0, -37), 7.5, fill(p.skin));
    if (back) {
      c.drawCircle(const Offset(0, -38), 7.8, fill(p.hair));
    } else if (side) {
      c.drawArc(Rect.fromCircle(center: const Offset(0, -38), radius: 7.8), dir > 0 ? math.pi * 0.6 : -math.pi * 0.6 - math.pi * 0.2,
          math.pi * 1.2, true, fill(p.hair));
      c.drawCircle(Offset(dir * 3.5, -37), 1.2, fill(hex(0x1A1228)));
    } else {
      c.drawArc(Rect.fromCircle(center: const Offset(0, -38), radius: 7.8), math.pi, math.pi, true, fill(p.hair));
      c.drawCircle(const Offset(-2.6, -36), 1.2, fill(hex(0x1A1228)));
      c.drawCircle(const Offset(2.6, -36), 1.2, fill(hex(0x1A1228)));
    }
    if (hero) {
      // A soft rim light so A and B stand out in the crowd.
      c.drawCircle(const Offset(0, -24), 22, glow(p.outfit.withValues(alpha: 0.12)));
    }
    c.restore();
  }

  /// A faint shimmering line between their eyes.
  void drawEyeContact(Canvas c) {
    final k = (metT / 0.5).clamp(0.0, 1.0) * (1 - ((metT - 1.0) / 0.4).clamp(0.0, 1.0));
    final p0 = Offset(b.x, b.y - 37), p1 = Offset(a.x, a.y - 37);
    for (var i = 0; i <= 10; i++) {
      final q = Offset.lerp(p0, p1, i / 10)!;
      final tw = math.sin(real * 12 + i) * 0.5 + 0.5;
      c.drawCircle(q.translate(0, math.sin(real * 6 + i) * 1.5), 1.5 + tw, glow(rgba(255, 200, 220, k * (0.3 + tw * 0.5))));
    }
  }

  void drawLabel(Canvas c, Seeker s) {
    final y = s.y - 58 + math.sin(real * 3 + (s.label == 'A' ? 1 : 0)) * 2;
    c.drawCircle(Offset(s.x, y - 6), 11, fill(rgba(14, 10, 28, 0.75)));
    c.drawCircle(Offset(s.x, y - 6), 11, stroke(s.outfit, 2));
    drawText(c, s.label, s.x, y, size: 13, family: fontDisplay, color: hex(0xF4EFFC), align: TextAlign.center);
    final tri = Path()
      ..moveTo(s.x - 4, y + 5)
      ..lineTo(s.x + 4, y + 5)
      ..lineTo(s.x, y + 10)
      ..close();
    c.drawPath(tri, fill(s.outfit));
  }

  void drawBubble(Canvas c, Person g) {
    final al = math.min(1.0, g.bubble * 3);
    final w = textWidth(g.say, 11, fontBody, FontWeight.w600) + 12;
    final y = g.y - 62;
    rr(c, g.x - w / 2, y - 12, w, 18, 8, fill(rgba(244, 239, 252, 0.9 * al)));
    final tail = Path()
      ..moveTo(g.x - 3, y + 6)
      ..lineTo(g.x + 3, y + 6)
      ..lineTo(g.x, y + 11)
      ..close();
    c.drawPath(tail, fill(rgba(244, 239, 252, 0.9 * al)));
    drawText(c, g.say, g.x, y + 1, size: 11, color: hex(0x2A1F3E, al), weight: FontWeight.w600, align: TextAlign.center);
  }

  void _heart(Canvas c, double x, double y, double s, Paint p) {
    final path = Path()
      ..moveTo(x, y + s * 0.35)
      ..cubicTo(x - s, y - s * 0.4, x - s * 0.4, y - s, x, y - s * 0.4)
      ..cubicTo(x + s * 0.4, y - s, x + s, y - s * 0.4, x, y + s * 0.35)
      ..close();
    c.drawPath(path, p);
  }

  void drawParticles(Canvas c) {
    for (final pt in parts) {
      final al = (pt.life / pt.max).clamp(0.0, 1.0);
      switch (pt.type) {
        case PPart.spark:
          c.drawCircle(Offset(pt.x, pt.y), pt.size, glow(pt.color.withValues(alpha: al)));
        case PPart.confetti:
          c.save();
          c.translate(pt.x, pt.y);
          c.rotate(pt.spin);
          rect(c, -pt.size / 2, -pt.size / 4, pt.size, pt.size / 2 * (0.4 + math.sin(pt.spin * 2).abs()), fill(pt.color.withValues(alpha: al * 0.8)));
          c.restore();
        case PPart.heart:
          _heart(c, pt.x, pt.y, pt.size, fill(pt.color.withValues(alpha: al)));
        case PPart.note:
          // A small eighth note.
          final p = fill(pt.color.withValues(alpha: al * 0.7));
          c.drawOval(Rect.fromCenter(center: Offset(pt.x, pt.y), width: 7, height: 5), p);
          line(c, pt.x + 3, pt.y, pt.x + 3, pt.y - 11, stroke(pt.color.withValues(alpha: al * 0.7), 1.5));
          line(c, pt.x + 3, pt.y - 11, pt.x + 7, pt.y - 7, stroke(pt.color.withValues(alpha: al * 0.7), 1.5));
        case PPart.puff:
          c.drawCircle(Offset(pt.x, pt.y), pt.size, fill(pt.color.withValues(alpha: al * 0.4)));
      }
    }
  }

  // ---------- HUD and screens ----------
  /// When A is off screen, a heart on the edge points the way.
  void drawFinder(Canvas c) {
    final sx = a.x - cam.dx, sy = a.y - 30 - cam.dy;
    const m = 34.0;
    if (sx > m && sx < stageW - m && sy > m && sy < stageH - m) return;
    final cx = stageW / 2, cy = stageH / 2;
    final dx = sx - cx, dy = sy - cy;
    final k = math.min((cx - m) / math.max(1, dx.abs()), (cy - m) / math.max(1, dy.abs()));
    final ex = cx + dx * k, ey = cy + dy * k;
    final pulse = 1 + math.sin(real * 5) * 0.12;
    c.drawCircle(Offset(ex, ey), 20 * pulse, fill(rgba(14, 10, 28, 0.7)));
    _heart(c, ex, ey + 2, 11 * pulse, fill(hex(0xFF6B8F)));
    drawText(c, 'A', ex, ey + 5, size: 10, family: fontDisplay, color: hex(0xF4EFFC), align: TextAlign.center);
    c.save();
    c.translate(ex, ey);
    c.rotate(math.atan2(dy, dx));
    final arrow = Path()
      ..moveTo(30, 0)
      ..lineTo(22, -6)
      ..lineTo(22, 6)
      ..close();
    c.drawPath(arrow, fill(hex(0xFF6B8F)));
    c.restore();
  }

  void drawHud(Canvas c) {
    final label = hex(0xB3A9C9);
    rr(c, 16, 14, 150, 76, 8, fill(rgba(14, 10, 28, 0.6)));
    drawText(c, 'TIME', 30, 34, size: 11, color: label, weight: FontWeight.w600);
    drawText(c, fmtTime(t), 30, 70, size: 28, family: fontDisplay, color: hex(0xFFB3C6));
    drawText(c, sfx.muted ? 'SOUND OFF (M)' : 'SOUND ON (M)', stageW - 19, 34,
        size: 11, color: rgba(179, 169, 201, 0.8), weight: FontWeight.w600, align: TextAlign.right);
  }

  void drawBanner(Canvas c) {
    final bn = banner;
    if (bn == null) return;
    final al = math.min(1.0, math.min(bn.t * 4, (bn.dur - bn.t) * 3)).clamp(0.0, 1.0);
    final double y = 150 - (1 - math.min(1.0, bn.t * 4)) * 20;
    rect(c, 0, y - 40, stageW, 70, fill(rgba(14, 10, 28, 0.55 * al)));
    drawText(c, bn.title, stageW / 2, y, size: 30, family: fontDisplay, color: hex(0xFFB3C6, al), align: TextAlign.center);
    drawText(c, bn.sub, stageW / 2, y + 22, size: 15, color: hex(0xF4EFFC, al), align: TextAlign.center);
  }

  void drawTitle(Canvas c) {
    rect(c, 0, 0, stageW, stageH,
        shaderPaint(linear(Offset.zero, const Offset(0, stageH), [rgba(14, 10, 28, 0.35), rgba(14, 10, 28, 0.6), rgba(14, 10, 28, 0.88)], [0, 0.5, 1])));
    final wob = reduceMotion ? 0.0 : math.sin(real * 2) * 3;
    const mid = stageW / 2;
    drawText(c, 'A  &  B  ·  THE NIGHT THEY MET', mid, 170, size: 13, color: hex(0xFF9AB0), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, 'AFTER', mid + 4, 254 + wob, size: 76, family: fontDisplay, color: hex(0xE0456A), align: TextAlign.center);
    drawText(c, 'AFTER', mid, 250 + wob, size: 76, family: fontDisplay, color: hex(0xF4EFFC), align: TextAlign.center);
    drawText(c, 'THE SHOW', mid + 4, 330 + wob, size: 76, family: fontDisplay, color: hex(0xE0456A), align: TextAlign.center);
    drawText(c, 'THE SHOW', mid, 326 + wob, size: 76, family: fontDisplay, color: hex(0xFFB3C6), align: TextAlign.center);
    drawText(c, 'The venue is packed. Somewhere in the crowd, A is looking too.', mid, 372, size: 17, align: TextAlign.center);
    if (math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS AN ARROW KEY OR TAP TO START', mid, 430, size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }

  void drawEnd(Canvas c) {
    if (metT < 3.4) return;
    final al = ((metT - 3.4) * 1.5).clamp(0.0, 1.0);
    rect(c, 0, 0, stageW, stageH, fill(rgba(14, 10, 28, 0.6 * al)));
    const mid = stageW / 2;
    drawText(c, 'A  &  B', mid, 180, size: 13, color: hex(0xFF9AB0, al), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, 'THERE YOU ARE.', mid, 250, size: 56, family: fontDisplay, color: hex(0xFFB3C6, al), align: TextAlign.center);
    drawText(c, 'You found each other in ${fmtTime(endTime)}, through a crowd of ${guests.length}.', mid, 300,
        size: 18, color: hex(0xF4EFFC, al), align: TextAlign.center);
    drawText(c, nudges == 0 ? 'You did not nudge a single person. Smooth.' : 'People you nudged on the way: $nudges', mid, 330,
        size: 18, color: hex(0xB3A9C9, al), align: TextAlign.center);
    if (endT > 1.2 && math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS SPACE OR TAP TO PLAY AGAIN  ·  ESC FOR MENU', mid, 400,
          size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }
}

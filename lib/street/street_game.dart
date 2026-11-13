import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../game/audio.dart';
import '../shared/draw.dart';

part 'street_render.dart';

/// Street Escape: a top-down mini game. You are on foot in the burning city
/// and have to find your way to the launch pad. Nothing ends the run: hazards
/// only knock you back.

const double stageW = 960;
const double stageH = 540;

/// Tile size in world units.
const double tile = 40;

/// Building height in the oblique view.
const double bldH = 34;

/// The city. # building, r wreck, x cracked wall (hidden shortcut),
/// v fire vent, ~ lava crack, E launch pad, S start.
const List<String> streetMap = [
  '############################################',
  '#EEEE.....#.........r........#.............#',
  '#EEEE.....#..~~.........v....#....####.....#',
  '#EEEE.........~~.............#....####..r..#',
  '#EEEE.....#.........####.....#.............#',
  '#.........#..r......####...........v.......#',
  '########x#############################.....#',
  '########x#############################.....#',
  '#...........r..........v.........~~........#',
  '#..####.......#####.......####.............#',
  '#..####..v....#####...r...####.....####....#',
  '#.............~~..................r####....#',
  '#....#####################################x#',
  '#....#####################################x#',
  '#.........~~.........v.......r.............#',
  '#..r..........####.......####......####....#',
  '#.....####....####...v...####..~~..####....#',
  '#.....####.........r...............####....#',
  '#.........................v................#',
  '###x###################################....#',
  '###x###################################....#',
  '#.........v......r.........~~..............#',
  '#S.......................r.......v.........#',
  '############################################',
];

final int cols = streetMap[0].length;
final int rows = streetMap.length;
final double worldW = cols * tile;
final double worldH = rows * tile;

enum StreetState { title, play, won }

enum SPart { smoke, spark, flame, chunk, grain }

class SParticle {
  SParticle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.type, {this.z = 0, this.vz = 0, this.g = 0})
      : max = life;
  double x, y, vx, vy, life, size;

  /// Height above the ground, drawn as an upward offset.
  double z, vz, g;
  final double max;
  final Color color;
  final SPart type;
}

class SText {
  SText(this.x, this.y, this.text, this.color);
  double x, y;
  final String text;
  final Color color;
  double life = 1.2;
}

class SBanner {
  SBanner(this.title, this.sub, this.dur);
  final String title, sub;
  final double dur;
  double t = 0;
}

class Walker {
  Walker(this.x, this.y);

  /// Feet position.
  double x, y;
  double vx = 0, vy = 0;

  /// Facing as a unit vector.
  double fx = 0, fy = 1;
  double run = 0, stun = 0, safe = 0, bob = 0;
  bool boarded = false;
  final List<Offset> scarf = List.filled(7, Offset.zero);

  static const double hw = 9, hh = 7;
  Rect get box => Rect.fromLTRB(x - hw, y - hh, x + hw, y + hh);
}

class Rock {
  Rock(this.x, this.y, this.r);
  final double x, y, r;

  /// Height above the ground; falls to 0.
  double z = 520, vz = 0, spin = 0;
  bool dead = false;
}

class Vent {
  Vent(this.cx, this.cy, this.phase);
  final double cx, cy, phase;
  bool on = false, warm = false;
}

class Crack {
  Crack(this.tiles);
  final List<math.Point<int>> tiles;
  bool broken = false;
  double push = 0;
}

class LaunchRocket {
  LaunchRocket(this.x, this.y);
  final double x, y;
  double lift = 0, vz = 0, t = 0;
  bool launching = false;
}

class StreetGame extends FlameGame with KeyboardEvents {
  StreetGame({this.reduceMotion = false, this.onExit});

  final bool reduceMotion;
  final void Function()? onExit;
  final Sfx sfx = Sfx();

  // Input.
  bool up = false, down = false, left = false, right = false;
  bool tUp = false, tDown = false, tLeft = false, tRight = false;

  StreetState state = StreetState.title;
  double t = 0, real = 0, endT = 0, endTime = 0;
  late Walker p;
  late List<List<String>> grid;
  late List<Vent> vents;
  late List<Crack> cracks;
  late LaunchRocket rocket;
  late Rect pad;
  List<Rock> rocks = [];
  List<SParticle> parts = [];
  List<SText> texts = [];
  SBanner? banner;
  Offset cam = Offset.zero;
  double shake = 0, quake = 0, quakeTimer = 5, rockTimer = 2.5, hintTimer = 0;
  int shortcuts = 0;
  double _lastDt = 0;

  @override
  Color backgroundColor() => const Color(0xFF0E0A1C);

  @override
  Future<void> onLoad() async {
    reset();
    state = StreetState.title;
  }

  // ---------- level ----------
  String at(int c, int r) => (c < 0 || r < 0 || c >= cols || r >= rows) ? '#' : grid[r][c];

  bool solidTile(int c, int r) {
    final k = at(c, r);
    return k == '#' || k == 'r' || k == 'x';
  }

  bool solidAt(Rect b) {
    final c0 = (b.left / tile).floor(), c1 = ((b.right - 0.001) / tile).floor();
    final r0 = (b.top / tile).floor(), r1 = ((b.bottom - 0.001) / tile).floor();
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (solidTile(c, r)) return true;
      }
    }
    return false;
  }

  void reset() {
    grid = [for (final row in streetMap) row.split('')];
    vents = [];
    cracks = [];
    var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    double sx = 0, sy = 0;
    final seen = <math.Point<int>>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final k = grid[r][c];
        if (k == 'v') vents.add(Vent(c * tile + tile / 2, r * tile + tile / 2, (c * 0.37 + r * 0.61) % 2.6));
        if (k == 'S') {
          sx = c * tile + tile / 2;
          sy = r * tile + tile / 2;
        }
        if (k == 'E') {
          minX = math.min(minX, c * tile);
          minY = math.min(minY, r * tile);
          maxX = math.max(maxX, c * tile + tile);
          maxY = math.max(maxY, r * tile + tile);
        }
        // Connected cracked tiles break together.
        if (k == 'x' && !seen.contains(math.Point(c, r))) {
          final group = <math.Point<int>>[];
          final stack = [math.Point(c, r)];
          while (stack.isNotEmpty) {
            final q = stack.removeLast();
            if (seen.contains(q) || at(q.x, q.y) != 'x') continue;
            seen.add(q);
            group.add(q);
            stack.addAll([math.Point(q.x + 1, q.y), math.Point(q.x - 1, q.y), math.Point(q.x, q.y + 1), math.Point(q.x, q.y - 1)]);
          }
          cracks.add(Crack(group));
        }
      }
    }
    pad = Rect.fromLTRB(minX, minY, maxX, maxY);
    rocket = LaunchRocket(pad.center.dx, pad.center.dy + 8);
    p = Walker(sx, sy);
    for (var i = 0; i < p.scarf.length; i++) {
      p.scarf[i] = Offset(sx, sy - 20 + i * 2);
    }
    rocks = [];
    parts = [];
    texts = [];
    banner = null;
    t = 0;
    endT = 0;
    shake = 0;
    quake = 0;
    quakeTimer = 5;
    rockTimer = 2.5;
    hintTimer = 0;
    shortcuts = 0;
    cam = Offset((sx - stageW / 2).clamp(0, worldW - stageW), (sy - stageH / 2).clamp(0, worldH - stageH));
  }

  void startGame() {
    reset();
    state = StreetState.play;
    showBanner('THE STREETS ARE BURNING', 'Find your way to the launch pad.', 3);
  }

  // ---------- input ----------
  void onStartPress() {
    sfx.init();
    if (state == StreetState.title) startGame();
    if (state == StreetState.won && endT > 1.2) startGame();
  }

  void onStageTap() {
    if (state != StreetState.play) onStartPress();
  }

  void setTouch({bool? u, bool? d, bool? l, bool? r}) {
    sfx.init();
    if (u != null) tUp = u;
    if (d != null) tDown = d;
    if (l != null) tLeft = l;
    if (r != null) tRight = r;
    if (state == StreetState.title && (u ?? d ?? l ?? r ?? false)) startGame();
  }

  static final _up = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW};
  static final _down = {LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS};
  static final _left = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _right = {LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD};

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    up = keysPressed.any(_up.contains);
    down = keysPressed.any(_down.contains);
    left = keysPressed.any(_left.contains);
    right = keysPressed.any(_right.contains);
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) onStartPress();
      if (state == StreetState.title && (_up.contains(k) || _down.contains(k) || _left.contains(k) || _right.contains(k))) {
        onStartPress();
      }
      if (k == LogicalKeyboardKey.keyR) {
        sfx.init();
        startGame();
      }
      if (k == LogicalKeyboardKey.keyM) {
        sfx.init();
        sfx.toggleMute();
      }
      if (k == LogicalKeyboardKey.escape) onExit?.call();
    }
    return KeyEventResult.handled;
  }

  // ---------- effects ----------
  void addPart(SParticle pt) {
    if (parts.length < 900) parts.add(pt);
  }

  void floatText(double x, double y, String s, Color c) => texts.add(SText(x, y, s, c));
  void showBanner(String title, String sub, double dur) => banner = SBanner(title, sub, dur);
  void addShake(double v) {
    if (!reduceMotion) shake = math.max(shake, v);
  }

  void dust(double x, double y, int n, double spread, [Color color = const Color(0xFF9D8FAE)]) {
    for (var i = 0; i < n; i++) {
      final a = rand(0, math.pi * 2);
      addPart(SParticle(x + rand(-spread, spread), y + rand(-spread, spread) * 0.5, math.cos(a) * rand(20, 70),
          math.sin(a) * rand(10, 40), rand(0.4, 0.9), rand(4, 9), color, SPart.smoke, z: rand(0, 6), vz: rand(10, 40)));
    }
  }

  /// Pushes the player away from a point. Costs nothing but a moment.
  void knock(double fromX, double fromY, String msg) {
    var dx = p.x - fromX, dy = p.y - fromY;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 0.01) {
      dx = -p.fx;
      dy = -p.fy;
    } else {
      dx /= d;
      dy /= d;
    }
    p.vx = dx * 380;
    p.vy = dy * 380;
    p.stun = 0.32;
    p.safe = 1.0;
    floatText(p.x, p.y - 50, msg, const Color(0xFFFF9A6A));
    addShake(7);
    sfx.hit();
  }

  // ---------- movement ----------
  /// Moves along one axis. When a corner blocks the way by a little,
  /// the player slides around it instead of stopping.
  void moveAxis(double dx, double dy, double dt) {
    final nx = p.x + dx, ny = p.y + dy;
    final b = Rect.fromLTRB(nx - Walker.hw, ny - Walker.hh, nx + Walker.hw, ny + Walker.hh);
    if (!solidAt(b)) {
      p.x = nx;
      p.y = ny;
      return;
    }
    _pushCrack(dx, dy, dt);
    // Corner assist: look for a free lane a few pixels to the side.
    for (var o = 1; o <= 14; o++) {
      for (final s in const [-1, 1]) {
        final ox = dx != 0 ? 0.0 : s * o.toDouble(), oy = dx != 0 ? s * o.toDouble() : 0.0;
        if (!solidAt(b.shift(Offset(ox, oy))) && !solidAt(p.box.shift(Offset(ox, oy)))) {
          final step = math.min(o.toDouble(), 160 * dt);
          p.x += ox == 0 ? 0 : s * step;
          p.y += oy == 0 ? 0 : s * step;
          return;
        }
      }
    }
    if (dx != 0) p.vx = 0;
    if (dy != 0) p.vy = 0;
  }

  void _pushCrack(double dx, double dy, double dt) {
    final px = p.x + dx.sign * (Walker.hw + 4), py = p.y + dy.sign * (Walker.hh + 4);
    final c = (px / tile).floor(), r = (py / tile).floor();
    if (at(c, r) != 'x') return;
    for (final cr in cracks) {
      if (cr.broken || !cr.tiles.contains(math.Point(c, r))) continue;
      cr.push += dt;
      if (rng.nextDouble() < dt * 30) {
        addPart(SParticle(c * tile + rand(0, tile), r * tile + tile, rand(-30, 30), rand(-10, 10), 0.6, rand(1.5, 3),
            const Color(0xFFD9C9E6), SPart.grain, z: rand(10, 30), g: -300));
      }
      if (cr.push > 0.25) breakCrack(cr);
    }
  }

  void breakCrack(Crack cr) {
    cr.broken = true;
    shortcuts++;
    for (final q in cr.tiles) {
      grid[q.y][q.x] = '.';
      final cx = q.x * tile + tile / 2, cy = q.y * tile + tile / 2;
      for (var i = 0; i < 22; i++) {
        addPart(SParticle(cx + rand(-18, 18), cy + rand(-18, 18), rand(-160, 160), rand(-120, 120), rand(0.7, 1.3), rand(3, 7),
            const Color(0xFF5B4A6E), SPart.chunk, z: rand(0, 30), vz: rand(80, 260), g: -900));
      }
      dust(cx, cy, 14, 18, const Color(0xFF8A7A96));
    }
    final q = cr.tiles.first;
    floatText(q.x * tile + tile / 2, q.y * tile - 20, 'SHORTCUT!', const Color(0xFF9FE3FF));
    addShake(9);
    sfx.shortcut();
  }

  void updatePlayer(double dt) {
    if (p.boarded) return;
    p.stun = math.max(0, p.stun - dt);
    p.safe = math.max(0, p.safe - dt);
    var ix = 0.0, iy = 0.0;
    if (p.stun <= 0) {
      if (left || tLeft) ix -= 1;
      if (right || tRight) ix += 1;
      if (up || tUp) iy -= 1;
      if (down || tDown) iy += 1;
    }
    final il = math.sqrt(ix * ix + iy * iy);
    const maxV = 235.0;
    if (il > 0) {
      ix /= il;
      iy /= il;
      p.vx += ix * 2400 * dt;
      p.vy += iy * 2400 * dt;
      final v = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      if (v > maxV) {
        p.vx *= maxV / v;
        p.vy *= maxV / v;
      }
      // Turn smoothly toward the input.
      p.fx = lerpD(p.fx, ix, math.min(1, dt * 14));
      p.fy = lerpD(p.fy, iy, math.min(1, dt * 14));
      final fl = math.max(0.001, math.sqrt(p.fx * p.fx + p.fy * p.fy));
      p.fx /= fl;
      p.fy /= fl;
    } else {
      final v = math.sqrt(p.vx * p.vx + p.vy * p.vy);
      final f = (p.stun > 0 ? 500 : 2100) * dt;
      if (v <= f) {
        p.vx = 0;
        p.vy = 0;
      } else {
        p.vx -= p.vx / v * f;
        p.vy -= p.vy / v * f;
      }
    }
    moveAxis(p.vx * dt, 0, dt);
    moveAxis(0, p.vy * dt, dt);
    final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
    p.run += speed * dt * 0.06;
    if (speed > 120 && rng.nextDouble() < dt * 10) {
      addPart(SParticle(p.x - p.fx * 6, p.y + 2, -p.vx * 0.15 + rand(-15, 15), -p.vy * 0.15 + rand(-8, 8), 0.5, rand(3, 6),
          const Color(0xFF8F809F), SPart.smoke, z: 2, vz: 12));
    }
    // Scarf trails behind the neck.
    final ax = p.x - p.fx * 3, ay = p.y - 25;
    p.scarf[0] = Offset(ax, ay);
    for (var i = 1; i < p.scarf.length; i++) {
      final a = p.scarf[i - 1];
      var b = p.scarf[i];
      b = b.translate(-p.vx * 0.01 + math.sin(real * 9 + i) * 0.5, -p.vy * 0.006 + 0.5 + math.cos(real * 7 + i) * 0.4);
      final d = b - a;
      final l = math.max(0.001, d.distance);
      p.scarf[i] = a + d / l * 5;
    }
  }

  // ---------- world ----------
  bool _streetAt(double x, double y) {
    final k = at((x / tile).floor(), (y / tile).floor());
    return k == '.' || k == 'v' || k == 'S';
  }

  void updateWorld(double dt) {
    final play = state == StreetState.play && !p.boarded;
    // Quakes.
    quakeTimer -= dt;
    if (quakeTimer <= 0) {
      quake = 1.4;
      quakeTimer = rand(7, 11);
      addShake(5);
    }
    quake = math.max(0, quake - dt);
    sfx.rumble(quake);
    if (quake > 0 && rng.nextDouble() < dt * 25) {
      addPart(SParticle(cam.dx + rand(0, stageW), cam.dy + rand(0, stageH), rand(-10, 10), rand(-10, 10), 1.2, rand(1.5, 3),
          const Color(0xFFB8A8C8), SPart.grain, z: rand(80, 160), g: -500));
    }

    // Falling rocks land ahead of you, with a growing shadow first.
    if (play) {
      rockTimer -= dt;
      if (rockTimer <= 0) {
        rockTimer = rand(1.4, 2.4);
        final speed = math.sqrt(p.vx * p.vx + p.vy * p.vy);
        final lead = speed > 40 ? rand(90, 240) : rand(0, 140);
        final a = rand(-0.6, 0.6);
        final dx = p.fx * math.cos(a) - p.fy * math.sin(a), dy = p.fx * math.sin(a) + p.fy * math.cos(a);
        final x = p.x + dx * lead, y = p.y + dy * lead;
        if (_streetAt(x, y)) rocks.add(Rock(x, y, rand(10, 16)));
      }
    }
    for (final r in rocks) {
      r.vz += 700 * dt;
      r.z -= r.vz * dt;
      r.spin += dt * 4;
      if (rng.nextDouble() < dt * 40) {
        addPart(SParticle(r.x + rand(-4, 4), r.y, rand(-15, 15), rand(-6, 6), rand(0.3, 0.6), rand(3, 6),
            const Color(0xFFFF8C4A), SPart.flame, z: r.z + r.r, vz: 30));
      }
      if (r.z <= 0) {
        r.dead = true;
        final d = math.sqrt(math.pow(p.x - r.x, 2) + math.pow(p.y - r.y, 2));
        if (play && p.safe <= 0 && d < r.r + 12) {
          knock(r.x, r.y, 'OUCH!');
        } else if (play && d < r.r + 46) {
          floatText(p.x, p.y - 50, 'CLOSE ONE!', const Color(0xFFFFD36B));
          sfx.lucky();
        }
        addShake(3);
        for (var i = 0; i < 14; i++) {
          final a = rand(0, math.pi * 2), s = rand(60, 200);
          addPart(SParticle(r.x, r.y, math.cos(a) * s, math.sin(a) * s * 0.6, rand(0.5, 1), rand(2, 5),
              i.isOdd ? const Color(0xFFFF9B54) : const Color(0xFF4A3B5C), i.isOdd ? SPart.spark : SPart.chunk,
              z: 4, vz: rand(100, 260), g: -900));
        }
        dust(r.x, r.y, 6, 10);
        sfx.debris();
      }
    }
    rocks.removeWhere((r) => r.dead);

    // Fire vents.
    for (final v in vents) {
      final c = (t + v.phase) % 2.6;
      v.on = c > 1.6;
      v.warm = !v.on && c > 1.1;
      if (v.warm && rng.nextDouble() < dt * 20) {
        addPart(SParticle(v.cx + rand(-12, 12), v.cy + rand(-8, 8), rand(-8, 8), rand(-4, 4), 0.5, rand(2, 4),
            const Color(0xFFFFCF7A), SPart.spark, vz: rand(40, 90)));
      }
      if (v.on) {
        for (var i = 0; i < 3; i++) {
          addPart(SParticle(v.cx + rand(-8, 8), v.cy + rand(-6, 6), rand(-20, 20), rand(-10, 10), rand(0.25, 0.45), rand(7, 14),
              const Color(0xFFFF7A3D), SPart.flame, vz: rand(220, 380)));
        }
        if (play && p.stun <= 0 && p.safe <= 0 && (p.x - v.cx).abs() < 24 && (p.y - v.cy).abs() < 22) {
          knock(v.cx, v.cy, 'TOO HOT!');
        }
      }
    }
    // Lava cracks.
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (grid[r][c] != '~') continue;
        if (rng.nextDouble() < dt * 2) {
          addPart(SParticle(c * tile + rand(4, tile - 4), r * tile + rand(4, tile - 4), 0, 0, 0.6, rand(2, 4),
              const Color(0xFFFFCF6A), SPart.spark, vz: rand(40, 90), g: 200));
        }
      }
    }
    if (play && p.stun <= 0 && p.safe <= 0) {
      final c = (p.x / tile).floor(), r = (p.y / tile).floor();
      if (at(c, r) == '~') knock(p.x - p.vx, p.y - p.vy, 'HOT HOT HOT!');
    }
    // Cracked walls hint with dust and a creak when you are near.
    hintTimer -= dt;
    for (final cr in cracks) {
      if (cr.broken) continue;
      final q = cr.tiles.first;
      final cx = q.x * tile + tile / 2, cy = q.y * tile + tile / 2;
      if (rng.nextDouble() < dt * 4) {
        addPart(SParticle(cx + rand(-14, 14), cy + tile / 2, rand(-6, 6), rand(2, 10), rand(1.2, 2), rand(1.2, 2.6),
            const Color(0xFFD9C9E6), SPart.grain, z: bldH, g: -60));
      }
      if (play && hintTimer <= 0 && (p.x - cx).abs() < 220 && (p.y - cy).abs() < 160) {
        sfx.creak();
        hintTimer = 3.5;
      }
      if (cr.push > 0 && rng.nextDouble() < dt) cr.push = math.max(0, cr.push - 0.1);
    }
    // Reaching the pad.
    if (play && pad.contains(Offset(p.x, p.y))) {
      p.boarded = true;
      rocket.launching = true;
      floatText(rocket.x, rocket.y - 140, 'ALL ABOARD!', const Color(0xFF9FE3FF));
      sfx.lucky();
    }
    updateRocket(dt);

    // Particles.
    for (final pt in parts) {
      pt.life -= dt;
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      pt.vz -= pt.g * dt;
      pt.z = math.max(0, pt.z + pt.vz * dt);
      if (pt.type == SPart.smoke) {
        pt.vx *= 1 - dt * 1.5;
        pt.vy *= 1 - dt * 1.5;
        pt.size += dt * 14;
      }
      if (pt.type == SPart.chunk && pt.z <= 0) {
        pt.vx *= 1 - dt * 6;
        pt.vy *= 1 - dt * 6;
        pt.vz = 0;
      }
    }
    parts.removeWhere((pt) => pt.life <= 0);
    for (final tx in texts) {
      tx.life -= dt;
      tx.y -= 30 * dt;
    }
    texts.removeWhere((tx) => tx.life <= 0);
    final bn = banner;
    if (bn != null) {
      bn.t += dt;
      if (bn.t > bn.dur) banner = null;
    }
  }

  void updateRocket(double dt) {
    final r = rocket;
    if (!r.launching) {
      if (rng.nextDouble() < dt * 6) {
        addPart(SParticle(r.x + rand(-40, 40), r.y + rand(-10, 20), rand(-20, 20), rand(-10, 10), rand(1, 1.6), rand(8, 14),
            const Color(0xFFD8D0E4), SPart.smoke, vz: 10));
      }
      return;
    }
    r.t += dt;
    if (r.t < 0.9) {
      for (var i = 0; i < 3; i++) {
        final a = rand(0, math.pi * 2);
        addPart(SParticle(r.x, r.y, math.cos(a) * rand(80, 220), math.sin(a) * rand(40, 120), rand(1, 1.8), rand(12, 22),
            const Color(0xFFE3DBE9), SPart.smoke, vz: 8));
      }
      return;
    }
    if (r.t - dt < 0.9) {
      addShake(12);
      sfx.launch();
    }
    final k = r.t - 0.9;
    r.vz += (k < 1.2 ? 90 : 700) * dt;
    r.lift += r.vz * dt;
    for (var i = 0; i < 4; i++) {
      addPart(SParticle(r.x + rand(-8, 8), r.y + rand(-4, 4), rand(-40, 40), rand(-10, 10), rand(0.2, 0.4), rand(8, 16),
          i.isOdd ? const Color(0xFFFFD36B) : const Color(0xFFFF7A3D), SPart.flame, z: r.lift, vz: -300));
    }
    if (k < 2.5) {
      for (var i = 0; i < 3; i++) {
        final a = rand(0, math.pi * 2), s = rand(150, 320);
        addPart(SParticle(r.x, r.y, math.cos(a) * s, math.sin(a) * s * 0.6, rand(1.2, 2.2), rand(16, 30),
            const Color(0xFFE3DBE9), SPart.smoke, vz: 6));
      }
      addShake(4);
    }
    if (k > 2.4 && state == StreetState.play) {
      state = StreetState.won;
      endT = 0;
      endTime = t;
      sfx.win();
    }
  }

  void updateCamera(double dt) {
    double fx, fy;
    if (state == StreetState.title) {
      fx = (math.sin(real * 0.08 - 1.2) * 0.5 + 0.5) * (worldW - stageW);
      fy = (math.cos(real * 0.06) * 0.5 + 0.5) * (worldH - stageH);
    } else if (rocket.launching) {
      fx = rocket.x - stageW / 2;
      fy = rocket.y - rocket.lift * 0.5 - stageH * 0.6;
    } else {
      fx = p.x + p.vx * 0.35 - stageW / 2;
      fy = p.y + p.vy * 0.35 - stageH / 2;
    }
    final k = math.min(1.0, dt * (state == StreetState.title ? 1 : 5));
    cam = Offset(
      lerpD(cam.dx, fx.clamp(0, worldW - stageW), k),
      lerpD(cam.dy, fy.clamp(rocket.launching ? -2000 : -bldH, worldH - stageH), k),
    );
    shake = math.max(0, shake - dt * 18);
  }

  void step(double dt) {
    real += dt;
    if (state == StreetState.play) {
      t += dt;
      updatePlayer(dt);
    } else {
      endT += dt;
    }
    updateWorld(dt);
    updateCamera(dt);
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = math.min(dt, 0.033);
    _lastDt = dt;
    final steps = dt > 1 / 60 ? 2 : 1;
    for (var i = 0; i < steps; i++) {
      step(dt / steps);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = size.x / stageW;
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, stageW, stageH));
    renderScene(canvas, _lastDt);
    canvas.restore();
  }
}

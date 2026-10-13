import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'audio.dart';

part 'model.dart';
part 'render.dart';

// The game draws into a fixed 960x540 stage that is scaled to fit the widget.
const double stageW = 960;
const double stageH = 540;
const double levelW = 6500;
const double ground = 460;

enum GameState { title, play, won, lost }

final math.Random _rng = math.Random();
double rand(double a, double b) => a + _rng.nextDouble() * (b - a);
double lerpD(double a, double b, double t) => a + (b - a) * t;
double ease(double k) => k < 0.5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;

String fmtTime(double s) {
  s = math.max(0, s);
  if (s < 10) return s.toStringAsFixed(1);
  final m = s ~/ 60, r = (s % 60).floor();
  return '$m:${r.toString().padLeft(2, '0')}';
}

class StarshipGame extends FlameGame with KeyboardEvents {
  StarshipGame({this.reduceMotion = false});

  final bool reduceMotion;
  final Sfx sfx = Sfx();

  // Input.
  bool left = false, right = false, jumpHeld = false;
  double jumpPressedAt = -9;

  // Game state.
  GameState state = GameState.title;
  double t = 0, real = 0, endT = 0;
  late Player p;
  late List<Solid> solids;
  late List<Vent> vents;
  late List<Box> lavas;
  late List<Trigger> triggers;
  late List<Rocket> rockets;
  late List<Bird> birds;
  late WaterTower tower;
  late Girder girder;
  late List<Solid> tunnelWalls;
  late Solid deck;
  List<Debris> debris = [];
  List<Particle> parts = [];
  List<FloatText> texts = [];
  List<BgRocket> bgRockets = [];
  Offset cam = Offset.zero;
  double shake = 0, quake = 0;
  Banner? banner;
  double debrisTimer = 3, quakeTimer = 6, bgRocketTimer = 2, hintTimer = 0;
  int shortcuts = 0;
  double? loseAt;
  int? wonRocket;
  double endTime = 0;
  double _lastDt = 0;

  @override
  Color backgroundColor() => const Color(0xFF1B1331);

  @override
  Future<void> onLoad() async {
    reset();
    state = GameState.title;
  }

  // ---------- level ----------
  Solid _s(double x, double y, double w, double h, Kind kind, {bool oneway = false, bool alive = true}) {
    final s = Solid(x, y, w, h, kind, oneway: oneway, alive: alive);
    solids.add(s);
    return s;
  }

  void buildLevel() {
    solids = [];
    vents = [];
    lavas = [];
    triggers = [];
    birds = [];
    // Segment 1: the outskirts. Rooftops lead up to the first gantry.
    _s(-200, ground, 3800, 260, Kind.ground);
    _s(430, 428, 70, 32, Kind.rubble);
    _s(980, 412, 90, 48, Kind.rubble);
    _s(1250, 380, 130, 80, Kind.building);
    _s(1450, 300, 130, 160, Kind.building);
    deck = _s(1830, 200, 330, 22, Kind.deck, oneway: true);
    _s(2210, 395, 70, 12, Kind.ledge, oneway: true);
    _s(2290, 325, 60, 12, Kind.ledge, oneway: true);
    _s(2200, 262, 60, 12, Kind.ledge, oneway: true);
    tower = WaterTower(1580, 300, _s(1580, 262, 250, 38, Kind.bridge, oneway: true, alive: false));

    // Segment 2: the ridge. Fire vents on top, a sealed tunnel underneath.
    _s(2860, 380, 70, 80, Kind.rock);
    _s(3000, 280, 500, 120, Kind.hill);
    tunnelWalls = [_s(3000, 400, 26, 60, Kind.wall), _s(3474, 400, 26, 60, Kind.wall)];
    vents.addAll([Vent(3070, 280, 32, 2.4, 0), Vent(3220, 280, 32, 2.4, 0.8), Vent(3380, 280, 32, 2.4, 1.6)]);
    _s(3600, 500, 160, 200, Kind.pitfloor);
    lavas.add(Box(3600, 478, 160, 40));
    _s(3630, 446, 40, 60, Kind.stone);
    _s(3700, 440, 40, 66, Kind.stone);
    _s(3760, ground, 740, 260, Kind.ground);
    _s(4060, 440, 190, 20, Kind.pad);
    _s(4300, 360, 80, 12, Kind.ledge, oneway: true);
    _s(4240, 420, 50, 12, Kind.ledge, oneway: true);

    // Segment 3: the chasm and the last launch pad.
    _s(4500, 620, 800, 200, Kind.ground);
    _s(5225, 560, 75, 60, Kind.rock);
    _s(5300, ground, 1300, 260, Kind.ground);
    for (final xy in const [[4590.0, 440.0], [4740.0, 420.0], [4890.0, 440.0], [5040.0, 415.0], [5190.0, 440.0]]) {
      _s(xy[0], xy[1], 80, 14, Kind.slab, oneway: true);
    }
    girder = Girder(_s(4500, 380, 800, 16, Kind.girder, oneway: true, alive: false));
    _s(5500, 430, 60, 30, Kind.rubble);
    _s(5760, 420, 80, 40, Kind.rubble);
    vents.addAll([Vent(5640, ground, 32, 2.8, 0.4), Vent(5880, ground, 32, 2.8, 1.7)]);
    _s(5980, 440, 200, 20, Kind.pad);
    _s(6500, -600, 200, 1400, Kind.cliff);

    // Hidden shortcuts. Each one hints with drifting dust and a flickering light.
    triggers.add(Trigger('water tower', Box(1530, 250, 50, 50), const Offset(1555, 170), const Offset(1470, 272),
        () => tower.falling = true));
    triggers.add(Trigger('tunnel', Box(2935, 400, 65, 60), const Offset(3012, 405), const Offset(2948, 360), _openTunnel));
    triggers.add(Trigger('crane', Box(4300, 310, 80, 50), const Offset(4372, 300), const Offset(4310, 336),
        () => girder.lowering = true));

    rockets = [Rocket(1, 1995, 200, 15), Rocket(2, 4155, 440, 38), Rocket(3, 6080, 440, 62)];

    const birdSpots = [
      [640.0, ground], [668.0, ground], [690.0, ground], [1290.0, 380.0], [1318.0, 380.0], [2560.0, ground],
      [2590.0, ground], [3260.0, 280.0], [4700.0, 620.0], [4730.0, 620.0], [5420.0, ground], [5448.0, ground],
      [5470.0, ground],
    ];
    for (var i = 0; i < birdSpots.length; i++) {
      birds.add(Bird(birdSpots[i][0], birdSpots[i][1], i.toDouble(), rand(0, 3)));
    }
  }

  void _openTunnel() {
    for (final w in tunnelWalls) {
      w.alive = false;
      for (var i = 0; i < 26; i++) {
        addPart(w.x + rand(0, w.w), w.y + rand(0, w.h), rand(-140, 140), rand(-260, -40), rand(0.8, 1.4), rand(3, 7),
            const Color(0xFF5B4A6E), 900, PartType.chunk);
      }
      for (var i = 0; i < 16; i++) {
        addPart(w.x + rand(0, w.w), w.y + rand(0, w.h), rand(-60, 60), rand(-60, 0), rand(1, 2), rand(14, 28),
            const Color(0xFF8A7A96), -10, PartType.smoke);
      }
    }
  }

  void reset() {
    t = 0;
    endT = 0;
    buildLevel();
    p = Player();
    debris = [];
    parts = [];
    texts = [];
    bgRockets = [];
    cam = Offset.zero;
    shake = 0;
    banner = null;
    quake = 0;
    debrisTimer = 3;
    quakeTimer = 6;
    bgRocketTimer = 2;
    hintTimer = 0;
    shortcuts = 0;
    loseAt = null;
    wonRocket = null;
  }

  void startGame() {
    reset();
    state = GameState.play;
    showBanner('THE GROUND IS GOING', 'Get to a launch pad before the rockets leave.', 3);
  }

  // ---------- input ----------
  void onJumpPress() {
    sfx.init();
    switch (state) {
      case GameState.title:
        startGame();
      case GameState.won:
      case GameState.lost:
        if (endT > 1.2) startGame();
      case GameState.play:
        jumpPressedAt = t;
    }
  }

  /// Taps on the stage start or restart the game.
  void onStageTap() {
    if (state != GameState.play) onJumpPress();
  }

  void setTouch({bool? l, bool? r, bool? j}) {
    if (l != null) left = l;
    if (r != null) right = r;
    if (j != null) {
      if (j && !jumpHeld) onJumpPress();
      jumpHeld = j;
    }
  }

  static final _leftKeys = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _rightKeys = {LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD};
  static final _jumpKeys = {
    LogicalKeyboardKey.space, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyZ,
  };

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    left = keysPressed.any(_leftKeys.contains);
    right = keysPressed.any(_rightKeys.contains);
    final jumpNow = keysPressed.any(_jumpKeys.contains);
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (_jumpKeys.contains(k) && !jumpHeld) onJumpPress();
      if (k == LogicalKeyboardKey.enter) onJumpPress();
      if (k == LogicalKeyboardKey.keyR) {
        sfx.init();
        startGame();
      }
      if (k == LogicalKeyboardKey.keyM) {
        sfx.init();
        sfx.toggleMute();
      }
    }
    jumpHeld = jumpNow;
    return KeyEventResult.handled;
  }

  // ---------- particles, text, banner ----------
  void addPart(double x, double y, double vx, double vy, double life, double size, Color color, double g, PartType type) {
    if (parts.length < 900) parts.add(Particle(x, y, vx, vy, life, size, color, g, type));
  }

  void floatText(double x, double y, String txt, Color color) => texts.add(FloatText(x, y, txt, color));
  void showBanner(String title, String sub, double dur) => banner = Banner(title, sub, dur);
  void addShake(double v) {
    if (!reduceMotion) shake = math.max(shake, v);
  }

  void dustPuff(double x, double y, int n, double spread) {
    for (var i = 0; i < n; i++) {
      addPart(x + rand(-spread, spread), y, rand(-70, 70), rand(-60, -10), rand(0.4, 0.8), rand(4, 9),
          const Color(0xFF9D8FAE), -20, PartType.smoke);
    }
  }

  // ---------- collision ----------
  void moveX(Player pl, double dx) {
    pl.x += dx;
    for (final s in solids) {
      if (!s.alive || s.oneway || !pl.overlaps(s)) continue;
      if (dx > 0) {
        pl.x = s.x - pl.w;
      } else if (dx < 0) {
        pl.x = s.x + s.w;
      }
      pl.vx = 0;
    }
  }

  void moveY(Player pl, double dy) {
    final prevBottom = pl.y + pl.h;
    pl.y += dy;
    pl.onGround = false;
    pl.standingOn = null;
    for (final s in solids) {
      if (!s.alive || !pl.overlaps(s)) continue;
      if (s.oneway) {
        if (dy >= 0 && prevBottom <= s.y + 1) {
          pl.y = s.y - pl.h;
          pl.vy = 0;
          pl.onGround = true;
          pl.standingOn = s;
        }
        continue;
      }
      if (dy > 0) {
        pl.y = s.y - pl.h;
        pl.vy = 0;
        pl.onGround = true;
        pl.standingOn = s;
      } else if (dy < 0) {
        pl.y = s.y + s.h;
        pl.vy = 0;
      }
    }
  }

  bool blocked(double x, double y, double w, double h) {
    final r = Box(x, y, w, h);
    return solids.any((s) => s.alive && !s.oneway && r.overlaps(s));
  }

  double surfaceBelow(double x, double fromY) {
    var best = 2000.0;
    for (final s in solids) {
      if (s.alive && x >= s.x && x <= s.x + s.w && s.y >= fromY && s.y < best) best = s.y;
    }
    return best;
  }

  /// Ledge assist: a near-miss jump snaps into a grab and pull-up.
  bool tryLedge(int d) {
    if (d == 0) return false;
    for (final s in solids) {
      if (!s.alive || s.kind == Kind.cliff || (s.kind == Kind.slab && s.falling)) continue;
      final edgeX = d > 0 ? s.x : s.x + s.w;
      final front = d > 0 ? p.x + p.w : p.x;
      final ahead = (edgeX - front) * d;
      if (ahead > 16 || ahead < -12) continue;
      if (s.y < p.y - 18 || s.y > p.y + 22) continue;
      if (p.y + p.h <= s.y + 2) continue;
      final nx = d > 0 ? s.x + 2 : s.x + s.w - p.w - 2;
      final ny = s.y - p.h;
      if (blocked(nx, ny, p.w, p.h - 1)) continue;
      p.climb = Climb(p.x, p.y, nx, ny, d);
      p.vx = 0;
      p.vy = 0;
      p.face = d;
      if (ahead > 3 || s.y < p.y - 4) {
        floatText(nx + 11, ny - 10, 'LUCKY!', const Color(0xFFFFD36B));
        sfx.lucky();
      }
      for (var i = 0; i < 8; i++) {
        addPart(edgeX, s.y, rand(-120, 120), rand(-160, -20), 0.5, rand(2, 3), const Color(0xFFFFE9A8), 300, PartType.spark);
      }
      return true;
    }
    return false;
  }

  void knock(int dir, String msg, [double vy = -340]) {
    p.vx = dir * 320;
    p.vy = vy;
    p.stun = 0.45;
    p.onGround = false;
    p.climb = null;
    floatText(p.x + 11, p.y - 8, msg, const Color(0xFFFF9A6A));
    addShake(7);
    sfx.hit();
  }

  // ---------- updates ----------
  void updatePlayer(double dt) {
    if (p.boarded != null) return;
    final c = p.climb;
    if (c != null) {
      c.t += dt;
      final k = math.min(1.0, c.t / 0.26);
      p.y = lerpD(c.y0, c.y1, ease(math.min(1, k * 1.6)));
      p.x = lerpD(c.x0, c.x1, ease(math.max(0, k * 1.6 - 0.6)));
      if (k >= 1) {
        p.climb = null;
        p.vy = 0;
        p.vx = c.d * 90;
        p.apexY = p.y;
        p.lastGround = t;
      }
      return;
    }
    p.stun = math.max(0, p.stun - dt);
    p.stagger = math.max(0, p.stagger - dt);
    final locked = p.stun > 0 || p.stagger > 0;
    var dir = 0;
    if (!locked) {
      if (left) dir -= 1;
      if (right) dir += 1;
    }
    if (dir != 0) {
      final acc = p.onGround ? 2600 : 1700;
      p.vx = (p.vx + dir * acc * dt).clamp(-255, 255).toDouble();
      p.face = dir;
    } else {
      final f = (p.stun > 0 ? 300 : p.onGround ? 2200 : 500) * dt;
      p.vx = p.vx.abs() <= f ? 0 : p.vx - p.vx.sign * f;
    }
    if (p.onGround) p.lastGround = t;
    // Coyote time and jump buffering.
    if (!locked && t - jumpPressedAt < 0.14 && t - p.lastGround < 0.12) {
      p.vy = -620;
      p.onGround = false;
      p.lastGround = -9;
      jumpPressedAt = -9;
      p.sq = 1.25;
      dustPuff(p.x + p.w / 2, p.y + p.h, 5, 8);
      sfx.jump();
    }
    final g = p.vy < 0 ? (jumpHeld && !locked ? 1350 : 2700) : 1650;
    p.vy = math.min(p.vy + g * dt, 760);
    final wasGround = p.onGround;
    moveX(p, p.vx * dt);
    moveY(p, p.vy * dt);
    if (!p.onGround) p.apexY = math.min(p.apexY, p.y);
    if (p.onGround && !wasGround) {
      final drop = p.y - p.apexY;
      if (drop > 270) {
        // Too high: a stagger instead of damage.
        p.stagger = 0.8;
        p.vx *= 0.2;
        addShake(6);
        floatText(p.x + 11, p.y - 10, 'WHOA!', const Color(0xFFFFB36B));
        dustPuff(p.x + p.w / 2, p.y + p.h, 14, 16);
        sfx.land();
      } else if (drop > 30) {
        p.sq = 0.75;
        dustPuff(p.x + p.w / 2, p.y + p.h, 4, 8);
        if (drop > 90) sfx.land();
      }
    }
    if (p.onGround) p.apexY = p.y;
    if (!p.onGround && p.vy > -240 && p.stun <= 0) {
      tryLedge(dir != 0 ? dir : (p.vx.abs() > 40 ? p.vx.sign.toInt() : 0));
    }
    if (p.x < 0) {
      p.x = 0;
      p.vx = 0;
    }
    if (p.y > 900) {
      p.x = 4520;
      p.y = 560;
      p.vy = 0;
    }
    if (p.onGround && p.vx.abs() > 120 && _rng.nextDouble() < dt * 9) {
      addPart(p.x + p.w / 2 - p.face * 8, p.y + p.h, -p.face * rand(10, 50), rand(-40, -10), 0.5, rand(3, 6),
          const Color(0xFF8F809F), -10, PartType.smoke);
    }
    p.run += p.vx.abs() * dt * 0.055;
    p.sq = lerpD(p.sq, 1, math.min(1, dt * 12));
  }

  void updateScarf() {
    final ax = p.x + p.w / 2 - p.face * 4, ay = p.y + 15;
    final pts = p.scarf;
    pts[0]
      ..x = ax
      ..y = ay;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      b.x += (-p.vx * 0.012 - p.face * 0.6) + math.sin(real * 9 + i) * 0.6;
      b.y += 0.9 + math.cos(real * 7 + i * 1.3) * 0.5;
      final dx = b.x - a.x, dy = b.y - a.y;
      final d = math.max(0.001, math.sqrt(dx * dx + dy * dy));
      b.x = a.x + dx / d * 5;
      b.y = a.y + dy / d * 5;
    }
  }

  double get progress => (t / rockets.last.launchT).clamp(0.0, 1.0);

  void updateWorld(double dt) {
    final prog = progress;
    // Quakes grow as the planet falls apart.
    quakeTimer -= dt;
    if (quakeTimer <= 0) {
      quake = 1.2 + prog * 1.5;
      quakeTimer = rand(7, 11) - prog * 4;
      addShake(4 + prog * 6);
    }
    quake = math.max(0, quake - dt);
    sfx.rumble(quake);
    if (quake > 0 && _rng.nextDouble() < dt * 20) {
      addPart(cam.dx + rand(0, stageW), cam.dy - 10, rand(-20, 20), rand(40, 120), 2, rand(1.5, 3),
          const Color(0xFFB8A8C8), 200, PartType.grain);
    }

    // Falling debris, with a shadow on the ground first.
    if (state == GameState.play && p.boarded == null) {
      debrisTimer -= dt;
      if (debrisTimer <= 0) {
        debrisTimer = rand(1.6, 2.8) * (1 - prog * 0.45);
        final x = p.x + p.face * rand(140, 460) + rand(-40, 40);
        final landY = surfaceBelow(x, p.y - 200);
        if (landY < 1500) debris.add(Debris(x, landY - 620, 160, rand(9, 16), landY, rand(0, 6), rand(-6, 6)));
      }
    }
    for (final d in debris) {
      d.vy += 900 * dt;
      d.y += d.vy * dt;
      d.spin += d.vs * dt;
      if (_rng.nextDouble() < dt * 40) {
        addPart(d.x + rand(-4, 4), d.y - d.r, rand(-20, 20), rand(-40, -10), rand(0.3, 0.6), rand(3, 6),
            const Color(0xFFFF8C4A), -40, PartType.flame);
      }
      if (p.boarded == null &&
          p.stun <= 0 &&
          p.climb == null &&
          (p.x + p.w / 2 - d.x).abs() < p.w / 2 + d.r * 0.8 &&
          d.y + d.r > p.y &&
          d.y - d.r < p.y + p.h) {
        d.dead = true;
        knock(p.x + p.w / 2 < d.x ? -1 : 1, 'OUCH!');
      }
      if (d.y + d.r >= d.landY) d.dead = true;
      if (d.dead) {
        addShake(3);
        for (var i = 0; i < 12; i++) {
          addPart(d.x, d.y, rand(-200, 200), rand(-280, -60), rand(0.5, 1), rand(2, 5),
              i.isOdd ? const Color(0xFFFF9B54) : const Color(0xFF4A3B5C), 900, i.isOdd ? PartType.spark : PartType.chunk);
        }
        dustPuff(d.x, d.landY, 6, 10);
        if ((d.x - p.x).abs() < 500) sfx.debris();
      }
    }
    debris.removeWhere((d) => d.dead);

    // Fire vents.
    for (final v in vents) {
      final c = (t + v.phase) % v.period;
      v.on = c > v.period - 1.0;
      v.warm = !v.on && c > v.period - 1.5;
      if (v.warm && _rng.nextDouble() < dt * 20) {
        addPart(v.x + rand(4, v.w - 4), v.y - 4, rand(-10, 10), rand(-80, -30), 0.5, rand(2, 4), const Color(0xFFFFCF7A), 0,
            PartType.spark);
      }
      if (v.on) {
        for (var i = 0; i < 3; i++) {
          addPart(v.x + v.w / 2 + rand(-8, 8), v.y - 4, rand(-25, 25), rand(-420, -260), rand(0.25, 0.45), rand(7, 14),
              const Color(0xFFFF7A3D), 0, PartType.flame);
        }
        if (p.boarded == null && p.stun <= 0 && p.overlaps(Box(v.x, v.y - 110, v.w, 110))) {
          knock(p.x + p.w / 2 < v.x + v.w / 2 ? -1 : 1, 'TOO HOT!', -380);
        }
      }
    }
    // Lava.
    for (final l in lavas) {
      if (_rng.nextDouble() < dt * 6) {
        addPart(l.x + rand(0, l.w), l.y, 0, rand(-90, -40), 0.6, rand(2, 4), const Color(0xFFFFCF6A), 200, PartType.spark);
      }
      if (p.boarded == null && p.stun <= 0 && p.overlaps(l)) knock(-p.face, 'HOT HOT HOT!', -600);
    }
    // Crumbling slabs.
    for (final s in solids) {
      if (s.kind != Kind.slab) continue;
      if (s.falling) {
        s.vy += 1300 * dt;
        s.y += s.vy * dt;
        s.respawn -= dt;
        if (s.respawn <= 0) {
          s
            ..falling = false
            ..alive = true
            ..y = s.home
            ..vy = 0
            ..crumble = 0
            ..fadeIn = 0.5;
        }
      } else {
        if (p.standingOn == s && p.onGround) {
          s.crumble += dt;
          if (_rng.nextDouble() < dt * 25) {
            addPart(s.x + rand(0, s.w), s.y + s.h, rand(-10, 10), rand(20, 60), 0.6, rand(1.5, 3), const Color(0xFF9A8AA8),
                400, PartType.grain);
          }
        }
        if (s.crumble > 0.5) {
          s
            ..falling = true
            ..alive = false
            ..vy = 0
            ..respawn = 3.5;
          sfx.debris();
        }
      }
      if (s.fadeIn > 0) s.fadeIn = math.max(0, s.fadeIn - dt);
    }
    // Triggers.
    hintTimer -= dt;
    for (final tr in triggers) {
      if (tr.fired) continue;
      if (_rng.nextDouble() < dt * 5) {
        addPart(tr.dust.dx + rand(-10, 10), tr.dust.dy, rand(-8, 8), rand(10, 40), rand(1.2, 2), rand(1.2, 2.6),
            const Color(0xFFD9C9E6), 60, PartType.grain);
      }
      if (_rng.nextDouble() < dt * 1.5) {
        addPart(tr.lamp.dx, tr.lamp.dy, rand(-60, 60), rand(-90, -20), 0.5, rand(1.5, 2.5), const Color(0xFFBFE9FF), 500,
            PartType.spark);
      }
      final near = math.sqrt(math.pow(p.x - tr.zone.x, 2) + math.pow(p.y - tr.zone.y, 2)) < 280;
      if (near && hintTimer <= 0 && state == GameState.play) {
        sfx.creak();
        hintTimer = 3.5;
      }
      if (state == GameState.play && p.boarded == null && p.overlaps(tr.zone)) {
        tr.fired = true;
        shortcuts++;
        tr.act();
        sfx.shortcut();
        addShake(8);
        floatText(tr.zone.x + tr.zone.w / 2, tr.zone.y - 24, 'SHORTCUT!', const Color(0xFF9FE3FF));
      }
    }
    // Water tower topples into a bridge.
    if (tower.falling && tower.ang < math.pi / 2) {
      tower.vel += 3.2 * dt;
      tower.ang = math.min(math.pi / 2, tower.ang + tower.vel * dt * 2.2);
      if (tower.ang >= math.pi / 2) {
        tower.bridge.alive = true;
        addShake(10);
        sfx.boom();
        for (var i = 0; i < 20; i++) {
          addPart(tower.px + rand(0, 250), tower.py - 20, rand(-60, 60), rand(-100, -10), rand(0.8, 1.6), rand(12, 24),
              const Color(0xFF8F7FA3), -20, PartType.smoke);
        }
        for (var i = 0; i < 30; i++) {
          addPart(tower.px + 200, tower.py - 20, rand(-150, 150), rand(-300, -80), rand(0.6, 1.2), rand(2, 4),
              const Color(0xFF9FD8FF), 700, PartType.spark);
        }
      }
    }
    // Crane lowers a girder across the chasm.
    if (girder.lowering && !girder.solid.alive) {
      girder.y = math.min(girder.target, girder.y + 420 * dt);
      if (girder.y >= girder.target) {
        girder.solid.alive = true;
        addShake(9);
        sfx.boom();
        dustPuff(4520, 380, 10, 20);
        dustPuff(5280, 380, 10, 20);
      }
    }
    for (final r in rockets) {
      updateRocket(r, dt);
    }
    // Birds scatter when you get close.
    for (final b in birds) {
      b.flap += dt * (b.flying ? 18 : 2);
      if (!b.flying) {
        b.hop -= dt;
        b.hopUp = math.max(0, b.hopUp - dt);
        if (b.hop < 0) {
          b.hop = rand(1, 3);
          b.hopUp = 0.12;
        }
        if ((p.x - b.x).abs() < 120 && (p.y - b.y).abs() < 120) {
          b.flying = true;
          b.vx = (b.x > p.x ? 1 : -1) * rand(120, 200);
          b.vy = rand(-220, -140);
        }
      } else {
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        b.vy -= 40 * dt;
      }
    }
    // Distant launches from other cities.
    bgRocketTimer -= dt;
    if (bgRocketTimer <= 0) {
      bgRocketTimer = rand(6, 12);
      bgRockets.add(BgRocket(rand(0, stageW * 1.6), 330));
    }
    for (final b in bgRockets) {
      b.vy += 22 * dt;
      b.y -= b.vy * dt;
      b.trail.add(Offset(b.x, b.y));
      if (b.trail.length > 60) b.trail.removeAt(0);
    }
    bgRockets.removeWhere((b) => b.y < -200);
    // Particles.
    for (final pt in parts) {
      pt.life -= dt;
      pt.vy += pt.g * dt;
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      if (pt.type == PartType.smoke) {
        pt.vx *= 1 - dt * 1.5;
        pt.vy *= 1 - dt * 1.5;
        pt.size += dt * 14;
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

  void updateRocket(Rocket r, double dt) {
    final left = r.launchT - t;
    if (r.phase == RocketPhase.wait) {
      if (left < 4 && _rng.nextDouble() < dt * 30) {
        addPart(r.x + rand(-30, 30), r.padY - 6, rand(-120, 120), rand(-40, -5), rand(0.8, 1.4), rand(10, 18),
            const Color(0xFFD8D0E4), -20, PartType.smoke);
      }
      if (state == GameState.play && p.boarded == null && p.overlaps(Box(r.x - 30, r.padY - 80, 60, 80))) {
        p.boarded = r;
        r.withPlayer = true;
        r.launchT = math.min(r.launchT, t + 0.9);
        floatText(r.x, r.padY - 170, 'ALL ABOARD!', const Color(0xFF9FE3FF));
        sfx.lucky();
      }
      if (t >= r.launchT) {
        r.phase = RocketPhase.launch;
        r.t = 0;
        addShake(12);
        sfx.launch();
        if (state == GameState.play && !r.withPlayer) {
          if (r.id == rockets.length) {
            loseAt = t + 2.6;
            showBanner('THE LAST ROCKET IS LEAVING', 'Nothing else is lifting off.', 2.6);
          } else {
            showBanner('ROCKET ${r.id} LEFT WITHOUT YOU', 'Keep running. There may be another pad ahead.', 3);
          }
          if (r.id == 1) deck.collapseAt = t + 1.4;
        }
      }
    } else if (r.phase == RocketPhase.launch) {
      r.t += dt;
      r.vy += (r.t < 1.2 ? 90 : 700) * dt;
      r.y -= r.vy * dt;
      final by = r.padY + r.y;
      for (var i = 0; i < 4; i++) {
        addPart(r.x + rand(-10, 10), by, rand(-60, 60), rand(200, 420), rand(0.2, 0.4), rand(8, 16),
            i.isOdd ? const Color(0xFFFFD36B) : const Color(0xFFFF7A3D), 0, PartType.flame);
      }
      if (r.t < 3) {
        for (var i = 0; i < 3; i++) {
          addPart(r.x + rand(-20, 20), math.min(by + 20, r.padY), rand(-260, 260), rand(-60, 30), rand(1.2, 2.4),
              rand(16, 30), const Color(0xFFE3DBE9), -15, PartType.smoke);
        }
      }
      if (r.t < 2) addShake(5);
      if (r.withPlayer && r.t > 2.4 && state == GameState.play) {
        state = GameState.won;
        endT = 0;
        wonRocket = r.id;
        endTime = t;
        sfx.win();
      }
      if (by < cam.dy - 2500) r.phase = RocketPhase.gone;
    }
  }

  void updateCamera(double dt) {
    var cx = cam.dx, cy = cam.dy;
    if (state == GameState.title) {
      cx = (math.sin(real * 0.06 - 1.4) * 0.5 + 0.5) * (levelW - stageW);
      cy = lerpD(cy, -40, dt * 2);
    } else {
      var fx = p.x + p.w / 2 - stageW * 0.4 + p.face * 60;
      var fy = p.y - stageH * 0.58;
      final b = p.boarded;
      if (b != null && b.phase == RocketPhase.launch) {
        fx = b.x - stageW / 2;
        fy = b.padY + b.y - stageH * 0.55;
      }
      cx = lerpD(cx, fx.clamp(0, levelW - stageW), math.min(1, dt * 5));
      cy = lerpD(cy, fy.clamp(b != null ? -3000 : -240, 200), math.min(1, dt * 4));
    }
    cam = Offset(cx, cy);
    shake = math.max(0, shake - dt * 18);
  }

  void step(double dt) {
    real += dt;
    if (state == GameState.play) {
      t += dt;
      updatePlayer(dt);
      final at = deck.collapseAt;
      if (at != null && t >= at && deck.alive) {
        deck
          ..alive = false
          ..falling = true
          ..vy = 0;
        addShake(10);
        sfx.boom();
        for (var i = 0; i < 30; i++) {
          addPart(deck.x + rand(0, deck.w), deck.y + 10, rand(-120, 120), rand(-200, 0), rand(0.8, 1.5), rand(3, 7),
              const Color(0xFF5D4C72), 900, PartType.chunk);
        }
      }
      final lose = loseAt;
      if (lose != null && t >= lose && p.boarded == null) {
        state = GameState.lost;
        endT = 0;
        endTime = t;
        sfx.lose();
      }
    } else {
      endT += dt;
      if (state != GameState.title) t += dt;
    }
    if (deck.falling) {
      deck.vy += 1200 * dt;
      deck.y += deck.vy * dt;
    }
    updateScarf();
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

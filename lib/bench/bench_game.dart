import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult, VoidCallback;

import '../game/audio.dart';
import '../shared/draw.dart';
import 'bench_sim.dart';

export 'bench_sim.dart' show BenchEnd;

const _display = fontDisplay;
const double stageW = 960;
const double stageH = 540;
const _floor = 422.0;
const _seatY = 372.0;
const _benchX = stageW / 2;

enum BenchState { title, play, outro, done }

/// Called once when a round ends, with the final score and how it ended.
typedef BenchFinish = void Function(int score, BenchEnd end);

final math.Random _rng = math.Random();
double _r(double a, double b) => a + _rng.nextDouble() * (b - a);

Color _lerpC(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0.0, 1.0))!;

/// Colour of the heat meter at [h] on the 0 to 100 scale.
Color heatColor(double h) {
  const cold = Color(0xFF7FD4FF), cozy = Color(0xFFFFB35A), hot = Color(0xFFFF4D6D);
  if (h < BenchSim.cozyLo) return _lerpC(cold, cozy, (h - BenchSim.coldLine) / (BenchSim.cozyLo - BenchSim.coldLine));
  if (h <= BenchSim.cozyHi) return cozy;
  return _lerpC(cozy, hot, (h - BenchSim.cozyHi) / (BenchSim.hotLine - BenchSim.cozyHi));
}

class _Flake {
  _Flake(this.x, this.y, this.r, this.v, this.ph);
  double x, y;
  final double r, v, ph;
}

enum _PK { heart, spark, breath, sweat, steam, smoke, flame }

class _Part {
  _Part(this.kind, this.x, this.y, this.vx, this.vy, this.life, this.size, this.color);
  final _PK kind;
  double x, y, vx, vy, life;
  final double size;
  final Color color;
  late final double maxLife = life;
}

class _Float {
  _Float(this.text, this.x, this.y, this.color, this.size);
  final String text;
  final double x;
  double y, life = 1.1;
  final Color color;
  final double size;
}

class _Star {
  _Star(this.x, this.y, this.r, this.ph);
  final double x, y, r, ph;
}

class BenchGame extends FlameGame with KeyboardEvents {
  BenchGame({this.reduceMotion = false, this.onFinish, this.onExit});

  final bool reduceMotion;
  final BenchFinish? onFinish;
  final VoidCallback? onExit;
  final Sfx sfx = Sfx();

  BenchState state = BenchState.title;
  BenchSim sim = BenchSim();
  double real = 0, outroT = 0, doneT = 0;
  double shownScore = 0, shownHeat = BenchSim.startHeat, lean = 0.3;
  double hugPose = 0, kissPose = 0, callFlash = 0, multPulse = 0, shake = 0;
  double pressHug = 0, pressKiss = 0, pressBoard = 0, kissDenied = 0;
  int _ticks = 0, _lastMult = 1;
  double _drainShown = 0, _drainTimer = 0;
  double shipLift = 0;

  final List<_Part> _parts = [];
  final List<_Float> _floats = [];
  late final List<_Flake> _snow;
  late final List<_Star> _stars;
  late final List<Offset> ridgeFar, ridgeNear;

  static final hugRect = Rect.fromCenter(center: const Offset(290, 492), width: 176, height: 62);
  static final boardRect = Rect.fromCenter(center: const Offset(480, 492), width: 150, height: 62);
  static final kissRect = Rect.fromCenter(center: const Offset(670, 492), width: 176, height: 62);

  @override
  Color backgroundColor() => const Color(0xFF0B0820);

  @override
  Future<void> onLoad() async {
    final r = math.Random(7);
    _snow = List.generate(110, (_) => _Flake(r.nextDouble() * stageW, r.nextDouble() * stageH, 0.6 + r.nextDouble() * 2.2, 20 + r.nextDouble() * 50, r.nextDouble() * 6));
    _stars = List.generate(120, (_) => _Star(r.nextDouble() * stageW, r.nextDouble() * 260, 0.3 + r.nextDouble() * 1.3, r.nextDouble() * 6));
    List<Offset> ridge(int seed, double base, double amp, double step) {
      final rr = math.Random(seed);
      final pts = <Offset>[const Offset(-20, stageH)];
      for (var x = -20.0; x <= stageW + 40; x += step) {
        pts.add(Offset(x, base - rr.nextDouble() * amp - math.sin(x / 140) * amp * 0.4));
      }
      pts.add(const Offset(stageW + 40, stageH));
      return pts;
    }

    ridgeFar = ridge(3, 330, 110, 46);
    ridgeNear = ridge(11, 385, 60, 34);
  }

  // ---------- flow ----------
  void startRound() {
    sim = BenchSim();
    state = BenchState.play;
    outroT = doneT = 0;
    shownScore = 0;
    shownHeat = sim.heat;
    lean = 0.3;
    hugPose = kissPose = callFlash = multPulse = shipLift = 0;
    _ticks = 0;
    _lastMult = 1;
    _drainShown = _drainTimer = 0;
    _parts.clear();
    _floats.clear();
  }

  void _primary() {
    sfx.init();
    switch (state) {
      case BenchState.title:
        startRound();
      case BenchState.done:
        if (doneT > 0.8) startRound();
      case BenchState.play:
        doBoard();
      case BenchState.outro:
        break;
    }
  }

  void doHug() {
    sfx.init();
    if (state != BenchState.play) return _primary();
    sim.hug();
    pressHug = 1;
  }

  void doKiss() {
    sfx.init();
    if (state != BenchState.play) return _primary();
    pressKiss = 1;
    if (!sim.kiss()) kissDenied = 1;
  }

  void doBoard() {
    sfx.init();
    if (state != BenchState.play) return _primary();
    pressBoard = 1;
    sim.board();
  }

  /// Pointer down at [local], in widget pixels.
  void pointerDown(Offset local) {
    if (size.x <= 0) return;
    final p = local / (size.x / stageW);
    if (state == BenchState.play) {
      if (hugRect.inflate(8).contains(p)) return doHug();
      if (kissRect.inflate(8).contains(p)) return doKiss();
      if (boardRect.inflate(8).contains(p)) return doBoard();
      return;
    }
    _primary();
  }

  static final _hugKeys = {LogicalKeyboardKey.keyH, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _kissKeys = {LogicalKeyboardKey.keyK, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD};
  static final _boardKeys = {LogicalKeyboardKey.space, LogicalKeyboardKey.enter, LogicalKeyboardKey.keyB, LogicalKeyboardKey.arrowUp};

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (_hugKeys.contains(k)) doHug();
      if (_kissKeys.contains(k)) doKiss();
      if (_boardKeys.contains(k)) _primary();
      if (k == LogicalKeyboardKey.escape) onExit?.call();
      if (k == LogicalKeyboardKey.keyR) {
        sfx.init();
        startRound();
      }
      if (k == LogicalKeyboardKey.keyM) {
        sfx.init();
        sfx.toggleMute();
      }
    }
    return KeyEventResult.handled;
  }

  // ---------- update ----------
  @override
  void update(double dt) {
    super.update(dt);
    dt = math.min(dt, 0.033);
    step(dt);
  }

  void step(double dt) {
    real += dt;
    if (state == BenchState.play) {
      sim.step(dt);
      _handleEvents();
      if (!sim.running) state = BenchState.outro;
    } else if (state == BenchState.outro) {
      outroT += dt;
      if (_launches && outroT > 1.9) {
        if (shipLift == 0) sfx.launch();
        shipLift += dt;
      }
      if (outroT > 3.2) state = BenchState.done;
    } else if (state == BenchState.done) {
      doneT += dt;
      if (_launches) shipLift += dt;
    }

    final h = state == BenchState.title ? 58 + math.sin(real * 0.8) * 6 : sim.heat;
    shownHeat = lerpD(shownHeat, h, math.min(1, dt * 10));
    shownScore = lerpD(shownScore, sim.score.toDouble(), math.min(1, dt * 8));
    if ((shownScore - sim.score).abs() < 0.5) shownScore = sim.score.toDouble();
    final targetLean = ((shownHeat - BenchSim.coldLine) / (BenchSim.cozyHi - BenchSim.coldLine)).clamp(0.0, 1.0);
    lean = lerpD(lean, targetLean, math.min(1, dt * 4));
    hugPose = math.max(0, hugPose - dt * 1.6);
    kissPose = math.max(0, kissPose - dt * 0.9);
    callFlash = math.max(0, callFlash - dt * 1.5);
    multPulse = math.max(0, multPulse - dt * 3);
    shake = math.max(0, shake - dt * 30);
    pressHug = math.max(0, pressHug - dt * 6);
    pressKiss = math.max(0, pressKiss - dt * 6);
    pressBoard = math.max(0, pressBoard - dt * 6);
    kissDenied = math.max(0, kissDenied - dt * 3);

    if (_drainShown > 0) {
      _drainTimer += dt;
      if (_drainTimer > 0.3) {
        _floats.add(_Float('-${_drainShown.round()}', _benchX + _r(-30, 30), 250, hex(0xFF4D6D), 18));
        _drainShown = 0;
        _drainTimer = 0;
      }
    }

    _ambientParticles(dt);
    _updateSnow(dt);
    for (final p in _parts) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.kind == _PK.sweat) p.vy += 300 * dt;
      if (p.kind == _PK.heart || p.kind == _PK.spark) p.vx *= 1 - dt * 1.5;
      if (p.kind == _PK.smoke) {
        p.vx *= 1 - dt;
        p.vy *= 1 - dt * 0.6;
      }
    }
    _parts.removeWhere((p) => p.life <= 0);
    for (final f in _floats) {
      f.life -= dt;
      f.y -= dt * 40;
    }
    _floats.removeWhere((f) => f.life <= 0);
  }

  bool get _launches => sim.end == BenchEnd.boarded || sim.end == BenchEnd.late;

  void _handleEvents() {
    for (final e in sim.events) {
      switch (e.kind) {
        case BenchEventKind.hug:
          hugPose = 1;
          sfx.land();
          for (var i = 0; i < 6; i++) {
            _add(_PK.spark, _benchX + _r(-40, 40), _seatY - 40 + _r(-20, 10), _r(-40, 40), _r(-70, -20), _r(0.5, 0.9), _r(2, 4), hex(0xFFD36B));
          }
        case BenchEventKind.kiss:
          kissPose = 1;
          sfx.shortcut();
          if (!reduceMotion) shake = 3;
          for (var i = 0; i < 14; i++) {
            final a = _r(-math.pi, 0);
            final s = _r(60, 170);
            _add(_PK.heart, _benchX, _seatY - 96, math.cos(a) * s, math.sin(a) * s, _r(0.9, 1.5), _r(7, 13), i.isEven ? hex(0xFF5C8A) : hex(0xFFB35A));
          }
        case BenchEventKind.points:
          _ticks++;
          final m = sim.multiplier;
          if (m > _lastMult) {
            multPulse = 1;
            sfx.lucky();
            _floats.add(_Float('x$m COZY', _benchX, 200, hex(0x9FE3FF), 20));
          } else if (_ticks % 4 == 0) {
            sfx.lucky();
          }
          _lastMult = m;
          _floats.add(_Float('+${e.amount}', _benchX + _r(-50, 50), 260, hex(0xFFD36B), 18 + m * 2.0));
        case BenchEventKind.drain:
          _drainShown += e.amount;
        case BenchEventKind.boardingCall:
          callFlash = 1;
          sfx.hit();
        case BenchEventKind.end:
          _onEnd();
      }
    }
    if (sim.multiplier < _lastMult) _lastMult = sim.multiplier;
    sim.events.clear();
  }

  void _onEnd() {
    switch (sim.end!) {
      case BenchEnd.boarded:
        sfx.win();
        _floats.add(_Float('+${sim.bonus} ON TIME', _benchX, 230, hex(0x9FE3FF), 24));
        for (var i = 0; i < 26; i++) {
          final a = _r(0, math.pi * 2);
          _add(_PK.spark, _benchX, _seatY - 70, math.cos(a) * _r(80, 220), math.sin(a) * _r(80, 220), _r(0.6, 1.2), _r(2, 5), i.isEven ? hex(0x9FE3FF) : hex(0xFFD36B));
        }
      case BenchEnd.early:
      case BenchEnd.late:
      case BenchEnd.froze:
        sfx.lose();
    }
    onFinish?.call(sim.score, sim.end!);
  }

  void _add(_PK k, double x, double y, double vx, double vy, double life, double size, Color c) {
    if (_parts.length < 500) _parts.add(_Part(k, x, y, vx, vy, life, size, c));
  }

  double _ambient = 0;
  void _ambientParticles(double dt) {
    if (state != BenchState.play && state != BenchState.title) return;
    _ambient += dt;
    if (_ambient < 0.08) return;
    _ambient = 0;
    final h = shownHeat;
    final coldK = ((BenchSim.cozyLo - h) / (BenchSim.cozyLo - BenchSim.coldLine + 10)).clamp(0.0, 1.0);
    final hotK = ((h - BenchSim.cozyHi) / (BenchSim.hotLine - BenchSim.cozyHi)).clamp(0.0, 1.0);
    final heads = _heads();
    // Breath fog when cold.
    if (_rng.nextDouble() < 0.15 + coldK * 0.6) {
      final hd = heads[_rng.nextInt(2)];
      final dir = hd.dx < _benchX ? 1.0 : -1.0;
      _add(_PK.breath, hd.dx + dir * 10, hd.dy + 8, dir * _r(10, 30), _r(-20, -8), _r(0.8, 1.4), _r(4, 8), rgba(220, 235, 255, 0.35 + coldK * 0.3));
    }
    // Sweat and steam when too hot.
    if (hotK > 0.05 && _rng.nextDouble() < hotK * 0.8) {
      final hd = heads[_rng.nextInt(2)];
      _add(_PK.sweat, hd.dx + _r(-14, 14), hd.dy - 6, _r(-20, 20), _r(-80, -40), _r(0.5, 0.8), _r(2.5, 4), hex(0x9FE3FF));
      _add(_PK.steam, hd.dx + _r(-10, 10), hd.dy - 26, _r(-8, 8), _r(-50, -30), _r(0.7, 1.1), _r(6, 10), rgba(255, 255, 255, 0.25));
    }
    // Small hearts drift up while cozy.
    if (h >= BenchSim.cozyLo && h <= BenchSim.cozyHi && _rng.nextDouble() < 0.12) {
      _add(_PK.heart, _benchX + _r(-20, 20), _seatY - 100, _r(-15, 15), _r(-50, -30), _r(1.2, 1.8), _r(4, 7), hex(0xFF8FB0));
    }
  }

  void _updateSnow(double dt) {
    final wind = 30 + sim.gust * 18;
    for (final f in _snow) {
      f.y += f.v * dt;
      f.x += (wind * (f.r / 2.5) + math.sin(real * 1.3 + f.ph) * 12) * dt;
      if (f.y > stageH + 5) {
        f.y = -5;
        f.x = _rng.nextDouble() * stageW;
      }
      if (f.x > stageW + 5) f.x -= stageW + 10;
    }
  }

  // ---------- crew layout ----------
  double get _standK => state == BenchState.outro || state == BenchState.done ? (outroT / 0.5).clamp(0.0, 1.0) : 0;
  bool get _outro => state == BenchState.outro || state == BenchState.done;

  /// 0 to 1: how far along the walk away from the bench they are.
  double get _walkK => _outro && sim.end != BenchEnd.late ? ((outroT - 0.55) / 1.2).clamp(0.0, 1.0) : 0;
  bool get _walking => _walkK > 0 && _walkK < 1;
  bool get _toShips => sim.end == BenchEnd.boarded || sim.end == BenchEnd.early;

  /// Fades each crewmate out as they step into their shuttle.
  double get _crewAlpha => _toShips ? 1 - ((_walkK - 0.85) / 0.15).clamp(0.0, 1.0) : 1;

  static const _shipX = [150.0, 730.0];

  double _crewX(int side) {
    // side: -1 for A on the left, +1 for B on the right.
    final gap = 54 - lean * 16 - hugPose * 4 - kissPose * 2;
    final seated = _benchX + side * (gap * (1 - _standK) + 46 * _standK);
    final k = _walkK;
    if (k <= 0) return seated;
    final goal = _toShips ? _shipX[side < 0 ? 0 : 1] : _benchX + side * 600;
    return lerpD(seated, goal, k < 0.5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2);
  }

  List<Offset> _heads() => [Offset(_crewX(-1), _seatY - 86), Offset(_crewX(1), _seatY - 86)];

  // ---------- render ----------
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = size.x / stageW;
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, stageW, stageH));
    final sx = shake > 0 ? _r(-shake, shake) : 0.0;
    canvas.translate(sx, 0);
    _scene(canvas);
    canvas.restore();
  }

  void _scene(Canvas c) {
    _sky(c);
    _ships(c);
    _pad(c);
    _lamp(c);
    _aura(c);
    _bench(c, back: true);
    _crew(c);
    _bench(c, back: false);
    _particles(c);
    _snowFg(c);
    _tempVignette(c);
    for (final f in _floats) {
      final a = (f.life * 2).clamp(0.0, 1.0);
      drawText(c, f.text, f.x + 2, f.y + 2, size: f.size, family: _display, color: hex(0x1A0F22, a * 0.8), align: TextAlign.center);
      drawText(c, f.text, f.x, f.y, size: f.size, family: _display, color: f.color.withValues(alpha: a), align: TextAlign.center);
    }
    if (state == BenchState.play) _hud(c);
    if (state == BenchState.title) _title(c);
    if (state == BenchState.done) _end(c);
  }

  void _sky(Canvas c) {
    rect(c, 0, 0, stageW, stageH, shaderPaint(linear(Offset.zero, const Offset(0, 420), [hex(0x070616), hex(0x141A3A), hex(0x2B3560)], [0, 0.6, 1])));
    for (final s in _stars) {
      final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(real * 2.2 + s.ph));
      c.drawCircle(Offset(s.x, s.y), s.r, fill(rgba(240, 240, 255, 0.7 * tw)));
    }
    // Ringed gas giant.
    const pc = Offset(170, 120);
    c.drawCircle(pc, 120, fill(rgba(150, 120, 255, 0.06)));
    c.save();
    c.translate(pc.dx, pc.dy);
    c.rotate(-0.35);
    final ringBack = Rect.fromCenter(center: Offset.zero, width: 250, height: 46);
    c.drawArc(ringBack, math.pi, math.pi, false, stroke(rgba(210, 190, 255, 0.35), 7));
    c.restore();
    c.drawCircle(pc, 64, shaderPaint(radial(const Offset(140, 95), 90, [hex(0xC9B8FF), hex(0x6B55C9), hex(0x2A1F5C)], [0, 0.55, 1])));
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: pc, radius: 64)));
    for (var i = 0; i < 5; i++) {
      rect(c, 100, 80 + i * 18.0, 140, 5, fill(rgba(255, 255, 255, 0.05 + (i % 2) * 0.04)));
    }
    c.restore();
    c.save();
    c.translate(pc.dx, pc.dy);
    c.rotate(-0.35);
    c.drawArc(ringBack, 0, math.pi, false, stroke(rgba(225, 210, 255, 0.55), 7));
    c.restore();

    // Aurora.
    final t = reduceMotion ? 0.0 : real;
    for (var b = 0; b < 3; b++) {
      final path = Path();
      for (var x = 0.0; x <= stageW; x += 20) {
        final y = 90.0 + b * 26 + math.sin(x / 130 + t * 0.4 + b) * 22 + math.sin(x / 57 - t * 0.7) * 8;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final col = [hex(0x53FFB0), hex(0x5EC8FF), hex(0xB07CFF)][b];
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 26 - b * 5.0
            ..color = col.withValues(alpha: 0.13 + 0.05 * math.sin(t + b))
            ..blendMode = BlendMode.plus
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    }

    c.drawPath(Path()..addPolygon(ridgeFar, true), fill(hex(0x2A3463)));
    c.drawPath(Path()..addPolygon(ridgeNear, true), fill(hex(0x3B4A80)));
    // Snow caps on the near ridge.
    for (var i = 1; i < ridgeNear.length - 2; i++) {
      final a = ridgeNear[i], b = ridgeNear[i + 1];
      line(c, a.dx, a.dy, b.dx, b.dy, stroke(rgba(220, 235, 255, 0.35), 3, cap: StrokeCap.round));
    }
  }

  void _ships(Canvas c) {
    _ship(c, 150, hex(0xFF7A3D), 0);
    _ship(c, 730, hex(0x4FD1C5), 0.7);
  }

  void _ship(Canvas c, double x, Color accent, double phase) {
    final lift = shipLift <= 0 ? 0.0 : shipLift * shipLift * 160 * (1 + phase * 0.3);
    final base = _floor - 6;
    // Gantry.
    final g = stroke(hex(0x232A4F), 4);
    for (var i = 0; i < 9; i++) {
      final y = base - i * 22.0;
      line(c, x + 46, y, x + 70, y - 22, g);
      line(c, x + 70, y, x + 46, y - 22, g);
    }
    rect(c, x + 44, base - 200, 4, 200, fill(hex(0x232A4F)));
    rect(c, x + 68, base - 200, 4, 200, fill(hex(0x232A4F)));
    c.save();
    c.translate(0, -lift);
    final top = base - 190;
    // Exhaust when launching.
    if (shipLift > 0) {
      final fl = 40 + math.sin(real * 40) * 8 + shipLift * 30;
      c.drawPath(
          Path()
            ..moveTo(x - 14, base)
            ..quadraticBezierTo(x, base + fl * 2, x + 14, base),
          shaderPaint(linear(Offset(x, base), Offset(x, base + fl * 2), [hex(0xFFF3B0), hex(0xFF7A3D), rgba(255, 90, 60, 0)], [0, 0.5, 1]), add: true));
      if (_rng.nextDouble() < 0.7) {
        _add(_PK.smoke, x + _r(-10, 10), base + 20 - lift, _r(-90, 90), _r(10, 50), _r(0.9, 1.6), _r(10, 22), rgba(200, 205, 225, 0.35));
      }
    } else if (math.sin(real * 3 + phase * 5) > 0.6 && _rng.nextDouble() < 0.3) {
      _add(_PK.smoke, x + _r(-16, 16), base - 2, _r(-30, 30), _r(-14, -4), _r(0.8, 1.3), _r(6, 12), rgba(220, 230, 255, 0.22));
    }
    // Body.
    c.drawPath(
        Path()
          ..moveTo(x - 16, base)
          ..lineTo(x - 16, top + 40)
          ..quadraticBezierTo(x - 16, top, x, top - 20)
          ..quadraticBezierTo(x + 16, top, x + 16, top + 40)
          ..lineTo(x + 16, base)
          ..close(),
        shaderPaint(linear(Offset(x - 16, 0), Offset(x + 16, 0), [hex(0x9AA6C9), hex(0xE6ECFF), hex(0x7A86AC)], [0, 0.4, 1])));
    rect(c, x - 16, top + 60, 32, 10, fill(accent));
    rect(c, x - 16, base - 40, 32, 6, fill(accent.withValues(alpha: 0.8)));
    // Fins.
    c.drawPath(Path()..addPolygon([Offset(x - 16, base - 44), Offset(x - 32, base + 2), Offset(x - 16, base)], true), fill(accent));
    c.drawPath(Path()..addPolygon([Offset(x + 16, base - 44), Offset(x + 32, base + 2), Offset(x + 16, base)], true), fill(accent));
    // Window.
    c.drawCircle(Offset(x, top + 26), 7, fill(hex(0x1B2244)));
    c.drawCircle(Offset(x, top + 26), 5, fill(hex(0xFFE7A8, 0.6 + 0.3 * math.sin(real * 2 + phase))));
    // Beacon.
    if (math.sin(real * 4 + phase * 3) > 0.4) {
      c.drawCircle(Offset(x, top - 22), 3, fill(hex(0xFF5C5C)));
      c.drawCircle(Offset(x, top - 22), 12, glow(rgba(255, 80, 80, 0.25)));
    }
    c.restore();
  }

  void _pad(Canvas c) {
    rect(c, 0, _floor, stageW, stageH - _floor, shaderPaint(linear(const Offset(0, _floor), const Offset(0, stageH), [hex(0x2C3254), hex(0x14162C)])));
    rect(c, 0, _floor, stageW, 5, fill(rgba(225, 235, 255, 0.55)));
    // Hazard stripes.
    c.save();
    c.clipRect(const Rect.fromLTWH(0, _floor + 12, stageW, 8));
    for (var x = -20.0; x < stageW + 20; x += 24) {
      c.drawPath(Path()..addPolygon([Offset(x, _floor + 20), Offset(x + 12, _floor + 12), Offset(x + 24, _floor + 12), Offset(x + 12, _floor + 20)], true), fill(hex(0xFFC93C, 0.55)));
    }
    c.restore();
    // Panel seams.
    for (var x = 40.0; x < stageW; x += 120) {
      line(c, x, _floor + 24, x - 40, stageH, stroke(rgba(255, 255, 255, 0.04), 2));
    }
  }

  void _lamp(Canvas c) {
    const lx = 360.0;
    rect(c, lx - 3, 190, 6, _floor - 190, fill(hex(0x1C2140)));
    line(c, lx, 192, lx + 34, 192, stroke(hex(0x1C2140), 5, cap: StrokeCap.round));
    rr(c, lx + 22, 190, 30, 10, 4, fill(hex(0x2A3058)));
    final flick = reduceMotion ? 1.0 : 0.92 + 0.08 * math.sin(real * 17) * math.sin(real * 3.3);
    c.drawPath(
        Path()..addPolygon(const [Offset(lx + 26, 200), Offset(lx + 48, 200), Offset(lx + 170, _floor), Offset(lx - 80, _floor)], true),
        shaderPaint(linear(const Offset(0, 200), const Offset(0, _floor), [rgba(255, 210, 140, 0.22 * flick), rgba(255, 210, 140, 0.04)]), add: true));
    c.drawCircle(const Offset(lx + 37, 202), 10, glow(rgba(255, 220, 160, 0.6 * flick)));
    c.drawOval(Rect.fromCenter(center: const Offset(lx + 45, _floor + 3), width: 260, height: 18), glow(rgba(255, 200, 120, 0.12 * flick)));
  }

  void _aura(Canvas c) {
    final h = shownHeat;
    final k = ((h - BenchSim.coldLine) / (BenchSim.cozyLo - BenchSim.coldLine)).clamp(0.0, 1.0);
    if (k <= 0) return;
    final col = heatColor(h);
    final pulse = reduceMotion ? 0.0 : math.sin(real * 3) * 6;
    final r = 90 + k * 50 + pulse + kissPose * 40;
    c.drawCircle(Offset(_benchX, _seatY - 60), r, shaderPaint(radial(Offset(_benchX, _seatY - 60), r, [col.withValues(alpha: 0.32 * k), col.withValues(alpha: 0)]), add: true));
  }

  void _bench(Canvas c, {required bool back}) {
    const w = 220.0;
    const x0 = _benchX - w / 2;
    final wood = hex(0x7A4A2E), woodHi = hex(0x9C6440), metal = hex(0x1E2342);
    if (back) {
      // Legs and backrest.
      rect(c, x0 + 14, _seatY - 70, 6, 70, fill(metal));
      rect(c, x0 + w - 20, _seatY - 70, 6, 70, fill(metal));
      for (var i = 0; i < 2; i++) {
        final y = _seatY - 66 + i * 22.0;
        rr(c, x0, y, w, 14, 3, fill(wood));
        rect(c, x0 + 2, y + 2, w - 4, 3, fill(woodHi));
      }
      // Snow on the backrest.
      rr(c, x0 - 2, _seatY - 72, w + 4, 7, 4, fill(rgba(235, 242, 255, 0.9)));
    } else {
      rr(c, x0 - 6, _seatY, w + 12, 14, 3, fill(wood));
      rect(c, x0 - 4, _seatY + 2, w + 8, 3, fill(woodHi));
      rect(c, x0 + 8, _seatY + 14, 8, _floor - _seatY - 14, fill(metal));
      rect(c, x0 + w - 16, _seatY + 14, 8, _floor - _seatY - 14, fill(metal));
      if (_standK < 1) {
        // Snow piles on the empty ends of the seat.
        c.drawOval(Rect.fromLTWH(x0 - 6, _seatY - 4, 38, 8), fill(rgba(235, 242, 255, 0.85)));
        c.drawOval(Rect.fromLTWH(x0 + w - 32, _seatY - 4, 38, 8), fill(rgba(235, 242, 255, 0.85)));
      }
    }
  }

  void _crew(Canvas c) {
    final h = shownHeat;
    final coldK = ((BenchSim.cozyLo - h) / (BenchSim.cozyLo - BenchSim.coldLine)).clamp(0.0, 1.0);
    final hotK = ((h - BenchSim.cozyHi) / (BenchSim.hotLine - BenchSim.cozyHi)).clamp(0.0, 1.0);
    final froze = sim.end == BenchEnd.froze;
    final shiver = (reduceMotion ? 0.0 : (coldK > 0.4 || (froze && state != BenchState.play) ? 1.6 : coldK * 1.2)) * math.sin(real * 55);
    final left = _CrewLook(hex(0xFF7A3D), hex(0xC9532A), hex(0xF2C29B), hex(0x3A2418));
    final right = _CrewLook(hex(0x4FD1C5), hex(0x2E8F88), hex(0xC98E66), hex(0x1B1B2E));
    final lx = _crewX(-1), rx = _crewX(1);
    final fade = _crewAlpha;
    if (fade <= 0) return;
    if (fade < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fade));
    _drawCrew(c, lx + shiver, 1, left, coldK, hotK, 'A');
    _drawCrew(c, rx - shiver, -1, right, coldK, hotK, 'B');
    if (fade < 1) c.restore();
    // Hug: the left crewmate's arm wraps around the other's shoulders.
    final hugK = math.max(hugPose, ((lean - 0.75) / 0.25).clamp(0.0, 1.0) * 0.6) * (1 - _standK);
    if (hugK > 0.05) {
      final y = _seatY - 54 - _standK * 30;
      final p = Path()
        ..moveTo(lx + 16, y)
        ..quadraticBezierTo(_benchX, y - 22 * hugK, lerpD(lx + 16, rx + 20, hugK), y - 4 + (1 - hugK) * 20);
      c.drawPath(p, stroke(left.suit, 11, cap: StrokeCap.round));
      c.drawCircle(Offset(lerpD(lx + 16, rx + 20, hugK), y - 4 + (1 - hugK) * 20), 6, fill(left.glove));
    }
  }

  void _drawCrew(Canvas c, double x, int face, _CrewLook look, double coldK, double hotK, String tag) {
    final st = _standK;
    final walking = _walking;
    final bob = walking ? (math.sin(outroT * 14) * 3).abs() : 0.0;
    final hipY = _seatY - st * 34 - bob;
    final torsoTop = hipY - 58;
    // Legs.
    final legPaint = stroke(look.pants, 12, cap: StrokeCap.round);
    for (var i = 0; i < 2; i++) {
      final lxp = x + (i == 0 ? -9 : 9);
      final swing = walking ? math.sin(outroT * 14 + i * math.pi) * 12 : 0.0;
      if (st < 0.5) {
        // Seated: thighs toward the viewer, shins down.
        line(c, lxp, hipY - 4, lxp + (i == 0 ? -2 : 2), _floor - 10, legPaint);
      } else {
        line(c, lxp, hipY - 4, lxp + swing, _floor - 10, legPaint);
      }
      rr(c, lxp - 9 + (st >= 0.5 ? swing : 0), _floor - 14, 18, 10, 4, fill(hex(0x14121F)));
    }
    // Torso (parka).
    rr(c, x - 24, torsoTop, 48, 62, 14, shaderPaint(linear(Offset(x - 24, 0), Offset(x + 24, 0), [look.suit, look.dark])));
    rect(c, x - 1.5, torsoTop + 10, 3, 48, fill(look.dark));
    // Initial on a chest patch.
    final px = x - face * 12;
    c.drawCircle(Offset(px, torsoTop + 30), 9, fill(hex(0xF4EFFC, 0.9)));
    drawText(c, tag, px, torsoTop + 35, size: 12, family: _display, color: look.dark, align: TextAlign.center);
    // Scarf.
    rr(c, x - 18, torsoTop - 2, 36, 10, 5, fill(hex(0xF4EFFC)));
    rr(c, x + face * 6 - 4, torsoTop + 4, 8, 22, 3, fill(hex(0xE3DCF2)));
    // Idle arm on the outside.
    line(c, x - face * 20, torsoTop + 12, x - face * 18, hipY - 8, stroke(look.dark, 10, cap: StrokeCap.round));
    // Fanning hand when too hot.
    if (hotK > 0.3) {
      final fan = math.sin(real * 18) * 6;
      line(c, x + face * 18, torsoTop + 14, x + face * 12, torsoTop - 18 + fan, stroke(look.dark, 9, cap: StrokeCap.round));
      c.drawCircle(Offset(x + face * 12, torsoTop - 20 + fan), 5, fill(look.glove));
    }

    // Head.
    final kissLean = kissPose > 0 ? math.sin(math.min(1, kissPose) * math.pi) : 0.0;
    final hx = x + face * (2 + lean * 3 + kissLean * 7), hy = torsoTop - 22 + kissLean * 2;
    c.drawCircle(Offset(hx, hy), 24, fill(look.dark));
    c.drawCircle(Offset(hx, hy), 21, fill(look.suit));
    // Fur rim.
    c.drawCircle(Offset(hx, hy + 1), 17, stroke(hex(0xF0E6D8), 5));
    final skin = _lerpC(_lerpC(look.skin, hex(0xC8DDF5), coldK * 0.6), hex(0xFF8A8A), hotK * 0.35);
    c.drawCircle(Offset(hx, hy + 1), 15, fill(skin));
    // Cheeks.
    final blush = (0.25 + hotK * 0.6 + kissLean * 0.4) * (1 - coldK);
    c.drawCircle(Offset(hx - 8 + face * 2, hy + 6), 4, fill(rgba(255, 90, 110, blush)));
    c.drawCircle(Offset(hx + 8 + face * 2, hy + 6), 4, fill(rgba(255, 90, 110, blush)));
    // Eyes look at the partner, closed during a kiss.
    final ey = hy - 1;
    final blink = math.sin(real * 1.7 + face) > 0.985;
    if (kissLean > 0.3 || blink) {
      line(c, hx - 7 + face * 3, ey, hx - 3 + face * 3, ey, stroke(hex(0x1A0F22), 2, cap: StrokeCap.round));
      line(c, hx + 3 + face * 3, ey, hx + 7 + face * 3, ey, stroke(hex(0x1A0F22), 2, cap: StrokeCap.round));
    } else {
      c.drawCircle(Offset(hx - 5 + face * 3, ey), 2.2, fill(hex(0x1A0F22)));
      c.drawCircle(Offset(hx + 5 + face * 3, ey), 2.2, fill(hex(0x1A0F22)));
    }
    // Mouth: chattering when cold, smile when cozy, wavy when hot.
    final mx = hx + face * 3, my = hy + 8;
    if (coldK > 0.5 && state == BenchState.play) {
      final o = 1.5 + math.sin(real * 40).abs() * 1.5;
      c.drawOval(Rect.fromCenter(center: Offset(mx, my), width: 6, height: o * 2), fill(hex(0x5A2030)));
    } else if (hotK > 0.5) {
      final p = Path()..moveTo(mx - 5, my);
      for (var i = 1; i <= 4; i++) {
        p.lineTo(mx - 5 + i * 2.5, my + (i.isOdd ? -1.5 : 1.5));
      }
      c.drawPath(p, stroke(hex(0x5A2030), 1.6));
    } else {
      c.drawArc(Rect.fromCenter(center: Offset(mx, my - 2), width: 8, height: 6), 0.2, math.pi - 0.4, false, stroke(hex(0x5A2030), 1.8, cap: StrokeCap.round));
    }
    // Frost on the hood when freezing.
    if (coldK > 0.2) {
      c.drawArc(Rect.fromCircle(center: Offset(hx, hy), radius: 22), math.pi * 1.1, math.pi * 0.8, false, stroke(rgba(220, 240, 255, coldK * 0.8), 4, cap: StrokeCap.round));
    }
  }

  void _heart(Canvas c, double x, double y, double s, Paint p) {
    final path = Path()
      ..moveTo(x, y + s * 0.35)
      ..cubicTo(x - s * 1.1, y - s * 0.4, x - s * 0.5, y - s * 1.1, x, y - s * 0.45)
      ..cubicTo(x + s * 0.5, y - s * 1.1, x + s * 1.1, y - s * 0.4, x, y + s * 0.35);
    c.drawPath(path, p);
  }

  void _particles(Canvas c) {
    for (final p in _parts) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      switch (p.kind) {
        case _PK.heart:
          _heart(c, p.x, p.y, p.size * (0.6 + 0.4 * a), fill(p.color.withValues(alpha: a)));
        case _PK.spark:
          c.drawCircle(Offset(p.x, p.y), p.size * a, glow(p.color.withValues(alpha: a)));
        case _PK.breath:
        case _PK.smoke:
          c.drawCircle(Offset(p.x, p.y), p.size * (2 - a), fill(p.color.withValues(alpha: p.color.a * a)));
        case _PK.sweat:
          c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: p.size, height: p.size * 1.6), fill(p.color.withValues(alpha: a)));
        case _PK.steam:
          final path = Path()..moveTo(p.x, p.y);
          for (var i = 1; i <= 3; i++) {
            path.quadraticBezierTo(p.x + (i.isOdd ? 5 : -5), p.y - i * 4 - 2, p.x, p.y - i * 6);
          }
          c.drawPath(path, stroke(p.color.withValues(alpha: p.color.a * a), 2, cap: StrokeCap.round));
        case _PK.flame:
          c.drawCircle(Offset(p.x, p.y), p.size * a, glow(p.color.withValues(alpha: a)));
      }
    }
  }

  void _snowFg(Canvas c) {
    for (final f in _snow) {
      c.drawCircle(Offset(f.x, f.y), f.r, fill(rgba(235, 242, 255, 0.35 + f.r * 0.18)));
    }
  }

  void _tempVignette(Canvas c) {
    final h = shownHeat;
    final coldK = ((BenchSim.cozyLo - h) / (BenchSim.cozyLo - BenchSim.coldLine + 8)).clamp(0.0, 1.0);
    final hotK = ((h - BenchSim.cozyHi) / (BenchSim.hotLine - BenchSim.cozyHi + 6)).clamp(0.0, 1.0);
    rect(c, 0, 0, stageW, stageH, shaderPaint(radial(const Offset(stageW / 2, stageH / 2), stageH, [const Color(0x00000000), const Color(0x00000000), hex(0x060414, 0.55)], [0, 0.45, 1])));
    if (coldK > 0) {
      rect(c, 0, 0, stageW, stageH,
          shaderPaint(radial(const Offset(stageW / 2, stageH / 2), stageH * 0.85, [rgba(160, 220, 255, 0), rgba(160, 220, 255, 0), rgba(190, 235, 255, 0.45 * coldK)], [0, 0.55, 1])));
    }
    if (hotK > 0) {
      rect(c, 0, 0, stageW, stageH,
          shaderPaint(radial(const Offset(stageW / 2, stageH / 2), stageH * 0.85, [rgba(255, 80, 120, 0), rgba(255, 80, 120, 0), rgba(255, 80, 120, 0.35 * hotK)], [0, 0.55, 1])));
    }
    if (callFlash > 0) rect(c, 0, 0, stageW, stageH, fill(rgba(159, 227, 255, 0.18 * callFlash)));
  }

  // ---------- HUD ----------
  void _hud(Canvas c) {
    final label = hex(0xB3A9C9);
    // Score.
    rr(c, 16, 14, 196, 76, 8, fill(rgba(14, 10, 28, 0.6)));
    drawText(c, 'SCORE', 30, 34, size: 11, color: label, weight: FontWeight.w600);
    final pop = 1 + multPulse * 0.25;
    drawText(c, '${shownScore.round()}', 30, 72, size: 28 * pop, family: _display, color: hex(0xFFD36B));
    final m = sim.multiplier;
    if (m > 1) {
      rr(c, 146, 44, 52, 30, 8, fill(hex(0x9FE3FF, 0.18 + multPulse * 0.3)));
      drawText(c, 'x$m', 172, 66, size: 18, family: _display, color: hex(0x9FE3FF), align: TextAlign.center);
    }

    // Boarding call.
    const mid = stageW / 2;
    if (!sim.boardingOpen) {
      rr(c, mid - 120, 14, 240, 40, 8, fill(rgba(14, 10, 28, 0.6)));
      drawText(c, 'BOARDING CALL IN', mid - 104, 40, size: 12, color: label, weight: FontWeight.w600);
      drawText(c, sim.untilCall.ceil().toString(), mid + 96, 44, size: 22, family: _display, color: hex(0xF4EFFC), align: TextAlign.right);
    } else {
      final on = math.sin(real * 10) > -0.2;
      rr(c, mid - 130, 14, 260, 48, 8, fill(rgba(20, 40, 60, 0.75)));
      drawText(c, 'BOARDING NOW', mid, 44, size: 22, family: _display, color: on ? hex(0x9FE3FF) : hex(0xF4EFFC), align: TextAlign.center);
      final k = sim.callLeft / (BenchSim.boardClose - BenchSim.boardOpen);
      rr(c, mid - 118, 52, 236 * k, 4, 2, fill(hex(0x9FE3FF)));
    }

    _thermo(c);
    _buttons(c);
    drawText(c, sfx.muted ? 'SOUND OFF (M)' : 'SOUND ON (M)', stageW - 18, 30, size: 11, color: rgba(179, 169, 201, 0.8), weight: FontWeight.w600, align: TextAlign.right);
  }

  void _thermo(Canvas c) {
    const x = 884.0, top = 70.0, h = 290.0, w = 26.0;
    double yOf(double v) => top + h * (1 - v / 100);
    rr(c, x - 44, top - 18, 92, h + 92, 12, fill(rgba(14, 10, 28, 0.55)));
    rr(c, x - w / 2, top, w, h, w / 2, fill(hex(0x1A1530)));
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - w / 2, top, w, h), const Radius.circular(w / 2)));
    rect(c, x - w / 2, yOf(100), w, yOf(BenchSim.hotLine) - yOf(100), fill(hex(0xFF4D6D, 0.25)));
    rect(c, x - w / 2, yOf(BenchSim.cozyHi), w, yOf(BenchSim.cozyLo) - yOf(BenchSim.cozyHi), fill(hex(0xFFB35A, 0.28)));
    rect(c, x - w / 2, yOf(BenchSim.coldLine), w, yOf(0) - yOf(BenchSim.coldLine), fill(hex(0x7FD4FF, 0.22)));
    final col = heatColor(shownHeat);
    final fy = yOf(shownHeat);
    rect(c, x - 6, fy, 12, top + h - fy + 10, shaderPaint(linear(Offset(0, fy), Offset(0, top + h), [col, _lerpC(col, hex(0x7FD4FF), 0.4)])));
    c.restore();
    rr(c, x - w / 2, top, w, h, w / 2, stroke(rgba(255, 255, 255, 0.18), 2));
    // Bulb.
    final bulb = Offset(x, top + h + 22);
    c.drawCircle(bulb, 22, fill(hex(0x1A1530)));
    c.drawCircle(bulb, 16, fill(col));
    c.drawCircle(bulb, 30 + math.sin(real * 4) * 3, glow(col.withValues(alpha: 0.25)));
    // Band edges.
    for (final v in [BenchSim.cozyLo, BenchSim.cozyHi]) {
      line(c, x - w / 2 - 6, yOf(v), x + w / 2 + 6, yOf(v), stroke(hex(0xFFD36B, 0.8), 2));
    }
    // Marker.
    final mk = Path()..addPolygon([Offset(x - w / 2 - 4, fy), Offset(x - w / 2 - 14, fy - 7), Offset(x - w / 2 - 14, fy + 7)], true);
    c.drawPath(mk, fill(hex(0xF4EFFC)));
    drawText(c, 'HOT', x, top - 4, size: 10, color: hex(0xFF8FA3), weight: FontWeight.w600, align: TextAlign.center);

    // Warnings.
    if (sim.coldFor > 0) {
      final k = sim.coldFor / BenchSim.leaveAfterCold;
      final on = math.sin(real * 14) > 0;
      drawText(c, 'FREEZING', _benchX, 140, size: 26, family: _display, color: on ? hex(0x9FE3FF) : hex(0xF4EFFC), align: TextAlign.center);
      rr(c, _benchX - 80, 150, 160, 6, 3, fill(rgba(255, 255, 255, 0.15)));
      rr(c, _benchX - 80, 150, 160 * (1 - k), 6, 3, fill(hex(0x9FE3FF)));
    } else if (sim.hot) {
      final on = math.sin(real * 14) > 0;
      drawText(c, 'TOO HOT', _benchX, 140, size: 26, family: _display, color: on ? hex(0xFF4D6D) : hex(0xFFD36B), align: TextAlign.center);
    }
  }

  void _buttons(Canvas c) {
    _button(c, hugRect, 'HUG', 'H', hex(0xFFB35A), 1, pressHug, null);
    final kissK = sim.kissReady ? 1.0 : 1 - sim.kissCd / BenchSim.kissCooldown;
    _button(c, kissRect, 'KISS', 'K', hex(0xFF5C8A), sim.kissReady ? 1 : 0.45, pressKiss, kissK);
    final open = sim.boardingOpen;
    if (open) {
      final pulse = 0.5 + 0.5 * math.sin(real * 8);
      c.drawRRect(RRect.fromRectAndRadius(boardRect.inflate(6 + pulse * 6), const Radius.circular(18)), glow(hex(0x9FE3FF, 0.25 * pulse + 0.1)));
    }
    _button(c, boardRect, 'BOARD', 'SPACE', hex(0x9FE3FF), open ? 1 : 0.4, pressBoard, null);
  }

  void _button(Canvas c, Rect r, String label, String key, Color col, double alpha, double press, double? fillK) {
    final rr2 = r.deflate(press * 3);
    final shake = label == 'KISS' && kissDenied > 0 ? math.sin(real * 60) * 4 * kissDenied : 0.0;
    final box = rr2.shift(Offset(shake, press * 2));
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)), fill(rgba(14, 10, 28, 0.78)));
    if (fillK != null && fillK < 1) {
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)));
      rect(c, box.left, box.top, box.width * fillK, box.height, fill(col.withValues(alpha: 0.18)));
      c.restore();
    }
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)), stroke(col.withValues(alpha: alpha), 2.5));
    if (press > 0) c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)), glow(col.withValues(alpha: 0.25 * press)));
    if (label == 'KISS') _heart(c, box.left + 28, box.center.dy + 2, 9, fill(col.withValues(alpha: alpha)));
    if (label == 'HUG') {
      c.drawArc(Rect.fromCenter(center: Offset(box.left + 28, box.center.dy + 2), width: 22, height: 18), 0.2, math.pi - 0.4, false, stroke(col.withValues(alpha: alpha), 3, cap: StrokeCap.round));
    }
    drawText(c, label, box.center.dx + (label == 'BOARD' ? 0 : 10), box.center.dy + 6, size: 20, family: _display, color: col.withValues(alpha: alpha), align: TextAlign.center);
    drawText(c, key, box.right - 10, box.bottom - 8, size: 9, color: rgba(179, 169, 201, 0.7 * alpha), weight: FontWeight.w600, align: TextAlign.right);
  }

  // ---------- title and end ----------
  void _title(Canvas c) {
    rect(c, 0, 0, stageW, stageH, shaderPaint(linear(Offset.zero, const Offset(0, stageH), [rgba(7, 6, 22, 0.35), rgba(7, 6, 22, 0.7), rgba(7, 6, 22, 0.9)], [0, 0.5, 1])));
    const mid = stageW / 2;
    final wob = reduceMotion ? 0.0 : math.sin(real * 2) * 3;
    drawText(c, 'LAUNCH PAD 7  ·  OUTSIDE  -48°C', mid, 150, size: 13, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, 'KEEP', mid + 4, 224 + wob, size: 68, family: _display, color: hex(0xFF5C8A), align: TextAlign.center);
    drawText(c, 'KEEP', mid, 220 + wob, size: 68, family: _display, color: hex(0xF4EFFC), align: TextAlign.center);
    drawText(c, 'WARM', mid + 4, 294 + wob, size: 68, family: _display, color: hex(0xFF5C8A), align: TextAlign.center);
    drawText(c, 'WARM', mid, 290 + wob, size: 68, family: _display, color: hex(0xFFD36B), align: TextAlign.center);
    drawText(c, 'A and B wait for their shuttles. Keep the heat in the cozy band,', mid, 336, size: 16, align: TextAlign.center);
    drawText(c, 'then board when the call sounds. Not before, not after.', mid, 358, size: 16, align: TextAlign.center);
    drawText(c, 'HUG  small, steady warmth      KISS  big burst, can overshoot', mid, 396, size: 14, color: hex(0xB3A9C9), weight: FontWeight.w600, align: TextAlign.center);
    if (math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS SPACE OR TAP TO START', mid, 450, size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }

  static const _headlines = {
    BenchEnd.boarded: ('ON BOARD', 'A and B boarded warm and right on time.'),
    BenchEnd.early: ('TOO SOON', 'The boarding call had not sounded yet.'),
    BenchEnd.late: ('MISSED IT', 'The shuttles left without A and B.'),
    BenchEnd.froze: ('TOO COLD', 'They gave up and went back inside.'),
  };

  void _end(Canvas c) {
    final a = (doneT * 2).clamp(0.0, 1.0);
    rect(c, 0, 0, stageW, stageH, fill(rgba(7, 6, 22, 0.7 * a)));
    final end = sim.end!;
    final good = end == BenchEnd.boarded;
    final (title, sub) = _headlines[end]!;
    const mid = stageW / 2;
    drawText(c, good ? 'BOARDING COMPLETE' : 'ROUND OVER', mid, 170, size: 13, color: (good ? hex(0x9FE3FF) : hex(0xFF9A6A)).withValues(alpha: a), weight: FontWeight.w600, align: TextAlign.center);
    drawText(c, title, mid, 236, size: 56, family: _display, color: (good ? hex(0xFFD36B) : hex(0xFF5C8A)).withValues(alpha: a), align: TextAlign.center);
    drawText(c, sub, mid, 276, size: 18, color: hex(0xF4EFFC, a), align: TextAlign.center);
    final countUp = (doneT / 1.0).clamp(0.0, 1.0);
    drawText(c, '${(sim.score * countUp).round()}', mid, 350, size: 48, family: _display, color: hex(0xFFD36B, a), align: TextAlign.center);
    drawText(c, good ? 'points, including ${sim.bonus} for boarding on time' : 'points', mid, 376, size: 15, color: hex(0xB3A9C9, a), align: TextAlign.center);
    if (doneT > 0.8 && math.sin(real * 4) > -0.3) {
      drawText(c, 'PRESS SPACE OR TAP TO PLAY AGAIN', mid, 440, size: 16, color: hex(0x9FE3FF), weight: FontWeight.w600, align: TextAlign.center);
    }
  }
}

class _CrewLook {
  const _CrewLook(this.suit, this.dark, this.skin, this.pants);
  final Color suit, dark, skin, pants;
  Color get glove => dark;
}

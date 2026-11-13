import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../game/audio.dart';
import '../../shared/draw.dart';

part 'stage_render.dart';
part 'stage_script.dart';

/// Stage Fright: a timing mini game. A (Alessandra) and B (Bogdan) are artists
/// aboard the escape ship. In Act I, B performs while A watches from the front
/// row; in Act II it's the other way around; in Act III they share the stage.
/// Under the stage a timing bar runs: a square slides left and right like a
/// ping pong ball. Press as it crosses the target line and the line lands.
/// Miss, and someone goes off script. Nothing ends the show early.

const double _sw = 960;
const double _sh = 540;

/// Feet height on the stage floor for depth 0 (front) and 1 (back).
const double _floorFront = 428;
const double _floorBack = 384;

/// Timing windows in seconds, either side of the cue.
const double winPerfect = 0.07;
const double winGood = 0.14;
const double winOk = 0.21;

/// Taps earlier than this before a cue are ignored, so mashing is not punished
/// and a stray tap long before the square arrives does nothing.
const double winIgnore = 0.38;

enum StagePhase { title, intro, play, outro, results }

enum Judge { perfect, good, ok, miss }

enum Pose { stand, sit, kneel }

class StageGame extends FlameGame with KeyboardEvents {
  StageGame({this.reduceMotion = false, this.onExit, bool? aSingsFirst}) {
    // Who performs solo first is a coin flip: sometimes A watches oblivious B,
    // sometimes B watches A.
    final aFirst = aSingsFirst ?? rng.nextBool();
    playbill = aFirst ? [acts[1], acts[0], acts[2]] : [acts[0], acts[1], acts[2]];
  }

  /// Acts in the order they play tonight.
  late final List<ActDef> playbill;

  final bool reduceMotion;
  final VoidCallback? onExit;
  final Sfx sfx = Sfx();

  StagePhase phase = StagePhase.title;

  /// Which act is on, an index into [playbill]. The duet is always last.
  int act = 0;
  ActDef get def => playbill[act];
  List<Line> get script => def.lines;
  bool get isSolo => def.solo != null;

  /// The one on stage in a solo act.
  Actor? get performer => def.solo == null ? null : def.solo == Solo.a ? actA : actB;

  /// The one watching from the front row in a solo act.
  Actor? get watcher => def.solo == null ? null : def.solo == Solo.a ? actB : actA;
  double watcherJoy = 0, watcherFluster = 0;

  /// Target line position (0..1 along the bar) for each cue.
  late List<double> targets;

  /// Bar feedback: flash strength, its judgment and where it happened.
  double barFlash = 0, barFlashX = 0, barBump = 0;
  Judge barJudge = Judge.good;
  bool _barDir = true;

  /// Seconds since the curtain started rising.
  double t = 0;

  /// Wall clock, always running, for idle animation.
  double real = 0;
  double phaseT = 0;
  double curtain = 0; // 0 closed, 1 open

  late Actor actA, actB;
  late List<double> cues;
  late List<Judge?> results;
  int next = 0;
  int score = 0, combo = 0, bestCombo = 0;
  final List<String> bloopers = [];
  final List<Particle> parts = [];
  final List<Rose> roses = [];
  final List<Popup> popups = [];
  final List<Fan> fans = [];
  double shake = 0, flash = 0, rumble = 0, rumbleTimer = 6;
  double hintT = 0;
  int _beat = -1;
  double _lastDt = 0;

  // Render-side state.
  double starScroll = 0;
  double moodR = 0, moodG = 0, moodB = 0, moodA = 0;
  final List<int> _offA = [], _offB = [];

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF120A1E);

  @override
  Future<void> onLoad() async => reset();

  void reset() {
    actA = Actor('A', tall: true, x: 330);
    actB = Actor('B', tall: false, x: 630);
    // Each cue is the moment the square crosses that cue's target line.
    // The next line is placed so there is always a breath between cues.
    cues = [];
    targets = [];
    final tr = math.Random(17 + acts.indexOf(def));
    var at = 3.0;
    for (var i = 0; i < script.length; i++) {
      final x = 0.18 + tr.nextDouble() * 0.64;
      var tt = at + 1.9;
      var prev = barPos(tt);
      while (true) {
        tt += 0.002;
        final cur = barPos(tt);
        if ((prev - x) * (cur - x) <= 0) break;
        prev = cur;
      }
      cues.add(tt);
      targets.add(x);
      at = tt;
    }
    results = List.filled(script.length, null);
    next = 0;
    score = combo = bestCombo = 0;
    bloopers.clear();
    parts.clear();
    roses.clear();
    popups.clear();
    _offA
      ..clear()
      ..addAll(List.generate(def.offA.length, (i) => i)..shuffle(rng));
    _offB
      ..clear()
      ..addAll(List.generate(def.offB.length, (i) => i)..shuffle(rng));
    _beat = -1;
    watcherJoy = watcherFluster = barFlash = barBump = 0;
    t = 0;
    phaseT = 0;
    hintT = 0;
    curtain = 0;
    shake = flash = rumble = 0;
    rumbleTimer = 7;
    if (fans.isEmpty) _makeFans();
    _applyBeat(0);
    actA.x = actA.tx;
    actB.x = actB.tx;
  }

  void _makeFans() {
    final r = math.Random(5);
    for (var row = 0; row < 2; row++) {
      final n = row == 0 ? 13 : 11;
      for (var i = 0; i < n; i++) {
        final x = (i + 0.5) / n * _sw + (row == 0 ? 0 : 20) + r.nextDouble() * 16 - 8;
        fans.add(Fan(x, row == 0 ? 500 : 538, row, r.nextDouble() * 6, r.nextInt(5), 0.85 + r.nextDouble() * 0.3));
      }
    }
  }

  /// How well the act went, 0..1, from the judgments alone.
  double get accuracy {
    if (results.isEmpty) return 0;
    var s = 0.0;
    for (final r in results) {
      s += r == Judge.perfect ? 1 : r == Judge.good ? 0.75 : r == Judge.ok ? 0.45 : 0;
    }
    return s / results.length;
  }

  int get maxScore {
    var s = 0;
    for (var i = 0; i < script.length; i++) {
      s += (100 * _mult(i)).round();
    }
    return s;
  }

  static double _mult(int combo) => 1 + math.min(combo, 10) * 0.1;

  // ---------- input ----------
  /// A tap or click. [pos] is in widget pixels, used to pick an act.
  void onStageTap([ui.Offset? pos]) {
    sfx.init();
    switch (phase) {
      case StagePhase.title:
        if (pos != null && size.x > 0) {
          final p = pos / (size.x / _sw);
          final picked = actCardAt(p);
          if (picked != null && picked != act) {
            selectAct(picked);
            return;
          }
          if (picked == null) return;
        }
        _raiseCurtain();
      case StagePhase.play:
        _tap();
      case StagePhase.results:
        if (phaseT > 1.2) {
          selectAct((act + 1) % acts.length);
          _raiseCurtain();
        }
      default:
    }
  }

  void selectAct(int i) {
    act = i;
    phase = StagePhase.title;
    phaseT = 0;
    reset();
  }

  /// Act cards on the title curtain, in stage units.
  static ui.Rect actCard(int i) => ui.Rect.fromLTWH(_sw / 2 - 330 + i * 225, 290, 210, 112);

  int? actCardAt(ui.Offset p) {
    for (var i = 0; i < acts.length; i++) {
      if (actCard(i).inflate(6).contains(p)) return i;
    }
    if (p.dy > 410 && p.dy < 470) return act;
    return null;
  }

  void _raiseCurtain() {
    phase = StagePhase.intro;
    phaseT = 0;
    t = 0;
    sfx.creak();
    sfx.rumble(0);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
        onStageTap();
      }
      if (phase == StagePhase.title && (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA)) {
        selectAct((act + acts.length - 1) % acts.length);
      }
      if (phase == StagePhase.title && (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD)) {
        selectAct((act + 1) % acts.length);
      }
      for (final (i, key) in [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3].indexed) {
        if (k == key && (phase == StagePhase.title || phase == StagePhase.results)) selectAct(i);
      }
      if (k == LogicalKeyboardKey.keyR) {
        sfx.init();
        reset();
        _raiseCurtain();
      }
      if (k == LogicalKeyboardKey.keyM) {
        sfx.init();
        sfx.toggleMute();
      }
      if (k == LogicalKeyboardKey.escape) onExit?.call();
    }
    return KeyEventResult.handled;
  }

  /// Who speaks on cue [i]. In the duet B speaks first and they alternate;
  /// in a solo every cue is the performer's.
  Actor target(int i) => performer ?? (i.isEven ? actB : actA);
  Actor source(int i) => performer ?? (i.isEven ? actA : actB);

  void _tap() {
    if (next >= cues.length) return;
    final d = t - cues[next];
    if (d < -winIgnore) return;
    final ad = d.abs();
    if (ad <= winPerfect) {
      _judge(Judge.perfect, d);
    } else if (ad <= winGood) {
      _judge(Judge.good, d);
    } else if (ad <= winOk) {
      _judge(Judge.ok, d);
    } else {
      _judge(Judge.miss, d);
    }
  }

  void _judge(Judge j, double d) {
    final i = next;
    results[i] = j;
    next++;
    barFlash = 1;
    barJudge = j;
    barFlashX = targets[i];
    final who = target(i), other = identical(who, actA) ? actB : actA;
    final hand = who.hand;
    if (j == Judge.miss) {
      combo = 0;
      who.bonk = 1;
      other.blush = 1.4;
      final pool = identical(who, actA) ? _offA : _offB;
      final lines = identical(who, actA) ? def.offA : def.offB;
      if (pool.isEmpty) pool.addAll(List.generate(lines.length, (k) => k)..shuffle(rng));
      final line = lines[pool.removeLast()];
      who.say(line, off: true);
      bloopers.add('${who.name}: "$line"');
      popups.add(Popup(hand.dx, hand.dy - 30, d < 0 ? 'TOO EARLY' : 'MISSED', hex(0xFF6B6B)));
      for (var k = 0; k < 7; k++) {
        _part(hand.dx, hand.dy, rand(-160, 160), rand(-220, -40), 0.7, rand(3, 5), hex(0xFFD166), 500, PartKind.star);
      }
      _crowd(laugh: true);
      if (isSolo) _watcherReact(false);
      shake = reduceMotion ? 0 : 5;
      sfx.hit();
    } else {
      combo++;
      bestCombo = math.max(bestCombo, combo);
      final base = j == Judge.perfect ? 100 : j == Judge.good ? 70 : 40;
      final pts = (base * _mult(combo - 1)).round();
      score += pts;
      who.swing = 1;
      who.say(script[i].text, sing: def.solo == Solo.a);
      who.glow = j == Judge.perfect ? 1 : 0.6;
      final label = j == Judge.perfect ? 'PERFECT' : j == Judge.good ? 'GOOD' : 'CLOSE';
      final col = j == Judge.perfect ? hex(0xFFD166) : j == Judge.good ? hex(0x7CF29A) : hex(0x9FE3FF);
      popups.add(Popup(hand.dx, hand.dy - 30, '$label +$pts', col));
      final n = j == Judge.perfect ? 26 : 14;
      for (var k = 0; k < n; k++) {
        final a = rand(0, math.pi * 2), s = rand(80, j == Judge.perfect ? 320 : 200);
        _part(hand.dx, hand.dy, math.cos(a) * s, math.sin(a) * s, rand(0.3, 0.7), rand(2, 4), col, 0, PartKind.spark);
      }
      if (j == Judge.perfect) {
        flash = 0.5;
        _throwRoses(1 + (combo >= 5 ? 1 : 0));
        sfx.lucky();
      } else {
        sfx.land();
      }
      if (combo > 0 && combo % 5 == 0) {
        _confetti(40);
        popups.add(Popup(_sw / 2, 150, '$combo IN A ROW!', hex(0xFF8FB8), big: true));
        sfx.shortcut();
      }
      _crowd(laugh: false, strong: j == Judge.perfect);
      if (isSolo && j != Judge.ok) _watcherReact(true);
    }
    if (i == script.length - 1 && !isSolo) {
      // The last line launches the ship: the stage shakes and the play ends.
      rumble = 2.5;
      _confetti(70);
      sfx.launch();
    }
  }

  /// The front row watcher: hearts when the show is good, flustered on a slip.
  void _watcherReact(bool good) {
    final w = watcher;
    if (w == null) return;
    const wx = watchSeatX, wy = watchSeatY - 70;
    if (good) {
      watcherJoy = 1;
      for (var k = 0; k < 2 + math.min(combo, 6) ~/ 2; k++) {
        _part(wx + rand(-14, 14), wy, rand(-30, 30), rand(-90, -50), rand(1.0, 1.6), rand(5, 8), hex(0xFF5A8A), -10, PartKind.heart);
      }
    } else {
      watcherFluster = 1;
      popups.add(Popup(wx, wy - 6, identical(w, actA) ? 'oh no!' : 'whoa!', hex(0xFFB3D1), small: true));
    }
  }

  void _crowd({required bool laugh, bool strong = false}) {
    for (final f in fans) {
      if (laugh) {
        if (rng.nextDouble() < 0.5) f.laugh = rand(0.6, 1.2);
      } else if (rng.nextDouble() < (strong ? 0.6 : 0.3)) {
        f.cheer = rand(0.5, 0.9);
      }
    }
    final picks = laugh ? const ['HA!', 'hah', 'ooh', '?!', 'heh', 'LOL'] : const ['bravo!', 'ooh', 'aww', 'yes!', 'wow'];
    for (var k = 0; k < (strong || laugh ? 3 : 1); k++) {
      final side = fans.where((f) => f.x < 190 || f.x > 770).toList();
      final f = side[rng.nextInt(side.length)];
      popups.add(Popup(f.x, f.y - 46, picks[rng.nextInt(picks.length)], laugh ? hex(0xFFE08A) : hex(0xFFB3D1), small: true));
    }
  }

  void _throwRoses(int n) {
    for (var k = 0; k < n; k++) {
      final f = fans[rng.nextInt(fans.length)];
      final tx = rand(190, 770), ty = rand(_floorBack + 14, _floorFront + 10);
      roses.add(Rose(f.x, f.y - 30, tx, ty, rand(0, math.pi * 2)));
    }
    if (roses.length > 70) roses.removeRange(0, roses.length - 70);
  }

  void _confetti(int n) {
    const cols = [0xFFD166, 0xFF6B9A, 0x9FE3FF, 0x7CF29A, 0xC59BFF, 0xFFFFFF];
    for (var k = 0; k < n; k++) {
      _part(rand(120, 840), rand(30, 70), rand(-60, 60), rand(-40, 60), rand(2.2, 3.5), rand(3, 6), hex(cols[k % cols.length]), 90,
          PartKind.confetti);
    }
  }

  void _part(double x, double y, double vx, double vy, double life, double size, ui.Color c, double g, PartKind k) {
    if (parts.length < 700) parts.add(Particle(x, y, vx, vy, life, size, c, g, k));
  }

  // ---------- choreography ----------
  void _applyBeat(int cue) {
    Beat? b;
    for (final x in def.beats) {
      if (x.from <= cue) b = x;
    }
    if (b == null) return;
    actA
      ..tx = b.ax
      ..tz = b.az
      ..pose = b.ap;
    actB
      ..tx = b.bx
      ..tz = b.bz
      ..pose = b.bp;
  }

  /// Lighting mood for the current part of the scene.
  int get mood {
    final f = next / script.length;
    if (f >= 0.75) return 3; // finale
    if (f >= 0.625) return 2; // night
    if (f >= 0.5) return 1; // sunset
    return 0;
  }

  // ---------- simulation ----------
  void step(double dt) {
    real += dt;
    phaseT += dt;
    switch (phase) {
      case StagePhase.title:
        curtain = math.max(0, curtain - dt);
      case StagePhase.intro:
        t += dt;
        curtain = math.min(1, curtain + dt / 2.2);
        if (curtain >= 1) {
          phase = StagePhase.play;
          phaseT = 0;
        }
      case StagePhase.play:
        t += dt;
        hintT += dt;
        if (next < cues.length && t > cues[next] + winOk) _judge(Judge.miss, t - cues[next]);
        final dir = barPos(t + 0.001) > barPos(t);
        if (dir != _barDir) {
          _barDir = dir;
          if (next < cues.length) {
            sfx.creak();
            barBump = 1;
            for (final f in fans) {
              f.bob = 1;
            }
          }
        }
        if (_beat != next) {
          _beat = next;
          _applyBeat(next);
        }
        if (next >= cues.length && t > cues.last + 2.4) {
          phase = StagePhase.outro;
          phaseT = 0;
          (performer ?? actA).bowing = true;
          (performer ?? actB).bowing = true;
          if (isSolo) _watcherReact(true);
          _throwRoses(results.where((r) => r == Judge.perfect).length ~/ 2 + 3);
          _crowd(laugh: false, strong: true);
          sfx.win();
        }
      case StagePhase.outro:
        t += dt;
        if (phaseT > 2.6) curtain = math.max(0, curtain - dt / 1.6);
        if (curtain <= 0) {
          phase = StagePhase.results;
          phaseT = 0;
        }
      case StagePhase.results:
        t += dt;
    }

    // Ship rumble: the escape ship shudders now and then, more near the end.
    rumbleTimer -= dt;
    if (rumbleTimer <= 0 && phase == StagePhase.play) {
      rumbleTimer = rand(8, 13);
      rumble = 1;
      for (var k = 0; k < 10; k++) {
        _part(rand(160, 800), 60, rand(-10, 10), rand(10, 40), rand(1.5, 2.5), rand(1, 2), hex(0xE8D8C8, 0.7), 60, PartKind.dust);
      }
    }
    rumble = math.max(0, rumble - dt * 0.8);
    sfx.rumble(rumble * 0.5);
    shake = math.max(0, shake - dt * 20);
    barFlash = math.max(0, barFlash - dt * 2);
    barBump = math.max(0, barBump - dt * 5);
    watcherJoy = math.max(0, watcherJoy - dt * 1.2);
    watcherFluster = math.max(0, watcherFluster - dt * 0.7);
    flash = math.max(0, flash - dt * 1.8);

    for (final a in [actA, actB]) {
      final other = identical(a, actA) ? actB : actA;
      final lookAt = isSolo ? watchSeatX + (a.x < watchSeatX ? 200 : -200) : other.x;
      a.update(dt, lookAt, ready: _readyFor(a));
    }
    for (final p in parts) {
      p.vy += p.g * dt;
      if (p.kind == PartKind.confetti) {
        p.vx += math.sin(real * 3 + p.size * 7) * 30 * dt;
        p.vx *= 1 - dt * 1.5;
        p.vy = math.min(p.vy, 80);
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
    }
    parts.removeWhere((p) => p.life <= 0 || p.y > _sh + 20);
    for (final r in roses) {
      if (r.k < 1) {
        r.k = math.min(1, r.k + dt / 0.9);
        r.spin += dt * 9;
      }
    }
    for (final p in popups) {
      p.life -= dt;
      p.y -= dt * (p.big ? 18 : 34);
    }
    popups.removeWhere((p) => p.life <= 0);
    for (final f in fans) {
      f.cheer = math.max(0, f.cheer - dt);
      f.laugh = math.max(0, f.laugh - dt);
      f.bob = math.max(0, f.bob - dt * 4);
    }
  }

  /// How close this actor's next line is, 0 far to 1 now. They draw a breath.
  double _readyFor(Actor a) {
    if (phase != StagePhase.play || next >= cues.length || !identical(target(next), a)) return 0;
    return (1 - (cues[next] - t) / 0.7).clamp(0.0, 1.0) * 0.5;
  }

  /// Seconds for the square to cross the bar once, at time [time]. It speeds
  /// up a little as the act goes on.
  double get barHalf => isSolo ? 1.45 : 1.3;

  /// Square position along the bar, 0..1, bouncing between the ends.
  double barPos(double time) {
    final ph = time / barHalf * (1 + time * 0.006);
    final f = ph % 2;
    return f < 1 ? f : 2 - f;
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = math.min(dt, 0.033);
    _lastDt = dt;
    step(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    final scale = size.x / _sw;
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(const ui.Rect.fromLTWH(0, 0, _sw, _sh));
    renderStage(canvas, _lastDt);
    canvas.restore();
  }
}

// ---------- model ----------
class Actor {
  Actor(this.name, {required this.tall, required this.x}) : tx = x;

  final String name;
  final bool tall;
  double x, tx;
  double z = 0, tz = 0;
  Pose pose = Pose.stand;
  double sit = 0, kneel = 0, bow = 0;
  bool bowing = false;
  double face = 1, faceS = 1;
  double walk = 0, moving = 0;
  double blinkT = 2, blink = 0;
  double talk = 0, swing = 0, bonk = 0, blush = 0, glow = 0, ready = 0;
  double lookTarget = 0;
  double capeVel = 0;
  Bubble? bubble;

  double get scale => 1 - z * 0.14;
  double get feetY => lerpD(_floorFront, _floorBack, z);

  /// Height of the hips above the feet, which drives where the hand sits.
  double get hipH => (tall ? 50.0 : 34.0) * (1 - sit * 0.45 - kneel * 0.48);

  /// Just in front of the chest, where hit effects burst from.
  ui.Offset get hand {
    final s = scale;
    final torso = tall ? 56.0 : 40.0;
    return ui.Offset(x + face * (tall ? 30 : 26) * s, feetY - (hipH + torso * 0.62) * s);
  }

  void say(String text, {bool off = false, bool sing = false}) {
    bubble = Bubble(text, off, sing: sing);
    talk = off ? 1.1 : math.min(2.2, 0.5 + text.length * 0.045);
  }

  void update(double dt, double other, {required double ready}) {
    this.ready = lerpD(this.ready, ready, math.min(1, dt * 12));
    lookTarget = other;
    final dx = tx - x;
    final sp = 150.0 * dt;
    final wasX = x;
    x += dx.abs() < sp ? dx : dx.sign * sp;
    final dz = tz - z;
    z += dz.abs() < dt * 1.1 ? dz : dz.sign * dt * 1.1;
    final v = (x - wasX) / math.max(dt, 1e-4);
    moving = lerpD(moving, (v.abs() > 5 || dz.abs() > 0.01) ? 1 : 0, math.min(1, dt * 8));
    walk += dt * 9 * moving;
    face = v.abs() > 5 ? v.sign : (other - x).sign == 0 ? face : (other - x).sign;
    faceS += (face - faceS) * math.min(1, dt * 10);
    capeVel = lerpD(capeVel, v, math.min(1, dt * 4));
    final arrived = (tx - x).abs() < 2 && (tz - z).abs() < 0.02;
    final want = arrived ? pose : Pose.stand;
    sit = _toward(sit, want == Pose.sit ? 1 : 0, dt * 2.6);
    kneel = _toward(kneel, want == Pose.kneel ? 1 : 0, dt * 2.6);
    bow = _toward(bow, bowing ? 1 : 0, dt * 1.5);
    blinkT -= dt;
    if (blinkT <= 0) {
      blinkT = rand(2, 4.5);
      blink = 1;
    }
    blink = math.max(0, blink - dt * 8);
    talk = math.max(0, talk - dt);
    swing = math.max(0, swing - dt * 3.2);
    bonk = math.max(0, bonk - dt * 0.9);
    blush = math.max(0, blush - dt * 0.6);
    glow = math.max(0, glow - dt * 1.4);
    final b = bubble;
    if (b != null) {
      b.age += dt;
      if (b.age > b.life) bubble = null;
    }
  }

  static double _toward(double v, double to, double s) => v < to ? math.min(to, v + s) : math.max(to, v - s);
}

class Bubble {
  Bubble(this.text, this.off, {this.sing = false}) : life = off ? 2.4 : math.max(2.2, 0.9 + text.length * 0.06);
  final String text;
  final bool off;

  /// A sung line: music notes float around it.
  final bool sing;
  final double life;
  double age = 0;
}

class Beat {
  const Beat(this.from, this.ax, this.az, this.ap, this.bx, this.bz, this.bp);
  final int from;
  final double ax, az, bx, bz;
  final Pose ap, bp;
}

enum PartKind { spark, star, confetti, dust, heart }

/// The front row seat of whoever is watching a solo act.
const double watchSeatX = 820;
const double watchSeatY = 500;

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.g, this.kind) : max = life;
  double x, y, vx, vy, life;
  final double max, size, g;
  final ui.Color color;
  final PartKind kind;
}

class Rose {
  Rose(this.x0, this.y0, this.x1, this.y1, this.rot);
  final double x0, y0, x1, y1, rot;
  double k = 0, spin = 0;
  ui.Offset get pos {
    final e = k;
    return ui.Offset(lerpD(x0, x1, e), lerpD(y0, y1, e) - 170 * 4 * e * (1 - e));
  }
}

class Popup {
  Popup(this.x, this.y, this.text, this.color, {this.big = false, this.small = false}) : life = big ? 1.6 : 1.1;
  double x, y, life;
  final String text;
  final ui.Color color;
  final bool big, small;
}

class Fan {
  Fan(this.x, this.y, this.row, this.phase, this.look, this.size);
  final double x, y, phase, size;
  final int row, look;
  double cheer = 0, laugh = 0, bob = 0;
}

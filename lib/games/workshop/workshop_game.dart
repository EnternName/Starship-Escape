import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../../game/audio.dart';
import '../../shared/draw.dart';

part 'workshop_render.dart';
part 'workshop_script.dart';

/// Workshop: a rhythm mini game in the ship's movement studio. Arrow prompts
/// glide along a light ribbon toward a ring; press the matching direction as
/// one reaches the ring and your performer does the move with the group.
///
/// Session I happens before the Halloween party: you are A, and B dances in
/// the same class, oblivious. Session II comes later, before the duet: A and B
/// are partners, prompts belong to A, to B, or to both together.
/// Nothing ends a session early.

const double _sw = 960;
const double _sh = 540;

/// Timing windows in seconds, either side of a prompt.
const double winPerfect = 0.06;
const double winGood = 0.12;
const double winOk = 0.18;

/// Presses earlier than this before the next prompt are ignored.
const double winIgnore = 0.3;

/// Seconds a prompt takes from the right edge of the ribbon to the ring.
const double leadTime = 2.1;

enum WsPhase { title, intro, play, outro, results }

enum Judge { perfect, good, ok, miss }

/// The four moves. The order matches the chime samples.
enum Move { left, up, down, right }

enum Owner { a, b, both }

class WorkshopGame extends FlameGame with KeyboardEvents {
  WorkshopGame({this.reduceMotion = false, this.onExit});

  final bool reduceMotion;
  final VoidCallback? onExit;
  final Sfx sfx = Sfx(ambient: false);

  WsPhase phase = WsPhase.title;

  /// Which session is picked, an index into [sessions].
  int session = 0;
  SessionDef get def => sessions[session];
  bool get together => def.together;

  /// Song time in seconds. Beat 0 is the first count of the count-in.
  double t = 0;
  double real = 0, phaseT = 0;

  /// Studio lights, 0 dim to 1 full.
  double lights = 0;

  late List<Note> notes;
  int next = 0;
  int score = 0, combo = 0, bestCombo = 0;

  /// Session I: how many times B looked over at A.
  int glances = 0;

  late Dancer a, b;
  final List<Dancer> crew = [];
  List<Dancer> get everyone => [...crew, a, b];

  final List<Particle> parts = [];
  final List<Popup> popups = [];
  String? coachLine;
  double coachT = 0;
  double ringFlash = 0, ringBump = 0, flash = 0, shake = 0;
  Judge ringJudge = Judge.good;
  Move ringMove = Move.up;
  int _beat = -1, _crewNext = 0;
  double _lastDt = 0;

  double get spb => 60 / def.bpm;
  double get beat => t / spb;

  @override
  ui.Color backgroundColor() => const ui.Color(0xFF120A1E);

  @override
  Future<void> onLoad() async => reset();

  void reset() {
    notes = buildChart(def);
    next = 0;
    score = combo = bestCombo = glances = 0;
    parts.clear();
    popups.clear();
    coachLine = null;
    t = 0;
    phaseT = 0;
    _beat = -1;
    _crewNext = 0;
    ringFlash = ringBump = flash = shake = 0;
    _makeCast();
  }

  void _makeCast() {
    // Back row: the rest of the class. Front row: A and B.
    crew
      ..clear()
      ..addAll([
        Dancer(Look.juggler, 205, 372, 0.8, 0.0),
        Dancer(Look.alien, 395, 366, 0.78, 0.9),
        Dancer(Look.mime, 575, 366, 0.78, 1.7),
        Dancer(Look.acrobat, 760, 372, 0.8, 2.6),
      ]);
    a = Dancer(Look.a, together ? 400 : 330, 468, 1, 0.4);
    b = Dancer(Look.b, together ? 560 : 650, 470, 1, 1.3);
  }

  void selectSession(int i) {
    session = i.clamp(0, sessions.length - 1);
    phase = WsPhase.title;
    phaseT = 0;
    reset();
  }

  /// Session cards on the title screen, in stage units.
  static ui.Rect sessionCard(int i) => ui.Rect.fromLTWH(_sw / 2 - 250 + i * 260, 250, 240, 132);

  int? sessionCardAt(ui.Offset p) {
    for (var i = 0; i < sessions.length; i++) {
      if (sessionCard(i).inflate(6).contains(p)) return i;
    }
    if (p.dy > 392 && p.dy < 450) return session;
    return null;
  }

  void _start() {
    reset();
    phase = WsPhase.intro;
    phaseT = 0;
  }

  /// How well the session went, 0..1.
  double get accuracy {
    if (notes.isEmpty) return 0;
    var s = 0.0;
    for (final n in notes) {
      s += n.judge == Judge.perfect ? 1 : n.judge == Judge.good ? 0.75 : n.judge == Judge.ok ? 0.45 : 0;
    }
    return s / notes.length;
  }

  int get maxScore {
    var s = 0;
    for (var i = 0; i < notes.length; i++) {
      s += (100 * _mult(i)).round();
    }
    return s;
  }

  static double _mult(int combo) => 1 + math.min(combo, 20) * 0.05;

  // ---------- input ----------
  void onStageTap([ui.Offset? pos]) {
    sfx.init();
    switch (phase) {
      case WsPhase.title:
        if (pos != null && size.x > 0) {
          final p = pos / (size.x / _sw);
          final picked = sessionCardAt(p);
          if (picked == null) return;
          if (picked != session) {
            selectSession(picked);
            return;
          }
        }
        _start();
      case WsPhase.play:
        // Touch: the stage is split into four zones, one per move.
        if (pos != null && size.x > 0) {
          final p = pos / (size.x / _sw);
          press(p.dx < _sw * 0.25 ? Move.left : p.dx > _sw * 0.75 ? Move.right : p.dy < _sh / 2 ? Move.up : Move.down);
        }
      case WsPhase.results:
        if (phaseT > 1.2) {
          selectSession((session + 1) % sessions.length);
          _start();
        }
      default:
    }
  }

  static final _keys = {
    LogicalKeyboardKey.arrowLeft: Move.left,
    LogicalKeyboardKey.keyA: Move.left,
    LogicalKeyboardKey.arrowUp: Move.up,
    LogicalKeyboardKey.keyW: Move.up,
    LogicalKeyboardKey.arrowDown: Move.down,
    LogicalKeyboardKey.keyS: Move.down,
    LogicalKeyboardKey.arrowRight: Move.right,
    LogicalKeyboardKey.keyD: Move.right,
  };

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      final m = _keys[k];
      sfx.init();
      if (phase == WsPhase.play && m != null) press(m);
      if (phase == WsPhase.title) {
        if (m == Move.left) selectSession(session - 1);
        if (m == Move.right) selectSession(session + 1);
        if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) _start();
      }
      if (phase == WsPhase.results && (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter)) onStageTap();
      if (k == LogicalKeyboardKey.digit1 && phase != WsPhase.play) selectSession(0);
      if (k == LogicalKeyboardKey.digit2 && phase != WsPhase.play) selectSession(1);
      if (k == LogicalKeyboardKey.keyR) _start();
      if (k == LogicalKeyboardKey.keyM) sfx.toggleMute();
      if (k == LogicalKeyboardKey.escape) onExit?.call();
    }
    return KeyEventResult.handled;
  }

  /// A direction press during play.
  void press(Move m) {
    if (next >= notes.length) return;
    final n = notes[next];
    final d = t - n.time;
    if (d < -winIgnore) return;
    if (m != n.move) {
      _judge(Judge.miss, d, wrong: m);
      return;
    }
    final ad = d.abs();
    _judge(ad <= winPerfect ? Judge.perfect : ad <= winGood ? Judge.good : ad <= winOk ? Judge.ok : Judge.miss, d);
  }

  List<Dancer> performersOf(Note n) => n.owner == Owner.both ? [a, b] : n.owner == Owner.b ? [b] : [a];

  void _judge(Judge j, double d, {Move? wrong}) {
    final n = notes[next];
    n.judge = j;
    next++;
    ringFlash = 1;
    ringJudge = j;
    ringMove = n.move;
    final who = performersOf(n);
    if (j == Judge.miss) {
      combo = 0;
      for (final p in who) {
        p.stumble(wrong ?? Move.values[rng.nextInt(4)]);
      }
      final p0 = who.first;
      popups.add(Popup(p0.x, p0.y - 150, wrong != null ? 'WRONG WAY' : d < 0 ? 'TOO EARLY' : 'MISSED', hex(0xFF6B6B)));
      // The class notices; in session I, B stays oblivious.
      for (final c in crew) {
        if (rng.nextDouble() < 0.5) c.glanceAt(p0.x, 0.9);
      }
      if (together) {
        final other = identical(p0, a) ? b : a;
        if (n.owner != Owner.both) {
          other.glanceAt(p0.x, 1.2);
          other.giggle = 1;
        }
      } else {
        a.blush = 1.3;
      }
      for (var k = 0; k < 6; k++) {
        _part(p0.x, p0.y - 120, rand(-120, 120), rand(-180, -40), 0.7, rand(3, 5), hex(0xFFD166), 420, PartKind.star);
      }
      shake = reduceMotion ? 0 : 4;
      sfx.oops();
      return;
    }
    combo++;
    bestCombo = math.max(bestCombo, combo);
    final base = j == Judge.perfect ? 100 : j == Judge.good ? 70 : 40;
    final pts = (base * _mult(combo - 1)).round();
    score += pts;
    for (final p in who) {
      p.pose(n.move, spb, sharp: j == Judge.perfect);
    }
    final col = j == Judge.perfect ? hex(0xFFD166) : j == Judge.good ? hex(0x7CF29A) : hex(0x9FE3FF);
    final label = j == Judge.perfect ? 'PERFECT' : j == Judge.good ? 'GOOD' : 'CLOSE';
    popups.add(Popup(_ringX, _ribbonY - 46, label, col, small: true));
    for (var k = 0; k < (j == Judge.perfect ? 22 : 12); k++) {
      final an = rand(0, math.pi * 2), s = rand(60, j == Judge.perfect ? 260 : 160);
      _part(_ringX, _ribbonY, math.cos(an) * s, math.sin(an) * s, rand(0.3, 0.6), rand(2, 4), col, 0, PartKind.spark);
    }
    for (final p in who) {
      for (var k = 0; k < (j == Judge.perfect ? 10 : 5); k++) {
        _part(p.x + rand(-30, 30), p.y - rand(10, 40), rand(-60, 60), rand(-120, -40), rand(0.4, 0.8), rand(2, 3.5), col, 120, PartKind.spark);
      }
    }
    if (j == Judge.perfect) {
      flash = 0.35;
      ringBump = 1;
    }
    if (n.owner == Owner.both) {
      // A move done together: a heart between them.
      _part((a.x + b.x) / 2, a.y - 140, 0, -50, 1.4, 8, hex(0xFF5A8A), -10, PartKind.heart);
      a.smile = b.smile = 1;
    }
    sfx.chime(n.move.index);
    if (combo > 0 && combo % 10 == 0) {
      popups.add(Popup(_sw / 2, 236, '$combo IN A ROW!', hex(0xFF8FB8), big: true));
      _confetti(36);
      for (final c in crew) {
        c.cheer = 1;
      }
    }
    // Session I: a good streak gets B to look over, just for a moment.
    if (!together && combo > 0 && combo % 6 == 0) {
      glances++;
      b.glanceAt(a.x, 1.6);
      a.blush = 1.2;
      _part(a.x + 14, a.y - 150, 0, -40, 1.2, 7, hex(0xFF5A8A), -10, PartKind.heart);
      popups.add(Popup(b.x, b.y - 150, b.glanceLine(glances), hex(0xFFB3D1), small: true));
    }
  }

  void _confetti(int n) {
    const cols = [0xFFD166, 0xFF6B9A, 0x9FE3FF, 0x7CF29A, 0xC59BFF, 0xFFFFFF];
    for (var k = 0; k < n; k++) {
      _part(rand(120, 840), rand(30, 60), rand(-60, 60), rand(-40, 60), rand(2, 3.2), rand(3, 6), hex(cols[k % cols.length]), 90, PartKind.confetti);
    }
  }

  void _part(double x, double y, double vx, double vy, double life, double size, ui.Color c, double g, PartKind k) {
    if (parts.length < 600) parts.add(Particle(x, y, vx, vy, life, size, c, g, k));
  }

  // ---------- simulation ----------
  void step(double dt) {
    real += dt;
    phaseT += dt;
    switch (phase) {
      case WsPhase.title:
        lights = math.max(0.35, lights - dt);
      case WsPhase.intro:
        lights = math.min(1, lights + dt / 1.2);
        if (phaseT > 1.2) {
          phase = WsPhase.play;
          phaseT = 0;
          t = 0;
        }
      case WsPhase.play:
        t += dt;
        while (next < notes.length && t > notes[next].time + winOk) {
          _judge(Judge.miss, t - notes[next].time);
        }
        _onBeats();
        _crewFollow();
        if (next >= notes.length && t > notes.last.time + spb * 4) {
          phase = WsPhase.outro;
          phaseT = 0;
          coachLine = def.outro;
          coachT = 3;
          for (final d in everyone) {
            d.bowing = true;
          }
          _confetti(60);
          sfx.win();
        }
      case WsPhase.outro:
        if (phaseT > 3.2) {
          phase = WsPhase.results;
          phaseT = 0;
        }
      case WsPhase.results:
    }

    shake = math.max(0, shake - dt * 20);
    ringFlash = math.max(0, ringFlash - dt * 3);
    ringBump = math.max(0, ringBump - dt * 4);
    flash = math.max(0, flash - dt * 2);
    coachT = math.max(0, coachT - dt);
    for (final d in everyone) {
      d.update(dt, phase == WsPhase.play ? beat : real / 0.6);
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
    for (final p in popups) {
      p.life -= dt;
      p.y -= dt * (p.big ? 16 : 30);
    }
    popups.removeWhere((p) => p.life <= 0);
  }

  /// Drums on every beat, the coach's calls, and the class following along.
  void _onBeats() {
    final bt = beat.floor();
    if (bt == _beat) return;
    _beat = bt;
    final last = notes.isEmpty ? 0 : (notes.last.time / spb).ceil() + 2;
    if (bt <= last) {
      final chord = (bt ~/ 4) % 4;
      bt.isEven ? sfx.groove(chord) : sfx.backbeat(chord);
      ringBump = math.max(ringBump, 0.5);
    }
    // Count-in: "5, 6, 7, 8" over the second bar.
    if (bt >= 4 && bt < 8) {
      popups.add(Popup(_ringX, _ribbonY + 4, '${bt + 1}', hex(0xFFFFFF), big: true));
    }
    for (final c in def.calls) {
      if (c.beat == bt) {
        coachLine = c.text;
        coachT = spb * 6;
      }
    }
  }

  /// The class does the move of every prompt, right on time.
  void _crewFollow() {
    while (_crewNext < notes.length && t >= notes[_crewNext].time) {
      final n = notes[_crewNext++];
      for (final c in crew) {
        c.pose(n.move, spb, sharp: false);
      }
      if (!together) b.pose(n.move, spb, sharp: false);
    }
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
    renderStudio(canvas, _lastDt);
    canvas.restore();
  }
}

// ---------- model ----------
class Note {
  Note(this.time, this.move, this.owner);
  final double time;
  final Move move;
  final Owner owner;
  Judge? judge;
}

enum Look { a, b, juggler, alien, mime, acrobat }

class Dancer {
  Dancer(this.look, this.x, this.y, this.scale, this.phase);

  final Look look;
  final double x, y, scale, phase;

  /// The move being held, and how far into it (1 at the hit, easing to 0).
  Move move = Move.up;
  double k = 0, hold = 0.5;
  bool sharp = false;

  /// A stumble after a miss: a wobble toward the wrong side.
  double wobble = 0;
  Move wobbleTo = Move.left;

  double groove = 0, blink = 0, blinkT = 2;
  double glance = 0, glanceX = 0;
  double blush = 0, smile = 0, giggle = 0, cheer = 0;
  bool bowing = false;
  double bow = 0;

  void pose(Move m, double spb, {required bool sharp}) {
    move = m;
    k = 1;
    hold = spb * 0.9;
    this.sharp = sharp;
  }

  void stumble(Move m) {
    wobble = 1;
    wobbleTo = m;
    k = 0;
  }

  void glanceAt(double tx, double secs) {
    glanceX = tx;
    glance = secs;
  }

  /// What B mutters on each look over in session I.
  String glanceLine(int i) => const ['oh, hi?', 'nice move...', 'wait, who is that?', 'huh. she\'s good.', 'is she smiling at me?'][(i - 1) % 5];

  void update(double dt, double beat) {
    groove = beat;
    k = math.max(0, k - dt / math.max(0.2, hold));
    wobble = math.max(0, wobble - dt * 1.2);
    glance = math.max(0, glance - dt);
    blush = math.max(0, blush - dt * 0.6);
    smile = math.max(0, smile - dt * 0.8);
    giggle = math.max(0, giggle - dt);
    cheer = math.max(0, cheer - dt);
    bow = bowing ? math.min(1, bow + dt * 1.6) : math.max(0, bow - dt * 2);
    blinkT -= dt;
    if (blinkT <= 0) {
      blinkT = rand(2, 4.5);
      blink = 1;
    }
    blink = math.max(0, blink - dt * 8);
  }
}

enum PartKind { spark, star, confetti, heart }

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.g, this.kind) : max = life;
  double x, y, vx, vy, life;
  final double max, size, g;
  final ui.Color color;
  final PartKind kind;
}

class Popup {
  Popup(this.x, this.y, this.text, this.color, {this.big = false, this.small = false}) : life = big ? 1.3 : 0.9;
  double x, y, life;
  final String text;
  final ui.Color color;
  final bool big, small;
}

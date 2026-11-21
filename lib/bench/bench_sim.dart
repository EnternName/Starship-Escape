import 'dart:math' as math;

/// Rules for the bench warmth mini game, kept apart from drawing so they can
/// be tested and tuned on their own.
///
/// Two crewmates wait on a bench at a freezing launch pad. The cold pulls the
/// heat meter down. A hug is a small, steady warm-up you can tap often. A kiss
/// is a big burst on a cooldown that can overshoot. Points come in while the
/// heat stays in the cozy band. Too hot only leaves them flustered. Stay too
/// cold and they give up and leave. Near the end a boarding call opens a window,
/// and boarding inside it earns a bonus.

enum BenchEnd { boarded, early, late, froze }

enum BenchEventKind { hug, kiss, points, boardingCall, end }

class BenchEvent {
  BenchEvent(this.kind, [this.amount = 0]);
  final BenchEventKind kind;
  final int amount;
}

class BenchSim {
  BenchSim({int? seed}) : _rng = math.Random(seed);

  // Timing, in seconds.
  static const double roundLen = 20;
  static const double boardOpen = 15;
  static const double boardClose = roundLen;

  // Heat bands, on a 0 to 100 scale.
  static const double coldLine = 25;
  static const double cozyLo = 45;
  static const double cozyHi = 72;
  static const double hotLine = 84;
  static const double startHeat = 50;

  // Feel.
  static const double baseChill = 6; // heat lost per second
  static const double hugHeat = 5;
  static const double kissHeat = 20;
  static const double kissSpread = 0.45; // seconds the kiss heat arrives over
  static const double kissCooldown = 2.4;
  static const double leaveAfterCold = 1.6; // seconds below coldLine before they leave
  static const double tickEvery = 0.5;
  static const int tickPoints = 10;
  static const int boardBonus = 200;

  final math.Random _rng;

  double t = 0;
  double heat = startHeat;
  double kissCd = 0;
  double _kissLeft = 0;
  double coldFor = 0, hotFor = 0, cozyFor = 0;
  double _tick = 0;
  double gust = 0, _gustTimer = 3;
  int score = 0;
  int bonus = 0;
  bool running = true;
  BenchEnd? end;
  bool _called = false;
  final List<BenchEvent> events = [];

  bool get cozy => heat >= cozyLo && heat <= cozyHi;
  bool get cold => heat < coldLine;
  bool get hot => heat > hotLine;
  bool get boardingOpen => t >= boardOpen && t < boardClose;
  bool get kissReady => kissCd <= 0;

  /// Current point multiplier, which grows the longer they stay cozy.
  int get multiplier => cozy ? math.min(4, 1 + cozyFor ~/ 3) : 1;

  /// Seconds left before the boarding call, or until it closes.
  double get untilCall => math.max(0, boardOpen - t);
  double get callLeft => math.max(0, boardClose - t);

  void hug() {
    if (!running) return;
    heat = math.min(100, heat + hugHeat);
    events.add(BenchEvent(BenchEventKind.hug));
  }

  /// Returns false when the kiss is still cooling down.
  bool kiss() {
    if (!running || !kissReady) return false;
    _kissLeft += kissHeat;
    kissCd = kissCooldown;
    events.add(BenchEvent(BenchEventKind.kiss));
    return true;
  }

  void board() {
    if (!running) return;
    if (t < boardOpen) {
      _finish(BenchEnd.early);
    } else {
      bonus = boardBonus;
      score += bonus;
      _finish(BenchEnd.boarded);
    }
  }

  void step(double dt) {
    if (!running) return;
    t += dt;
    kissCd = math.max(0, kissCd - dt);

    // Wind gusts make the cold bite harder for a moment.
    _gustTimer -= dt;
    if (_gustTimer <= 0) {
      gust = 6 + _rng.nextDouble() * 6;
      _gustTimer = 3 + _rng.nextDouble() * 3;
    }
    gust = math.max(0, gust - dt * 5);

    if (_kissLeft > 0) {
      final add = math.min(_kissLeft, kissHeat / kissSpread * dt);
      _kissLeft -= add;
      heat += add;
    }
    heat = (heat - (baseChill + gust) * dt).clamp(0, 100);

    if (cozy) {
      cozyFor += dt;
      _tick += dt;
      while (_tick >= tickEvery) {
        _tick -= tickEvery;
        final pts = tickPoints * multiplier;
        score += pts;
        events.add(BenchEvent(BenchEventKind.points, pts));
      }
    } else {
      cozyFor = 0;
      _tick = 0;
    }

    hotFor = hot ? hotFor + dt : 0;

    coldFor = cold ? coldFor + dt : 0;
    if (coldFor >= leaveAfterCold) {
      _finish(BenchEnd.froze);
      return;
    }

    if (!_called && t >= boardOpen) {
      _called = true;
      events.add(BenchEvent(BenchEventKind.boardingCall));
    }
    if (t >= boardClose) _finish(BenchEnd.late);
  }

  void _finish(BenchEnd how) {
    running = false;
    end = how;
    events.add(BenchEvent(BenchEventKind.end));
  }
}

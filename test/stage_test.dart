import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/games/stage/stage_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Runs the simulation for [seconds] with fixed 60 fps steps.
  void run(StageGame g, double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      g.step(1 / 60);
    }
  }

  StageGame start({int act = 0, bool aFirst = false}) {
    final g = StageGame(aSingsFirst: aFirst)..reset();
    g.selectAct(act);
    g.onStageTap();
    run(g, 2.5);
    expect(g.phase, StagePhase.play);
    return g;
  }

  test('three acts: two solos in either order, then the duet', () {
    final bFirst = StageGame(aSingsFirst: false);
    final aFirst = StageGame(aSingsFirst: true);
    expect(bFirst.playbill.map((a) => a.solo), [Solo.b, Solo.a, null]);
    expect(aFirst.playbill.map((a) => a.solo), [Solo.a, Solo.b, null]);
    expect(bFirst.playbill.last.lines.length, 16);
  });

  test('the square is on the target line at every cue', () {
    for (var act = 0; act < 3; act++) {
      final g = StageGame()..reset();
      g.selectAct(act);
      for (var i = 0; i < g.cues.length; i++) {
        expect(g.barPos(g.cues[i]), closeTo(g.targets[i], 0.01));
        if (i > 0) expect(g.cues[i] - g.cues[i - 1], greaterThan(1.8));
      }
      expect(g.cues.last, inInclusiveRange(30, 75));
    }
  });

  test('hitting every cue in the duet scores all perfects and ends the show', () {
    final g = start(act: 2);
    for (var i = 0; i < g.cues.length; i++) {
      run(g, g.cues[i] - g.t);
      g.onStageTap();
    }
    expect(g.results.every((r) => r == Judge.perfect), isTrue);
    expect(g.score, g.maxScore);
    run(g, 12);
    expect(g.phase, StagePhase.results);
  });

  test('never pressing still finishes, with every cue off script', () {
    final g = start();
    run(g, g.cues.last + 12);
    expect(g.phase, StagePhase.results);
    expect(g.results.every((r) => r == Judge.miss), isTrue);
    expect(g.bloopers.length, g.cues.length);
  });

  test('a miss in a solo puts an off script line over the performer', () {
    final g = start(act: 0);
    run(g, g.cues[0] + 0.3 - g.t);
    expect(g.results[0], Judge.miss);
    expect(g.performer, same(g.actB));
    expect(g.actB.bubble?.off, isTrue);
  });

  test('a press long before the square arrives is ignored', () {
    final g = start();
    run(g, g.cues[0] - 1.0 - g.t);
    g.onStageTap();
    expect(g.next, 0);
  });

  test('a slightly late press still counts', () {
    final g = start(act: 2);
    run(g, g.cues[0] + 0.1 - g.t);
    g.onStageTap();
    expect(g.results[0], Judge.good);
    expect(g.target(0).bubble?.off, isFalse);
  });

  test('the duet actors sit on the crates in the sunset scene', () {
    final g = start(act: 2);
    run(g, g.cues[9] - g.t);
    expect(g.actA.sit, greaterThan(0.9));
    expect(g.actB.sit, greaterThan(0.9));
  });

  test('after the results a tap starts the next act', () {
    final g = start();
    run(g, g.cues.last + 12);
    g.onStageTap();
    expect(g.act, 1);
    expect(g.phase, StagePhase.intro);
  });
}

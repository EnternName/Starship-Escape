import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/games/workshop/workshop_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void run(WorkshopGame g, double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      g.step(1 / 60);
    }
  }

  WorkshopGame start({int session = 0}) {
    final g = WorkshopGame()..reset();
    g.selectSession(session);
    g.onStageTap();
    run(g, 1.3);
    expect(g.phase, WsPhase.play);
    return g;
  }

  test('two sessions: A alone first, then A and B as partners', () {
    expect(sessions.length, 2);
    expect(sessions[0].together, isFalse);
    expect(buildChart(sessions[0]).every((n) => n.owner == Owner.a), isTrue);
    final two = buildChart(sessions[1]);
    expect(two.map((n) => n.owner).toSet(), {Owner.a, Owner.b, Owner.both});
  });

  test('prompts land on the eighth-note grid after the count-in, in order', () {
    for (final s in sessions) {
      final spb = 60 / s.bpm;
      final chart = buildChart(s);
      expect(chart.first.time, greaterThanOrEqualTo(countIn * spb - 1e-9));
      for (var i = 1; i < chart.length; i++) {
        expect(chart[i].time, greaterThan(chart[i - 1].time));
        final eighths = chart[i].time / (spb / 2);
        expect(eighths, closeTo(eighths.roundToDouble(), 1e-6));
      }
      expect(chart.last.time, inInclusiveRange(30, 60));
    }
  });

  test('pressing every prompt on time scores all perfects and finishes', () {
    for (var s = 0; s < 2; s++) {
      final g = start(session: s);
      for (final n in g.notes) {
        run(g, n.time - g.t);
        g.press(n.move);
      }
      expect(g.notes.every((n) => n.judge == Judge.perfect), isTrue);
      expect(g.score, g.maxScore);
      run(g, 10);
      expect(g.phase, WsPhase.results);
    }
  });

  test('a wrong direction is a miss and breaks the combo', () {
    final g = start();
    final n = g.notes.first;
    run(g, n.time - g.t);
    g.press(n.move == Move.left ? Move.right : Move.left);
    expect(n.judge, Judge.miss);
    expect(g.combo, 0);
    expect(g.a.wobble, greaterThan(0));
  });

  test('presses long before a prompt are ignored', () {
    final g = start();
    g.press(Move.up);
    expect(g.next, 0);
  });

  test('never pressing still finishes with every prompt missed', () {
    final g = start(session: 1);
    run(g, g.notes.last.time + 10);
    expect(g.phase, WsPhase.results);
    expect(g.notes.every((n) => n.judge == Judge.miss), isTrue);
  });

  test('in session I a good streak makes B look over', () {
    final g = start();
    for (final n in g.notes.take(12)) {
      run(g, n.time - g.t);
      g.press(n.move);
    }
    expect(g.glances, 2);
  });
}

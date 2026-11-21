import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/bench/bench_sim.dart';

void main() {
  void run(BenchSim s, double seconds, {void Function(BenchSim)? each}) {
    for (var i = 0; i < (seconds * 60).round() && s.running; i++) {
      each?.call(s);
      s.step(1 / 60);
    }
  }

  // Keeps the heat in the cozy band with hugs, like a careful player.
  void cozyPlayer(BenchSim s) {
    if (s.heat < BenchSim.cozyLo + 6) s.hug();
  }

  test('doing nothing lets them freeze and leave', () {
    final s = BenchSim(seed: 1);
    run(s, 20);
    expect(s.end, BenchEnd.froze);
    expect(s.t, lessThan(BenchSim.boardOpen));
  });

  test('staying cozy earns points and boarding in the window adds the bonus', () {
    final s = BenchSim(seed: 2);
    run(s, BenchSim.boardOpen + 1, each: cozyPlayer);
    expect(s.running, isTrue);
    expect(s.boardingOpen, isTrue);
    final before = s.score;
    expect(before, greaterThan(200));
    s.board();
    expect(s.end, BenchEnd.boarded);
    expect(s.score, before + BenchSim.boardBonus);
  });

  test('boarding before the call ends the round early with no bonus', () {
    final s = BenchSim(seed: 3);
    run(s, 5, each: cozyPlayer);
    s.board();
    expect(s.end, BenchEnd.early);
    expect(s.bonus, 0);
  });

  test('never boarding misses the call when the timer runs out', () {
    final s = BenchSim(seed: 4);
    run(s, BenchSim.roundLen + 1, each: cozyPlayer);
    expect(s.end, BenchEnd.late);
  });

  test('a kiss is a big burst on a cooldown', () {
    final s = BenchSim(seed: 5);
    expect(s.kiss(), isTrue);
    expect(s.kiss(), isFalse);
    final h0 = s.heat;
    run(s, 0.6);
    expect(s.heat, greaterThan(h0 + BenchSim.kissHeat * 0.6));
    run(s, BenchSim.kissCooldown);
    expect(s.kissReady, isTrue);
  });

  test('too hot only stops points, it never takes them away', () {
    final s = BenchSim(seed: 6);
    run(s, 4, each: cozyPlayer);
    final before = s.score;
    run(s, 3, each: (s) {
      if (s.heat < 95) s.hug();
    });
    expect(s.hot, isTrue);
    expect(s.score, greaterThanOrEqualTo(before));
    expect(s.running, isTrue);
  });
}

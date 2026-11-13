import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/games/stage/stage_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StageGame game;

  setUp(() {
    game = StageGame()..reset();
  });

  void run(double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      game.step(1 / 60);
    }
  }

  void start() {
    game.onStageTap();
    run(2.5);
    expect(game.phase, StagePhase.play);
  }

  test('the play has 16 cues, about a minute long', () {
    expect(script.length, 16);
    expect(game.cues.length, 16);
    expect(game.cues.last, inInclusiveRange(45, 60));
  });

  test('tapping on every cue scores all perfects and ends the show', () {
    start();
    for (var i = 0; i < game.cues.length; i++) {
      run(game.cues[i] - game.t);
      game.onStageTap();
    }
    expect(game.results.every((r) => r == Judge.perfect), isTrue);
    expect(game.bestCombo, 16);
    expect(game.score, game.maxScore);
    run(12);
    expect(game.phase, StagePhase.results);
  });

  test('never tapping still finishes, with every cue off script', () {
    start();
    run(game.cues.last + 12);
    expect(game.phase, StagePhase.results);
    expect(game.results.every((r) => r == Judge.miss), isTrue);
    expect(game.score, 0);
    expect(game.bloopers.length, 16);
  });

  test('a miss puts an off script line over the actor', () {
    start();
    run(game.cues[0] + 0.3 - game.t);
    expect(game.results[0], Judge.miss);
    expect(game.target(0).bubble?.off, isTrue);
  });

  test('a tap long before the orb arrives is ignored', () {
    start();
    run(game.cues[0] - 1.0 - game.t);
    game.onStageTap();
    expect(game.next, 0);
    expect(game.results[0], isNull);
  });

  test('a slightly late tap still counts', () {
    start();
    run(game.cues[0] + 0.1 - game.t);
    game.onStageTap();
    expect(game.results[0], Judge.good);
    expect(game.target(0).bubble?.off, isFalse);
  });

  test('the actors sit on the crates in the sunset scene', () {
    start();
    run(game.cues[9] - game.t);
    expect(game.actA.sit, greaterThan(0.9));
    expect(game.actB.sit, greaterThan(0.9));
  });
}

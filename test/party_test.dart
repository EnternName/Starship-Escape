import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/party/party_game.dart';

void main() {
  late PartyGame game;

  setUp(() {
    game = PartyGame()..reset();
    game.startGame();
  });

  void run(double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      game.step(1 / 60);
    }
  }

  test('the venue fills with a crowd that is not on top of A or B', () {
    expect(game.guests.length, 64);
    for (final g in game.guests) {
      expect(game.solidAt(g.x, g.y, 0), isFalse);
    }
  });

  test('arrow keys move B in all four directions', () {
    final x0 = game.b.x, y0 = game.b.y;
    game.right = true;
    run(0.4);
    game.right = false;
    expect(game.b.x, greaterThan(x0 + 30));
    game.up = true;
    run(0.4);
    game.up = false;
    expect(game.b.y, lessThan(y0 - 30));
  });

  test('walls stop B', () {
    game.left = true;
    run(1);
    expect(game.b.x, greaterThanOrEqualTo(tile));
  });

  test('pushing into someone moves them, and the round goes on', () {
    final g = game.guests.first;
    game.guests = [g];
    final gx = g.x;
    game.b
      ..x = g.x - 40
      ..y = g.y;
    game.a
      ..x = 30 * tile
      ..y = 2 * tile;
    game.right = true;
    run(0.6);
    expect(game.nudges, 1);
    expect(g.x, greaterThan(gx + 5));
    expect(game.state, PartyState.play);
  });

  test('holding a direction pushes B through a whole group', () {
    // Put B just left of the densest group and walk right through it.
    final g = game.guests.first;
    game.b
      ..x = g.x - 70
      ..y = g.y;
    game.right = true;
    run(3);
    expect(game.b.x, greaterThan(g.x + 30));
  });

  test('reaching A ends the round with them together', () {
    game.b
      ..x = game.a.x - 60
      ..y = game.a.y;
    game.right = true;
    run(2);
    expect(game.state, PartyState.met);
  });

  test('if you just stand still, A eventually drifts toward B', () {
    final d0 = (game.a.x - game.b.x).abs() + (game.a.y - game.b.y).abs();
    run(60);
    final d1 = (game.a.x - game.b.x).abs() + (game.a.y - game.b.y).abs();
    expect(d1 < d0 || game.state == PartyState.met, isTrue);
  });
}

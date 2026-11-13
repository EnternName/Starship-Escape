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
    final x0 = game.a.x, y0 = game.a.y;
    game.right = true;
    run(0.4);
    game.right = false;
    expect(game.a.x, greaterThan(x0 + 30));
    game.up = true;
    run(0.4);
    game.up = false;
    expect(game.a.y, lessThan(y0 - 30));
  });

  test('walls stop B', () {
    game.left = true;
    run(1);
    expect(game.a.x, greaterThanOrEqualTo(tile));
  });

  test('pushing into someone moves them, and the round goes on', () {
    final g = game.guests.first;
    game.guests = [g];
    final gx = g.x;
    game.a
      ..x = g.x - 40
      ..y = g.y;
    game.b
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
    game.a
      ..x = g.x - 70
      ..y = g.y;
    game.right = true;
    run(3);
    expect(game.a.x, greaterThan(g.x + 30));
  });

  test('standing in front of B gets noticed, and the round ends with a hello', () {
    game.guests = [];
    final b = game.b;
    b
      ..fx = 1
      ..fy = 0
      ..lookX = b.x + 50
      ..lookY = b.y;
    game.a
      ..x = b.x + 60
      ..y = b.y;
    run(5);
    expect(game.state, PartyState.met);
    expect(game.b.say, 'oh! hi.');
    expect(game.a.say, 'hi.');
  });

  test('standing behind B is not enough', () {
    game.guests = [game.guests.first];
    // Keep B facing right in place and stand behind.
    final b = game.b;
    for (var i = 0; i < 180; i++) {
      b
        ..fx = 1
        ..fy = 0
        ..tx = b.x
        ..ty = b.y
        ..lookX = b.x + 50
        ..lookY = b.y
        ..retarget = 9;
      game.a
        ..x = b.x - 40
        ..y = b.y;
      game.step(1 / 60);
    }
    expect(game.state, PartyState.play);
    expect(game.attention, 0);
  });
}

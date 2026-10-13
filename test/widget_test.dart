import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/game/starship_game.dart';

void main() {
  late StarshipGame game;

  setUp(() {
    game = StarshipGame()..reset();
  });

  // Runs the simulation for [seconds] with fixed 60 fps steps.
  void run(double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      game.step(1 / 60);
    }
  }

  test('player lands on the ground and runs right', () {
    game.startGame();
    game.right = true;
    run(2);
    expect(game.p.onGround, isTrue);
    expect(game.p.x, greaterThan(300));
  });

  test('a long fall staggers instead of hurting', () {
    game.startGame();
    game.p
      ..x = 200
      ..y = 0
      ..apexY = 0;
    run(1.5);
    expect(game.p.stagger, greaterThan(0));
    expect(game.state, GameState.play);
  });

  test('missing every rocket ends the game', () {
    game.startGame();
    run(game.rockets.last.launchT + 3);
    expect(game.state, GameState.lost);
  });

  test('reaching a pad boards the rocket and wins', () {
    game.startGame();
    final r = game.rockets[1];
    game.p
      ..x = r.x - 11
      ..y = r.padY - 40;
    run(4);
    expect(game.state, GameState.won);
    expect(game.wonRocket, 2);
  });

  test('running through a hidden trigger opens the tunnel', () {
    game.startGame();
    final tunnel = game.triggers[1];
    game.p
      ..x = tunnel.zone.x + 10
      ..y = tunnel.zone.y + 10;
    run(0.1);
    expect(tunnel.fired, isTrue);
    expect(game.tunnelWalls.every((w) => !w.alive), isTrue);
  });

  test('a runner who holds right and keeps jumping catches a rocket', () {
    game.startGame();
    game.right = true;
    for (var i = 0; i < 120 && game.state == GameState.play; i++) {
      game
        ..jumpPressedAt = game.t
        ..jumpHeld = true;
      run(0.25);
      game.jumpHeld = false;
      run(0.25);
    }
    expect(game.state, GameState.won);
  });
}

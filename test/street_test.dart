import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/street/street_game.dart';

void main() {
  late StreetGame game;

  setUp(() {
    game = StreetGame()..reset();
    game.startGame();
    game.rockTimer = 999; // No random rocks unless a test wants them.
  });

  void run(double seconds) {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      game.step(1 / 60);
      game.rockTimer = 999;
    }
  }

  int shortestPath({required bool cracksOpen}) {
    final start = (game.p.x ~/ tile, game.p.y ~/ tile);
    final dist = {start: 0};
    final q = Queue.of([start]);
    while (q.isNotEmpty) {
      final (c, r) = q.removeFirst();
      if (game.at(c, r) == 'E') return dist[(c, r)]!;
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final n = (c + dc, r + dr);
        final k = game.at(n.$1, n.$2);
        if (dist.containsKey(n) || k == '#' || k == 'r' || (k == 'x' && !cracksOpen)) continue;
        dist[n] = dist[(c, r)]! + 1;
        q.add(n);
      }
    }
    return -1;
  }

  test('the pad is reachable, and the cracked walls are real shortcuts', () {
    final long = shortestPath(cracksOpen: false);
    final short = shortestPath(cracksOpen: true);
    expect(long, greaterThan(0));
    expect(short, lessThan(long ~/ 2));
  });

  test('arrow keys move in all four directions', () {
    final x0 = game.p.x, y0 = game.p.y;
    game.right = true;
    run(0.5);
    game.right = false;
    expect(game.p.x, greaterThan(x0 + 60));
    game.up = true;
    run(0.3);
    game.up = false;
    expect(game.p.y, lessThan(y0));
    final x1 = game.p.x;
    game.left = true;
    run(0.3);
    game.left = false;
    expect(game.p.x, lessThan(x1));
    final y1 = game.p.y;
    game.down = true;
    run(0.3);
    expect(game.p.y, greaterThan(y1));
  });

  test('walls stop the player', () {
    game.left = true;
    run(1);
    expect(game.p.x, greaterThanOrEqualTo(tile + 9));
  });

  test('lava knocks you back but the run goes on', () {
    // Lava at row 21, columns 27 and 28.
    game.p
      ..x = 25 * tile + 20
      ..y = 21 * tile + 20;
    game.right = true;
    run(1.5);
    expect(game.state, StreetState.play);
    expect(game.p.x, lessThan(28 * tile));
  });

  test('pushing into a cracked wall breaks it', () {
    // Cracked wall at column 3, rows 19 and 20. Stand below it and push up.
    game.p
      ..x = 3 * tile + 20
      ..y = 21 * tile + 20;
    game.up = true;
    run(1.5);
    expect(game.shortcuts, 1);
    expect(game.at(3, 19), '.');
    expect(game.at(3, 20), '.');
    expect(game.p.y, lessThan(19 * tile));
  });

  test('reaching the pad launches the rocket and wins', () {
    game.p
      ..x = game.pad.right + 20
      ..y = game.pad.center.dy;
    game.left = true;
    run(6);
    expect(game.p.boarded, isTrue);
    expect(game.state, StreetState.won);
  });

  test('a falling rock only knocks you back', () {
    game.rocks.add(Rock(game.p.x, game.p.y, 12)..z = 1);
    run(0.2);
    expect(game.p.stun, greaterThan(0));
    expect(game.state, StreetState.play);
  });
}

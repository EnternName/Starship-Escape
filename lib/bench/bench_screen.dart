import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../shared/stage_frame.dart';
import 'bench_game.dart';

/// Keep Warm: A and B on a bench at the launch pad.
class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key, required this.onExit, this.onFinish});
  final VoidCallback onExit;

  /// Called when a round ends, with the score kept inside this game.
  final BenchFinish? onFinish;

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  BenchGame? _game;

  @override
  Widget build(BuildContext context) {
    final game = _game ??= BenchGame(reduceMotion: MediaQuery.of(context).disableAnimations, onFinish: widget.onFinish, onExit: widget.onExit);
    final touch = isTouchDevice;
    return StageFrame(
      onExit: widget.onExit,
      stage: Listener(onPointerDown: (e) => game.pointerDown(e.localPosition), child: GameWidget(game: game)),
      caption: [
        if (!touch) ...[
          keyHint(['H', ' hug']),
          keyHint(['K', ' kiss']),
          keyHint(['Space', ' board']),
          keyHint(['M', ' sound']),
        ],
        const Text('Keep them cozy. Board when the call sounds.', style: TextStyle(color: ashColor, fontSize: 13)),
      ],
    );
  }
}

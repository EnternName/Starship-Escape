import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../shared/stage_frame.dart';
import 'stage_game.dart';

/// Stage Fright: the stage timing mini game.
class StageScreen extends StatefulWidget {
  const StageScreen({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<StageScreen> createState() => _StageScreenState();
}

class _StageScreenState extends State<StageScreen> {
  StageGame? _game;

  @override
  Widget build(BuildContext context) {
    final game = _game ??= StageGame(reduceMotion: MediaQuery.of(context).disableAnimations, onExit: widget.onExit);
    final touch = isTouchDevice;
    return StageFrame(
      onExit: widget.onExit,
      stage: Listener(onPointerDown: (_) => game.onStageTap(), child: GameWidget(game: game)),
      caption: [
        if (!touch) ...[
          keyHint(['Space', ', ', 'click', ' or ', 'tap', ' hit the cue']),
          keyHint(['R', ' restart']),
          keyHint(['M', ' sound']),
        ],
        const Text('Tap as the orb meets the ring. Misses go off script.', style: TextStyle(color: ashColor, fontSize: 13)),
      ],
    );
  }
}

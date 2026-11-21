import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../shared/stage_frame.dart';
import 'workshop_game.dart';

/// Workshop: the movement class rhythm mini game.
class WorkshopScreen extends StatefulWidget {
  const WorkshopScreen({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends State<WorkshopScreen> {
  WorkshopGame? _game;

  @override
  Widget build(BuildContext context) {
    final game = _game ??= WorkshopGame(reduceMotion: MediaQuery.of(context).disableAnimations, onExit: widget.onExit);
    final touch = isTouchDevice;
    return StageFrame(
      onExit: widget.onExit,
      stage: Listener(onPointerDown: (e) => game.onStageTap(e.localPosition), child: GameWidget(game: game)),
      caption: [
        if (!touch) ...[
          keyHint(['← ↑ ↓ →', ' or ', 'WASD', ' moves']),
          keyHint(['1 2', ' pick a session']),
          keyHint(['R', ' restart']),
          keyHint(['M', ' sound']),
        ] else
          const Text('Tap the left, right, top or bottom of the stage for each move.', style: TextStyle(color: ashColor, fontSize: 13)),
        const Text('Press the arrow as it reaches the ring.', style: TextStyle(color: ashColor, fontSize: 13)),
      ],
    );
  }
}

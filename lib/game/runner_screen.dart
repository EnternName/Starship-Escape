import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../shared/stage_frame.dart';
import 'starship_game.dart';

/// Rooftop Run: the original side-on platformer.
class RunnerScreen extends StatefulWidget {
  const RunnerScreen({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<RunnerScreen> createState() => _RunnerScreenState();
}

class _RunnerScreenState extends State<RunnerScreen> {
  StarshipGame? _game;

  @override
  Widget build(BuildContext context) {
    final game = _game ??= StarshipGame(reduceMotion: MediaQuery.of(context).disableAnimations, onExit: widget.onExit);
    final touch = isTouchDevice;
    return StageFrame(
      onExit: widget.onExit,
      stage: Listener(onPointerDown: (_) => game.onStageTap(), child: GameWidget(game: game)),
      overlay: touch ? _RunnerTouch(game: game) : null,
      caption: [
        if (!touch) ...[
          keyHint(['← →', ' or ', 'A D', ' run']),
          keyHint(['Space', ', ', 'W', ' or ', '↑', ' jump (hold for height)']),
          keyHint(['R', ' restart']),
          keyHint(['M', ' sound']),
        ],
        const Text('Catch a rocket before the last one leaves.', style: TextStyle(color: ashColor, fontSize: 13)),
      ],
    );
  }
}

class _RunnerTouch extends StatelessWidget {
  const _RunnerTouch({required this.game});
  final StarshipGame game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final small = box.maxWidth < 600;
      final s = small ? 44.0 : 64.0;
      final j = small ? 52.0 : 76.0;
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.all(small ? 6 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TouchButton(size: s, label: '◀', onChange: (v) => game.setTouch(l: v)),
              SizedBox(width: small ? 6 : 10),
              TouchButton(size: s, label: '▶', onChange: (v) => game.setTouch(r: v)),
              const Spacer(),
              TouchButton(size: j, label: 'JUMP', accent: true, onChange: (v) => game.setTouch(j: v)),
            ],
          ),
        ),
      );
    });
  }
}

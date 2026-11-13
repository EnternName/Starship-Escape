import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../shared/stage_frame.dart';
import 'street_game.dart';

/// Street Escape: the top-down mini game.
class StreetScreen extends StatefulWidget {
  const StreetScreen({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<StreetScreen> createState() => _StreetScreenState();
}

class _StreetScreenState extends State<StreetScreen> {
  StreetGame? _game;

  @override
  Widget build(BuildContext context) {
    final game = _game ??= StreetGame(reduceMotion: MediaQuery.of(context).disableAnimations, onExit: widget.onExit);
    final touch = isTouchDevice;
    return StageFrame(
      onExit: widget.onExit,
      stage: Listener(onPointerDown: (_) => game.onStageTap(), child: GameWidget(game: game)),
      overlay: touch ? _DPad(game: game) : null,
      caption: [
        if (!touch) ...[
          keyHint(['← ↑ → ↓', ' or ', 'W A S D', ' move']),
          keyHint(['R', ' restart']),
          keyHint(['M', ' sound']),
        ],
        const Text('Reach the launch pad. Cracked walls give way if you push.', style: TextStyle(color: ashColor, fontSize: 13)),
      ],
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({required this.game});
  final StreetGame game;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final s = box.maxWidth < 600 ? 40.0 : 56.0;
      Widget b(String label, void Function(bool) f) => TouchButton(size: s, label: label, onChange: f);
      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: s * 3,
            height: s * 3,
            child: Stack(children: [
              Positioned(left: s, top: 0, child: b('▲', (v) => game.setTouch(u: v))),
              Positioned(left: 0, top: s, child: b('◀', (v) => game.setTouch(l: v))),
              Positioned(left: s * 2, top: s, child: b('▶', (v) => game.setTouch(r: v))),
              Positioned(left: s, top: s * 2, child: b('▼', (v) => game.setTouch(d: v))),
            ]),
          ),
        ),
      );
    });
  }
}

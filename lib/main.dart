import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game/starship_game.dart';

void main() => runApp(const StarshipApp());

const _void = Color(0xFF0E0A1C);
const _ash = Color(0xFFB3A9C9);
const _ink = Color(0xFFF4EFFC);

class StarshipApp extends StatelessWidget {
  const StarshipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Starship Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'ChakraPetch', scaffoldBackgroundColor: _void),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  StarshipGame? _game;

  bool get _touch => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final game = _game ??= StarshipGame(reduceMotion: MediaQuery.of(context).disableAnimations);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, 1.2), radius: 1.2, colors: [Color(0xFF2A1226), _void]),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            const caption = 44.0;
            final w = math.min(box.maxWidth - 32, (box.maxHeight - 32 - caption) * 16 / 9).clamp(160.0, 1280.0);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: w,
                    height: w * 9 / 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Color(0x55FF7A3D), blurRadius: 60, spreadRadius: -20, offset: Offset(0, 20))],
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Listener(onPointerDown: (_) => game.onStageTap(), child: GameWidget(game: game)),
                          if (_touch) _TouchControls(game: game, small: w < 600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Keys(touch: _touch),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Keys extends StatelessWidget {
  const _Keys({required this.touch});
  final bool touch;

  @override
  Widget build(BuildContext context) {
    const plain = TextStyle(color: _ash, fontSize: 13);
    const bold = TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600);
    Widget item(List<InlineSpan> spans) => Text.rich(TextSpan(style: plain, children: spans));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 6,
        children: [
          if (!touch) ...[
            item(const [TextSpan(text: '← →', style: bold), TextSpan(text: ' or '), TextSpan(text: 'A D', style: bold), TextSpan(text: ' run')]),
            item(const [TextSpan(text: 'Space', style: bold), TextSpan(text: ', '), TextSpan(text: 'W', style: bold), TextSpan(text: ' or '), TextSpan(text: '↑', style: bold), TextSpan(text: ' jump (hold for height)')]),
            item(const [TextSpan(text: 'R', style: bold), TextSpan(text: ' restart')]),
            item(const [TextSpan(text: 'M', style: bold), TextSpan(text: ' sound')]),
          ],
          const Text('Catch a rocket before the last one leaves.', style: plain),
        ],
      ),
    );
  }
}

class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.game, required this.small});
  final StarshipGame game;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = small ? 44.0 : 64.0;
    final j = small ? 52.0 : 76.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(small ? 6 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _TouchButton(size: s, label: '◀', onChange: (v) => game.setTouch(l: v)),
            SizedBox(width: small ? 6 : 10),
            _TouchButton(size: s, label: '▶', onChange: (v) => game.setTouch(r: v)),
            const Spacer(),
            _TouchButton(size: j, label: 'JUMP', accent: true, onChange: (v) => game.setTouch(j: v)),
          ],
        ),
      ),
    );
  }
}

class _TouchButton extends StatelessWidget {
  const _TouchButton({required this.size, required this.label, required this.onChange, this.accent = false});
  final double size;
  final String label;
  final bool accent;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onChange(true),
      onPointerUp: (_) => onChange(false),
      onPointerCancel: (_) => onChange(false),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent ? const Color(0x55FF7A3D) : const Color(0x800E0A1C),
          border: Border.all(color: const Color(0x40FFFFFF)),
        ),
        child: Text(label, style: TextStyle(color: _ink, fontSize: size < 50 ? 11 : 14, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ),
    );
  }
}

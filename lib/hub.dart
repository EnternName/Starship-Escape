import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'minigames.dart';
import 'shared/stage_frame.dart';

/// The mini game menu.
class Hub extends StatefulWidget {
  const Hub({super.key});

  @override
  State<Hub> createState() => _HubState();
}

class _HubState extends State<Hub> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  final FocusNode _focus = FocusNode();
  int _selected = 0;
  int? _hover;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open(int i) {
    final nav = Navigator.of(context);
    nav.push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, a, b) => miniGames[i].build(() => nav.pop()),
      transitionsBuilder: (context, a, b, child) => FadeTransition(opacity: a, child: child),
    )).then((_) => _focus.requestFocus());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final n = miniGames.length;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.keyS) {
      setState(() => _selected = (_selected + 1) % n);
    } else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.keyW) {
      setState(() => _selected = (_selected - 1 + n) % n);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      _open(_selected);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _SkyPainter(_time, still))),
            SafeArea(
              child: LayoutBuilder(builder: (context, box) {
                final narrow = box.maxWidth < 720;
                final cards = [
                  for (var i = 0; i < miniGames.length; i++)
                    _GameCard(
                      game: miniGames[i],
                      index: i,
                      time: _time,
                      active: i == (_hover ?? _selected),
                      onHover: (h) => setState(() => _hover = h ? i : null),
                      onTap: () => _open(i),
                    ),
                ];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 64),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('EARTH  ·  FINAL EVACUATION',
                            style: TextStyle(color: Color(0xFFFF9A6A), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        _Title(time: _time, still: still, size: narrow ? 40 : 64),
                        const SizedBox(height: 6),
                        const Text('Pick a way out.', style: TextStyle(color: ashColor, fontSize: 17)),
                        const SizedBox(height: 28),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: narrow
                              ? Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)])
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < cards.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 20),
                                      Expanded(child: cards[i]),
                                    ],
                                  ],
                                ),
                        ),
                        const SizedBox(height: 22),
                        const Text('← → choose   ·   Enter or click to play   ·   Esc in a game returns here',
                            textAlign: TextAlign.center, style: TextStyle(color: ashColor, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.time, required this.still, required this.size});
  final ValueNotifier<double> time;
  final bool still;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: time,
      builder: (context, t, _) {
        final wob = still ? 0.0 : math.sin(t * 2) * 3;
        Widget word(String s, Color c) => Stack(children: [
              Transform.translate(
                  offset: const Offset(4, 4), child: Text(s, style: TextStyle(fontFamily: 'Bungee', fontSize: size, color: const Color(0xFFFF5B3A), height: 1))),
              Text(s, style: TextStyle(fontFamily: 'Bungee', fontSize: size, color: c, height: 1)),
            ]);
        return Transform.translate(
          offset: Offset(0, wob),
          child: Wrap(alignment: WrapAlignment.center, spacing: size * 0.4, children: [
            word('STARSHIP', inkColor),
            word('ESCAPE', const Color(0xFFFFD36B)),
          ]),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.index, required this.time, required this.active, required this.onHover, required this.onTap});
  final MiniGame game;
  final int index;
  final ValueNotifier<double> time;
  final bool active;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          scale: active ? 1.03 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: const Color(0xCC0E0A1C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? game.accent : const Color(0x22FFFFFF), width: active ? 2 : 1),
              boxShadow: [if (active) BoxShadow(color: game.accent.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -8)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RepaintBoundary(child: CustomPaint(painter: _PreviewPainter(index, time, game.accent))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.view, style: TextStyle(color: game.accent, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text(game.title, style: const TextStyle(fontFamily: 'Bungee', fontSize: 26, color: inkColor)),
                      const SizedBox(height: 6),
                      Text(game.tagline, style: const TextStyle(color: ashColor, fontSize: 14, height: 1.35)),
                      const SizedBox(height: 12),
                      Text(active ? 'PLAY  ▶' : 'PLAY', style: TextStyle(color: active ? game.accent : ashColor, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Burning sky behind the menu: stars, a glowing horizon and distant launches.
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.time, this.still) : super(repaint: time);
  final ValueNotifier<double> time;
  final bool still;
  static final _r = math.Random(7);
  static final _stars = List.generate(160, (_) => [_r.nextDouble(), _r.nextDouble() * 0.75, _r.nextDouble() * 1.4 + 0.4, _r.nextDouble() * 6]);

  @override
  void paint(Canvas c, Size s) {
    final t = still ? 0.0 : time.value;
    final full = Offset.zero & s;
    c.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0D0A24), Color(0xFF2B1446), Color(0xFF8A3446)], stops: [0, 0.6, 1]).createShader(full));
    for (final st in _stars) {
      final a = 0.3 + 0.6 * math.sin(t * 1.3 + st[3]).abs();
      c.drawRect(Rect.fromLTWH(st[0] * s.width, st[1] * s.height, st[2], st[2]), Paint()..color = Color.fromRGBO(255, 240, 255, a));
    }
    // Distant launches climbing on a loop.
    for (var i = 0; i < 4; i++) {
      final k = ((t * 0.07 + i * 0.27) % 1);
      final x = s.width * (0.12 + i * 0.25) + math.sin(i * 3.0) * 40;
      final y = s.height * (1 - k * 1.2);
      for (var j = 0; j < 30; j++) {
        final yy = y + j * 6;
        c.drawCircle(Offset(x + math.sin(j * 0.4) * 1.5, yy), 1 + j * 0.15,
            Paint()..color = Color.fromRGBO(255, 190, 120, (1 - j / 30) * 0.25)..blendMode = BlendMode.plus);
      }
      c.drawCircle(Offset(x, y), 2.5, Paint()..color = const Color(0xFFFFF3C4)..blendMode = BlendMode.plus);
    }
    // City silhouette and fire glow.
    final base = s.height;
    final city = Path()..moveTo(0, base);
    var x = 0.0;
    var i = 0;
    while (x < s.width) {
      final w = 30 + (i * 37 % 60).toDouble(), h = 40 + (i * 53 % 110).toDouble();
      city
        ..lineTo(x, base - h)
        ..lineTo(x + w, base - h);
      x += w;
      i++;
    }
    city
      ..lineTo(s.width, base)
      ..close();
    c.drawRect(Rect.fromLTWH(0, base - 260, s.width, 260),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00FF5A28), Color(0x55FF5A28)])
            .createShader(Rect.fromLTWH(0, base - 260, s.width, 260))..blendMode = BlendMode.plus);
    c.drawPath(city, Paint()..color = const Color(0xFF180A20));
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}

/// A small animated picture of each game for its card.
class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.kind, this.time, this.accent) : super(repaint: time);
  final int kind;
  final ValueNotifier<double> time;
  final Color accent;

  @override
  void paint(Canvas c, Size s) {
    final t = time.value;
    final full = Offset.zero & s;
    if (kind == 0) {
      c.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1E0F33), Color(0xFF6A2238)]).createShader(full));
      // Rooftops scrolling past.
      final ground = s.height * 0.78;
      for (var i = 0; i < 8; i++) {
        final w = s.width * 0.22;
        final x = (i * w * 1.25 - t * 60) % (w * 1.25 * 8) - w;
        final h = s.height * (0.15 + (i * 37 % 5) * 0.06);
        c.drawRect(Rect.fromLTWH(x, ground - h, w, h + s.height), Paint()..color = const Color(0xFF2A1640));
        c.drawRect(Rect.fromLTWH(x, ground - h, w, 3), Paint()..color = const Color(0xFF5A4876));
      }
      // Rocket lifting off on the right.
      final k = (t * 0.25) % 1;
      final rx = s.width * 0.8, ry = s.height * 0.6 - k * s.height * 0.9;
      c.drawCircle(Offset(rx, ry + 30), 14, Paint()..color = const Color(0xCCFFB36B)..blendMode = BlendMode.plus);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(rx, ry), width: 14, height: 46), const Radius.circular(5)),
          Paint()..color = const Color(0xFFEFE9FA));
      // Runner hopping.
      final hop = (math.sin(t * 5)).abs() * s.height * 0.12;
      final px = s.width * 0.3, py = ground - s.height * 0.24 - hop;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px - 6, py - 22, 12, 22), const Radius.circular(4)), Paint()..color = const Color(0xFFEFE9FA));
      c.drawCircle(Offset(px, py - 28), 7, Paint()..color = const Color(0xFFF7F3FF));
      c.drawLine(Offset(px - 4, py - 18), Offset(px - 18, py - 14 + math.sin(t * 9) * 3),
          Paint()..color = const Color(0xFFFF5B3A)..strokeWidth = 3..strokeCap = StrokeCap.round);
    } else {
      c.drawRect(full, Paint()..color = const Color(0xFF241A36));
      // City blocks from above.
      final cell = s.width / 12;
      for (var r = 0; r < 8; r++) {
        for (var col = 0; col < 12; col++) {
          final solid = (r % 3 == 1 && col % 4 != 0) || (col % 4 == 2 && r % 3 != 0 && r != 6);
          if (!solid) continue;
          c.drawRect(Rect.fromLTWH(col * cell, r * cell, cell, cell), Paint()..color = const Color(0xFF1E1430));
          c.drawRect(Rect.fromLTWH(col * cell, r * cell - cell * 0.6, cell, cell), Paint()..color = const Color(0xFF3A2A50));
        }
      }
      // Walker following a looping path, with a trail.
      Offset at(double k) {
        final a = k * math.pi * 2;
        return Offset(s.width * (0.5 + math.cos(a) * 0.38), s.height * (0.55 + math.sin(a * 2) * 0.28));
      }

      for (var j = 0; j < 14; j++) {
        final p = at((t * 0.08 - j * 0.006) % 1);
        c.drawCircle(p, 4 - j * 0.25, Paint()..color = Color.fromRGBO(255, 91, 58, 0.5 * (1 - j / 14)));
      }
      final p = at((t * 0.08) % 1);
      c.drawCircle(p, 8, Paint()..color = const Color(0xFFF7F3FF));
      c.drawCircle(p.translate(0, -1), 4, Paint()..color = const Color(0xFFFFB36B));
      // Pad beacon.
      final pad = Offset(s.width * 0.88, s.height * 0.2);
      final pulse = (t * 1.2) % 1;
      c.drawCircle(pad, 12 + pulse * 24, Paint()..color = accent.withValues(alpha: 0.6 * (1 - pulse))..style = PaintingStyle.stroke..strokeWidth = 2);
      c.drawCircle(pad, 10, Paint()..color = accent);
      // A falling rock shadow.
      final k = (t * 0.6) % 1;
      final rp = Offset(s.width * 0.3, s.height * 0.3);
      c.drawOval(Rect.fromCenter(center: rp, width: 10 + k * 18, height: 6 + k * 9), Paint()..color = Color.fromRGBO(255, 70, 40, 0.2 + k * 0.5));
    }
    c.drawRect(full, Paint()..shader = RadialGradient(colors: [const Color(0x00000000), const Color(0xAA080410)], stops: const [0.55, 1]).createShader(full));
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => false;
}

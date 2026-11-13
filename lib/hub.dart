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
                        const Text('A  &  B  ·  A STORY IN MINI GAMES',
                            style: TextStyle(color: Color(0xFFFF9A6A), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                        const SizedBox(height: 8),
                        _Title(time: _time, still: still, size: narrow ? 40 : 64),
                        const SizedBox(height: 6),
                        const Text('How they met, one moment at a time.', style: TextStyle(color: ashColor, fontSize: 17)),
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
                  child: RepaintBoundary(child: CustomPaint(painter: _PreviewPainter(game.title, time, game.accent))),
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
  _PreviewPainter(this.title, this.time, this.accent) : super(repaint: time);

  /// Picks the picture by the game's title, so new games can add their own.
  final String title;
  final ValueNotifier<double> time;
  final Color accent;

  @override
  void paint(Canvas c, Size s) {
    final t = time.value;
    final full = Offset.zero & s;
    if (title == 'ROOFTOP RUN') {
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
    } else if (title == 'AFTER THE SHOW') {
      _party(c, s, t);
    } else if (title.contains('WARM')) {
      _bench(c, s, t);
    } else if (title.contains('STAGE')) {
      _stage(c, s, t);
    } else {
      c.drawRect(full, Paint()..shader = RadialGradient(colors: [accent.withValues(alpha: 0.5), const Color(0xFF140C22)]).createShader(full));
    }
    c.drawRect(full, Paint()..shader = RadialGradient(colors: [const Color(0x00000000), const Color(0xAA080410)], stops: const [0.55, 1]).createShader(full));
  }

  /// A crowd from above, with A and B drifting toward each other.
  void _party(Canvas c, Size s, double t) {
    final full = Offset.zero & s;
    c.drawRect(full, Paint()..color = const Color(0xFF1E1530));
    for (var i = 0; i < 6; i++) {
      for (var j = 0; j < 3; j++) {
        final h = (i * 50 + j * 70 + t * 40) % 360;
        final beat = math.sin(t * 4 + i + j) * 0.5 + 0.5;
        c.drawRect(Rect.fromLTWH(s.width * 0.3 + i * s.width * 0.067, s.height * 0.35 + j * s.width * 0.067, s.width * 0.063, s.width * 0.063),
            Paint()..color = HSLColor.fromAHSL(1, h, 0.6, 0.15 + beat * 0.15).toColor());
      }
    }
    final r = math.Random(3);
    const outfits = [0xFFF2C14E, 0xFF7AD0C1, 0xFFB58BE8, 0xFFF08A5D, 0xFF5F8DE0, 0xFFA7D86B, 0xFFD9D1EA];
    for (var i = 0; i < 46; i++) {
      final x = r.nextDouble() * s.width, y = r.nextDouble() * s.height;
      final sway = math.sin(t * 2 + i) * 1.5;
      c.drawCircle(Offset(x + sway, y), 6, Paint()..color = Color(outfits[i % outfits.length]));
      c.drawCircle(Offset(x + sway, y - 6), 3.5, Paint()..color = const Color(0xFF3A2A30));
    }
    final k = (math.sin(t * 0.6) * 0.5 + 0.5) * 0.8;
    final pa = Offset.lerp(Offset(s.width * 0.85, s.height * 0.25), Offset(s.width * 0.55, s.height * 0.5), k)!;
    final pb = Offset.lerp(Offset(s.width * 0.15, s.height * 0.8), Offset(s.width * 0.45, s.height * 0.55), k)!;
    for (final (p, col, l) in [(pa, const Color(0xFFE0456A), 'A'), (pb, const Color(0xFF2E9C9C), 'B')]) {
      c.drawCircle(p, 22, Paint()..color = col.withValues(alpha: 0.25)..blendMode = BlendMode.plus);
      c.drawCircle(p, 8, Paint()..color = col);
      final tp = TextPainter(text: TextSpan(text: l, style: const TextStyle(fontFamily: 'Bungee', fontSize: 12, color: inkColor)), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, p - Offset(tp.width / 2, 30));
    }
    if (k > 0.7) {
      final mid = Offset.lerp(pa, pb, 0.5)!;
      c.drawCircle(mid.translate(0, -10 - (t * 20) % 20), 4, Paint()..color = const Color(0xFFFF6B8F));
    }
  }

  /// A red curtain with a gold bar and a spotlight that swells to a beat.
  void _stage(Canvas c, Size s, double t) {
    final full = Offset.zero & s;
    c.drawRect(full, Paint()..color = const Color(0xFF1A0A14));
    final beat = math.pow(math.sin(t * 3).abs(), 6).toDouble();
    final spot = Offset(s.width / 2, s.height * 0.62);
    c.drawCircle(spot, s.height * (0.35 + beat * 0.08), Paint()..shader = RadialGradient(colors: [Color.fromRGBO(255, 230, 190, 0.45 + beat * 0.3), const Color(0x00FFE6BE)])
        .createShader(Rect.fromCircle(center: spot, radius: s.height * 0.45))..blendMode = BlendMode.plus);
    final open = 0.18 + math.sin(t * 0.5).abs() * 0.08;
    for (final side in [0, 1]) {
      final w = s.width * (0.5 - open);
      final x0 = side == 0 ? 0.0 : s.width - w;
      for (var i = 0; i < 7; i++) {
        final fx = x0 + i * w / 7;
        c.drawRect(Rect.fromLTWH(fx, 0, w / 7 + 1, s.height),
            Paint()..shader = LinearGradient(colors: [const Color(0xFF8C1A2A), const Color(0xFFC8303E), const Color(0xFF7A1424)])
                .createShader(Rect.fromLTWH(fx, 0, w / 7, s.height)));
      }
    }
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height * 0.1), Paint()..color = const Color(0xFF7A1424));
    c.drawRect(Rect.fromLTWH(0, s.height * 0.1, s.width, 5), Paint()..color = const Color(0xFFE8B84A));
    c.drawRect(Rect.fromLTWH(0, s.height * 0.86, s.width, s.height * 0.14), Paint()..color = const Color(0xFF3A2414));
  }

  /// Two figures on a bench under a lamp, with snow and a pink glow.
  void _bench(Canvas c, Size s, double t) {
    final full = Offset.zero & s;
    c.drawRect(full, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF140C2A), Color(0xFF2A1640)]).createShader(full));
    final lamp = Offset(s.width * 0.68, s.height * 0.22);
    c.drawCircle(lamp, s.height * 0.6, Paint()..shader = RadialGradient(colors: [const Color(0x55FF5C8A), const Color(0x00FF5C8A)])
        .createShader(Rect.fromCircle(center: lamp, radius: s.height * 0.6))..blendMode = BlendMode.plus);
    c.drawLine(lamp, Offset(lamp.dx, s.height * 0.85), Paint()..color = const Color(0xFF3A2D4E)..strokeWidth = 4);
    c.drawCircle(lamp, 6, Paint()..color = const Color(0xFFFFE3B0));
    final by = s.height * 0.72;
    c.drawRect(Rect.fromLTWH(s.width * 0.25, by, s.width * 0.36, 6), Paint()..color = const Color(0xFF6D4A3A));
    c.drawRect(Rect.fromLTWH(s.width * 0.25, by - 18, s.width * 0.36, 5), Paint()..color = const Color(0xFF6D4A3A));
    for (final (dx, col) in [(0.37, const Color(0xFF2E9C9C)), (0.49, const Color(0xFFE0456A))]) {
      final x = s.width * dx;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 8, by - 26, 16, 26), const Radius.circular(5)), Paint()..color = col);
      c.drawCircle(Offset(x, by - 33), 7, Paint()..color = const Color(0xFFF0C8A8));
    }
    final beat = math.sin(t * 3).abs();
    c.drawCircle(Offset(s.width * 0.43, by - 52 - beat * 4), 4 + beat, Paint()..color = const Color(0xFFFF5C8A));
    final r = math.Random(11);
    for (var i = 0; i < 40; i++) {
      final x = (r.nextDouble() * s.width + math.sin(t + i) * 6) % s.width;
      final y = (r.nextDouble() * s.height + t * (10 + i % 5 * 4)) % s.height;
      c.drawCircle(Offset(x, y), 1 + (i % 3) * 0.5, Paint()..color = const Color(0xCCFFFFFF));
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => false;
}

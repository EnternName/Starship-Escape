import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const voidColor = Color(0xFF0E0A1C);
const ashColor = Color(0xFFB3A9C9);
const inkColor = Color(0xFFF4EFFC);

/// The page around a mini game: a 16:9 stage with a glow, a back button,
/// optional touch controls on top and a caption of keys below.
class StageFrame extends StatelessWidget {
  const StageFrame({super.key, required this.stage, required this.onExit, this.overlay, this.caption = const []});

  final Widget stage;
  final VoidCallback onExit;

  /// Touch controls or anything else drawn over the stage.
  final Widget? overlay;

  /// Short lines under the stage, usually built with [keyHint].
  final List<Widget> caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, 1.2), radius: 1.2, colors: [Color(0xFF2A1226), voidColor]),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            const extra = 44.0 + 40;
            final w = math.min(box.maxWidth - 32, (box.maxHeight - 32 - extra) * 16 / 9).clamp(160.0, 1280.0);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: w,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onExit,
                        style: TextButton.styleFrom(foregroundColor: ashColor),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('MINI GAMES  (Esc)', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                      ),
                    ),
                  ),
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
                      child: Stack(fit: StackFit.expand, children: [stage, ?overlay]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 6, children: caption),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// A caption item such as "← → run": [parts] alternate bold key and plain text.
Widget keyHint(List<String> parts) {
  const plain = TextStyle(color: ashColor, fontSize: 13);
  const bold = TextStyle(color: inkColor, fontSize: 13, fontWeight: FontWeight.w600);
  return Text.rich(TextSpan(style: plain, children: [
    for (var i = 0; i < parts.length; i++) TextSpan(text: parts[i], style: i.isEven ? bold : null),
  ]));
}

bool get isTouchDevice => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// A round touch button that reports press and release.
class TouchButton extends StatelessWidget {
  const TouchButton({super.key, required this.size, required this.label, required this.onChange, this.accent = false});
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
        child: Text(label, style: TextStyle(color: inkColor, fontSize: size < 50 ? 11 : 14, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Drawing and math helpers shared by every mini game.

final math.Random rng = math.Random();
double rand(double a, double b) => a + rng.nextDouble() * (b - a);
double lerpD(double a, double b, double t) => a + (b - a) * t;
double ease(double k) => k < 0.5 ? 2 * k * k : 1 - math.pow(-2 * k + 2, 2) / 2;

String fmtTime(double s) {
  s = math.max(0, s);
  if (s < 10) return s.toStringAsFixed(1);
  final m = s ~/ 60, r = (s % 60).floor();
  return '$m:${r.toString().padLeft(2, '0')}';
}


// ---------- drawing helpers ----------
const fontDisplay = 'Bungee';
const fontBody = 'ChakraPetch';

Color hex(int v, [double a = 1]) => Color(0xFF000000 | v).withValues(alpha: a.clamp(0.0, 1.0));
Color rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a.clamp(0.0, 1.0));
Paint fill(Color c) => Paint()..color = c;
Paint glow(Color c) => Paint()
  ..color = c
  ..blendMode = BlendMode.plus;
Paint stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt}) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = cap
  ..strokeJoin = StrokeJoin.round;
Paint shaderPaint(Shader s, {bool add = false}) => Paint()
  ..shader = s
  ..blendMode = add ? BlendMode.plus : BlendMode.srcOver;
Shader linear(Offset a, Offset b, List<Color> colors, [List<double>? stops]) => ui.Gradient.linear(a, b, colors, stops);
Shader radial(Offset c, double r, List<Color> colors, [List<double>? stops]) => ui.Gradient.radial(c, r, colors, stops);

void rr(Canvas c, double x, double y, double w, double h, double r, Paint p) =>
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p);
void rect(Canvas c, double x, double y, double w, double h, Paint p) => c.drawRect(Rect.fromLTWH(x, y, w, h), p);
void line(Canvas c, double x0, double y0, double x1, double y1, Paint p) => c.drawLine(Offset(x0, y0), Offset(x1, y1), p);

final Map<String, TextPainter> _textCache = {};

/// Draws text with its baseline at [y], like canvas fillText.
void drawText(Canvas c, String s, double x, double y,
    {double size = 14, Color color = const Color(0xFFF4EFFC), String family = fontBody, FontWeight weight = FontWeight.w400, TextAlign align = TextAlign.left}) {
  final key = '$s|$size|${color.toARGB32()}|$family|${weight.value}';
  var tp = _textCache[key];
  if (tp == null) {
    if (_textCache.length > 400) _textCache.clear();
    tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    _textCache[key] = tp;
  }
  final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  final dx = align == TextAlign.center ? x - tp.width / 2 : align == TextAlign.right ? x - tp.width : x;
  tp.paint(c, Offset(dx, y - base));
}

double textWidth(String s, double size, String family, FontWeight weight) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(fontFamily: family, fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp.width;
}


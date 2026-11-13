// Renders frames of the bench game to PNGs for a visual check. Not part of CI.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starship_escape/bench/bench_game.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  testWidgets('snap', (t) async {
    FlutterError.onError = (_) {};
    await t.runAsync(() async {
      await _font('Bungee', ['assets/fonts/Bungee-Regular.ttf']);
      await _font('ChakraPetch', ['assets/fonts/ChakraPetch-Regular.ttf', 'assets/fonts/ChakraPetch-SemiBold.ttf']);
      final g = BenchGame();
      await g.onLoad();
      g.onGameResize(Vector2(960, 540));
      final out = Platform.environment['SNAP_DIR']!;
      Future<void> snap(String name) async {
        final rec = ui.PictureRecorder();
        g.render(ui.Canvas(rec));
        final img = await rec.endRecording().toImage(960, 540);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }

      void run(double s, [void Function()? each]) {
        for (var i = 0; i < (s * 60).round(); i++) {
          each?.call();
          g.step(1 / 60);
        }
      }

      void cozy() {
        if (g.sim.running && g.sim.heat < 52) g.doHug();
      }

      g.startRound();
      run(2.5);
      await snap('cold');
      run(5, cozy);
      await snap('cozy');
      g.doKiss();
      run(0.25);
      await snap('kiss');
      run(9, cozy);
      await snap('call');
      g.doBoard();
      run(1.2);
      await snap('outro1');
      run(1.4);
      await snap('outro2');
      run(1.5);
      await snap('end');
      g.startRound();
      run(6);
      await snap('froze');
    });
  });
}

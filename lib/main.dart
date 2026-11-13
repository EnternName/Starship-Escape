import 'package:flutter/material.dart';

import 'hub.dart';
import 'shared/stage_frame.dart';

void main() => runApp(const StarshipApp());

class StarshipApp extends StatelessWidget {
  const StarshipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Starship Escape',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'ChakraPetch', scaffoldBackgroundColor: voidColor),
      home: const Hub(),
    );
  }
}

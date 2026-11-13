import 'package:flutter/widgets.dart';

import 'game/runner_screen.dart';
import 'games/stage/stage_screen.dart';
import 'street/street_screen.dart';

/// One entry in the mini game menu.
///
/// To add a game: build a screen widget that takes an `onExit` callback
/// (wrap it in `StageFrame` from `shared/stage_frame.dart` to match the look),
/// then add one line to [miniGames].
class MiniGame {
  const MiniGame({required this.title, required this.tagline, required this.view, required this.accent, required this.build});

  final String title;
  final String tagline;

  /// Shown on the card, for example "SIDE VIEW" or "TOP DOWN".
  final String view;
  final Color accent;
  final Widget Function(VoidCallback onExit) build;
}

final List<MiniGame> miniGames = [
  MiniGame(
    title: 'ROOFTOP RUN',
    tagline: 'Run and jump across the collapsing city. Catch a rocket before the last one leaves.',
    view: 'SIDE VIEW',
    accent: const Color(0xFFFF7A3D),
    build: (onExit) => RunnerScreen(onExit: onExit),
  ),
  MiniGame(
    title: 'STREET ESCAPE',
    tagline: 'On foot through the burning streets. Find your way to the launch pad.',
    view: 'TOP DOWN',
    accent: const Color(0xFF9FE3FF),
    build: (onExit) => StreetScreen(onExit: onExit),
  ),
  MiniGame(
    title: 'STAGE FRIGHT',
    tagline: 'Show night on the ship. Hit the timing bar on cue, or A and B go off script.',
    view: 'TIMING',
    accent: const Color(0xFFFF8FB8),
    build: (onExit) => StageScreen(onExit: onExit),
  ),
];

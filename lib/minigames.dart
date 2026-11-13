import 'package:flutter/widgets.dart';

import 'game/runner_screen.dart';
import 'party/party_screen.dart';

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
    title: 'AFTER THE SHOW',
    tagline: 'The venue is packed and B is oblivious. As A, push through the crowd and get noticed.',
    view: 'TOP DOWN',
    accent: const Color(0xFFFF6B8F),
    build: (onExit) => PartyScreen(onExit: onExit),
  ),
  MiniGame(
    title: 'ROOFTOP RUN',
    tagline: 'Run and jump across the collapsing city. Catch a rocket before the last one leaves.',
    view: 'SIDE VIEW',
    accent: const Color(0xFFFF7A3D),
    build: (onExit) => RunnerScreen(onExit: onExit),
  ),
];

part of 'workshop_game.dart';

/// The two workshop sessions. Prompts are written bar by bar, eight slots per
/// bar (eighth notes): L, U, D, R for a move, '.' for a rest. In session II a
/// bar starts with who moves: "A:", "B:" or "AB:" for both together.
class Call {
  const Call(this.beat, this.text);
  final int beat;
  final String text;
}

class SessionDef {
  const SessionDef({
    required this.title,
    required this.number,
    required this.blurb,
    required this.bpm,
    required this.bars,
    required this.calls,
    required this.outro,
    this.together = false,
  });

  final String title, number, blurb, outro;
  final double bpm;
  final List<String> bars;
  final List<Call> calls;

  /// Session II: A and B are partners and prompts belong to one or both.
  final bool together;
}

/// Beats of count-in before the first bar.
const int countIn = 8;

List<Note> buildChart(SessionDef d) {
  final spb = 60 / d.bpm;
  final out = <Note>[];
  for (var bi = 0; bi < d.bars.length; bi++) {
    var bar = d.bars[bi];
    var owner = Owner.a;
    final colon = bar.indexOf(':');
    if (colon >= 0) {
      final w = bar.substring(0, colon);
      owner = w == 'AB' ? Owner.both : w == 'B' ? Owner.b : Owner.a;
      bar = bar.substring(colon + 1);
    }
    bar = bar.replaceAll(' ', '');
    for (var i = 0; i < bar.length; i++) {
      final m = switch (bar[i]) { 'L' => Move.left, 'U' => Move.up, 'D' => Move.down, 'R' => Move.right, _ => null };
      if (m == null) continue;
      out.add(Note((countIn + bi * 4 + i * 0.5) * spb, m, owner));
    }
  }
  return out;
}

const List<SessionDef> sessions = [
  SessionDef(
    title: 'FIRST CLASS',
    number: 'SESSION I',
    blurb: 'Before the Halloween party. You are A. B is in the same class and has not noticed you yet.',
    bpm: 96,
    bars: [
      'L . . . R . . .',
      'L . . . R . . .',
      'U . . . D . . .',
      'U . . . D . . .',
      'L . R . L . R .',
      'U . D . U . . .',
      'L . . . L . R .',
      'R . . . U . D .',
      'L . U . R . D .',
      'L . U . R . D .',
      'U . U . D . . .',
      'L . R . U . . .',
      'R . . . L . . .',
      'R . L . R . L .',
      'D . U . D . U .',
      'L . R . U . . .',
    ],
    calls: [
      Call(0, 'Welcome, class! Mirror me.'),
      Call(6, 'Five, six, seven, eight!'),
      Call(16, 'Reach up! Now sink down.'),
      Call(24, 'Side to side, keep it light.'),
      Call(40, 'Pick it up! Four corners.'),
      Call(56, 'Stay with the beat, everyone.'),
      Call(68, 'Last eight. Make it big!'),
    ],
    outro: 'Lovely work. Same time next week.',
  ),
  SessionDef(
    title: 'PARTNER WORK',
    number: 'SESSION II',
    blurb: 'Before the duet. A and B rehearse as partners. Purple is A, orange is B, gold is both.',
    bpm: 104,
    together: true,
    bars: [
      'A:L . . . R . . .',
      'B:R . . . L . . .',
      'A:U . . . D . . .',
      'B:U . . . D . . .',
      'AB:L . . . R . . .',
      'AB:U . . . D . . .',
      'A:L . R . L . . .',
      'B:R . L . R . . .',
      'A:U . D . U . D .',
      'B:D . U . D . U .',
      'AB:L . U . R . . .',
      'AB:R . U . L . . .',
      'A:L . L R . . U .',
      'B:R . R L . . U .',
      'A:U . D . L . R .',
      'B:U . D . R . L .',
      'AB:L . R . L . R .',
      'AB:U . U . D . D .',
      'AB:L . U . R . D .',
      'AB:U . . . U . . .',
    ],
    calls: [
      Call(0, 'Partners! A leads, B answers.'),
      Call(6, 'Five, six, seven, eight!'),
      Call(24, 'Now together. Breathe as one.'),
      Call(32, 'Trade it back and forth.'),
      Call(48, 'Together again. Bigger!'),
      Call(56, 'Faster now. Trust each other.'),
      Call(72, 'Final phrase. Look at each other!'),
    ],
    outro: 'That was the one. Save it for the show.',
  ),
];

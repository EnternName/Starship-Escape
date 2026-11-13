part of 'stage_game.dart';

/// The ship's show night, in three acts. A (Alessandra) and B (Bogdan) are
/// artists aboard the escape ship. First B performs while A watches from the
/// front row, then A performs while B watches. Later they share the stage in
/// the play "The Last Launch".
class Line {
  const Line(this.text);
  final String text;
}

enum Solo { a, b }

class ActDef {
  const ActDef({
    required this.title,
    required this.marquee,
    required this.blurb,
    required this.lines,
    required this.beats,
    required this.offA,
    required this.offB,
    this.solo,
    this.slow = 3.6,
    this.fast = 2.6,
  });

  final String title, marquee, blurb;
  final List<Line> lines;
  final List<Beat> beats;
  final List<String> offA, offB;

  /// Who performs alone, or null for the duet.
  final Solo? solo;

  /// Seconds between cues at the start and at the end.
  final double slow, fast;
}

/// The three acts. The two solos come first, in a random order per show.
const List<ActDef> acts = [
  ActDef(
    title: "B's SOLO",
    marquee: 'B: ONE PILOT SHOW',
    blurb: 'B performs his comedy act. A watches from the front row.',
    solo: Solo.b,
    slow: 3.4,
    fast: 2.4,
    lines: [
      Line('Good evening, ship! Is this thing on?'),
      Line('They said: B, keep it short. I am short.'),
      Line('So a pilot walks into an airlock...'),
      Line("...and that's why we don't keep pets."),
      Line('To fly, or not to fly? Obviously fly.'),
      Line("The planet's on fire. Lovely sunset, though."),
      Line('I packed light. One sock. Optimistic.'),
      Line("Mom said I'd go far. She meant it literally."),
      Line('Hold the applause. No, wait, keep it.'),
      Line('I dedicate this next bit... to the orb.'),
      Line('For my final trick: catching this. Probably.'),
      Line('Goodnight, and keep your helmets on!'),
    ],
    beats: [
      Beat(0, 0, 0, Pose.stand, 330, 0, Pose.stand),
      Beat(3, 0, 0, Pose.stand, 640, 0.2, Pose.stand),
      Beat(6, 0, 0, Pose.stand, 350, 0.55, Pose.sit),
      Beat(8, 0, 0, Pose.stand, 640, 0, Pose.stand),
      Beat(10, 0, 0, Pose.stand, 330, 0, Pose.kneel),
    ],
    offA: [],
    offB: [
      "Is that my line? I forgot my line.",
      '@#%&! Where was I?',
      'Who moved my mark?!',
      'Hi Mom! Oh no. @#%&.',
      'Uh... rhubarb rhubarb.',
      'I had a joke about that. Gone.',
      'Sorry, the lights. I see nothing.',
      "Is this mic on? Oh. It's an orb.",
    ],
  ),
  ActDef(
    title: "A's SOLO",
    marquee: 'A: SONG FOR THE SKY',
    blurb: 'A sings her song. B watches from the front row.',
    solo: Solo.a,
    slow: 3.4,
    fast: 2.4,
    lines: [
      Line('Pack your bags, the sky is falling'),
      Line("Can't you hear the engines calling?"),
      Line('Farewell streets and farewell rain'),
      Line("I won't see that moon again"),
      Line('Somewhere out past all the stars'),
      Line("There's a place that could be ours"),
      Line('Every rocket needs a spark'),
      Line("Someone's light to cut the dark"),
      Line('Is that pilot... watching me?'),
      Line('Hold your breath and count to three'),
      Line('Home is where we land again'),
      Line('Lift off, lift off, lift off!'),
    ],
    beats: [
      Beat(0, 630, 0, Pose.stand, 0, 0, Pose.stand),
      Beat(3, 330, 0.2, Pose.stand, 0, 0, Pose.stand),
      Beat(5, 610, 0.55, Pose.sit, 0, 0, Pose.stand),
      Beat(8, 330, 0, Pose.stand, 0, 0, Pose.stand),
      Beat(10, 600, 0, Pose.stand, 0, 0, Pose.stand),
    ],
    offA: [
      "Is that my line? I forgot my line.",
      '@#%&! Wrong key!',
      'La la la... lyrics?',
      'Who wrote this song? Oh. Me.',
      'Ow! My @#%& heel!',
      'Stop staring, pilot. No, keep... ugh.',
      'Hmm hmm hmm... @#%&',
      'Sorry. Frog in my throat.',
    ],
    offB: [],
  ),
  ActDef(
    title: 'THE DUET',
    marquee: 'THE LAST LAUNCH',
    blurb: 'Later on, A and B share the stage in the ship\'s play.',
    lines: [
      Line('Captain! The planet is crumbling!'),
      Line('Then we leave tonight. Together.'),
      Line("But the engines haven't flown in years."),
      Line('Neither has my heart. And yet, here we are.'),
      // A circles behind him and they trade sides.
      Line('Why do you circle me so, Captain?'),
      Line('A captain paces. It is tradition.'),
      Line("The fuel gauge says... 'nope'."),
      Line('Then we fly on hope. And fumes.'),
      // They sit on the crates for one last sunset.
      Line('Sit with me. One last sunset.'),
      Line('It was always a little too orange.'),
      // She kneels to inspect the hull.
      Line('Captain, why do you kneel?'),
      Line('To check the hull. Also my knee.'),
      // Finale: center stage, the ship lifts off.
      Line('Countdown! Ten! Nine! Eight!'),
      Line("Skip to one. We're dramatic, not patient."),
      Line('Take my hand, Captain. LIFTOFF!'),
      Line('Farewell, old world. Exit, stage UP!'),
    ],
    // Depth 0 is the front of the stage and 1 the back; the crates sit at 0.55.
    beats: [
      Beat(0, 340, 0, Pose.stand, 620, 0, Pose.stand),
      Beat(4, 720, 1, Pose.stand, 540, 0, Pose.stand),
      Beat(5, 640, 0, Pose.stand, 360, 0, Pose.stand),
      Beat(8, 610, 0.55, Pose.sit, 350, 0.55, Pose.sit),
      Beat(10, 560, 0, Pose.kneel, 400, 0, Pose.stand),
      Beat(12, 545, 0.1, Pose.stand, 415, 0.1, Pose.stand),
    ],
    offA: [
      "Is that my line? I forgot my line.",
      "@#%&! That's not my line!",
      'Stop looking at me like that.',
      'Ow! My @#%& knee!',
      'LINE! Anyone? Line?',
      'Did you just wink at me?',
      'Wait, are we improvising now?',
      'Focus, A. Focus.',
    ],
    offB: [
      "Is that my line? I forgot my line.",
      '@#%&! Where was I?',
      'Sorry. Your eyes. Distracting.',
      'Who moved my mark?!',
      'Hi Mom! Oh no. @#%&.',
      'You smell like cinnamon. Sorry.',
      'Uh... rhubarb rhubarb.',
      'I like your cape. Sorry. Line?',
    ],
  ),
];

/// Crate x positions: B's crate (lower) and A's crate.
const List<double> crates = [350, 610];


const List<String> actNumbers = ['ACT I', 'ACT II', 'ACT III'];

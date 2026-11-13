part of 'stage_game.dart';

/// The ship's play, "The Last Launch". A (Alessandra) plays the Captain and
/// B (Bogdan) plays her Pilot. It is their first time on stage together.
class Line {
  const Line(this.text);
  final String text;
}

/// Cue i goes to B when i is even and to A when it is odd.
const List<Line> script = [
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
];

/// Where everyone stands, from a cue onward. Depth 0 is the front of the
/// stage and 1 the back; the crates sit at depth 0.55.
const List<Beat> beats = [
  Beat(0, 340, 0, Pose.stand, 620, 0, Pose.stand),
  Beat(4, 720, 1, Pose.stand, 540, 0, Pose.stand),
  Beat(5, 640, 0, Pose.stand, 360, 0, Pose.stand),
  Beat(8, 610, 0.55, Pose.sit, 350, 0.55, Pose.sit),
  Beat(10, 560, 0, Pose.kneel, 400, 0, Pose.stand),
  Beat(12, 545, 0.1, Pose.stand, 415, 0.1, Pose.stand),
];

/// Crate x positions for the sunset scene.
const List<double> crates = [350, 610];

/// What slips out when a cue is missed.
const List<String> offScriptA = [
  "Is that my line? I forgot my line.",
  "@#%&! That's not my line!",
  'Stop looking at me like that.',
  'Ow! My @#%& knee!',
  'LINE! Anyone? Line?',
  'Did you just wink at me?',
  'Wait, are we improvising now?',
  'Focus, A. Focus.',
];

const List<String> offScriptB = [
  "Is that my line? I forgot my line.",
  '@#%&! Where was I?',
  'Sorry. Your eyes. Distracting.',
  'Who moved my mark?!',
  'Hi Mom! Oh no. @#%&.',
  'You smell like cinnamon. Sorry.',
  'Uh... rhubarb rhubarb.',
  'I like your cape. Sorry. Line?',
];

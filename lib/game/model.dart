part of 'starship_game.dart';

enum Kind { ground, pitfloor, building, rubble, rock, hill, wall, deck, ledge, pad, stone, slab, bridge, girder, cliff }

/// Anything with an axis-aligned box.
class Box {
  Box(this.x, this.y, this.w, this.h);
  double x, y, w, h;

  bool overlaps(Box o) => x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y;
}

class Solid extends Box {
  Solid(super.x, super.y, super.w, super.h, this.kind, {this.alive = true, this.oneway = false})
      : seed = (x * 7 + y * 13).floor(),
        home = y;

  final Kind kind;
  final bool oneway;
  final int seed;
  bool alive;

  // Crumbling slabs and the collapsing gantry deck.
  double home;
  double crumble = 0;
  double vy = 0;
  double respawn = 0;
  double fadeIn = 0;
  bool falling = false;
  double? collapseAt;
}

class Vent {
  Vent(this.x, this.y, this.w, this.period, this.phase);
  final double x, y, w, period, phase;
  bool on = false;
  bool warm = false;
}

class Trigger {
  Trigger(this.name, this.zone, this.dust, this.lamp, this.act);
  final String name;
  final Box zone;
  final Offset dust;
  final Offset lamp;
  final void Function() act;
  bool fired = false;
}

enum RocketPhase { wait, launch, gone }

class Rocket {
  Rocket(this.id, this.x, this.padY, this.launchT);
  final int id;
  final double x, padY;
  double launchT;
  RocketPhase phase = RocketPhase.wait;
  double t = 0;
  double y = 0;
  double vy = 0;
  bool withPlayer = false;
}

class Bird {
  Bird(this.x, this.y, this.flap, this.hop);
  double x, y, flap, hop;
  double vx = 0, vy = 0, hopUp = 0;
  bool flying = false;
}

class Debris {
  Debris(this.x, this.y, this.vy, this.r, this.landY, this.spin, this.vs);
  double x, y, vy, r, landY, spin, vs;
  bool dead = false;
}

enum PartType { smoke, spark, flame, chunk, grain }

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.g, this.type) : max = life;
  double x, y, vx, vy, life, size, g;
  final double max;
  final Color color;
  final PartType type;
}

class FloatText {
  FloatText(this.x, this.y, this.text, this.color);
  double x, y;
  final String text;
  final Color color;
  double life = 1.2;
  final double max = 1.2;
}

class Banner {
  Banner(this.title, this.sub, this.dur);
  final String title, sub;
  final double dur;
  double t = 0;
}

class Climb {
  Climb(this.x0, this.y0, this.x1, this.y1, this.d);
  final double x0, y0, x1, y1;
  final int d;
  double t = 0;
}

class Pt {
  Pt(this.x, this.y);
  double x, y;
}

class Player extends Box {
  Player() : super(80, ground - 40, 22, 40) {
    apexY = y;
    scarf = List.generate(7, (_) => Pt(90, ground - 30));
  }

  double vx = 0, vy = 0;
  int face = 1;
  bool onGround = false;
  double lastGround = 0;
  late double apexY;
  double stun = 0, stagger = 0, run = 0, sq = 1;
  Climb? climb;
  Rocket? boarded;
  Solid? standingOn;
  late List<Pt> scarf;
}

class WaterTower {
  WaterTower(this.px, this.py, this.bridge);
  final double px, py;
  final Solid bridge;
  double ang = 0, vel = 0;
  bool falling = false;
}

class Girder {
  Girder(this.solid);
  final Solid solid;
  double y = -160;
  final double target = 380;
  bool lowering = false;
}

class Star {
  Star(this.x, this.y, this.s, this.tw);
  final double x, y, s, tw;
}

class Ember {
  Ember(this.x, this.y, this.s, this.v, this.ash);
  double x, y;
  final double s, v;
  final bool ash;
}

class SkyWindow {
  SkyWindow(this.x, this.y, this.f);
  final double x, y, f;
}

class SkyBuilding {
  SkyBuilding(this.x, this.w, this.h, this.broken, this.cut, this.wins, this.fire);
  final double x, w, h, cut;
  final bool broken, fire;
  final List<SkyWindow> wins;
}

class BgRocket {
  BgRocket(this.x, this.y);
  final double x;
  double y;
  double vy = 10;
  final List<Offset> trail = [];
}

import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import '../game/audio.dart';
import '../shared/draw.dart';

part 'party_render.dart';

/// After the Show: a top-down mini game. The show is over and the venue is
/// packed. You are A. B is somewhere in the crowd, chatting away and
/// completely oblivious. Push through the people, get into B's line of sight
/// and stay there until B finally notices you. Nothing ends the round.

const double stageW = 960;
const double stageH = 540;
const double tile = 40;

/// The venue. # wall, S stage, B bar, T table, P pillar, L sofa,
/// D dance floor, b where A (you) starts, a where B starts.
const List<String> venueMap = [
  '########################################',
  '#..........SSSSSSSSSSSSSSSS............#',
  '#..........SSSSSSSSSSSSSSSS............#',
  '#..........SSSSSSSSSSSSSSSS.........a..#',
  '#......................................#',
  '#BB.......P..............P.........T...#',
  '#BB..T..........................T......#',
  '#BB.........DDDDDDDDDDDDDDD............#',
  '#BB.........DDDDDDDDDDDDDDD.....P......#',
  '#BB...P.....DDDDDDDDDDDDDDD............#',
  '#BB.........DDDDDDDDDDDDDDD........T...#',
  '#BB...T.....DDDDDDDDDDDDDDD............#',
  '#BB.........DDDDDDDDDDDDDDD...T........#',
  '#BB....................................#',
  '#......P..........T..........P....LLLL.#',
  '#..T...........................T..LLLL.#',
  '#......................................#',
  '#...................................T..#',
  '#.b..........T.........................#',
  '########################################',
];

final int cols = venueMap[0].length;
final int rows = venueMap.length;
final double worldW = cols * tile;
final double worldH = rows * tile;

enum PartyState { title, play, met }

enum GuestKind { chat, dance, walk }

enum PPart { spark, confetti, heart, note, puff }

class PParticle {
  PParticle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.type, {this.spin = 0}) : max = life;
  double x, y, vx, vy, life, size, spin;
  final double max;
  final Color color;
  final PPart type;
}

class PText {
  PText(this.x, this.y, this.text, this.color, {this.size = 16});
  double x, y;
  final String text;
  final Color color;
  final double size;
  double life = 1.2;
}

class PBanner {
  PBanner(this.title, this.sub, this.dur);
  final String title, sub;
  final double dur;
  double t = 0;
}

/// Anyone in the venue, including A and B.
class Person {
  Person(this.x, this.y, this.outfit, this.hair, this.skin);
  double x, y;
  double vx = 0, vy = 0;
  double fx = 0, fy = 1, run = 0;
  final Color outfit, hair, skin;
  double bubble = 0;
  String say = '';
  static const double r = 11;
}

class Guest extends Person {
  Guest(super.x, super.y, super.outfit, super.hair, super.skin, this.kind, this.ax, this.ay, this.phase);
  final GuestKind kind;

  /// Where the guest wants to be: a spot in a group, on the dance floor,
  /// or a walker's next destination.
  double ax, ay;
  final double phase;
  double lookX = 0, lookY = 0;
  double bumpCd = 0;
}

class Seeker extends Person {
  Seeker(super.x, super.y, super.outfit, super.hair, super.skin, this.label);
  final String label;
  double stun = 0, tx = 0, ty = 0, retarget = 0, lookX = 0, lookY = 0;
}

class PartyGame extends FlameGame with KeyboardEvents {
  PartyGame({this.reduceMotion = false, this.onExit, this.crowdSize = 64});

  final bool reduceMotion;
  final void Function()? onExit;
  final int crowdSize;
  final Sfx sfx = Sfx(ambient: false);

  bool up = false, down = false, left = false, right = false;
  bool tUp = false, tDown = false, tLeft = false, tRight = false;

  PartyState state = PartyState.title;
  double t = 0, real = 0, endT = 0, endTime = 0, metT = 0;
  late Seeker b;
  late Seeker a;
  List<Guest> guests = [];
  List<PParticle> parts = [];
  List<PText> texts = [];
  PBanner? banner;
  Offset cam = Offset.zero;
  double shake = 0;
  bool warm = false;
  int nudges = 0;

  /// How close B is to noticing A, from 0 to 1.
  double attention = 0;
  double noticeLine = 0;
  double _lastDt = 0;
  math.Random _seed = math.Random(1);

  @override
  Color backgroundColor() => const Color(0xFF0E0A1C);

  @override
  Future<void> onLoad() async {
    reset();
    state = PartyState.title;
  }

  // ---------- venue ----------
  String at(int c, int r) => (c < 0 || r < 0 || c >= cols || r >= rows) ? '#' : venueMap[r][c];

  bool solidTile(int c, int r) {
    final k = at(c, r);
    return k == '#' || k == 'S' || k == 'B' || k == 'T' || k == 'P' || k == 'L';
  }

  bool solidAt(double x, double y, double rad) {
    final c0 = ((x - rad) / tile).floor(), c1 = ((x + rad) / tile).floor();
    final r0 = ((y - rad * 0.6) / tile).floor(), r1 = ((y + rad * 0.6) / tile).floor();
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (solidTile(c, r)) return true;
      }
    }
    return false;
  }

  Offset _spawn(String k) {
    for (var r = 0; r < rows; r++) {
      final c = venueMap[r].indexOf(k);
      if (c >= 0) return Offset(c * tile + tile / 2, r * tile + tile / 2);
    }
    return const Offset(100, 100);
  }

  Offset randomFloor({bool dance = false}) {
    for (var i = 0; i < 200; i++) {
      final c = 1 + _seed.nextInt(cols - 2), r = 1 + _seed.nextInt(rows - 2);
      final k = at(c, r);
      if (dance ? k == 'D' : (k == '.' || k == 'D')) {
        return Offset(c * tile + 8 + _seed.nextDouble() * (tile - 16), r * tile + 8 + _seed.nextDouble() * (tile - 16));
      }
    }
    return const Offset(200, 200);
  }

  static const _outfits = [
    0xF2C14E, 0x7AD0C1, 0xB58BE8, 0xF08A5D, 0x5F8DE0, 0xE86A92, 0xA7D86B, 0xD9D1EA, 0x4A3B5C, 0x3D6E8C, 0x8C3D5A, 0xE0B8D0,
  ];
  static const _hairs = [0x2A1A14, 0x5A3A22, 0xC98B4A, 0x1A1228, 0xE8D3A0, 0x8A2A2A, 0x6D6288, 0xB0B0B8];
  static const _skins = [0xF6D2B8, 0xE3B08A, 0xC68A62, 0x9A6440, 0x6E4630, 0xFFE2CC];

  Guest _guest(GuestKind kind, double x, double y) {
    final g = Guest(x, y, hex(_outfits[_seed.nextInt(_outfits.length)]), hex(_hairs[_seed.nextInt(_hairs.length)]),
        hex(_skins[_seed.nextInt(_skins.length)]), kind, x, y, _seed.nextDouble() * 10);
    guests.add(g);
    return g;
  }

  void reset() {
    _seed = math.Random(7);
    guests = [];
    final bs = _spawn('b'), as = _spawn('a');
    a = Seeker(bs.dx, bs.dy, hex(0xE0456A), hex(0x5A2A1A), hex(0xF6D2B8), 'A')..fy = -1;
    b = Seeker(as.dx, as.dy, hex(0x2E9C9C), hex(0x2A1A14), hex(0xF0C8A8), 'B');
    b.tx = b.x;
    b.ty = b.y;
    b.retarget = 2;
    b.lookX = b.x - 40;
    b.lookY = b.y + 30;
    attention = 0;
    noticeLine = 0;
    // Chatting groups of 3 to 5, standing in a loose ring.
    var made = 0;
    final dancers = (crowdSize * 0.3).round();
    final walkers = (crowdSize * 0.15).round();
    while (made < crowdSize - dancers - walkers) {
      final c = randomFloor();
      if ((c - bs).distance < 120 || (c - as).distance < 90) continue;
      final n = 3 + _seed.nextInt(3);
      final rad = 18.0 + n * 3;
      for (var i = 0; i < n && made < crowdSize - dancers - walkers; i++) {
        final ang = i / n * math.pi * 2 + _seed.nextDouble() * 0.4;
        final x = c.dx + math.cos(ang) * rad, y = c.dy + math.sin(ang) * rad * 0.8;
        if (solidAt(x, y, Person.r)) continue;
        _guest(GuestKind.chat, x, y)
          ..lookX = c.dx
          ..lookY = c.dy;
        made++;
      }
    }
    for (var i = 0; i < dancers; i++) {
      final p = randomFloor(dance: true);
      _guest(GuestKind.dance, p.dx, p.dy);
    }
    for (var i = 0; i < walkers; i++) {
      final p = randomFloor(), q = randomFloor();
      _guest(GuestKind.walk, p.dx, p.dy)
        ..ax = q.dx
        ..ay = q.dy;
    }
    parts = [];
    texts = [];
    banner = null;
    t = 0;
    endT = 0;
    metT = 0;
    shake = 0;
    warm = false;
    nudges = 0;
    cam = Offset((a.x - stageW / 2).clamp(0, worldW - stageW), (a.y - stageH / 2).clamp(0, worldH - stageH));
  }

  void startGame() {
    reset();
    state = PartyState.play;
    showBanner('THE SHOW IS OVER', 'B is somewhere in this crowd. Get noticed.', 3.2);
  }

  // ---------- input ----------
  void onStartPress() {
    sfx.init();
    if (state == PartyState.title) startGame();
    if (state == PartyState.met && endT > 1.2) startGame();
  }

  void onStageTap() {
    if (state != PartyState.play) onStartPress();
  }

  void setTouch({bool? u, bool? d, bool? l, bool? r}) {
    sfx.init();
    if (u != null) tUp = u;
    if (d != null) tDown = d;
    if (l != null) tLeft = l;
    if (r != null) tRight = r;
    if (state == PartyState.title && (u ?? d ?? l ?? r ?? false)) startGame();
  }

  static final _up = {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW};
  static final _down = {LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS};
  static final _left = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA};
  static final _right = {LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD};

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    up = keysPressed.any(_up.contains);
    down = keysPressed.any(_down.contains);
    left = keysPressed.any(_left.contains);
    right = keysPressed.any(_right.contains);
    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) onStartPress();
      if (state == PartyState.title && (_up.contains(k) || _down.contains(k) || _left.contains(k) || _right.contains(k))) {
        onStartPress();
      }
      if (k == LogicalKeyboardKey.keyR) {
        sfx.init();
        startGame();
      }
      if (k == LogicalKeyboardKey.keyM) {
        sfx.init();
        sfx.toggleMute();
      }
      if (k == LogicalKeyboardKey.escape) onExit?.call();
    }
    return KeyEventResult.handled;
  }

  // ---------- effects ----------
  void addPart(PParticle p) {
    if (parts.length < 700) parts.add(p);
  }

  void floatText(double x, double y, String s, Color c, {double size = 16}) => texts.add(PText(x, y, s, c, size: size));
  void showBanner(String title, String sub, double dur) => banner = PBanner(title, sub, dur);
  void addShake(double v) {
    if (!reduceMotion) shake = math.max(shake, v);
  }

  void hearts(double x, double y, int n, double spread) {
    for (var i = 0; i < n; i++) {
      final ang = rand(0, math.pi * 2), s = rand(20, spread);
      addPart(PParticle(x, y, math.cos(ang) * s, math.sin(ang) * s - 40, rand(0.8, 1.6), rand(5, 9),
          i.isEven ? const Color(0xFFFF6B8F) : const Color(0xFFFFB3C6), PPart.heart));
    }
  }

  // ---------- movement ----------
  /// Moves a person with wall collision and a nudge around corners.
  void slide(Person p, double dx, double dy) {
    if (!solidAt(p.x + dx, p.y, Person.r)) {
      p.x += dx;
    } else {
      var nudged = false;
      for (var o = 1; o <= 12 && !nudged; o++) {
        for (final s in const [-1, 1]) {
          if (!solidAt(p.x + dx, p.y + s * o, Person.r) && !solidAt(p.x, p.y + s * o, Person.r)) {
            p.y += s * math.min(o.toDouble(), 2.5);
            nudged = true;
            break;
          }
        }
      }
      p.vx = 0;
    }
    if (!solidAt(p.x, p.y + dy, Person.r)) {
      p.y += dy;
    } else {
      var nudged = false;
      for (var o = 1; o <= 12 && !nudged; o++) {
        for (final s in const [-1, 1]) {
          if (!solidAt(p.x + s * o, p.y + dy, Person.r) && !solidAt(p.x + s * o, p.y, Person.r)) {
            p.x += s * math.min(o.toDouble(), 2.5);
            nudged = true;
            break;
          }
        }
      }
      p.vy = 0;
    }
  }

  void face(Person p, double dx, double dy, double dt, [double rate = 12]) {
    final l = math.sqrt(dx * dx + dy * dy);
    if (l < 0.01) return;
    p.fx = lerpD(p.fx, dx / l, math.min(1, dt * rate));
    p.fy = lerpD(p.fy, dy / l, math.min(1, dt * rate));
    final fl = math.max(0.001, math.sqrt(p.fx * p.fx + p.fy * p.fy));
    p.fx /= fl;
    p.fy /= fl;
  }

  /// A is yours: arrow keys or WASD.
  void updatePlayer(double dt) {
    a.stun = math.max(0, a.stun - dt);
    var ix = 0.0, iy = 0.0;
    if (a.stun <= 0 && state == PartyState.play) {
      if (left || tLeft) ix -= 1;
      if (right || tRight) ix += 1;
      if (up || tUp) iy -= 1;
      if (down || tDown) iy += 1;
    }
    final il = math.sqrt(ix * ix + iy * iy);
    if (il > 0) {
      ix /= il;
      iy /= il;
      a.vx += ix * 1800 * dt;
      a.vy += iy * 1800 * dt;
      final v = math.sqrt(a.vx * a.vx + a.vy * a.vy);
      if (v > walkV) {
        a.vx *= walkV / v;
        a.vy *= walkV / v;
      }
      face(a, ix, iy, dt, 14);
    } else {
      final v = math.sqrt(a.vx * a.vx + a.vy * a.vy);
      final f = 1900 * dt;
      if (v <= f) {
        a.vx = 0;
        a.vy = 0;
      } else {
        a.vx -= a.vx / v * f;
        a.vy -= a.vy / v * f;
      }
    }
    slide(a, a.vx * dt, a.vy * dt);
    a.run += math.sqrt(a.vx * a.vx + a.vy * a.vy) * dt * 0.07;
  }

  /// B drifts from group to group, stops to chat, and does not look around
  /// much. While chatting B faces the group; while walking, the way ahead.
  void updateB(double dt) {
    if (state == PartyState.met) {
      b.vx = 0;
      b.vy = 0;
      return;
    }
    b.retarget -= dt;
    final d = Offset(b.tx - b.x, b.ty - b.y);
    final chatting = d.distance < 14;
    if (b.retarget <= 0) {
      b.retarget = rand(5, 9);
      // Stand at the edge of someone's group and face them.
      final pick = guests.isEmpty ? null : guests[rng.nextInt(guests.length)];
      final g = pick == null ? randomFloor() : Offset(pick.x, pick.y);
      final ang = rand(0, math.pi * 2);
      b.tx = g.dx + math.cos(ang) * 26;
      b.ty = g.dy + math.sin(ang) * 20;
      b.lookX = g.dx;
      b.lookY = g.dy;
      if (solidAt(b.tx, b.ty, Person.r)) b.retarget = 0.2;
    }
    final l = math.max(0.001, d.distance);
    const sp = 50.0;
    final want = chatting ? Offset.zero : Offset(d.dx / l * sp, d.dy / l * sp);
    b.vx = lerpD(b.vx, want.dx, math.min(1, dt * 3));
    b.vy = lerpD(b.vy, want.dy, math.min(1, dt * 3));
    final bx = b.x, by = b.y;
    slide(b, b.vx * dt, b.vy * dt);
    if (!chatting && (b.x - bx).abs() + (b.y - by).abs() < sp * dt * 0.2) b.retarget = math.min(b.retarget, 0.4);
    if (chatting) {
      face(b, b.lookX - b.x, b.lookY - b.y, dt, 3);
      if (b.bubble <= 0 && rng.nextDouble() < dt * 0.15) {
        b.bubble = 1.8;
        b.say = _bLines[rng.nextInt(_bLines.length)];
      }
    } else {
      face(b, b.vx, b.vy, dt, 5);
    }
    b.run += math.sqrt(b.vx * b.vx + b.vy * b.vy) * dt * 0.07;
  }

  /// Whether A is standing where B is looking.
  bool get inSight {
    final dx = a.x - b.x, dy = a.y - b.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > sightRange || d < 1) return d < 1;
    return (dx * b.fx + dy * b.fy) / d > math.cos(sightAngle);
  }

  static const double sightRange = 170, sightAngle = 0.6;
  static const _bLines = ['...and then the drummer...', 'ha!', 'no, seriously', 'what a night', 'right?', 'one more song'];
  static const _ignored = ['not looking your way', 'B did not see you', 'still chatting', 'get in front of B'];

  /// A's walking pace.
  static const double walkV = 180;

  static const _nudgeLines = ['oof', 'sorry!', 'excuse you', 'oh, hi', 'whoa', 'careful'];
  static const _chat = ['haha', 'no way', '!', '...', 'wow', 'cheers', 'what a show'];

  void updateGuests(double dt) {
    for (final g in guests) {
      g.bumpCd = math.max(0, g.bumpCd - dt);
      double tx = g.ax, ty = g.ay;
      if (g.kind == GuestKind.dance) {
        tx += math.cos(real * 1.6 + g.phase) * 6;
        ty += math.sin(real * 3.2 + g.phase) * 4;
      }
      if (g.kind == GuestKind.walk && Offset(g.ax - g.x, g.ay - g.y).distance < 10) {
        final p = randomFloor();
        g.ax = p.dx;
        g.ay = p.dy;
      }
      final dx = tx - g.x, dy = ty - g.y;
      final dist = math.sqrt(dx * dx + dy * dy);
      final sp = g.kind == GuestKind.walk ? 45.0 : math.min(60.0, dist * 3);
      final want = dist > 1 ? Offset(dx / dist * sp, dy / dist * sp) : Offset.zero;
      g.vx = lerpD(g.vx, want.dx, math.min(1, dt * 2.5));
      g.vy = lerpD(g.vy, want.dy, math.min(1, dt * 2.5));
      slide(g, g.vx * dt, g.vy * dt);
      g.run += math.sqrt(g.vx * g.vx + g.vy * g.vy) * dt * 0.07;
      switch (g.kind) {
        case GuestKind.chat:
          face(g, g.lookX - g.x, g.lookY - g.y, dt, 4);
        case GuestKind.walk:
          face(g, g.vx, g.vy, dt, 6);
        case GuestKind.dance:
          face(g, math.cos(real * 0.8 + g.phase), math.sin(real * 0.8 + g.phase), dt, 2);
      }
      g.bubble = math.max(0, g.bubble - dt);
      if (g.kind == GuestKind.chat && g.bubble <= 0 && rng.nextDouble() < dt * 0.08) {
        g.bubble = 1.6;
        g.say = _chat[rng.nextInt(_chat.length)];
      }
    }
    // Guests keep a little space from each other.
    for (var i = 0; i < guests.length; i++) {
      final g = guests[i];
      for (var j = i + 1; j < guests.length; j++) {
        final h = guests[j];
        final dx = h.x - g.x, dy = h.y - g.y;
        if (dx.abs() > 22 || dy.abs() > 22) continue;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < 20 && d > 0.01) {
          final push = (20 - d) / 2;
          slide(g, -dx / d * push, -dy / d * push * 0.5);
          slide(h, dx / d * push, dy / d * push * 0.5);
        }
      }
    }
  }

  /// People are soft bodies. Pushing into someone moves them, and they
  /// push their neighbours in turn, so a dense group is slow to get through.
  /// Nothing hurts and nothing ends the round.
  void crowdContact(Seeker s, bool player, double dt) {
    for (final g in guests) {
      final dx = g.x - s.x, dy = (g.y - s.y) * 1.4;
      if (dx.abs() > 26 || dy.abs() > 26) continue;
      final d = math.sqrt(dx * dx + dy * dy);
      const minD = Person.r * 2;
      if (d >= minD || d < 0.01) continue;
      final nx = dx / d, ny = dy / d;
      final overlap = minD - d;
      final share = player ? 0.55 : 0.3;
      slide(g, nx * overlap * share, ny * overlap * share / 1.4);
      slide(s, -nx * overlap * (1 - share), -ny * overlap * (1 - share) / 1.4);
      final speedIn = s.vx * nx + s.vy * ny;
      if (speedIn > 0) {
        // Hand some momentum to the guest and lose some yourself.
        g.vx += nx * speedIn * 0.5;
        g.vy += ny * speedIn * 0.5;
        s.vx -= nx * speedIn * 0.35;
        s.vy -= ny * speedIn * 0.35;
      }
      if (player && g.bumpCd <= 0 && speedIn > 60) {
        g.bumpCd = 2.5;
        nudges++;
        if (g.bubble <= 0 && rng.nextDouble() < 0.5) {
          g.bubble = 1.2;
          g.say = _nudgeLines[rng.nextInt(_nudgeLines.length)];
        }
        sfx.land();
        for (var i = 0; i < 4; i++) {
          addPart(PParticle(s.x + nx * Person.r, s.y + ny * Person.r - 20, rand(-60, 60), rand(-60, 10), 0.35, rand(1.5, 2.5),
              const Color(0xFFFFE9A8), PPart.spark));
        }
      }
    }
  }

  void updateWorld(double dt) {
    a.bubble = math.max(0, a.bubble - dt);
    b.bubble = math.max(0, b.bubble - dt);
    // Confetti drifts down from the ceiling.
    if (rng.nextDouble() < dt * 10) {
      const cols = [0xFFFF6B8F, 0xFFFFD36B, 0xFF9FE3FF, 0xFFB58BE8, 0xFFA7D86B];
      addPart(PParticle(cam.dx + rand(0, stageW), cam.dy - 10, rand(-20, 20), rand(30, 60), rand(6, 10), rand(3, 5),
          Color(cols[rng.nextInt(cols.length)]), PPart.confetti, spin: rand(0, 6)));
    }
    // Music notes from the speakers on stage.
    if (rng.nextDouble() < dt * 2) {
      final x = rng.nextBool() ? 12 * tile : 26 * tile;
      addPart(PParticle(x + rand(-10, 10), 3 * tile, rand(-20, 20), rand(-50, -30), rand(1.5, 2.5), 12, const Color(0xFFE0B8D0),
          PPart.note));
    }
    final dist = Offset(a.x - b.x, a.y - b.y).distance;
    if (state == PartyState.play) {
      final nowWarm = dist < 260;
      if (nowWarm && !warm) {
        floatText(b.x, b.y - 54, 'THERE!', const Color(0xFFFF6B8F));
        sfx.lucky();
      }
      warm = nowWarm;
      // B only notices A standing in front, close, for a moment.
      if (inSight) {
        final near = 1 - (dist / sightRange).clamp(0.0, 1.0);
        attention = math.min(1, attention + dt * (0.45 + near * 0.6));
        if (rng.nextDouble() < dt * 10) {
          addPart(PParticle(a.x + rand(-8, 8), a.y - 44, rand(-10, 10), rand(-40, -20), 1, rand(4, 6), const Color(0xFFFF6B8F), PPart.heart));
        }
      } else {
        attention = math.max(0, attention - dt * 0.25);
        noticeLine -= dt;
        if (dist < 90 && noticeLine <= 0) {
          noticeLine = 4;
          floatText(a.x, a.y - 60, _ignored[rng.nextInt(_ignored.length)], const Color(0xFFB3A9C9), size: 12);
        }
      }
      if (attention >= 1) {
        state = PartyState.met;
        metT = 0;
        endTime = t;
        a.vx = 0;
        a.vy = 0;
        b.vx = 0;
        b.vy = 0;
        face(b, a.x - b.x, a.y - b.y, 1, 100);
        face(a, b.x - a.x, b.y - a.y, 1, 100);
        b.bubble = 0;
        sfx.win();
      }
    }
    if (state == PartyState.met) {
      final before = metT;
      metT += dt;
      // Eye contact first, then a hello each.
      if (before < 0.9 && metT >= 0.9) {
        b.say = 'oh! hi.';
        b.bubble = 2.4;
        sfx.lucky();
      }
      if (before < 1.8 && metT >= 1.8) {
        a.say = 'hi.';
        a.bubble = 2.4;
        hearts((a.x + b.x) / 2, (a.y + b.y) / 2 - 40, 24, 160);
        sfx.lucky();
      }
      if (metT > 1.8 && rng.nextDouble() < dt * 8) hearts((a.x + b.x) / 2, (a.y + b.y) / 2 - 40, 1, 60);
    }
    for (final pt in parts) {
      pt.life -= dt;
      pt.x += pt.vx * dt;
      pt.y += pt.vy * dt;
      pt.spin += dt * 4;
      if (pt.type == PPart.confetti) pt.vx = math.sin(real * 2 + pt.spin) * 25;
      if (pt.type == PPart.heart) pt.vy -= 20 * dt;
      if (pt.type == PPart.puff) pt.size += dt * 12;
    }
    parts.removeWhere((pt) => pt.life <= 0);
    for (final tx in texts) {
      tx.life -= dt;
      tx.y -= 30 * dt;
    }
    texts.removeWhere((tx) => tx.life <= 0);
    final bn = banner;
    if (bn != null) {
      bn.t += dt;
      if (bn.t > bn.dur) banner = null;
    }
  }

  void updateCamera(double dt) {
    double fx, fy;
    if (state == PartyState.title) {
      fx = (math.sin(real * 0.08 - 1.2) * 0.5 + 0.5) * (worldW - stageW);
      fy = (math.cos(real * 0.06) * 0.5 + 0.5) * (worldH - stageH);
    } else if (state == PartyState.met) {
      fx = (a.x + b.x) / 2 - stageW / 2;
      fy = (a.y + b.y) / 2 - stageH / 2;
    } else {
      // Frame both when A is close, so you can see them coming.
      final close = Offset(a.x - b.x, a.y - b.y).distance < 360;
      final mx = close ? (b.x + a.x * 2) / 3 : a.x, my = close ? (b.y + a.y * 2) / 3 : a.y;
      fx = mx + a.vx * 0.3 - stageW / 2;
      fy = my + a.vy * 0.3 - stageH / 2;
    }
    final k = math.min(1.0, dt * (state == PartyState.title ? 1 : 4));
    cam = Offset(lerpD(cam.dx, fx.clamp(0, worldW - stageW), k), lerpD(cam.dy, fy.clamp(-30, worldH - stageH), k));
    shake = math.max(0, shake - dt * 18);
  }

  void step(double dt) {
    real += dt;
    if (state == PartyState.play) t += dt;
    if (state == PartyState.met && metT > 3.4) endT += dt;
    if (state != PartyState.title) {
      updatePlayer(dt);
      updateB(dt);
      crowdContact(a, true, dt);
      crowdContact(b, false, dt);
    }
    updateGuests(dt);
    updateWorld(dt);
    updateCamera(dt);
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = math.min(dt, 0.033);
    _lastDt = dt;
    final steps = dt > 1 / 60 ? 2 : 1;
    for (var i = 0; i < steps; i++) {
      step(dt / steps);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = size.x / stageW;
    canvas.save();
    canvas.scale(scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, stageW, stageH));
    renderScene(canvas, _lastDt);
    canvas.restore();
  }
}

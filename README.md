# Starship Escape

Earth is collapsing. Rockets are leaving one by one, and you have to catch one before the last rocket leaves.

A 2D browser platformer. Open `index.html` in a browser to play; there is nothing to install.

## Controls

- Left / Right or A / D: run
- Space, W or Up: jump (hold for a higher jump)
- R: restart, M: sound on or off
- On a phone, use the on-screen buttons.

## What is in this prototype

- **Forgiving movement:** ledge assist that turns near-miss jumps into a grab and pull-up, coyote time, jump buffering, and a short stagger instead of damage after a long fall.
- **The chase:** three rockets launch on a timer. The HUD shows the time to the next launch, but not how many rockets are left. Catching any rocket wins; the game ends only when the last one leaves without you.
- **Routes:** a rooftop route leads to the first rocket. If you miss it, the gantry collapses and you continue on the street route, which rejoins at the second pad and funnels toward the final launch pad.
- **Soft hazards:** falling debris (with a ground shadow as a warning), fire vents and lava knock you back and cost time. Nothing kills you.
- **Hidden shortcuts:** a water tower that topples into a bridge, a sealed tunnel under the ridge, and a crane that lowers a girder across the chasm. Each one hints at itself with drifting dust, a flickering light and a faint creak, and fires when you run through it.

## Code layout

- `src/game.html` is the game source (markup, styles and script in one file).
- `build.sh` wraps it in a full HTML document as `index.html`. Run it after editing the source.

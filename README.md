# Serpent X

Godot 4.7 vertical slice — 3D third-person martial arts fighter (OG Dragon Ball ground combat, no flight).
Fighters are rigged Mixamo X Bot / Y Bot dummies driven by a baked library of Mixamo + Rapa Motion clips
(boxing, kickboxing, capoeira, ki casts).

## Run

```bash
godot --path /Users/marlon/dev/games/serpent_x
```

Or open the folder in Godot 4.7+ and press Play.

## Flow

Title (live kata showcase) → **Enter Tournament** → choose your school → win 3 rounds → Champion.

Title → **Training** → choose your school → endless session vs a Training Dummy (no timer, nobody dies,
HP refills 0.8 s after a combo ends).

| Training key | Action |
|--------------|--------|
| 1–7 | Dummy mode: Stand, Block, Block after first hit, Random block, Hop, Jab, CPU (full AI) |
| F | Toggle infinite ki (both fighters, on by default) |
| R | Reset positions, HP and ki |
| Tab | Show / hide the move list (inputs, damage, startup frames, effects, cancels) |
| Esc | Back to title |

The top-left panel shows the active dummy mode and the last combo's hits and damage.

## Schools

Same J/K strings and branches for every school; the animation style, stats and U / I / O techniques differ.

| School | Style | HP / speed / power | U | I | O (confirm only) |
|--------|-------|--------------------|---|---|------------------|
| Turtle School | kung fu | 120 / 1.0 / 1.0 | Afterimage Step: invulnerable blink behind | Kame Whip: ki blast | Dragon Fist Rush |
| Crane School | capoeira | 100 / 1.15 / 0.95 | Solar Flare: unblockable blind (they must face you), hits don't wake them | Dodon Ray: very fast thin beam | Crane Kick Barrage |
| Wolf Fang | boxing | 110 / 1.08 / 1.0 | Counter Stance: parry window, auto-counter crumple | Spirit Ball: slow homing ball, launches | Wolf Fang Fist (7 hits) |
| Mountain Fist | elbows & knees | 145 / 0.88 / 1.15 | Iron Body: 3 s super armor (60% damage, no stun) | Earth Splitter: unblockable ground slam, hop over it | Volcano Crush (50 ki) |

| Round | Opponent | Style | Threat |
|-------|----------|-------|--------|
| 1 | Tinto, Street Boxer | jab/cross/hook strings | short strings, no ki techniques |
| 2 | Goro, Iron Bull | elbows, knees, uppercuts | charges ki, Kame Whip zoning |
| 3 | Riku, Crane Phantom | capoeira kicks | Afterimage, Kame Whip, Dragon Fist Rush |

## Controls

| Action | Key |
|--------|-----|
| Move (relative to opponent) | WASD |
| Hop / air attacks | Space, then J / K in the air |
| Dash | Shift (no i-frames) — Dash+J Flying Kick, Dash+K heavy |
| Light / Heavy | J / K |
| Block | L (hold) |
| Charge ki | C (hold, interruptible) |
| School techniques | U / I / O (see table above) |
| Back to title | Esc |

## Combo routes

- Light string: `J J J J` (4th hit knocks down). Any light can branch into a heavy:
  - `J K` Rising Dragon (launcher) → `J` or `I`, or `Space` to chase them into the air
  - `J J K` Knee Crush (crumple, long stun) → `U` or `O`
  - `J J J K` Tornado Heel (knockdown)
- Lights cancel into `U`; Turtle's Afterimage → `J`/`K`/`O` from behind the opponent.
- The `O` rush only fires after a confirm (3-hit string, Afterimage hit, Knee Crush, Solar Flare blind, or a
  Wolf counter hit) — the HUD shows **<RUSH NAME> READY**.
- Damage scales down per hit; combos cap at 12 hits.

## Air combos

- In the air (after a hop or the launcher chase): `J J J` ends in Heaven Kick (blows them away), `K` from
  neutral air, air `J` or air `J J` is Meteor Smash (spikes them into the floor).
- Air attacks hold you level with a juggled opponent, so strings connect while you both float.
- Meteor Smash bounces the opponent off the floor once per combo; they can be hit during the bounce.
- Any hit on an airborne opponent lifts them; the lift shrinks with each juggle hit.
- One air string per jump. Landing mid-attack costs 6 frames of landing lag. Air `K` on a standing
  opponent is a plain jump-in hit.
- Full route: `J K` › `Space` › `J J K` › (bounce) `J K` › `Space` › `J J J` (10 hits).

## Tools

```bash
# Rebuild the animation library (bone remap, root-motion strip, impact-frame detection)
godot --headless --path . --script res://tools/build_anim_library.gd
# AI-vs-AI smoke test for a round (0..2) and school; extra args = frames to screenshot (windowed)
godot --headless --path . --fixed-fps 60 --script res://tools/autoplay.gd -- 2:crane
# Forces every school technique in set-up situations and checks it connects (12 cases)
godot --headless --path . --fixed-fps 60 --script res://tools/tech_test.gd
# Air combos on every school: launcher chase, spike bounce relaunch, jump-in, one string per jump
godot --headless --path . --fixed-fps 60 --script res://tools/air_test.gd
# Training mode: dummy modes, immortality, HP refill, CPU handoff, reset, move list (exits 1 on failure)
godot --headless --path . --fixed-fps 60 --script res://tools/training_test.gd
# Pose contact sheet of clips at their impact frame
godot --path . --script res://tools/contact_sheet.gd -- /tmp/sheet.png jab roundhouse armada@0.5
```

## Design / plan

- Plan: `docs/superpowers/plans/2026-11-25-budokai-lite-vertical-slice.md`

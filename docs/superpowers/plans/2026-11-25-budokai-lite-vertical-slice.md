# Serpent X Budokai-lite Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native — partner said plan + build). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Playable Godot 4.7 slice: title → 3 tournament rounds → champion, with clash/footsies/light techniques on dummy humanoids.

**Architecture:** Autoload `GameState` drives bracket. Shared `Fighter` (`CharacterBody3D`) + `MoveData`/`TechniqueData` resources. `Fight` scene owns arena, HUD, round flow, AI opponent. Techniques + cancels driven by tagged state machine, not AnimationTree complexity for slice.

**Tech Stack:** Godot 4.7.2, GDScript, CharacterBody3D, AnimationPlayer stubs, CSG/capsule dummies.

**Spec:** `docs/superpowers/specs/2026-11-25-budokai-lite-vertical-slice-design.md`

## Global Constraints

- Godot 4.x GDScript; no flight; soft lock one opponent; best-of-one rounds; 75s timer.
- Hop movement-only; dash no i-frames, cancel into light only; T1 invuln; T1/T2 from neutral; T3 confirm-only.
- Title name **Serpent X**; humanoid dummies only; no Z planet beams.
- Commits only if partner later asks (partner rules override plan commit steps — skip commits unless asked).

## Review Focus

- Ki spent when technique interrupted mid-startup → expect spend on commit/active, not on buffer press.
- Blocked heavy must leave enough recovery for light punish → Round 1–2 AI should be punishable.
- T3 from neutral must no-op (confirm-only gate).
- Arena bounds: fighters cannot leave ring or fall forever.
- Soft lock: camera stays usable when fighters cross / hug wall.

## File structure

```
project.godot
autoload/game_state.gd
autoload/feedback.gd
scenes/title/title.tscn + title.gd
scenes/fight/fight.tscn + fight.gd + hud.gd + arena pieces
scenes/fight/camera_rig.gd
actors/fighter.tscn + fighter.gd + hitbox.gd + hurtbox.gd + dummy_mesh.gd
actors/ai_controller.gd
data/move_data.gd + technique_data.gd
data/moves/*.tres (or inline defaults in code for speed)
projectiles/ki_blast.tscn + ki_blast.gd
```

---

### Task 1: Godot project scaffold + title flow

**Files:**
- Create: `project.godot`, `autoload/game_state.gd`, `scenes/title/title.tscn`, `scenes/title/title.gd`, `scenes/fight/fight.tscn` (stub), `icon.svg`
- Test: headless quit-after title loads

**Interfaces:**
- Produces: `GameState` autoload with `round_index: int`, `reset_tournament()`, `advance_round() -> bool`, `notify_round_result(won: bool)`, signals `tournament_won`, `eliminated`
- Produces: main scene = title; Play → `res://scenes/fight/fight.tscn`

- [ ] **Step 1:** Create Godot 4.7 project (`config/features` includes 4.7), InputMap actions: `move_left/right/forward/back`, `light`, `heavy`, `block`, `dash`, `tech1`, `tech2`, `tech3`, `hop`, `pause`, `ui_accept`
- [ ] **Step 2:** Implement `GameState` bracket (rounds 0..2; loss → title; win 3 → champion flag)
- [ ] **Step 3:** Title UI: “Serpent X”, Play, Quit; Play resets tournament and changes to fight
- [ ] **Step 4:** Verify: `godot --headless --path . --import` then `--quit-after 60` with main=title; no SCRIPT ERROR
- [ ] **Step 5:** Skip commit unless asked

---

### Task 2: Arena + dummy fighter locomotion

**Files:**
- Create: `actors/fighter.gd`, `actors/fighter.tscn`, `actors/dummy_mesh.gd`, `scenes/fight/fight.gd`, `scenes/fight/camera_rig.gd`
- Modify: `scenes/fight/fight.tscn`

**Interfaces:**
- Produces: `Fighter` with `team: int`, `max_hp`, `hp`, `ki`, `is_player`, `facing`, `apply_tint(Color)`, movement: walk, hop, dash (no i-frames), gravity
- Produces: `CameraRig` soft-locks mid-point / look at opponent
- Consumes: InputMap from Task 1

- [ ] **Step 1:** Build circular CSG arena + bounds + sun/`WorldEnvironment`
- [ ] **Step 2:** Fighter capsule dummy (body + limbs), player + enemy spawn
- [ ] **Step 3:** Player move/hop/dash; enemy idle stand
- [ ] **Step 4:** Camera spring-arm behind player looking toward enemy
- [ ] **Step 5:** Verify headless fight scene 120 frames; no SCRIPT ERROR; fighters Y≈ground

---

### Task 3: Attack state machine + hitboxes + block/clash

**Files:**
- Create: `data/move_data.gd`, `actors/hitbox.gd`, `actors/hurtbox.gd`
- Modify: `actors/fighter.gd`

**Interfaces:**
- Produces: `MoveData` resource fields: `id`, `startup`, `active`, `recovery`, `damage`, `hitstun`, `blockstun`, `knockback`, `ki_gain_on_hit`, `cancel_tags: PackedStringArray`
- Produces: Fighter states: `IDLE`, `MOVE`, `ATTACK`, `BLOCK`, `HITSTUN`, `BLOCKSTUN`, `DASH`, `TECH`, `DEAD`, `KNOCKDOWN`
- Produces: light/heavy moves; block hold; clash on mutual active hitboxes in window → pushback + ki crumb
- Produces: signals `hit_landed`, `got_hit`, `blocked_hit`, `clashed`, `died`

- [ ] **Step 1:** Implement frame-counted attack phases + Area3D hit/hurt
- [ ] **Step 2:** Block reduces damage (~15% chip), applies blockstun to defender / recovery on attacker
- [ ] **Step 3:** Combo counter soft cap ~6 then knockdown
- [ ] **Step 4:** Verify: scripted headless or manual — light string connects; blocked heavy punishable (attacker recovery > defender blockstun)

---

### Task 4: Techniques T1–T3 + cancel graph + ki

**Files:**
- Create: `data/technique_data.gd`, `projectiles/ki_blast.gd`, `projectiles/ki_blast.tscn`
- Modify: `actors/fighter.gd`, `scenes/fight/fight.gd`

**Interfaces:**
- Produces: `try_technique(id) -> bool` respecting ki + gates (T3 needs `confirm_ready` from 3+ hit string or T1 land)
- Produces: T1 Afterimage Step (i-frames + reappear, link), T2 Kame Whip blast, T3 Dragon Fist Rush
- Produces: cancel graph per spec; feedback hooks on connect

- [ ] **Step 1:** Ki gain on hit/block; spend on tech commit
- [ ] **Step 2:** T1/T2/T3 behaviors + VFX stubs (trail/flash mesh)
- [ ] **Step 3:** Cancels: L→L→L, L→H, L→T1, H→T2, T1→L/H, confirm→T3
- [ ] **Step 4:** Verify T3 from neutral fails; Light→T1→T3 path works with enough ki

---

### Task 5: Tournament AI + HUD + round flow + juice

**Files:**
- Create: `actors/ai_controller.gd`, `scenes/fight/hud.gd`, `autoload/feedback.gd`
- Modify: `scenes/fight/fight.gd`, `autoload/game_state.gd`

**Interfaces:**
- Produces: AI profiles `tinto`, `goro`, `riku` matching spec table
- Produces: HUD HP/ki/timer/round; KO / champion / eliminated overlays
- Produces: `Feedback` hitstop + camera trauma on hit tiers
- Consumes: `GameState`, fighter signals

- [ ] **Step 1:** Round start announce → fight → KO/timeout → advance or eliminate
- [ ] **Step 2:** Three AI profiles + tint/name
- [ ] **Step 3:** HUD + results screens back to title
- [ ] **Step 4:** Hitstop/shake/`Feedback`
- [ ] **Step 5:** Full path verify: title→fake wins or play → champion; grep SCRIPT ERROR clean

---

## Self-review notes

- Spec coverage: intro, 3 rounds, techniques, combos, dummies, no flight, clash, soft spectacle — mapped to tasks 1–5.
- Commits deferred (user rule).
- Proportion: lean; combat numbers left as exported defaults on resources for tuning.

---

## Status (animation pass, 2026-11-25)

- Capsule dummies replaced by rigged Mixamo X Bot / Y Bot with a baked 62-clip library
  (`tools/build_anim_library.gd`): root motion stripped, strikes cropped and time-warped so the visual
  impact frame lands on the hitbox frame.
- Four styles (turtle / boxer / brawler / capoeira) map the shared frame-data moveset to different clips.
- Added ki charge (C), hit effects (pop / crumple / knockdown + get-up), combo counter, technique callouts,
  confirm prompt, additive VFX (`Fx`), synthesized + licensed SFX (`Sfx`), slow-mo KO, live 3D title.
- Verified: headless AI-vs-AI runs of all three rounds end in KO with no script errors; windowed
  screenshots of title and round 3 checked.

# Serpent X Roadmap

Post–vertical-slice backlog: fun first, then AAA polish. One item per session.

## Session protocol

1. Pick the first unchecked item whose **Depends on** items are done (or one the user names).
2. Mark it `[~]` here, then read its **Touch points** before designing.
3. Build it. Every gameplay item ships with a headless test script in `tools/`, following
   `tools/tech_test.gd` / `tools/air_test.gd` (exits 1 on failure). Run the existing suites too; they
   must stay green.
4. Update `README.md` (controls, mechanics, tool commands) for anything player-facing.
5. Mark the item `[x]`, add the date and a one-line note under it (what shipped, what was cut).

Status: `[ ]` todo · `[~]` in progress · `[x]` done · `[-]` dropped

---

## Phase 1 — Core fun

### [-] 1. Ring-outs
2026-11-27: dropped. Not every stage will have a ring, so ring-outs can't be a core rule.
Signature mechanic of the original Dragon Ball tournament. Positioning matters, and losing players get a
comeback route.
- **Scope:** knockback finishers (Heaven Kick, Tornado Heel, Spirit Ball launch, Wolf counter, rush
  enders) can carry a fighter past the ring edge. Touching the grass while not in control = **RING OUT**:
  instant round win, unique banner, camera shot of the fall. Walking, dashing and Afterimage stay
  clamped, so you can't step out by accident.
- **Touch points:** `actors/fighter.gd` boundary clamp (`ARENA_HALF`, ~line 1209) and the Afterimage
  target clamp (~line 772); `scenes/fight/fight.gd` `_finish_round` (new result type);
  `scenes/fight/fight.tscn` ring/grass meshes (edge must match `ARENA_HALF`);
  `actors/ai_controller.gd` (avoid backing toward the edge, prefer launchers when the opponent is near it).
- **Done when:** test script forces each knockback finisher at the edge and asserts ring-out; walking or
  dashing into the edge never triggers one; training mode respawns instead of ending the round.

### [x] 2. Defensive triangle: throws, guard meter, wakeup options, Vanish
2026-11-27: J+L throw (7f, tech with J in 10f, simultaneous auto-tech), guard meter + Guard Crush (4 blocked
heavies), getup / delay / roll L-R-back (18 of 26f invulnerable), Vanish (Shift in hitstun, 50 ki, once per
combo); AI throws turtlers, techs, varies wakeup, Vanishes; dummy modes 8 Tech throws / 9 Random wakeup;
`tools/defense_test.gd` (19 checks). Cut: dedicated grab / roll clips (reuses elbow, knee, dash clips); the
crush has no unique SFX file yet (layered shock_big + block + clash).
Holding block is currently safe against everything. This adds an offense/defense rock-paper-scissors and
gives ki a reason to be saved.
- **Scope:**
  - **Throw** (J+L, short range, beats block and charge, loses to attacks, throw-tech window).
  - **Guard meter**: drains on blocked hits, regenerates when not blocking; empty = guard crush (long
    stun, unique VFX/SFX). Shown on the HUD.
  - **Wakeup options** after knockdown: getup in place, roll left / right / back, delayed getup.
  - **Vanish escape**: 50 ki mid-hitstun, teleport behind the attacker, limited to once per combo.
    Reuse the Afterimage blink.
- **Touch points:** `actors/fighter.gd` (new states: throw, guard crush, roll; knockdown getup ~line
  1086; `_reset_combo`); `data/moveset.gd` / `data/move_data.gd` (throw move); `scenes/fight/hud.gd`
  (guard bar); `project.godot` input map; `actors/ai_controller.gd` (throw blockers, tech throws, vary
  wakeup); `scenes/fight/move_list.gd`; `actors/training_dummy.gd` (new modes: throw tech, random wakeup).
- **Done when:** throw beats block and loses to a jab in tests; guard crush triggers after N blocked
  heavies; each wakeup option is reachable and invulnerable for the right frames; Vanish costs ki and
  works at most once per combo.

### [ ] 3. Beam struggles
Two ki projectiles meeting currently pass through or cancel silently.
- **Scope:** beam-vs-beam (and blast-vs-blast) contact starts a struggle. Both fighters lock in pose and
  mash; the contact point slides toward the loser; the winner's beam detonates on the loser. Side camera
  angle, growing glow, rising audio, screen shake that ramps up.
- **Touch points:** `projectiles/ki_blast.gd` / `ki_blast.tscn` (collision between projectiles);
  `actors/fighter.gd` (struggle state, mash input); `scenes/fight/camera_rig.gd` (struggle shot);
  `autoload/fx.gd`, `autoload/sfx.gd`; `actors/ai_controller.gd` (mash rate per difficulty).
- **Done when:** test fires opposing blasts, asserts struggle starts, scripted mash decides the winner,
  loser takes the damage, and both fighters return to neutral.

### [ ] 4. Ultimates and low-HP power-up
- **Scope:**
  - One **ultimate per school** at 100 ki (e.g. Turtle Kamehameha-style beam; Crane, Wolf and Mountain
    get their own). Cinematic camera cut, brief freeze on activation, unique callout.
  - **Power-up state** below 25% HP: once per round, timed, faster and stronger, gold aura. Comeback tool.
- **Touch points:** `data/loadouts.gd` (school kits), `data/moveset.gd`, `actors/fighter.gd` (tech
  dispatch, aura via `Fx.make_aura`), `scenes/fight/camera_rig.gd`, `scenes/fight/hud.gd` (ultimate-ready
  indicator), `autoload/game_state.gd` (opponent profiles use them), `scenes/fight/move_list.gd`.
- **Depends on:** 13 (cinematic camera) for the full presentation; can ship first with a basic camera cut.
- **Done when:** extend `tools/tech_test.gd` so every school's ultimate connects in a setup situation;
  power-up triggers once per round under the HP threshold and expires.

---

## Phase 2 — Opponents and structure

### [ ] 5. Smarter AI
`ai_controller.gd` uses random-weighted choices; blocking is a dice roll (`block_skill * 0.35`) and it
doesn't adapt.
- **Scope:**
  - Difficulty tiers (Easy / Normal / Hard / Master) as profile multipliers.
  - Punish after blocking an attack; anti-air jump-ins; whiff-punish window by difficulty.
  - **Pattern reading**: track the player's last N openers; if one repeats, raise the counter chance
    (block, Counter Stance, throw).
  - Personalities beyond tuning numbers: rushdown, zoner, counter-fighter.
  - Uses the new systems: throws/tech, Vanish, beam mashing, ultimates.
- **Touch points:** `actors/ai_controller.gd` (consider utility scoring per tick), `autoload/game_state.gd`
  opponent profiles, `tools/autoplay.gd`.
- **Depends on:** 2–4 for full coverage (can start earlier and extend).
- **Done when:** headless AI-vs-AI win rates order correctly by difficulty over many seeds; a scripted
  player repeating one opener gets countered more often after a few repeats.

### [ ] 6. Tournament structure
- **Scope:** best-of-3 rounds per opponent (round win pips on the HUD); bracket screen between fights;
  short pre-fight banter lines; a final boss with a unique rule (e.g. a giant with super armor and slow
  huge attacks, or an armored mercenary immune to stun). Difficulty selection feeds item 5.
- **Touch points:** `autoload/game_state.gd` (`MAX_ROUNDS`, `round_index`, `notify_round_result`),
  `scenes/fight/fight.gd` (round loop, intro), `scenes/fight/hud.gd`, new `scenes/bracket/`.
- **Done when:** lose one round and still advance by winning 2 of 3; the bracket shows progress; the boss
  rule is covered by a test.

---

## Phase 3 — Presentation (AAA feel)

### [ ] 7. Music, announcer and voices
There is no music, only 14 SFX clips generated by `tools/gen_sfx.py`. This is the largest single
perceived-quality gain.
- **Scope:** music bus with title, select and fight tracks; layered fight music (intensity layer when
  either fighter is below 30% HP or in a beam struggle); announcer lines (round N, fight, K.O., perfect,
  time); per-character kiai, grunt and hurt voices; crowd ambience with reactions to big hits.
  Audio bus layout with a ducking side-chain for the announcer.
- **Touch points:** `autoload/sfx.gd` (extend into a full audio manager, or add `autoload/music.gd`),
  `default_bus_layout.tres`, `scenes/fight/fight.gd` intro/KO hooks, `assets/audio/`. Source royalty-free
  assets (record licenses in `assets/third_party/.asset-sources.json`).
- **Done when:** every banner has an announcer line; music layers change on cue; no clipping at max
  combo spam (check bus peak).

### [ ] 8. Cel-shaded anime look
Fighters are tinted X Bot / Y Bot test dummies. Toon shading hides that cheaply and matches the
Dragon Ball tone.
- **Scope:** toon ramp shader (2–3 bands + rim light) for fighters; inverted-hull or post-process
  outline; tune `Environment` (glow, tonemap) to match; apply to the arena too so it stays consistent.
- **Touch points:** `actors/fighter_model.gd` (material setup ~lines 36–47, afterimage ghost ~line 123),
  new `assets/shaders/toon.gdshader`, `scenes/fight/fight.tscn` WorldEnvironment,
  `scenes/fight/arena_tiles.gdshader`, `scenes/title/title.tscn`.
- **Done when:** screenshot comparison via `tools/contact_sheet.gd` and `tools/autoplay.gd` frames;
  stays at 60 fps.

### [ ] 9. Impact VFX and arena damage
- **Scope:** anime **impact frames** on finishers (1–2 frames of inverted black and white); speed lines
  on dashes and rushes; limb motion trails on heavies; ground cracks and crater decals from Earth
  Splitter, Meteor Smash and slam knockdowns that persist for the round; dust puffs on knockdown and
  landing; debris chunks.
- **Touch points:** `autoload/fx.gd`, `autoload/feedback.gd` (tier 3 hook), `actors/fighter.gd` hit and
  knockdown sites, new full-screen `CanvasLayer` shader for impact frames.
- **Done when:** each effect visible in autoplay screenshots; decal count capped (pool) so long fights
  don't drop frames.

### [ ] 10. Hit feel upgrades
- **Scope:** defender model jitter during hitstop (camera-only shake today); directional hit reactions
  (high / low / left / right / gut); partial ragdoll or physics flop on the KO hit; gamepad rumble by hit
  tier; foot IK so feet plant on the ring.
- **Touch points:** `autoload/feedback.gd`, `actors/fighter_model.gd`, `actors/fighter.gd` (hit
  reaction selection), `tools/build_anim_library.gd` (extra hit-reaction clips from the Mixamo library).
- **Done when:** hit reaction varies with attack direction in contact sheets; rumble fires on device 0.

### [ ] 11. Living arena and crowd
- **Scope:** crowd in the stands (instanced billboards or low-poly animated figures via MultiMesh)
  that cheer on big hits and KOs; wind, banners and lantern flicker; time-of-day or weather variants per
  round.
- **Touch points:** `scenes/fight/fight.tscn` (stands, pillars, lanterns), new `scenes/fight/crowd.gd`,
  ties into item 7 crowd audio.
- **Done when:** crowd reacts to `Feedback.pulse` tier 3; draw calls stay bounded (MultiMesh).

### [x] 12. Real character models
2026-11-25: 7 Meshy fighters (4 schools + Tinto, Goro, Riku; 203 credits) via concept → smart topology
→ rig, all 62 clips retargeted by `tools/retarget_anims.gd`, toon-banded materials in `fighter_model.gd`.
Cut: costume variants; Riku's tunic hem stretches on high kicks (skin weights); Training Dummy stays Y Bot.
- **Scope:** a distinct rigged fighter per school and per tournament opponent, replacing X Bot / Y Bot.
  Pipeline: Meshy (smart topology, T-pose, rigged) or sourced models → retarget onto the existing anim
  library. Costume variants per fighter.
- **Touch points:** `tools/build_anim_library.gd` (bone remap), `actors/fighter_model.gd`,
  `data/loadouts.gd`, `autoload/game_state.gd` profiles.
- **Depends on:** 8 (the shader must work on the new meshes).
- **Done when:** every clip plays on every model without broken bones (contact sheet per model);
  hurtboxes still line up.

### [ ] 13. Cinematic camera
- **Scope:** scripted cut angles for O rushes, ultimates and beam struggles; KO replay of the final hit
  from a side angle in slow motion; walk-in intros (replacing orbit plus banners); victory poses with a
  camera move.
- **Touch points:** `scenes/fight/camera_rig.gd` (add a shot/sequence API beside `focus()`),
  `scenes/fight/fight.gd` intro/KO flow, `autoload/feedback.gd` slow-mo.
- **Done when:** each cinematic is triggered in a test and the camera returns to the fight cam with no
  snap; the player can skip intros.

---

## Phase 4 — UX and modes

### [ ] 14. Pause, settings and results screens
Esc currently drops straight to the title from a fight (`scenes/fight/fight.gd` `_process`).
- **Scope:** pause menu (resume, move list, restart, quit with confirm); settings (master, music, SFX and
  voice volume; key and pad rebinding; display mode, vsync; screen-shake intensity; persisted);
  end-of-fight results (max combo, damage dealt, techniques used, style grade); controller button
  prompts that switch with the last input device.
- **Touch points:** `scenes/fight/fight.gd`, new `scenes/ui/pause_menu`, `scenes/ui/settings`,
  `autoload/game_state.gd`, `project.godot` input map, `scenes/fight/move_list.gd` (reuse in pause).
- **Depends on:** 18 for persisting settings (or ship a minimal ConfigFile first and let 18 absorb it).
- **Done when:** pause freezes gameplay including hitstop/slow-mo timers (`Feedback` runs
  `PROCESS_MODE_ALWAYS`; check this explicitly); rebinding survives a restart.

### [ ] 15. Character select upgrade
- **Scope:** 3D model turntable per school, portraits, stat bars, technique preview clip, costume picker.
- **Touch points:** `scenes/select/select.gd`, `select.tscn`.
- **Depends on:** 12 for real models (works with dummies first).

### [ ] 16. Local 2-player versus
- **Scope:** VS mode from the title; both players pick schools; per-device input. Player input currently
  reads global actions (`Input.is_action_*` in `actors/fighter.gd` ~lines 216–235), so input needs a
  per-device layer (an input source object per fighter, matching how `set_ai_input` feeds the AI).
  Camera must frame both fairly (the current rig sits behind the player).
- **Touch points:** `actors/fighter.gd` input reading, `project.godot`, `scenes/fight/camera_rig.gd`
  (neutral side-on framing for VS), `scenes/select/`, `autoload/game_state.gd`.
- **Done when:** two pads control two fighters independently; keyboard plus pad works; a test drives
  both via injected input sources.

### [ ] 17. Combo trials and survival
- **Scope:** combo trials per school (scripted target routes; step-by-step checklist UI; built on the
  training session and dummy); survival (endless opponents, partial HP refill between, high score);
  input display and frame advantage readout added to training.
- **Touch points:** `scenes/fight/training.gd`, `actors/training_dummy.gd`, `scenes/fight/hud.gd`,
  `autoload/game_state.gd`.
- **Done when:** each trial is completable by a scripted input replay in a headless test.

### [ ] 18. Save system and unlocks
- **Scope:** persistent profile (settings, tournament clears per school and difficulty, trial
  completion, survival best); unlocks (costumes, the boss as playable, a secret school) earned from
  progress. Versioned save format.
- **Touch points:** new `autoload/save.gd` (`user://`), `autoload/game_state.gd`, `scenes/select/`.
- **Done when:** a save round-trips in a test; a corrupted or old-version file falls back safely.

---

## Phase 5 — Long term

### [ ] 19. Online play with rollback netcode
The AAA bar for fighting games, and a major undertaking: requires a deterministic fixed-step
simulation (no `Engine.time_scale` for hitstop inside the sim, deterministic RNG, state
save/restore for every fighter, projectile and FX-relevant flag).
- **Depends on:** 16 (input source abstraction). Start with a determinism audit and a local
  "two-sims-in-lockstep" test before any networking.

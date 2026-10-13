# Towerbound

## Purpose and current state

Towerbound is a fantasy game combining a trading card game with 2D tower defense. The immediate goal is a small playable prototype that tests drawing cards, spending mana to build towers, and defending a castle against enemy waves.

This file is the project brief and implementation roadmap for agents. The milestones below are planned work, not completed features. Build them in order and keep the project runnable after each milestone.

The repository is a Godot 4.7 project using GDScript, with the battle prototype described in the log below and an iOS export preset. Preserve its portrait mobile foundation:

- Reference viewport: 720 × 1280, with an interface that adapts to phone aspect ratios.
- Entry scene: `scenes/main.tscn`; its root script is `scripts/battle/battle_screen.gd`. See **Architecture** for how the code fits together.
- Renderer: GL Compatibility.
- Existing simulator workflow: `run_ios_simulator.sh`.
- `build/` contains generated export output and is excluded from version control.

## Game vision

Players bring a 16-card deck into a level, draw four cards, and spend mana to place towers or cast spells. A castle starts with 20 health and must survive 10 waves. Enemies that reach it deal damage based on their type. Killing enemies grants a small amount of mana.

Each wave begins with 15 seconds of preparation, followed by approximately 15 seconds of combat. Cards can be played during both preparation and combat. Clearing all 10 waves with castle health remaining wins the level.

The setting is fantasy, with humans and/or elves defending against skeletons, goblins, giants, and other monsters. Example cards include Archer Tower, Cannon Tower, Fireball, and Slow.

### Card collection and economy

These are separate dimensions of a card:

| Dimension | Options | Intended effect |
| --- | --- | --- |
| Rarity | Common, uncommon, rare, epic, legendary | Collection rarity; exact distribution and balance are future work |
| Finish | Base, shiny, holographic | Shiny receives a small stat increase; holographic receives a slightly larger increase |
| Art treatment | Standard, full art | Cosmetic only; full art can accompany any finish |

Players will earn gold by winning levels and selling cards, then spend gold on card packs. Packs will also come from other reward sources. Exact rewards, pack contents, probabilities, and variant bonuses are not yet defined.

## First playable prototype

Implement one map, one tower card (Archer Tower), one enemy (skeleton), and a complete ten-wave battle loop. Prioritize clear interactions, readable graphics, and reliable mechanics. Keep animation minimal.

Defer spells, other tower and enemy types, collection management, deck editing, rarity and finish bonuses, full art variants, packs, selling, gold, and persistence. Preserve those ideas in the vision without building their systems during this slice.

### Confirmed gameplay choices

- The deck contains 16 cards and the initial hand contains four.
- Cards can be played during both preparation and combat.
- Unplayed cards remain in hand between waves. At the start of each preparation phase, draw until the hand contains four cards.
- Playing a card removes it from the hand. It does not immediately draw a replacement.
- Preparation lasts 15 seconds; combat should take approximately 15 seconds.
- The castle starts with 20 health, and the level contains 10 waves.

### Provisional implementation and tuning defaults

These defaults make the first slice implementable. They are not final game balance. Keep their values in editable resources or configuration and record deliberate changes in the tuning log below.

| Setting | Initial value |
| --- | --- |
| Prototype deck | 15 cards: 4 Archer Tower, 2 Cannon Tower, 2 Fireball, 2 Upgrade, 2 Repair (Heal), 1 Barricade, 1 Oil Slick, 1 Chill (changed from 16 Archer Towers; see log) |
| Starting mana | 6 (changed from 8, then 4, then 5; see log) |
| Mana cap | 10 |
| Archer Tower cost | 2 mana |
| Mana per skeleton killed | 1 |
| Skeleton health | 1.5 (changed from 3, then 2; see log) |
| Skeleton castle damage | 0.85 (changed from 1; see log) |
| Archer Tower damage | 1.5 per shot (changed from 1; see log) |
| Archer Tower firing interval | 1 second |
| Archer Tower range | 180 world units at the reference resolution |
| Enemies per wave | 16 on wave one, rising to 89 on wave ten in tight clumps (see `tools/make_waves.py` and log) |

**Deck and mana**

- Shuffle the deck at level start. Played cards enter a discard pile.
- When drawing from an empty deck, shuffle the discard pile into the draw pile and continue drawing. If both piles are empty, stop drawing without error.
- Placed towers persist until the level ends. Their cards can cycle through the discard and draw piles independently of the towers already on the map.
- Mana carries between waves. There is no passive regeneration. Mana is capped at 10, shown by a 0–10 bar on the right edge.
- Grant mana exactly once per killed enemy. An enemy that reaches the castle grants no mana.

**Map and placement**

- Use a fixed winding path from an enemy entrance to the castle, with visibly marked build slots beside it.
- Tap a card, then an available slot to place its tower. Mouse clicks should support the same flow for desktop development.
- Preview the tower's range when selecting a placement. Tapping the selected card again or pressing Escape cancels selection.
- Occupied slots, the path, the castle, and areas outside build slots are invalid placement targets.
- Check phase, slot availability, and mana when committing placement. A successful placement spends one card and its mana cost exactly once. Cancellation or invalid placement spends neither.
- Keep selected cards selected after an invalid placement so the player can try another slot. Clear selection when the card is played, canceled, or the battle ends.

**Combat and battle phases**

- Skeletons follow the fixed path. At the castle, apply damage once and remove the enemy.
- Towers target the in-range enemy furthest along the path and fire on their cooldown.
- Use simple visible arrow projectiles. An arrow whose target has disappeared is removed without applying damage or rewards.
- Tune skeleton speed and spawn spacing so ordinary waves resolve in approximately 15 seconds. This is a pacing target, not a hard combat cutoff.
- A wave ends only after all scheduled enemies have spawned and every enemy has died or reached the castle. Do not delete survivors when a timer reaches 15 seconds.
- After waves 1–9 resolve, refill the hand and begin the next 15-second preparation phase.
- Castle health reaching zero causes immediate defeat. Defeat takes precedence if the last enemy also resolves the last wave. Otherwise, clearing wave 10 causes victory.
- Result states stop spawning, combat, gameplay timers, and card placement. Retry starts a fresh level with a new shuffled deck, 20 health, 8 mana, and no placed towers or enemies.

## Implementation milestones

All milestones begin unchecked. Complete each milestone's acceptance criteria before moving on; mark it complete and briefly record what was validated.

### 1. Map and basic interface

**Status:** [ ] Not started  
**Depends on:** Existing Godot starter project.

**Objective:** Establish the playable screen and visual layout.

- Create one 2D battlefield with a winding path, enemy entrance, castle, and clearly marked build slots.
- Reserve the top HUD for castle health, mana, wave number, and phase status/countdown. Reserve the bottom for four cards.
- Use simple cohesive fantasy graphics, readable text, and generous touch targets. Primitive shapes or lightweight placeholder assets are acceptable if the scene is understandable.
- Replace the current tower-climbing placeholder copy with the castle-defense premise.
- Keep the battlefield and card hand visually distinct so UI interaction cannot accidentally place a tower.

**Acceptance:** The map, castle, slots, HUD, and four-card area fit the portrait screen without overlap or clipping and remain usable across phone aspect ratios.

### 2. Skeleton movement and castle damage

**Status:** [ ] Not started  
**Depends on:** Milestone 1.

**Objective:** Establish enemies, a defended objective, and a loss condition.

- Create a reusable skeleton scene with health, path movement, and castle damage values.
- Add a basic spawn mechanism and track active enemies.
- Apply damage and remove a skeleton exactly once when it reaches the castle.
- Update the castle health display, trigger defeat at zero health, and provide restart behavior.

**Acceptance:** A skeleton visibly travels from entrance to castle and reduces castle health once. Repeated arrivals can trigger defeat. Restart clears enemies and restores the encounter's initial state.

### 3. Archer Tower combat

**Status:** [ ] Not started  
**Depends on:** Milestones 1–2.

**Objective:** Make the core tower-defense interaction work.

- Create a reusable Archer Tower scene with configurable range, damage, cooldown, and target selection.
- Add simple arrows, hit handling, enemy death, and range feedback.
- Use a temporary development placement mechanism to put towers on build slots until card placement replaces it in milestone 4.
- Ensure dead enemies cannot reach the castle, receive further damage, or trigger duplicate death events.

**Acceptance:** Towers attack only eligible targets in range. Arrows visibly connect attacks to damage. Skeletons die at zero health, and towers handle targets disappearing while arrows are in flight.

### 4. Cards, mana, and placement

**Status:** [ ] Not started  
**Depends on:** Milestones 1–3.

**Objective:** Connect the card game to tower placement.

- Define an Archer Tower card resource and instantiate the fixed 16-card prototype deck.
- Implement shuffle, draw pile, four-card hand, discard pile, retained unplayed cards, and discard recycling.
- Add mana state, card cost display, and one-time kill rewards.
- Replace development placement with card selection, slot validation, range preview, cancellation, and placement during both preparation and combat.
- Provide clear feedback when a card is unaffordable or a placement is invalid.

**Acceptance:** Valid placement consumes exactly one card and 2 mana. Invalid placement and cancellation consume nothing. Each kill grants 1 mana exactly once. Unplayed cards remain in hand; drawing refills toward four and works after deck exhaustion. Playing a card does not immediately replace it.

### 5. Complete ten-wave level

**Status:** [ ] Not started  
**Depends on:** Milestones 1–4.

**Objective:** Connect all mechanics into a complete, replayable level.

- Introduce one authoritative battle state for preparation, combat, victory, and defeat.
- Run the 15-second preparation countdown, wave spawning, resolution checks, hand refill, and next-wave transition.
- Configure 10 waves with the initial skeleton-count progression and tune spawn spacing and movement toward the combat pacing target.
- Carry towers, hand, deck/discards, and mana through the level.
- Add victory, defeat, and retry flows; stop gameplay after either result and fully reset on retry.

**Acceptance:** A player can win or lose a complete run. No wave ends with pending spawns or living enemies. Wave 10 ends in victory only if the castle survives. Timers and callbacks cannot advance the battle after a result, and retry produces a clean run.

### 6. Minimal polish and playable review

**Status:** [ ] Not started  
**Depends on:** Milestones 1–5.

**Objective:** Make the prototype understandable and reasonably presentable.

- Provide a simple Start → Battle → Result → Retry flow.
- Add brief card draw/play transitions, placement confirmation, enemy hit feedback, health indicators, and clear selected/unaffordable card states.
- Keep animations short and ensure they do not block gameplay or delay authoritative state changes.
- Review touch targets, spacing, text readability, range visibility, and battlefield contrast on the portrait layout.
- Remove the temporary development placement mechanism and complete the manual acceptance checklist below.

**Acceptance:** A new player can understand the objective, play a card, follow combat, recognize victory or defeat, and retry without debug controls. The complete flow is usable in the existing iOS simulator workflow.

## Implementation guidance for agents

- Work milestone by milestone. Do not start collection, economy, or additional content systems during this slice.
- Prefer small reusable Godot scenes, typed GDScript where practical, resource-based card/enemy definitions, and signals for gameplay events.
- Keep battle state authoritative. UI and animations display state; they must not independently award mana, spend cards, or advance waves.
- Keep tower/enemy/card tuning centralized. Avoid building a generalized framework for future features before this loop works.
- Use the existing renderer, portrait layout, and iOS export setup. Do not edit generated `.godot/` or `build/` output as source files.
- Preserve existing user work. Record milestone completion, actual validation, and deliberate tuning changes here without claiming planned work is implemented.
- Do not invent final rarity probabilities, economy values, or shiny/holographic bonuses; those remain future design work.

## Architecture

How the code is organized, for anyone adding to it. The test suite and screenshot tools below keep it honest.

### Layers

- **`BattleScreen`** (`scripts/battle/battle_screen.gd`, root of `scenes/main.tscn`) starts the battle for its exported `level` and keeps the display in step: wave panel, wave preview, banners, health and mana bars, mana wisps. It holds no rules.
- **`Battle`** (`scripts/battle/battle.gd`) is the one authoritative battle state: `State.PREPARING`, `COMBAT`, `VICTORY`, `DEFEAT`.
  - It owns the `ManaPool`, the `Deck`, the wave sequence and spawner, the count of active enemies, and kill rewards.
  - The first result wins and halts everything.
  - Everything else reads `state`, `can_play_cards()`, and `is_over()`, and reacts to its signals.
- **`Battlefield`** (`scripts/battle/battlefield.gd`, `scenes/battlefield.tscn`) is the context passed to everything in the battle instead of global groups or statics. It holds:
  - the `BuildGrid` and its `PlacementPreview`
  - the `Castle`, the `EnemyPath`, and its `BarricadeLayer`
  - the `ground` layer for `AreaEffect`s and the `effects` layer for projectiles and spell visuals
  - per-battle services: `enemies` (`EnemyRegistry`), `ledger` (`DamageLedger`), and `targeting` (`TargetPlanner`)
  - a reference to the `battle`
- **`CardPlayController`** (`scripts/battle/card_play_controller.gd`) turns taps and drags into card plays.
  - It refills the hand, aims, opens the upgrade chooser, and runs discard mode.
  - It spends a card and its mana exactly once, and only when `CardData.play` succeeds.
- **`HudLayout`** (on `HandLayer`) places the HUD around the safe area. **`DebugOverlay`** (`scenes/debug_overlay.tscn`) holds the debug Restart button; delete that node to remove it.

Conventions:
- Signals go up and calls go down.
- Gameplay nodes get the `Battlefield` passed in or exported, never looked up through tree-wide groups.
- Distances and speeds are tuned in world units (720 across the reference screen) and converted with `Units.px`. Cards print distances in paces (`Units.paces`, 36 world units).
- UI fonts, panels, and buttons come from the project theme `ui/theme.tres`; shared colors come from `Palette`.

### Adding content

- **A card** is one `CardData` resource in `data/cards/`, with no new script unless it needs a new kind of targeting or effect. Add it to a level's `deck`. It combines:
  - a `targeting`: `CellTargeting`, `TowerTargeting`, `AreaTargeting` (anywhere, or `on_road`), `RoadTargeting`, or `CastleTargeting`
  - `effects`: `CardEffect` subclasses in `scripts/cards/effects/`
  - optional `discard_effects`
  - a `painting`, an `icon`, a `description` template, and three `stats` templates (`"{damage}|DAMAGE"`, optionally `|icon_name`)

  Placeholders come from each effect's and targeting's `describe()`, so printed numbers always match the tuning. `test_card_composition.gd` builds a card from existing parts as an example.
- **Card art:**
  1. Paint the full card in `art/cards/<id>.png` with the tools in `tools/` (Godot ignores `art/`).
  2. Run `python tools/export_card_faces.py` to write the shared frame, the painting, the icon, and the stat icons into `assets/cards/`.
  3. `CardFace` draws the cost, title, description, and stats as text.
- **An enemy** needs three things:
  - an `EnemyStats` resource in `data/enemies/`, with `damage_taken` by type, `final_death_types`, and revives
  - an `EnemyBody` subclass for the procedural art
  - a scene in `scenes/enemies/` with an `Enemy` root and a `Body` child

  Then add a key to `tools/make_waves.py` and regenerate the waves.
- **A tower** needs a `TowerStats` resource in `data/towers/` that names its `projectile` scene (`scenes/projectiles/`), a scene in `scenes/towers/` whose root extends `Tower`, and a card with a `PlaceTowerEffect`.
- **A status effect** (slow, chill, and so on) is a `StatusEffect` resource in `data/status/`, applied with `Enemy.apply_status`.
- **A tower upgrade** is a `TowerUpgrade` subclass in `scripts/towers/upgrades/` plus a resource in `data/upgrades/`, listed on the Upgrade card's `UpgradeTowerEffect`.
- **A ground effect** extends `AreaEffect`. Override `_tick`, then optionally `touched_by` (to react to fire or frost), and `predicted_damage_to` (so towers count its damage over time).
- **A projectile** extends `Projectile` and implements `_advance`, `_arrive`, and `_draw`. It needs a scene in `scenes/projectiles/`.

### Tests and review tools

- `./run_tests.sh` runs the GUT suite (`tests/unit`, `tests/integration`) headless at a fixed 60 fps. Pass `-gselect=<file>` to run one file.
- Integration tests drive `scenes/main.tscn` through `tests/support/battle_driver.gd`. It hosts the battle in a 720 × 1280 SubViewport, sends taps, drags, and keys, fast-forwards time, and wraps every read of battle internals. When internals move, update the driver, not the tests.
- `godot --path . --fixed-fps 60 -s tools/capture_screens.gd -- <dir>` renders seeded reference screenshots at 720 × 1280 and 720 × 1560. It needs a display.
- `godot --headless --path . -s tools/diff_screens.gd -- <before> <after> <diff dir>` reports how much each screenshot changed.
- GUT (`addons/gut`) and `tests/` are excluded from the iOS export.

## Manual acceptance checklist

Run these checks as the corresponding systems become available and repeat the complete playable flow at milestone 6. These checks are planned validation, not evidence of current functionality.

- [ ] Start a level: 20 castle health, 8 mana, four cards, wave 1, and a 15-second preparation phase.
- [ ] Place a tower on a valid slot and confirm one card and exactly 2 mana are spent.
- [ ] Attempt placement on an occupied slot, path, castle, and outside build slots; confirm no resources are spent.
- [ ] Cancel placement and attempt an unaffordable card; confirm no resources are spent.
- [ ] Place towers during preparation and combat, including with mana just earned from kills.
- [ ] Keep unplayed cards across a wave boundary; draw only enough to refill to four.
- [ ] Exhaust the draw pile and confirm discards reshuffle correctly without duplicating or losing cards.
- [ ] Observe enemies entering and leaving tower range; confirm target selection and firing cooldown.
- [ ] Have multiple towers attack one enemy; confirm its death and mana reward happen once, including with arrows still in flight.
- [ ] Let a skeleton reach the castle; confirm one damage event and no kill reward.
- [ ] Let combat exceed the pacing target; confirm the wave waits for pending spawns and surviving enemies.
- [ ] Complete all 10 waves with health remaining and confirm victory.
- [ ] Reach zero castle health, including on the last enemy of wave 10, and confirm defeat.
- [ ] Confirm result states stop spawning, damage, card placement, and phase progression.
- [ ] Retry after victory and defeat; confirm no previous towers, enemies, projectiles, timers, cards, or mana leak into the new run.
- [ ] Verify readable portrait layout and touch placement using the existing iOS simulator workflow.

## Progress and tuning log

- Initial brief: documentation created; all six implementation milestones remain unstarted. No gameplay validation has been performed.
- 2026-10-11 — Partial milestone 1 + placement slice of milestone 4 (both still open). Replaced the placeholder screen with the woodland battlefield (`assets/maps/woodland.png`, generated from `sketches/woodland.png` by `tools/clean_woodland.gd`, which paints out the baked-in mana bar). Added `BuildGrid` (`scripts/build_grid.gd`) aligned to the grid painted on the map, auto-blocking path and forest cells, and one reusable Archer Tower test card in a bottom tray that places a placeholder tower by drag-and-drop or tap-then-tap, with buildable-cell overlay, range preview, red invalid feedback, and Escape/tap-again cancel. The card is not consumed and no mana is spent; HUD, mana, deck, and enemies are deliberately absent for now. Validated by headless run with no errors and scripted input at 720 × 1280 and 720 × 1560: drag and tap placement succeed on grass, while path and occupied-cell drops place nothing. Not yet tested on the iOS simulator. Known art issue: the painted grid is uneven (one short row mid-map; lower-left columns shift about 12 px), so the overlay cannot match every painted line.
- 2026-10-11 — Card and tower art plus hand interaction (milestones 1 and 4 still open). Tuning: Archer Tower cost changed from 3 to 2 mana at the user's request. The card art, `assets/cards/archer_tower.png`, is built from `sketches/archer.png` by `tools/edit_archer_card.py`. The tool crops the card, replaces the cost with 2, and paints out the second archer and the background castle. The placed tower, `assets/towers/archer_tower.png`, is the map's left castle turret, cut out by `tools/extract_tower.py` so it matches the map style. The bottom tray is gone. The hand (`scripts/hand.gd`) shows four Archer Tower cards, fanned and half below the screen edge. Tapping a card raises it into full view and enables tap-to-place. Dragging a card turns it into a tower preview over the map. A valid drop places the tower and removes the card from the hand; an invalid drop returns the card. There is no deck, refill, or mana yet. Validated with scripted input at 720 × 1280: a valid drag drop left 1 tower and 3 cards, a path drop changed nothing, and two more drops left 3 towers and 1 card. Screenshots were checked. Both art tools need numpy, scipy, and Pillow.
- 2026-10-11 — Map rework, wooden tower, mana bar, and bigger cards (milestones 1 and 4 still open). Tuning: starting mana changed from 6 to 8, and mana is now capped at 10, both at the user's request. `tools/build_woodland.py` replaces the old cleanup script. It removes the mana bar and the painted grid lines (the game now draws faint grid lines itself). It removes about 80% of the flowers. It shifts the path's left bend 95 px right, so the tightest point leaves at least two buildable cells. It withers grass and trees near the Badlands: the top quarter fades from dead to fresh, and a few dead trees remain lower down. It also exports `woodland_blocked.png`, which the grid now reads instead of guessing from colors. The map now fits the screen width, so the side forests stay visible; on taller phones, dark sky fills above it and the castle courtyard continues below. `tools/draw_archer_tower.py` draws the new wooden Archer Tower. `tools/edit_archer_card.py` also exports the crystal gem and the numbers 0–10 used by the mana bar (`scripts/mana_bar.gd`). Cards are now 180 × 310. Placing a tower spends the card's cost, and an unaffordable card shakes, flashes the mana bar, and spends nothing. Validated with scripted input at 720 × 1280 and 720 × 1560: each placement spent exactly 2 mana and one card (8 → 6 → 4 → 2), and a drop with 1 mana was rejected with nothing spent.
- 2026-10-11 — Full-screen map and bigger grid (milestones 1 and 4 still open). `tools/build_woodland.py` now makes the map 941 × 2039 (about the 9:19.5 iPhone shape). It adds a 140 px strip of Badlands forest above the gate, which sits under the notch. It stretches the courtyard below the castle so the castle sits above the tucked cards. The meadow gets the remaining 72 px. The battlefield fills the screen and crops any overflow, with no mirrored or flat-color padding. The tool also moves the path's upper-right bend 55 px left. The grid is now 7 × 10 cells of about 107 × 106 map px (roughly 1.75× larger). A cell counts as blocked at 30% path or forest coverage. Every row now has at least two buildable cells on each side of the path. Towers were scaled up to match the cells; tower range stays 180 units. The mana bar is now centered vertically on the right edge. Validated with scripted input at 720 × 1560: four placements spent 2 mana each, and a drop at 1 mana was rejected.
- 2026-10-11 — Tower combat, skeletons, and a test trickle (milestones 2 and 3 partly done; still open). Tower stats now live on the card: `TowerStats` (`scripts/tower_stats.gd`, `data/archer_tower.tres`) sets damage, firing interval, range, and arrow speed. `TowerCard.tower_stats` passes it through `BuildGrid.begin_placement`/`place_tower` to `ArcherTower.activate`, so later tower types only need new stats and scenes. Towers fire at the in-range enemy furthest along the path. Arrows (`scripts/arrow.gd`) home on the target, deal damage once on contact, and land and fade harmlessly if the target dies first. `EnemyPath` (`scripts/enemy_path.gd`) builds a smooth curve along the painted road (about 1,720 map px), from the Badlands gate to the castle wall. The skeleton (`scenes/skeleton.tscn`; logic in `scripts/skeleton.gd`, procedural art in `scripts/skeleton_body.gd`, stats in `EnemyStats`/`data/skeleton.tres`) walks with a leg-and-arm cycle. Hits flash it and show a health bar. On death it collapses into a bone pile with the skull bouncing, then fades. At the wall it raises its sword, chops, deals castle damage once, and fades. `EnemySpawner` (`scripts/enemy_spawner.gd`) is a temporary test trickle: 20 skeletons with 1.5–3.5 s gaps and 30% clumps of 2–4. Kills grant mana once. Castle hits lower a logged health counter; there is no HUD or defeat yet. Tuning: skeleton speed is 85 units/s, so the walk takes about 15 s. Arrow speed is 420 units/s, slowed from a first try of 600 so arrows are visible. Validated with scripted runs at 720 × 1560. With three towers, all 20 skeletons died, each `died` fired once, mana capped at 10, and no arrows were left over. With no towers, there were 20 castle hits, one per skeleton. With one tower, kills and castle hits added up to 20 and each skeleton resolved exactly once. A card-flow check confirmed a played card spends 2 mana and its tower uses the card's stats. Screenshots of walking, arrows, death, and the gate swing were reviewed. Not yet tested on the iOS simulator.
- 2026-10-11 — Mana wisps (milestone 4 still open). Tuning: mana per kill changed from 1 to 0.1 at the user's request, so mana is now fractional (`main.gd` snaps to hundredths and compares costs with a small tolerance). The gem shows whole mana and the bar fill shows tenths. On a kill the mana is granted at once; a blue `ManaWisp` (`scripts/mana_wisp.gd`) drifts up from the skeleton and arcs into the bar's fill surface. `ManaBar.send_wisp` holds the amount back from the display until the wisp lands, then the fill rises with a brief glow. Kills at the 10 cap grant nothing and send no wisp. Validated with scripted runs at 720 × 1560: 8 kills took mana from 8.0 to 8.8, and screenshots show the wisp rising, arcing, and the bar rising by a tenth on arrival.
- 2026-10-11 — Goblins and the Cannon Tower (extra content requested by the user ahead of the milestone order; milestones 2–4 still open). Tuning, at the user's request: skeleton health changed from 3 to 2 (two arrows). Goblins have 3 health (three arrows). The Cannon Tower costs 3 mana, deals 3 damage every 2.5 s, has the same 180 range, and fires cannonballs at 300 units/s, so it one-shots both enemies. Shared code: `Enemy` (`scripts/enemy.gd`, formerly `skeleton.gd`) drives any enemy, and its art comes from an `EnemyBody` subclass (`skeleton_body.gd`, new `goblin_body.gd`). `Tower` (`scripts/tower.gd`) holds targeting and cooldown for `ArcherTower` and the new `CannonTower`. The goblin (`scenes/goblin.tscn`, `data/goblin.tres`) is small and green, with long ears and a club. It waddles, swings at the gate, and topples over backward when killed. The Cannon Tower (`scenes/cannon_tower.tscn`, `data/cannon_tower.tres`) is a stone keep drawn by `tools/draw_cannon_tower.py` in the wooden tower's style. Its iron cannon is drawn in code: it turns toward its target, recoils, and flashes and smokes when firing. `Cannonball` (`scripts/cannonball.gd`) lobs in an arc, hits once, and bursts into dust; if its target is already gone it lands harmlessly. The cannon card (`assets/cards/cannon_tower.png`, `scenes/cannon_card.tscn`) is made by `tools/edit_cannon_card.py` from the archer card's source painting. The tool paints out the archer and adds an iron cannon with muzzle flash and smoke, a powder keg, a cannonball banner emblem, cost 3, and new title, description, icon, and stats (3.0 damage, 0.6 attack speed, 5.0 range). The test trickle now picks skeletons or goblins at random, and the test hand holds two Archer and two Cannon cards. Known gap: the archer card's printed 1.4 attack speed doesn't match its in-game one shot per second, so the cannon's 0.6 is only in proportion. Validated with scripted runs at 720 × 1560. With three archer towers and two cannon towers, all 20 enemies (14 goblins, 6 skeletons) died exactly once and mana reached 10. Playing a Cannon card spent 3 mana and placed a cannon tower with the card's stats. Screenshots and a close-up pose gallery of both enemies and the cannon were reviewed.
- 2026-10-11 — Wave 1 and battle banners (milestone 5 started; still open). The random test trickle is gone. `EnemySpawner` now plays a `WaveConfig` (`scripts/wave_config.gd`), which is a list of `WaveGroup`s (`scripts/wave_group.gd`). Each group has a pause before it, spacing between enemies, and an ordered list of enemy scenes. `data/waves/wave_1.tres` sends 1 skeleton, then 2 skeletons, then 2 skeletons and a goblin, then a final group of 4 skeletons and 2 goblins (12 enemies). `main.gd` runs the phases. Preparing shows "Enemies Gathering" and "Prepare for Battle". After 10 s, combat shows "Enemies Attacking!" and starts the wave. When every enemy has been sent and none are left walking, cleared shows "Wave N Defeated". Messages come from `Banner` (`scripts/banner.gd`, on its own CanvasLayer), which queues centered text on a dark ribbon that fades out at the screen edges, in a bold serif system font. Tuning: preparation is 10 s instead of 15 at the user's request. Only wave 1 exists; there's no next wave, castle HUD, defeat, or retry yet. Validated with a scripted run at 720 × 1560 (two archer towers, one cannon tower): the banners appeared at 0 s, 2.8 s, and 10 s. Enemies spawned from 11 s in groups of 1/2/3/6, all 12 died, and "Wave 1 Defeated" appeared the moment the last one fell. Screenshots of each banner were reviewed.
- 2026-10-11 — Debug restart button. A temporary "Restart" button sits in the top-right corner, below the notch (`_add_restart_button` in `main.gd`). It reloads the main scene, so the run starts over from scratch. Remove it with the other debug controls in milestone 6. Validated with a scripted run. Mid-combat (cannon placed, 5 mana, 3 cards, 1 enemy walking), pressing it gave a fresh preparation phase: 8 mana, 4 cards, no towers, no enemies.
- 2026-10-12 — Ten-wave level, deck, new cards and enemies, and castle health (milestones 2, 4, and 5 mostly done; milestones stay open until the iOS simulator check).
  - **Level data:** A level is now one `LevelConfig` resource (`scripts/level_config.gd`, `data/levels/woodland.tres`). It holds 10 waves (`data/levels/woodland/wave_01–10.tres`), the deck, hand size, starting and max mana, castle health, and preparation time. `main.gd` reads everything from its exported `level`.
  - **Code split:** `WaveRunner` (`scripts/wave_runner.gd`) owns the preparation → combat → cleared loop and the active-enemy count. `Deck` (`scripts/deck.gd`) owns the draw and discard piles. `Castle` (`scripts/castle.gd`) owns castle health. `main.gd` coordinates mana, the hand, card play, and results.
  - **Banners:** Each wave announces "Wave N Incoming" (`WaveConfig.announcement` overrides it, so wave 10 says "Final Wave"), then "Prepare for Battle", then "Enemies Attacking!" and "Wave N Defeated". The level ends with "Victory!" or "Defeat" / "The Castle Has Fallen".
  - **HUD:** `CastleHud` (`scripts/castle_hud.gd`) shows castle health, "Wave N / 10", and the preparation countdown in the top left.
  - **Cards:** Cards are data now. `CardData` (`scripts/cards/`) has targeting and `play` hooks, with subclasses for towers, Fireball, Upgrade, and Heal. Definitions live in `data/cards/*.tres`. One generic `scenes/card.tscn` replaces the per-card scenes.
  - **Deck tuning, at the user's request:** The deck is 12 cards instead of 16: 4 Archer Tower, 2 Cannon Tower, 2 Fireball, 2 Upgrade, and 2 Heal.
    - Fireball costs 3 and deals 3 damage to every enemy within 70 units, anywhere on the map.
    - Upgrade costs 3 and gives a tower +50% attack rate (fire interval ÷ 1.5), once per tower. An upgraded tower shows a gold badge.
    - Heal costs 2 and restores 5 castle health, up to 20. The castle glows while Heal is aimed, and dropping or tapping anywhere on the battlefield casts it, because the raised card covers the castle.
    - Heal at full health, and Upgrade with no upgradeable tower, shake and spend nothing.
  - **Hand:** The hand draws to 4 at the start of every preparation phase, and unplayed cards stay. Played cards go to the discard pile, which is reshuffled when the draw pile runs out. Drawn cards slide in.
  - **Gate attacks:** Enemies no longer vanish at the gate. They stay there, still targetable, and strike the castle every `EnemyStats.attack_interval` until killed. Castle health at 0 is immediate defeat: spawns, timers, enemies, and card play stop, and the debug Restart button retries.
  - **Enemy tuning, provisional:**
    - Skeleton: 2 health, speed 85, 1 damage every 1.5 s, 0.1 mana.
    - Goblin: 3 health, speed 85, 1 damage every 1.2 s, 0.1 mana.
    - Big goblin (new; `scenes/big_goblin.tscn`, the goblin art at 1.5× with darker colors): 8 health, speed 70, 2 damage every 1.5 s, 0.3 mana.
    - Giant (new; `scenes/giant.tscn`, procedural art in `scripts/giant_body.gd`): 25 health, speed 50, 4 damage every 2.5 s, 1.0 mana.
  - **Wave tuning, provisional:** Wave 1 is unchanged. Each later wave has more enemies and shorter gaps, in groups that build to a final horde. Counts per wave are skeletons / goblins / big goblins / giants:
    - Waves 1–3: 9/3, 10/5, 9/8.
    - Waves 4–8: 9/6/2, 9/8/3, 8/9/4, 9/10/5, 9/11/6.
    - Waves 9–10: 10/12/5/1, then 11/14/6/2.
    Giants appear only in waves 9 and 10.
  - **Card art:** `tools/make_spell_cards.py` builds the Fireball, Upgrade, and Heal cards from the archer card's painting.
  - **Validation:** Scripted runs at 720 × 1560 all passed.
    - Deck: 12 cards survive repeated draw and discard with no loss or duplication, and drawing with both piles empty returns null.
    - Cards:
      - Archer placement spends 2. A path cell or an occupied cell is rejected with nothing spent.
      - Heal is rejected at full health, gives 13 → 18 → 20 (capped), and is rejected when dropped on the hand.
      - Upgrade on an empty cell is rejected, an upgrade sets the interval to 0.667, and a second upgrade is rejected.
      - The cannon is unaffordable at 1 mana.
      - Fireball killed 3 grouped skeletons once each for +0.3 mana and left a distant goblin untouched.
    - Defeat: With no towers, the first skeleton struck at a 1.5 s interval. Health fell 20 → 0 in 20 hits, then the battle stopped: no further spawns, waves stopped, and cards blocked.
    - Victory: A meadow full of upgraded towers won all 10 waves. Every wave ended with nothing pending or alive. The banners matched, giants spawned only in waves 9 (1) and 10 (2), and all 213 enemies died exactly once. The two unplayed cards stayed in hand across the wave 1 → 2 refill.
    - Retry: After both victory and defeat, retry gave 20 health, 8 mana, 4 cards, wave 1, and no towers or enemies.
    - Screenshots of the new enemies, Fireball, the targeting highlights, the HUD, and the cards were reviewed.
  - **Not yet done:** Not tested on the iOS simulator. Pacing toward the 15-second combat target has not been tuned, and later waves run longer.
- 2026-10-12 — Bigger, denser waves (tuning, at the user's request; milestones unchanged).
  - **Waves:** Wave files are now generated by `tools/make_waves.py` from a compact table of groups (pause, spacing, counts per type). The script spreads tougher enemies evenly through each group. Enemies per wave rose from 12–33 to 16, 22, 28, 34, 40, 47, 54, 62, 70, and 79. Spacing inside groups is 0.2–0.45 s instead of 0.45–0.7 s, so groups arrive as tight clumps. Big goblins still start at wave 4, and giants still appear only in waves 9 (1) and 10 (2).
  - **Enemies:** Bodies are 1.3× larger (big goblin 1.95×, so it stays 1.5× a goblin). Speeds rose about 10%: skeleton and goblin 93, big goblin 77, giant 55. The spawner's sideways spread is 20 px (was 12), and the gate crowd depth is 60 px (was 36), so clumps walk abreast and spread out at the gate.
  - **Preparation:** 7 s instead of 10.
  - **Validation:** At 720 × 1560, the scripted win run cleared all 10 waves (452 enemies, each died once) with matching banners and a clean retry. The defeat run still fell at 0 with one hit per strike. Wave 10 crowd screenshots were reviewed. Winnability with a real 12-card deck is untested.
- 2026-10-12 — Right-edge health bar, wave panel, castle turrets, Discard, and starting mana (requested by the user; milestones unchanged).
  - **Health bar:** Castle health is now a vertical bar on the right edge, styled like the mana bar. It has a red fill, a notch per point, and a gold-rimmed heart cap showing the number. It pulses red when the castle is struck and green when healed. Both bars share the new `Gauge` base (`scripts/gauge.gd`); `HealthBar` (`scripts/health_bar.gd`) and `ManaBar` draw only their fill colors and cap. The health bar sits above the mana bar, and both shrink (up to 470 tall) to fit between the Restart button and the hand.
  - **Wave panel:** The top-left panel (`WaveHud`, `scripts/wave_hud.gd`, replacing `castle_hud.gd`) now shows only "Wave N / 10", with the countdown or phase on its own line below.
  - **Castle turrets:** The two painted turrets on the castle wall each shoot arrows (`CastleTurret`, `scripts/castle_turret.gd`, two nodes under `Castle` in `battlefield.tscn`). Stats are in `data/castle_turret.tres`: 0.25 damage (a quarter of an Archer Tower's), 1 shot per second, range 180. They draw nothing; the map shows the turrets. Damage is now fractional: `TowerStats.damage`, projectile damage, and enemy health are floats.
  - **Discard:** Selecting a card shows a Discard button above the raised card. It sends the card to the discard pile without spending mana. Tapping a card now raises it even when it can't be played (it still shakes, and the mana bar flashes if mana is short), so unaffordable cards can be discarded. Dragging an unplayable card is still rejected.
  - **Tuning:** Starting mana changed from 8 to 4 at the user's request.
  - **Validation:** At 720 × 1560, a scripted check confirmed the following:
    - The run starts with 4 mana. The health bar sits above the mana bar on the right edge, below Restart and clear of the hand.
    - Discarding an affordable card, and a card selected at 0 mana, removed one card into the discard pile and spent nothing. The button showed only while a card was selected.
    - With no towers, the two turrets took a goblin near the gate down 1.5 health in 3 s, all in quarter hits, and killed it.
    - The card, deck, full-win, and defeat runs still passed, and retry gave 20 health and 4 mana.
    - Screenshots of the new layout and the Discard button were reviewed.
- 2026-10-12 — Health bar on the left and a ruby heart (requested by the user; milestones unchanged). The castle health bar now sits on the left edge, and the mana bar stays on the right. Since they no longer stack, each bar is up to 470 tall and centered between the top HUD and the hand. The heart cap is now a texture, `assets/ui/heart_gem.png`, drawn by `tools/draw_heart_gem.py` (numpy, scipy, Pillow) in the mana gem's style: a faceted ruby with a flat heart-shaped table, pale cut lines, a glint, and a bevelled gold rim. The health number is drawn over it, and the heart brightens when the castle is struck and tints green on a heal. Validated with screenshots at 720 × 1280 and 720 × 1560: the bars mirror each other, with no overlap with the wave panel, Restart button, or hand. Also built with `run_ios_simulator.sh` and checked on the iPhone 17 simulator, where the layout matched.
- 2026-10-12 — Physical iPhone builds (tooling; milestones unchanged). `run_ios_device.sh` exports the project like the simulator script, builds for the connected, paired iPhone, signs with automatic provisioning, installs, and launches. It defaults to the free Personal Team `JZ82P2C5W7` and the bundle ID `com.woodale.towerbound`; set `TEAM_ID`, `BUNDLE_ID`, or `DEVICE_ID` to override them. Free-team builds stop opening after 7 days, and rerunning the script fixes that. The first install needs the developer profile trusted under Settings → General → VPN & Device Management. Validated: the app built, installed, and launched on an iPhone 15 Pro (iOS 26.6.1). Gameplay on the phone has not been checked yet.
- 2026-10-12 — Starting mana changed from 4 to 5 at the user's request (`starting_mana` in `data/levels/woodland.tres`; milestones unchanged).
- 2026-10-12 — Gentler castle attacks (tuning, at the user's request; milestones unchanged). Enemies at the gate now strike about 20% less often, so they deal about 17% less damage per second. Damage per hit is unchanged. New `attack_interval` values: skeleton 1.8 s (was 1.5), goblin 1.45 s (was 1.2), big goblin 1.8 s (was 1.5), giant 3.0 s (was 2.5).
- 2026-10-12 — Discard button beside the card and richer kill rewards (requested by the user; milestones unchanged).
  - **Discard:** The Discard button now sits beside the raised card instead of above it. It goes on the side facing the middle of the screen, near the card's top, so it stays clear of the tucked hand.
  - **Tuning:** Mana from kills is tripled: skeleton and goblin 0.3 (was 0.1), big goblin 0.9 (was 0.3), giant 3.0 (was 1.0).
  - **Validation:** At 720 × 1560, a scripted run selected the left, middle, and right cards. The button appeared beside each one without leaving the screen. A screenshot was reviewed, and the run started with 5 mana. The run printed no errors.
- 2026-10-12 — Skeletons invisible on the iPhone (bug fix; milestones unchanged). On the iPhone 15 Pro, skeletons drew only their shadow. Exported builds on the phone loaded `SkeletonBody`'s `const PILE_LIMBS: Array[PackedVector2Array]` (nested `[a, b]` literals) as eight empty arrays, so `_draw` failed with an out-of-bounds error right after the shadow. Neither the desktop nor the simulator build showed this. The bone-pile table is now `static var _pile_limbs` with explicit `PackedVector2Array([...])` entries. Debugging tip: Godot errors on iOS don't reach the `devicectl --console` output. To see them, temporarily set `debug/file_logging/enable_file_logging=true` and pull `Documents/logs/godot.log` with `xcrun devicectl device copy from --domain-type appDataContainer`. Validated on the phone with an in-game screenshot: skeletons and goblins both draw, and the log has no script errors.
- 2026-10-12 — Zombies (new enemy, requested by the user; milestones unchanged).
  - **Behavior:** A zombie gets back up once after being killed. It falls on its face, lies still, twitches, and stands up 2 s after falling with full health. Then it keeps walking, or keeps striking if it was at the gate. While down it can't be targeted or hurt, and arrows aimed at it land harmlessly. Only the second death emits `died`, so the mana reward and the wave's enemy count happen once. If the battle ends while a zombie is down, it stays down.
  - **Code:** `EnemyStats` has new `revives` and `revive_delay` fields, so any enemy can revive. `Enemy` has a new `DOWNED` state. A downed enemy stays in the "enemies" group so a battle halt still reaches it, but `is_alive()` is false. The art is in `scripts/zombie_body.gd`: a hunched grey-green corpse in a torn shirt, arms reaching forward, dragging its back leg, and swiping with its claws at the gate. After rising, its back arm hangs limp. `EnemyBody.risen` tells the art it has risen.
  - **Tuning, provisional:** Zombie (`data/zombie.tres`, `scenes/zombie.tscn`): 3 health, speed 78 (skeletons are 93), 1 damage every 1.8 s, 0.5 mana, 1 revive after 2 s.
  - **Waves:** `tools/make_waves.py` adds zombies on top of the existing enemies, starting at wave 3: 2, 2, 3, 4, 5, 6, 7, and 10 in waves 3–10. Waves now have 16, 22, 30, 36, 43, 51, 59, 68, 77, and 89 enemies.
  - **Validation:** A scripted headless run checked the following:
    - The first kill left the zombie downed. It emitted no `died`, granted no mana, and the wave still counted it as active. A hit while it was down did nothing.
    - It stood up 2 s after falling with full health and walked on.
    - The second kill emitted `died` once, granted 0.5 mana, and lowered the active count to 0.
    - A zombie killed at the gate got back up and kept striking.
    - A zombie downed when the battle ended stayed down.
    - A pose gallery and an in-game screenshot at 720 × 1560 were reviewed.
    - Full-run winnability with zombies was not retested, and it was not checked on the iOS simulator or the phone.
- 2026-10-12 — Discard rework, Barricade card, and softer enemy hits (requested by the user; milestones unchanged).
  - **Discard:** The Discard button now sits in the bottom-left corner, just above the tucked hand; the health and mana bars end above it. Pressing it arms discard mode: the button reads "Cancel", every card gets a red outline, and the next card tapped goes to the discard pile without spending mana. Escape, the button, or a tap on the battlefield backs out. Only one discard is allowed per wave; the button greys out once it's used and comes back at the next preparation phase. Tapping an unplayable card no longer raises it (it only shakes), since discarding no longer needs a selected card. The button sits behind the hand, so a raised card covers it.
  - **Barricade card:** Costs 2 and puts a spiked wooden barricade with 5 health across the road (`BarricadeCardData`, `data/cards/barricade.tres`). A drop snaps to the nearest point on the road. It's invalid more than 80 map px from the road, within 160 px of the Badlands gate or 200 px of the castle end, or within 110 px of another barricade; the preview turns red there. `BarricadeLayer` (`scripts/barricade_layer.gd`, under `BuildGrid` so it y-sorts with enemies) owns placement and the preview. `Barricade` (`scripts/barricade.gd`) is drawn in code, shows a health bar once hit, and topples apart when broken. Enemies that walk into a standing barricade enter a new `BLOCKED` state: they stop 22–62 px short of it and strike it with their castle damage on their attack interval. When it breaks, they walk on. A zombie downed at a barricade goes back to striking it when it gets up. Enemies already past a barricade when it's placed aren't affected. The deck now has 13 cards, including one Barricade. The card art comes from `tools/make_spell_cards.py`, which can now build a single card (`python tools/make_spell_cards.py barricade`).
  - **Tuning:** Enemy damage is 15% lower: skeleton, goblin, and zombie 0.85 (was 1), big goblin 1.7 (was 2), and giant 3.4 (was 4). Castle health is now fractional. The heart shows it rounded up, so it reads 0 only once the castle falls.
  - **Validation:** A scripted run at 720 × 1560 checked the following:
    - Discard mode outlined all four cards. Discarding left 3 cards and 1 card in the discard pile, with mana unchanged at 5. After that the button was disabled and couldn't be armed again.
    - Barricade snapping accepted a road point and rejected a point off the road, a point near the gate, and a second barricade 50 px away.
    - Wave 1 skeletons stopped at the barricade and struck it from 5 down to 4.15 (one 0.85 hit). It broke, and they walked on.
    - Castle hits took health from 20 to 14.05 in steps of 0.85.
    - Screenshots of discard mode, the used button, and a close-up of skeletons at the barricade were reviewed.
    - The project loads with no script errors.
    - Not yet checked: the iOS simulator or phone, and a full ten-wave run with these changes.
- 2026-10-12 — Tower charges and burning Fireball ground (requested by the user to make placement choices matter; milestones unchanged).
  - **Charges:** Archer and Cannon towers hold `TowerStats.charges` (2). If a tower fires at least once in a wave, that wave spends one charge. A tower that spends its last charge keeps firing until the wave ends. It then sits out the whole next wave reloading and returns full: fire, fire, reload. A tower that never fires keeps its charges. The rules live in `Tower` (`can_fire`, `begin_wave`, `end_wave`). `main.gd` calls `BuildGrid.begin_wave`/`end_wave` on combat start and wave clear. Castle turrets have `charges = 0` (unlimited) and aren't in the grid.
  - **Charge UI:** Amber gem pips on a dark plate under each tower base show charges left, and a pip pops as it's spent. A reloading tower is dimmed and shows a turning amber reload ring through the preparation phase and the wave it sits out. The cannon stops tracking targets while it reloads.
  - **Fireball:** Impact damage is unchanged (3). The impact leaves a `BurningGround` patch (`scripts/burning_ground.gd`) on a new `Ground` layer under the enemies (`Battlefield.ground`). The patch has the same circle as the aiming preview. For `burn_duration` (4 s) it deals `burn_dps` (1) every 0.5 s in half-damage ticks to every living enemy inside, including enemies that walk in later. Both values are exported on `FireballCardData` (`data/cards/fireball.tres`).
  - **Validation:** Scripted runs at 720 × 1560.
    - Charges: A tower beside the path went 2 → 1 → 0 over waves 1–2. It fired no shots in wave 3 and was dimmed and reloading from wave 3's preparation. It was back to 2 by wave 4's preparation, then fired and dropped to 1. A tower out of reach kept 2. A tower placed mid-combat in wave 4 spent a charge on its first shot. The castle turrets fired in waves 1–3.
    - Burn: Impact took exactly 3. A stationary giant lost 2.0 health over 2 s in the patch. A giant moved in later lost 1.0. The patch stopped hurting and freed itself after 4 s. A burn kill fired `died` once and paid 0.3 mana. A patch lit after defeat dealt nothing.
    - Full runs: The scripted meadow-full win run still won with 20 health, and retry after victory and defeat was clean (20 health, 5 mana, 4 cards, no towers).
    - Screenshots of the pips, a reloading cannon, and the patch under enemies were reviewed.
  - **Stale test expectations, not failures:** The defeat script's "20 one-damage hits" check now counts 24, because enemy hits deal 0.85 after the softer-hits change.
  - **Not done:** Not checked on the iOS simulator or the phone.
- 2026-10-12 — Spell card art, Heal renamed to Repair, and a longer Fireball burn (requested by the user; milestones unchanged).
  - **Art:** `tools/make_spell_cards.py` now paints scenes instead of decorating the Archer Tower painting. The Upgrade card is the only one that keeps the tower.
    - Shared scenery comes from the new `tools/card_scenery.py`: procedural sky, clouds, two mountain ranges, and pine forests. The ground is the woodland map's meadow and road, warped into perspective.
    - Fireball: a meteor falls at dusk onto a burning patch of road, with smoke rising.
    - Barricade: the spiked barricade stands across the road through the meadow.
    - Repair: a castle wall with a breach. Stones rise back into it on golden trails, with scaffolding and a glowing hammer.
    - Upgrade: the tower gets riveted iron straps, plus scaffolding and a hoist lifting a stone block.
    - The painting now fills the whole frame opening (`frame_window`). The gem and the frame's ornaments are kept from the sketch.
  - **Repair:** The Heal card is now titled "Repair" (`data/cards/heal.tres`; art `assets/cards/repair.png`, and `heal.png` was removed). It has a hammer icon and keeps the same effect (+5 castle health). The code still calls it `HealCardData`.
  - **Tuning:** Fireball `burn_duration` changed from 4 s to 10 s at the user's request. At 1 damage per second, an enemy that stays in the patch takes up to 10 burn damage on top of the impact. The card text now reads "10s BURN".
  - **Validation:** All four cards were rendered and reviewed. Headless loads show the new titles, the 830 × 1429 art, and a burn of 10.0. The main scene ran headless for 300 frames with no errors. Not checked in play or on the iOS simulator.
- 2026-10-12 — Damage types, wave preview, and combo cards (requested by the user so card and tower choices depend on the coming wave; milestones unchanged).
  - **Damage types:** `Damage` (`scripts/damage.gd`) defines pierce, crush, fire, and frost, and draws a small icon for each.
    - Sources: Archer Towers and castle turrets deal pierce, and Cannon Towers deal crush (`TowerStats.damage_type`). Fireball, burning ground, and ignited oil deal fire. Chill deals frost.
    - `EnemyStats` has a multiplier per type and a `display_name`. `Enemy.take_damage(amount, type)` applies the multiplier.
    - Hit flashes are gold on a weakness and grey on a resistance.
    - A killing fire hit keeps a zombie down, with no revive.
  - **Tuning, provisional:** Damage multipliers per enemy:
    - Skeleton: pierce ×0.5, crush ×1.5.
    - Goblin: neutral.
    - Big goblin: pierce ×1.5, crush ×0.5.
    - Zombie: fire ×2.
    - Giant: pierce ×0.5, crush ×1.25, frost ×0.5 (its chill lasts half as long).
  - **Statuses:** `Enemy.apply_slow` (the strongest slow wins) and `apply_chill`. Chill:
    - Halves walking speed.
    - Makes gate and barricade strikes 1.5× slower; the change applies from the next swing.
    - Makes the enemy brittle: crush damage ×1.5.
    - Chilled enemies get a pale blue tint (`EnemyBody.frost`).
  - **Wave preview:** `WavePreview` (`scripts/wave_preview.gd`) is a panel under the top HUD during preparation.
    - It shows each enemy type in the coming wave, using its real art (the scene's `Body` node), with "×N".
    - Below each type, damage icons with a green ▲ for a weakness and a grey ▼ for a resistance. Zombies also get a "gets back up" arrow.
    - Counts come from `WaveConfig.enemy_counts()`.
    - It fades out when combat starts or the battle ends, and dims while a card is aimed.
  - **Card badges:** Cards that deal damage show their damage type's icon in a badge in the top-right corner (`CardData.damage_type()`).
  - **Oil Slick card** (cost 1; `OilCardData`, `scripts/oil_slick.gd`, `data/cards/oil_slick.tres`):
    - It snaps to the road and is rejected off it (`Battlefield.road_point`). The radius is 55.
    - It slows enemies inside to 60% speed for 25 s.
    - Any Fireball blast or burning ground that touches it ignites it into a BurningGround with 2.5 dps for 7 s. That blaze can ignite a neighboring slick in turn.
  - **Chill card** (cost 2; `ChillCardData`, `scripts/frost_burst.gd`, `data/cards/chill.tres`): Can target anywhere. It deals 0.5 frost and chills enemies within 70 for 5 s.
  - **Barricade discard:** New `CardData.on_discard` hook. A Barricade thrown away with Discard scatters caltrops (`scripts/caltrops.gd`) on the road 270 map px before its end, just ahead of the gate crowd. The first 8 enemies to cross take 1 pierce each. More discards add to the same patch.
  - **Card art:** `tools/make_spell_cards.py` has new `oil_slick` and `chill` entries, and the Barricade card text now mentions caltrops.
  - **Validation:** A scripted headless run checked the following:
    - Preview: Wave 1 shows 11 skeletons and 5 goblins. Wave 10 shows all 5 types, 89 enemies. The preview is hidden in combat.
    - Damage: An arrow takes 0.5 from a skeleton and 1.5 from a big goblin. A cannonball takes 4.5 from a skeleton and 1.5 from a big goblin.
    - Zombies: Fire deals ×2, and a fire kill emits `died` once with no revive. An arrow kill still revives.
    - Chill:
      - It lasts 5 s on a goblin and 2.5 s on a giant.
      - A chilled goblin walks at 0.50× speed, and a cannonball deals it 4.5.
      - Chill wears off.
      - A chilled skeleton at the gate strikes every 2.71 s (1.8 × 1.5).
    - Oil:
      - It is rejected off the road and slows a goblin to 0.6×.
      - A Fireball ignited the near slick first, and the blaze then chained to a second slick.
      - A still giant in the blaze plus the Fireball patch lost 7 health in 2 s.
    - Caltrops: Discarding a Barricade spent no mana and removed the card. Ten walking goblins crossed, exactly 8 were hurt, and the patch was then used up.
    - Full runs: The full win run still clears all 10 waves (491 enemies, each dying once) with a clean retry. The defeat run only fails its stale 20-hit check (it counts 24 at 0.85 per hit).
    - Screenshots at 720 × 1560 of the preview, card badges, oil, chill tint, caltrops, and the ignited slick were reviewed.
  - **Not checked:** Winnability with a real hand, now that arrows do half damage to skeletons, the most common enemy. Also not checked on the iOS simulator.
- 2026-10-12 — Upgrade picks Rate of Fire or Ammo (requested by the user; milestones unchanged).
  - **Behavior:** Dropping Upgrade on a tower opens two buttons beside it: "Rate of Fire +50% speed" and "Ammo +1 charge" (`UpgradeChooser`, `scripts/upgrade_chooser.gd`). The card and its 3 mana are spent only after a pick. Escape, a tap off the buttons, tapping a card, or the battle ending closes the chooser and spends nothing. The buttons sit above the tower, or below it for towers in the top half so they clear the HUD.
  - **Each kind once per tower:** A tower can take one Rate and one Ammo upgrade. When only one is left, Upgrade applies it straight away with no chooser. A tower with both is no longer highlighted or a valid target.
  - **Ammo:** `Tower.max_charges` starts at the card's `charges` (2) and goes to 3. A tower that isn't reloading also gets the charge right away, so one that just spent its last charge doesn't reload. A reloading tower refills to the new maximum. The extra charge shows as a third pip. The gold chevron badge now means the Rate upgrade only; both upgrades play the gold burst.
  - **Code:** `CardData` has new `choices_at` and `play_choice` hooks. `main.gd` opens the chooser when `choices_at` returns options and finishes the play in `_finish_play`. `Tower.upgrade` is split into `upgrade_rate` and `upgrade_ammo`. `UpgradeCardData` exports `attack_rate_bonus` (0.5) and the new `extra_charges` (1).
  - **Card art:** `tools/make_spell_cards.py upgrade` now prints "Upgrade a tower: +50% attack speed or +1 ammo."
  - **Validation:** A scripted run at 720 × 1560 passed all 22 checks:
    - Opening the chooser spent nothing, and Escape closed it with mana and hand unchanged.
    - Picking Rate set the interval to 0.667 and spent 3 mana and one card once. A second Upgrade on that tower applied Ammo with no chooser (3 max, 3 left), and a third was rejected with nothing spent.
    - Ammo on a tower that had spent its last charge gave it 1, and it didn't reload. Ammo on a reloading tower gave nothing until it refilled to 3.
    - Defeat with the chooser open closed it, and a late pick did nothing.
    - Screenshots of the chooser and the upgraded tower (badge plus three pips) were reviewed.
    - Not yet checked on the iOS simulator or the phone.
- 2026-10-12 — Stronger towers and more starting mana (tuning, at the user's request; milestones unchanged). Starting mana changed from 5 to 6. Archer Tower arrows deal 1.5 instead of 1 (0.75 to skeletons, 2.25 to big goblins). Castle turret arrows deal 0.75 instead of 0.25, half an Archer Tower's. The Cannon Tower fires every 2.0 s instead of 2.5 s (25% faster). The printed card stats were not redrawn. Validated: the project ran headless with no errors, and `run_ios_device.sh` built, installed, and launched it on the iPhone. Not play-tested.
- 2026-10-12 — Arrows one-shot skeletons and two-shot goblins (tuning, at the user's request; milestones unchanged). Skeleton health changed from 2 to 1.5, and its pierce ×0.5 and crush ×1.5 multipliers were removed. Goblins were already neutral and keep 3 health. `EnemyStats.max_health` is now a float. With 1.5-damage arrows, a skeleton takes one arrow and a goblin two. Side effects: castle turret arrows (0.75) now take two hits on a skeleton instead of three, and a cannonball deals 3 to a skeleton instead of 4.5, which still kills it. Validated: a headless check printed 1 arrow for a skeleton and 2 for a goblin, and the main scene ran headless for 300 frames with no errors. Not play-tested.
- 2026-10-12 — Oil Slick and Chill card art without the tower (requested by the user so cards are easier to tell apart; milestones unchanged). These two cards were still painted over the Archer Tower painting. `tools/make_spell_cards.py` now paints them on the shared `card_scenery.py` landscape, like Fireball, Barricade, and Repair. Oil Slick is a glossy black pool on the meadow road, with thin rainbow sheen, sky glints, and droplet rings. Chill is a frosted winter meadow with a cracked sheet of ice, ice shards at its rim, and falling snow. Upgrade keeps its tower because it targets towers. Text and stats are unchanged. Validated by reviewing the rendered cards; not checked in game or on the iOS simulator.
- 2026-10-12 — Smarter tower targeting: no overkill (requested by the user; milestones unchanged).
  - **Behavior:** Towers and castle turrets still shoot the in-range enemy furthest along the path, but they now skip enemies that are already doomed. They pick the next enemy instead, or hold fire if every enemy in range is doomed. A held tower keeps its cooldown at 0 and spends no charge.
  - **What counts as doomed:** An enemy is doomed when the damage already on its way covers its health. That damage is the projectiles in flight at it (after its resistances) plus the burn it will take from burning ground in the next 1.5 s (`BURN_HORIZON`). The burn prediction moves walking enemies along the path at their current speed, and enemies at the gate or a barricade stay put.
  - **Code:** `TargetPlanner` (`scripts/target_planner.gd`) is a static service that holds all of this logic. `Tower.find_target` calls `TargetPlanner.pick_target`. `Arrow` and `Cannonball` commit their damage when launched. They release it once: on hit, on a harmless landing, or when they leave the tree, so a restart can't leak. `BurningGround` joins the `burning_ground` group and exposes `upcoming_ticks`, `tick_damage`, and `contains`. Instant effects (Fireball and Chill impacts, caltrops) aren't predicted.
  - **Validation:** A headless script placed three Archer Towers around one road point, with the castle turrets silenced.
    - A skeleton drew exactly 1 arrow, and a goblin drew exactly 2.
    - A 0.5-health goblin in a fresh burn patch was doomed. The towers fired nothing, and the burn killed it.
    - A full-health goblin in the patch drew 1 arrow, and the burn finished it.
    - 6 walking skeletons took 6 arrows for 6 kills.
    - The ledger was empty after each case and after the scene was freed with arrows in flight.
    - The main scene ran headless for 300 frames with no errors.
    - Not checked in a full ten-wave run or on the iOS simulator.
- 2026-10-13 — Architecture refactor for extendability (requested by the user; milestones unchanged, gameplay and tuning unchanged). See **Architecture** above for the result. One commit per phase on branch `refactor/architecture`:
  - **Tests:** Added GUT 9.7.1 and a regression suite written against the old code before anything moved. It started with 71 tests and has 104 now.
  - **Structure:** Scripts, scenes, and data were moved into folders. Added `Units`, `Palette`, and a project theme in place of StyleBoxes and SystemFonts built in code.
  - **Battle state:** `Battle` replaced `WaveRunner` and `main.gd`'s separate result. `ManaPool` holds mana. The `Battlefield` context carries `EnemyRegistry`, `DamageLedger` (no more static ledger), and `TargetPlanner`.
  - **`main.gd` split:** It became `BattleScreen`, `CardPlayController`, `HudLayout`, and `DebugOverlay`.
  - **Combat:**
    - `Hit` objects, plus `damage_taken` and `final_death_types` on `EnemyStats`.
    - `StatusEffect` resources for chill and oil slow.
    - Enemies strike the gate and barricades through one attack target.
    - `Projectile` and `AreaEffect` base classes, `BurnSpec`, and fire spreading through `touched_by`.
  - **Towers:** `TowerAmmo`, per-tower copies of stats, `TowerUpgrade` resources, `ChargePips` and `UpgradeBadge` display nodes, and `PlacementPreview` split out of `BuildGrid`.
  - **Cards:**
    - Cards are composed from a `CardTargeting` and `CardEffect`s, and the seven `*_card_data.gd` subclasses are gone.
    - `heal.tres` was renamed `repair.tres`.
    - Faces are drawn from data by `CardFace`, and `Card` was renamed `CardView`.
    - Printed numbers now match the tuning. Archer: 1.5 damage and 1.0 attack speed (it printed 1.0 and 1.4). Cannon: 0.5 attack speed (it printed 0.6). Radius values print 1.9 (70 ÷ 36) where they were hand-typed as 2.0.
    - The baked full cards moved to `art/cards/`, which Godot ignores.
    - Card titles use synthetic bold, because Godot resolves Baskerville at weight 700 to the regular face. The HUD's `serif_bold.tres` has always rendered regular for the same reason.
  - **Validation:**
    - After every phase, the full suite passed with the phase-0 expectations unchanged, and the main scene ran headless with no errors.
    - Seeded screenshots matched the pre-refactor baseline pixel for pixel through the card-composition step. After the card-face change, only the hand differs.
    - New card faces were reviewed side by side with the old baked cards.
    - iOS simulator exports were run after the `main.gd` split and after the card faces. Both reached the battle with the HUD below the Dynamic Island.
  - **Not checked:** Raised-card text on a real iPhone (fonts come from iOS system fonts), and a manual play-through on the phone.
- Add subsequent entries with the milestone, completed behavior, validation performed, and any tuning changes with their reason.

# Towerbound

## Purpose and current state

Towerbound is a fantasy game combining a trading card game with 2D tower defense. The immediate goal is a small playable prototype that tests drawing cards, spending mana to build towers, and defending a castle against enemy waves.

This file is the project brief and implementation roadmap for agents. The milestones below are planned work, not completed features. Build them in order and keep the project runnable after each milestone.

The repository currently contains a Godot 4.7 starter project using GDScript, a placeholder screen, and an iOS export preset. Preserve its portrait mobile foundation:

- Reference viewport: 720 × 1280, with an interface that adapts to phone aspect ratios.
- Entry scene: `scenes/main.tscn`; current entry script: `scripts/main.gd`.
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
| Prototype deck | 16 common, base Archer Tower cards |
| Starting mana | 8 |
| Mana cap | 10 |
| Archer Tower cost | 2 mana |
| Mana per skeleton killed | 1 |
| Skeleton health | 3 |
| Skeleton castle damage | 1 |
| Archer Tower damage | 1 per shot |
| Archer Tower firing interval | 1 second |
| Archer Tower range | 180 world units at the reference resolution |
| Skeletons per wave | 4 on wave one, increasing by 1 each wave |

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
- Add subsequent entries with the milestone, completed behavior, validation performed, and any tuning changes with their reason.

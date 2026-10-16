# Moonwell Bastion — design and implementation contract

Implement the GPT Image design in `source-art/design.png` (1672×941) as a playable standalone Godot 4.6.3 tower-defense battle screen using Godot UI Fidelity. Preserve the marsh battlefield, edge HUD, three tower cards, dark wood and brass materials, cream typography and illustrated silhouettes.

## Output and environment

- Main viewport: 1280×720. Compact viewport: 960×540. Keep the entire battlefield visible and its route and build sites usable. A uniformly scaled composition is allowed.
- The source design guides composition. The runtime uses a clean map, individual actor sprites, native Godot buttons and changing labels. Actionable HUD input belongs to native controls; decorative sprites may be drawn normally.
- `shared/battle_model.gd` owns gameplay and economy. The implementation reads its snapshots and dispatches actions through its public API.
- Cinzel is supplied with its SIL Open Font License; Godot's bundled font may supply supporting text. Keep audio silent and state in memory, with no filesystem persistence or network dependency.

## Assets

`shared/assets/map.webp` is the opaque 1280×720 battlefield. Show its full frame with one consistent world transform. Six stone pads are scenery; tower sprites overlay occupied pads. `ranger.png`, `ember.png`, `frost.png` and `beetle.png` retain transparent full silhouettes. Preserve aspect ratios and use each tower's bottom-center as its ground anchor.

`wood.png` and `gold.png` are empty illustrated panels suitable for nine-slice decoration; `crest.png` is the crescent emblem. Retain texture references through deferred rendering. Source dimensions, measured crops, runtime sizes and hashes are recorded in `source-art/ASSETS.json` and `shared/ASSETS.json`.

## Gameplay and controls

The initial state is an active wave 3/8 paused at tick 0: gold 360, crystal 12, lives 20, two towers and three beetles. Resume advances enemies, spawning, targeting, projectiles and resource changes. The initial pause control offers Resume, and Next Wave remains unavailable during an active wave. These controls reflect actual state even where the generated concept depicts a different action.

Required HUD: MOONWELL BASTION / THE LANTERN MARSH; wave, lives, gold and crystal values; pause/resume; RANGER, EMBER and FROST cards with live costs; DEFEND THE MOONWELL / Keep the lanterns burning.; Next Wave; a compact selected-site/tower context with the available build or upgrade action and current price; and restart.

- Choose a build card, then click an empty eligible stone pad to build once when running and affordable.
- Click an occupied pad to select its tower, then use Upgrade for one upgrade and one debit.
- Click empty world to clear selection. HUD input must not also act on the world beneath it.
- Pause allows selection and inspection while blocking build, upgrade and wave start. Resume continues the existing battle.
- `Space` starts the next eligible wave, `P` toggles pause and `R` restores the initial paused battle. Native keyboard focus and activation are acceptance requirements whose verification status is recorded in [RESULTS.md](RESULTS.md).
- The demo continues through wave 8 and has model-driven win/loss and restart behavior. `reset_ready()` is a model-test helper.

## Observation and source integrity

Native buttons expose the names `PauseButton`, `NextWaveButton`, `RangerButton`, `EmberButton`, `FrostButton`, `UpgradeButton` and `RestartButton`. The root exposes its authoritative `model` and `get_probe_state() -> Dictionary`, including UI selection state. The optional passive probe reads state and control geometry; it does not send gameplay commands.

The GDScript in `implementation/` retains the first-complete implementation bytes. [SOURCE-SHA256.json](SOURCE-SHA256.json) records retained source hashes. Rendered differences and incomplete acceptance checks remain disclosed in [RESULTS.md](RESULTS.md).

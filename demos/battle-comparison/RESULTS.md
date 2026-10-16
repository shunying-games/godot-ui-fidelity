# Moonwell Bastion — observed implementation results

The skill-assisted Godot implementation renders the GPT Image design as a playable battle screen. The retained GDScript is unchanged from its first-complete submission. The observations below were recorded under Godot 4.6.3 on macOS using headless import/export and the hidden in-app Chromium Web renderer.

## Rendered result

The 1280×720 and 960×540 captures preserve the marsh battlefield, bright winding path, cyan goal, thin upper HUD and raised three-card deck. Towers, beetles, health bars and empty build pads are distinguishable in the initial paused wave. The selected-tower view includes a ranger selection ring, range outline, compact context panel, current model values, upgrade price and the paused-state hint.

The initial state is wave 3/8, seed 1729, tick 0, paused with gold 360, crystal 12, lives 20, two towers and three enemies. Resume and disabled Next Wave reflect that real state. The implementation renders the clean map and individual actors separately; native buttons and labels provide input and changing values.

Remaining visual limitations: carved decoration is simpler than the design; secondary labels become small at 960×540; disabled upgrade text has limited contrast in the compact view; exposed circular pads make tower placement look composited. Detailed active-combat visual feedback has not received complete visual acceptance.

One selected desktop capture caught a viewport-resize transient. A fresh fixed-viewport capture from unchanged source resolved it.

## Observed browser behavior — 8/8 groups passed

Actual pointer and keyboard input exercised these groups. The passive probe recorded model and UI state.

| Check group | Observed evidence |
| --- | --- |
| Paused selection and resize | Site 0 selected at tick 0; pause preserved after resize. |
| Pause over real time | Tick remained 0 over approximately 24 seconds. |
| Blocked paused purchase and HUD routing | Gold stayed 360 and site 0 stayed selected while choosing Frost in the HUD. |
| Native Resume and Frost build | Simulation advanced; one Frost tower appeared on site 5; gold changed 360→220. |
| Upgrade and occupied selection | Existing tower reached level 2; gold changed 420→320 once; tower count stayed 3. |
| Combat progression and keyboard pause | The wave cleared to ready at tick 1169; keyboard pause passed. |
| Native Next Wave and repeated start | Pointer Next Wave plus repeated Space started wave 4 with one enemy and 11 remaining spawns, without duplicating the wave. |
| Keyboard restart | R restored gold 360, two towers and the paused tick 0 state. |

Import and Web export completed cleanly, with no browser console errors reported. These observations cover the listed flows.

## Model and harness checks

The battle model passed **90 headless assertions** under Godot 4.6.3. They cover atomic economy, pause invariance, deterministic stepping, attacks, projectiles, rewards, bounded waves, terminal win/loss simulation and restart state. Its retained SHA-256 is:

```text
779d816e9066a1ab42743d8a0270cfbec0959806462dec924f109cb1fdd8d150
```

The passive probe passed **8 synthetic harness checks**. Those validate evidence collection with a synthetic root. Model and harness tests do not establish rendered appearance or every UI input route.

Source inspection confirms native `Button` nodes connected to model commands, HUD labels reading snapshots, and availability states driven by the model. Space is consumed as a global Next Wave shortcut in `_input` before native GUI handling; focused-button Space activation still needs explicit verification.

## Unverified browser flows

- Complete play through wave 8, terminal win/loss presentation and restart through the outcome button.
- An unaffordable build or upgrade attempted through the UI, including visible feedback.
- Tab/focus traversal and Enter/Space activation of focused controls.
- Precise hit boundaries, edge/corner targets and press-drag-out-release at both sizes.

These remain unverified. The model's terminal-state tests do not substitute for completing those browser flows. This standalone demo does not establish real-device performance or production readiness. Full source hashes are in [SOURCE-SHA256.json](SOURCE-SHA256.json); generated-art provenance and measured asset derivation are in [source-art](source-art/GENERATION.md) and [PROVENANCE.json](PROVENANCE.json).

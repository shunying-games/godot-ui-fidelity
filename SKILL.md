---
name: godot-ui-fidelity
description: Design, implement and verify Godot game UI; plan raster asset dimensions and runtime texture budgets. Use for interface design, approved-reference implementation, input/layout fixes, game image creation or resizing, and visual QA within the requested gameplay scope.
license: MIT
---

# Godot Game UI and Fidelity

Build an interface that belongs to the game, stays usable during play, and works through real Godot controls and game state. Treat an approved design as a visual contract. Visual fidelity, interaction correctness and subjective game feel are separate acceptance results.

## Choose the task mode

Use only the modes needed for the request; a small fix does not require a full redesign.

| Request | Work to perform | Read |
|---|---|---|
| New menu, HUD, reward screen, or design alternatives | Define player decisions and visual direction; compare meaningfully different options; produce the requested design or prototype | [Design and assets](references/design-and-assets.md) |
| Implement an approved screenshot or layered design | Freeze its composition and state, measure components, prepare assets, implement against that contract | [Design and assets](references/design-and-assets.md), [Godot implementation](references/godot-implementation.md) |
| Create game images or optimize raster/atlas dimensions | Measure maximum displayed pixels, keep source art, choose runtime texture budgets, and preserve region/scale semantics | [Texture budgets](references/texture-budgets.md), [Design and assets](references/design-and-assets.md) |
| Fix input, layout, localization, or add UI feedback | Trace the real event/state path, change the relevant controls, and add feedback with correct cancellation/pause behavior | [Godot implementation](references/godot-implementation.md) |
| Review a shipped UI or verify a change | Inspect the actual implementation and rendered state, reproduce the issue, and judge relevant dimensions separately | [Acceptance](references/acceptance.md) |
| Evaluate or improve this skill | Freeze a candidate, run independent realistic tasks and negative controls, revise from observed failures, then run a transfer check | [Skill evaluation](references/skill-evaluation.md) |

Before work, read the project's `AGENTS.md` when present and the local design, testing or asset-policy documents it points to that apply to the task. Resolve those paths from the project, not this skill's installation directory. Preserve the user's selected design, platforms, language support and gameplay requirements. Keep project-specific references, helper commands and authorization history in project-local documentation. Updating this skill does not itself authorize changes to the running game.

## Shared workflow

1. **Define the outcome.** Identify the screen, player action, real data source, opening/closing rules, target viewports and requested deliverable. Use existing context; clarify only choices that materially block work.
2. **Design or measure.** For exploration, define theme and hierarchy before coding. For a selected reference, record proportions, typography, decoration and states before deriving assets. Keep unapproved alternatives distinct from the chosen design.
3. **Prepare a usable handoff.** Reuse suitable assets and theme resources. Identify native text/input, illustrated chrome, scale rules and required state variants. For raster creation or resizing, establish source and runtime budgets from [Texture budgets](references/texture-budgets.md). Inspect generated assets before integrating them.
4. **Implement within the authorized deliverable.** When implementation is requested, Godot Controls handle input, focus and dynamic values; presentation reads the authoritative game model. Keep scene decoration, UI feedback and gameplay timing distinct. Design-only work stays at its design/handoff stage.
5. **Verify the changed behavior and actual pixels.** Use focused checks appropriate to the change, real input for interaction-sensitive fixes, and rendered evidence for visual acceptance. For adaptive layouts, inspect fresh compact launches and live resize.
6. **Iterate and deliver.** Fix the largest observed difference, preserve the best reviewed candidate, respect the user's limit, and show the actual result with remaining differences and evidence boundaries.

## Rules that prevent recurrent failures

- Persistent HUDs must leave the game's paths, placement areas, enemies and important effects readable. Put secondary explanations on contextual or pause surfaces. Full-screen menus have a different space budget from combat HUDs.
- Preserve approved silhouettes, icon aspect ratios, typography and critical decoration. Native input does not require generic flat visuals. Use one measured, uniformly scaled canvas for fixed illustrated compositions; use Containers/anchors where content must flow.
- Update fonts, child minimum sizes and native grabber sizes before final rectangles. Font shaping and container sorting can finish later: verify text bounds after settling, including fresh small-screen startup and longest supported values.
- In custom `_draw`, hold textures, atlases, StyleBoxes and meshes in constants, members or persistent caches. Inspect actual frames; compilation cannot catch resources disappearing before deferred rendering.
- Keep live numbers, prices, rewards, disabled states, language and navigation connected to real data. Artwork supplies decoration; input and authoritative state remain real.
- Give hover, focus, pressed, disabled and pending states distinct feedback where applicable. UI feedback must not cause duplicate rewards, stale callbacks, overlapping tweens or changes to combat speed.
- Check hit areas independently of visible art, especially touch, drag and modal boundaries. Measure neighboring targets together after layout; individually meeting a minimum size does not pass if their active regions overlap. Decorative overlays should not intercept input; modal input must not leak into the playfield.
- Separate function tests from visual review. Missing text, clipped controls, wrong proportions, important missing art, blocked input or clearly unreadable states block their respective acceptance result.

## Use available tools when needed

This skill works with local Godot assets and the project's existing tooling. Image generation, design services and other installed skills are optional capabilities, selected for the requested deliverable.

- For raster creation or edits, use an available image workflow and follow its current operating instructions. Reuse editable project-native assets for deterministic edits when appropriate. If an unavailable capability blocks a requested artifact, report that gap without inventing an output.
- For a structured design source, obtain its measurements, typography, states and exports using authorized tooling. Import the design contract into Godot rather than treating generated Web code as a Godot implementation.
- Use the project's existing Godot test framework. A substantial task may benefit from an available review/testing skill; a small visual adjustment does not require a new framework or a full TDD workflow.
- Tool availability and authorizations remain task-specific. If rendered capture is blocked, finish unaffected work and report visual acceptance as pending; do not bypass an approval rejection or invent a passing screenshot.

## Deliver

Give the user the actual artifact or runtime screenshot, explain what changed and why, and report visual, interaction and technical results with their limits. For design-only requests, deliver the alternatives or handoff without claiming the game was updated. For new motion, distinguish observed correctness from subjective feel. Do not infer permission to publish, commit, push, spend on external APIs or change unrelated gameplay.

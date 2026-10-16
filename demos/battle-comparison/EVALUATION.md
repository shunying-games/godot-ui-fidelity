# Moonwell Bastion — predeclared acceptance and comparison

Status: rubric declared before candidate implementations or candidate screenshots are inspected. Primary scenario finalized before candidate dispatch: the shared model's initial paused-active wave-3 snapshot.

This is a controlled native Godot UI fidelity exercise, not a prediction that either implementation method must win. Report the two candidates' actual strengths, defects, scores, and uncertainty. A tie or an inconclusive comparison is a valid result.

## 1. Common contract to freeze before implementation

Both candidates receive the same immutable package:

- One full-screen GPT Image reference, its exact dimensions, and the same clean map artwork derived from it. The map artwork must not contain baked-in HUD, buttons, resource numbers, enemies, towers, or selection effects that candidates are expected to implement dynamically.
- The same written brief identifying any ambiguous reference labels, intended controls, build sites, tower types, path endpoints, and required interactions. Resolve ambiguities once, before either candidate starts.
- The same authoritative simulation module, configuration, named deterministic scenarios, fonts, icons, and permitted art assets. Record file hashes in a manifest.
- Godot 4.6.3, a 1280 × 720 target viewport, a 960 × 540 compact viewport, the same renderer/stretch settings, muted audio, and the same runtime/capture environment.
- Equivalent tool, time, generation, and repair budgets. The only intended treatment difference is access to the frozen skill. Store that skill's version/hash before the trial; do not edit it during the trial.

Any shared-asset or shared-model fix must be documented and applied equally. Preserve the originally submitted candidates and score only the declared final submissions. Do not let the evaluator's interim findings reach one candidate alone.

## 2. Blind procedure and evidence order

1. The coordinator assigns neutral identifiers A and B and strips method names from supplied captures. The evaluator does not read candidate sources, method-specific notes, self-assessments, or previous settings-demo results before locking visual scores.
2. Inspect the actual shared reference at its native size, then matched A/B runtime screenshots for the same scenario and viewport. Alternate display order between states. Record observations and visual subscores before source inspection.
3. Run the same input sequence against isolated project copies. Capture actual UI input, model events, snapshots, and pause timing evidence. Use the hidden Codex in-app browser for a web export or headless Godot automation; do not open native/external browser windows.
4. Inspect candidate source and scene trees only after visual observations are locked, to verify native controls, model integration, input routing, and any discrepancy that runtime evidence cannot settle.
5. Reveal identities only after both evidence tables and scores are recorded. A source explanation may clarify a functional finding but cannot retroactively improve a screenshot's fidelity.

Keep raw logs, screenshots, exports, and browser recordings in this temporary trial root or an ignored artifact folder. Do not use normal player saves, personal configuration, real game source, or network services. Disable music and sound.

## 3. Required matched capture states

Use named scenarios supplied by the shared model. The coordinator records the exact snapshot/tick for each capture; UI animation should be held at the same declared settled phase where possible.

| State | Required visible evidence | Size |
| --- | --- | --- |
| Initial (primary) | Shared paused-active initial board: gold360/crystal12/lives20, wave3/8, two towers, three beetles, selection -1, native resume action; next-wave unavailable | 1280 × 720 |
| Active | A reproducible mid-wave moment with multiple enemies, operating towers, health/lives/resources, and a readable path | 1280 × 720 |
| Selected | A real selected tower/site with native build or upgrade controls and a correct affordable price | 1280 × 720 |
| Paused | The same active game after pause, with correct state and a visibly discoverable resume action; no full-screen overlay is required | 1280 × 720 |
| Compact | Initial primary state, plus active or selected, with the same model state as their large captures | 960 × 540 |
| Outcome | A deterministic win or loss reached through the common model, with an operable restart | 1280 × 720 |

The initial paused-active snapshot is the primary reference-fidelity comparison at both sizes. The generated concept's pause glyph yields to the real model state: an appropriate resume action and disabled next-wave are correct. Do not deduct fidelity points for these declared semantic corrections. Selection is permitted while paused; build, upgrade, and start are rejected. Restart always restores this paused-active snapshot. `reset_ready()` is an external test helper, not a normal restart or an alternate initial screenshot. Active and selected states confirm that fidelity survives actual gameplay. Do not compare an empty scene to a populated reference. Pixel-only review scores visual categories only and makes no inference that a screenshot proves functional behavior.

Screenshots must come from the running application. Reference overlays, painted screenshots presented as runtime UI, or evaluation-only scene substitution do not qualify. Postprocessing is limited to identical cropping of window chrome; preserve the full viewport.

## 4. Scoring (100 points)

Award partial credit. For each subcriterion use the same anchors: 100% = convincing with no material issue; 75% = minor defects; 50% = clear defects but usable; 25% = major defects; 0% = absent or broken. Explain material deductions with a screenshot crop, coordinates, model event, or repeatable input result. Avoid spurious precision: round category scores to the nearest 0.5 point.

| Category | Points | Subcriteria |
| --- | ---: | --- |
| Reference fidelity | 40 | Major placement, sizing, proportions, and spatial hierarchy (16); map, structures, materials, palette, and lighting coherence (12); typography, icons, HUD styling, and control treatment (8); borders, shadows, selection details, and visual finish (4) |
| Visible gameplay and readability | 15 | Path, build sites, goal, and playable area remain legible (5); enemies, towers, health, targeting/attack feedback, and selection can be distinguished during play (5); resource/wave/control state is readable and communicates the available next action (5) |
| Authoritative state and gameplay | 20 | Resources, lives, wave progress, and outcomes match the shared model (6); start creates a progressing wave and repeated start cannot duplicate it (4); build, selection, upgrade, affordability, and debit behavior work (6); outcome and restart work without stale state (4) |
| Pause behavior | 6 | Pause and resume are discoverable and correctly reflected in UI (2); gameplay time, movement, attacks, spawning, and economy freeze and resume correctly (4) |
| Native controls and hit geometry | 11 | Required HUD/panel actions use native Godot `Control`-based interactive nodes with actual focus/disabled state (4); mouse/touch hit targets agree with the visible controls and remain correct after resizing (4); overlays, panel/world routing, keyboard activation, and repeated inputs cause no unintended actions (3) |
| Compact layout | 8 | Essential HUD, prices, buttons, and panels stay in bounds without overlap or clipping (4); readable hierarchy and usable playfield/input geometry survive 960 × 540 (4) |

Do not reward extra features, extra controls, unrelated artistic redesign, code volume, or the use/absence of the skill. Compare requested behavior only. Score text readability at native display size, without magnifying it to excuse inadequate runtime sizing.

The reference-fidelity score is a visual judgment. Pixel-difference or similarity metrics may expose misalignment, but are supporting evidence only: antialiasing, font rasterization, particles, and dynamic actors prevent a meaningful universal pixel threshold.

## 5. Required interaction checks

Use real pointer/key input for UI acceptance. Calling model methods is appropriate for model tests and scenario setup, but it does not prove a button or build site works.

| Check | Expected result |
| --- | --- |
| Start in ready state | Exactly one wave begins; UI and model agree; start becomes unavailable or reflects the correct next action. |
| Build an affordable tower | Correct tower appears on the chosen eligible site; one debit occurs; occupancy and selection update. |
| Upgrade selected tower | Exactly one upgrade and debit occur; level/stat/price display reflects the new model state. |
| Attempt unaffordable action | Resource balance and tower state do not change; the unavailable action is communicated. |
| Select another site/tower and click empty map | Selection behavior matches the common brief; no stale price or accidental purchase. |
| Rapid/repeated action input | No negative resources, duplicate occupancy, duplicate wave, or double debit. |
| Pause during an active wave | Capture a snapshot, wait at least two real seconds, and compare gameplay state; only permitted UI effects may advance. |
| Inputs while paused | Build/start/upgrade are rejected; site selection and clearing remain allowed; resume and restart stay usable. |
| Resume | Simulation continues from its frozen state without a catch-up burst, duplicate spawns, or reset. |
| Panel/overlay click | Clicking visible UI cannot also select/build on the world beneath it. |
| Hit boundaries | Center/near-edge inside clicks activate once; a declared outside point does not; press-drag-out-release follows native button semantics. |
| Resize and repeat | The same checks work at 960 × 540 and after returning to 1280 × 720. |
| Keyboard activation | Tab focus and Enter/Space activate essential enabled controls once; disabled controls remain disabled. |
| Win/loss and restart | Outcome matches the model; restart clears actors, selection, pause, resources, and pending wave events consistently. |

For geometry, use the actual visible control bounds and scene transforms at each size. Test corners/edges that are visually part of a control; do not require transparent ornamental flourishes to be clickable. World hit regions may use the shared site's declared disk or polygon. Report mismatch in viewport pixels and behavior; do not impose undocumented target sizes after submission.

## 6. Acceptance versus comparison

Report category scores and total, plus these explicit acceptance conditions:

- The application launches and renders the intended game in the agreed environment at both sizes.
- The shared authoritative model drives visible state; no replacement/static mock model is used.
- Start, build, select, upgrade, pause/resume, and restart are operational through runtime input.
- Pause does not advance gameplay, and input routing does not cause world actions beneath a visible blocking UI panel/overlay (when present).
- Required interactive UI is native Godot UI rather than a single baked interface image or invisible hotspots over painted controls.

A failed condition is a named blocker even if the total score is high. Do not erase the visual score because of a functional blocker; show both so the result stays interpretable. The above conditions do not introduce a requirement that every decorative element be a `Control` node.

Call a method's advantage only when it is supported by observed differences. A total difference of 3 points or less is a practical tie for this single trial; larger differences still require the category evidence and uncertainty statement. One scene, one reference, and one implementation per condition cannot establish general skill effectiveness. Report environment/capture failures separately from candidate defects, rerun both equally when needed, and mark unobserved checks as unverified rather than passed.

## 7. Final evidence table

For each candidate record: artifact manifest/hash, engine/version, runtime/capture environment, reference/scenario IDs, screenshot paths, category subscores, acceptance blockers, repeatable defects, successful input evidence, and any unverified requirement. Then provide a short comparison grounded in those records. Do not accept a candidate's own checklist as execution evidence.

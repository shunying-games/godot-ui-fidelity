# Moonwell Bastion — controlled comparison results

The two implementations are a **practical visual tie** in this trial. The version using the frozen Godot UI fidelity skill has a small clarity advantage, while both pass the same eight observed core browser interaction checks. This result does not establish that either method is generally superior.

## Trial and blind review

Both implementations used the same generated reference, clean map, actor/chrome assets, font, authoritative battle simulation, Godot 4.6.3, and 1280 × 720 design canvas. The primary comparison used the same real paused-active wave 3 snapshot at 1280 × 720 and 960 × 540. An appropriate Resume action and unavailable Next Wave correctly override the generated concept's pause glyph and enabled-looking button.

The evaluator locked the primary pixel review before seeing sources, runtime evidence, self-assessments, or the identity mapping:

| Blind identifier | Revealed condition |
| --- | --- |
| A / Ivory | With the frozen UI fidelity skill |
| B / Slate | Without the skill |

## Locked visual scores — 63 points possible

| Visual category | Maximum | With skill / A | Without skill / B |
| --- | ---: | ---: | ---: |
| Reference fidelity | 40 | 33.5 | 33.0 |
| Visible gameplay and readability | 15 | 12.5 | 11.5 |
| Compact layout | 8 | 6.5 | 5.5 |
| **Visual subtotal** | **63** | **52.5** | **50.0** |

The 2.5-point difference falls within the predeclared 3-point practical-tie threshold. These are visual scores only. No overall score out of 100 has been assigned; screenshots do not establish gameplay correctness, native controls, or hit geometry.

Both preserve the reference's marsh battlefield, bright winding path, cyan goal, thin upper HUD, and raised three-card lower deck. The shared artwork remains coherent and detailed, and the playable area stays visible at both sizes. Both distinguish towers, beetles, health bars, and empty build pads clearly in the paused scene.

A's resume triangle, restart label, and lower-left hint are easier to read. B's central deck surround is slightly closer to the reference's proportions, and its `Resume to defend` caption communicates the immediate paused-state action well. The concrete defects are:

- B's resume/restart text symbols render as unresolved box-like glyphs in the captured browser export. Its small `RESUME` label provides some context but does not restore a recognizable symbol.
- B's centered lower instruction reaches the viewport edge and is partially clipped in both primary sizes. A gives its analogous hint visible bottom margin.
- Both reduce the reference's richer carved ornament to flatter HUD treatments. Thin, muted labels and secondary instructions become small at 960 × 540. The towers' visibly exposed circular pads make their ground integration look more composited than the reference.

Matched selected-site supplements were inspected after the primary lock. Both show a distinct selected ranger ring, a restrained range outline, a lower-left context panel, model values, upgrade 100, and `Resume to upgrade`. A uses a narrower text-led panel with attack interval; B uses a tower thumbnail and a wider panel. Disabled upgrade text is small/low contrast in both compact views. These observations do not change the locked primary scores.

An initial A selected-desktop capture caught a browser viewport-resize transient. A fresh fixed 1280 × 720 capture from the unchanged source resolved the scaling/cropping mismatch. This was treated as a harness correction, with no candidate penalty or source repair.

## Observed browser behavior — 8 of 8 groups passed for each

The coordinator used actual pointer/keyboard input and read the passive probe to capture model/UI state. All 16 recorded check groups report `pass: true`:

| Common check group | Observed evidence in both conditions |
| --- | --- |
| Paused site selection and resize | Site 0 selected at tick 0; paused state preserved. |
| Pause over real time | Tick remained 0 over approximately 24 s for A and 44 s for B. These durations are not performance scores. |
| Blocked paused purchase and HUD/world routing | Gold stayed 360 and selected site stayed 0 while choosing frost in the HUD. |
| Native Resume and atomic frost build | Resume advanced the simulation; one frost tower appeared on site 5 and gold changed 360→220. |
| Explicit upgrade and occupied selection | Existing tower reached level 2; gold changed 420→320 exactly once; tower count stayed 3. |
| Combat progression and keyboard pause | The running wave advanced and cleared to ready at tick 1169; the probe's keyboard-pause group passed. |
| Native Next Wave and repeated start guard | Pointer Next Wave plus repeated Space produced wave 4 with one live enemy and 11 remaining spawns, without a duplicate wave. |
| Keyboard restart | R restored gold 360, two initial towers, and the paused tick 0 fixture. |

Both imports/Web exports completed cleanly, and the coordinator reported no browser console errors for either condition. The checks above demonstrate the observed core flows; they are not exhaustive UI acceptance.

## Source and shared-model validation

Post-lock inspection confirms that both versions instantiate native Godot `Button` controls and connect their `pressed` callbacks to model commands. HUD labels read snapshots, build/upgrade/next-wave disabled states follow model availability, and real model snapshots supply enemies, towers, projectiles, health, resources, wave state, and effects.

Both render the clean map and individual actor assets separately. The inspected sources do not load or render the full reference screenshot as the interface. HUD panels/buttons use native controls decorated with reusable texture styles and independently rendered icons/art; world/site selection uses model coordinates and a consistent scaled design canvas.

The shared model's SHA 256 matches the frozen version:

```text
779d816e9066a1ab42743d8a0270cfbec0959806462dec924f109cb1fdd8d150
```

The common model passed 90 headless assertions under Godot 4.6.3, including atomic economy, pause invariance, deterministic stepping, real attacks/projectiles/rewards, bounded waves, terminal win/loss simulation, and restart state. Those tests validate the simulation, not every candidate UI route into it.

One source-level follow-up applies to both: Space is consumed as a global Next Wave shortcut in `_input` before native GUI handling. Native focused-button Space activation should therefore be tested explicitly before claiming conventional keyboard activation semantics. No additional integration blocker was established by the inspected source and observed core probe. The glyph and clipping issues above remain actual rendered clarity defects.

## Still unverified in the candidate browser UIs

- The complete remaining campaign through wave 8, terminal win/loss presentation, and restart through the terminal outcome button.
- An unaffordable build/upgrade attempted through the UI, including its visible feedback.
- Tab/focus traversal and Enter/Space activation of focused controls.
- Precise inside/outside hit boundaries, edge/corner targets, and press-drag-out-release behavior at both sizes.

These items remain unverified rather than passed or failed. The shared model's 90 tests do not substitute for those UI flows. Active combat's detailed visual feedback was not part of the locked pixel comparison.

This is one reference scene, one shared asset package, one common simulation, and one implementation per condition. Shared artwork and logic account for much of both results. The useful outcome is the measured practical tie, the small observed clarity difference, and the explicit remaining acceptance work—not a broad claim about skill effectiveness.

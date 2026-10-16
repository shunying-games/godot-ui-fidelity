# Predeclared acceptance plan: Mosslight Atelier

Prepared from the frozen `BRIEF.md`, `shared/settings_model.gd`, and `shared/project.godot` only. Neither candidate source, the candidate mapping, nor the UI skill was inspected. This plan and the common harness are evaluation artifacts; they give no candidate implementation advice.

## Evidence protocol

1. Freeze the first submitted source for each candidate before adding the identical probe. Preserve a source hash separately from the instrumented export. Instrument an isolated copy, keeping generated evidence outside candidate source and normal player saves. Do not edit the immutable model or project settings.
2. Use Godot 4.6.3, Web/gl_compatibility, the hidden Codex in-app browser, and disabled sound/music. Avoid native windows and external browsers. Use the same export options, browser/device pixel ratio, loading wait, viewport dimensions, and action sequence for both candidates.
3. Use anonymous candidate identifiers during review. Do not show the reviewer candidate source, assignment, mapping, skill status, earlier critiques, or expected outcome. The root coordinator controls that mapping.
4. Record the actual logical viewport from `ui-study-probe`, browser viewport and canvas bounds, and the exported source hash with each screenshot/action record. Use actual rendered screenshots. If the browser canvas is not the requested logical size, correct the test setup before judging layout.
5. Use only real pointer/keyboard interaction for UI actions. Probe JSON is observation, never an input channel. Wait at least two published samples after an interaction, then record screenshot plus JSON. Observe numeric/state changes over time for a single action to detect duplicate Apply effects.
6. Run the same sequences at 1280×800, 390×844, and 844×390. Begin each full behavioral sequence with a fresh page load. Separately resize an already open modal through all three sizes and back to desktop to detect stale layout or lost draft state. A control reached through intentional scrolling is accessible if the scrolling works by ordinary input and its target remains usable.

## Required behavior checks

| ID | Procedure using actual controls | Expected observation |
| --- | --- | --- |
| B01 | Fresh load, settle, inspect screenshot and snapshot. | Settings opens immediately. Saved and draft begin at Music 60, Sfx 80, reduced motion false, language 0. `modal_open=true`, `paused=true`, `apply_count=0`, `brew_count=0`. The title, world context, heading, support copy, sliders with numeric values, motion control, language control, Apply, Cancel and X are present. |
| B02 | Change each slider by a normal pointer gesture to a clearly different value; toggle motion; select Extended labels. | UI numeric values follow the actual slider values. `draft` changes accordingly; `saved` remains 60/80/false/0. No Apply or Brew count changes. Compare slider range/value from the probe with displayed numbers, allowing presentation rounding if consistent. |
| B03 | Inspect Extended labels at every size, scrolling if needed. | Exact texts are visibly available: “Background music volume during exploration”; “Sound effects volume for tools and discoveries”; “Reduce decorative motion and transition effects”. All settings and footer/close actions remain reachable. Language can return to English through the ordinary menu. |
| B04 | After draft edits, click Cancel. Reopen using PrefsToggle. | Modal closes, pause restores to false, draft resets to saved, Apply count stays 0. PrefsToggle remains visible/reachable while closed. Reopening shows saved values rather than the discarded edits. |
| B05 | After new draft edits, use X. Reopen. | Same discard and pause-restoration behavior as Cancel, with no commit or count change. |
| B06 | After new draft edits, press Escape while settings is open. Reopen. Also test Escape after opening the language menu and closing that popup. | Settings cancellation works through keyboard and discards draft. If the language popup consumes the first Escape to close itself, a subsequent Escape cancels settings; record this interaction honestly. |
| B07 | Edit all four settings, record draft, click Apply once, and wait. Reopen. | Saved equals the recorded draft; modal closes; pause restores; Apply count increments exactly once and remains stable while idle. Reopening shows committed values. Clicking Apply once after another edit increments once again. |
| B08 | While modal is open, attempt to click the underlying Brew target, using its observed center or a visible exposed portion. If occluded, retain the intended underlying coordinate and note the actual foreground control hit. | `brew_count` never changes while modal is open. A foreground settings action may legitimately receive the click. No click-through reaches the world. |
| B09 | Close settings, click Brew once, wait, reopen. | `brew_count` increments once for the single activation when closed/unpaused. Reopening leaves count unchanged and again blocks brewing. |
| B10 | Navigate/activate representative buttons, slider, CheckButton and OptionButton with standard keyboard controls where provided. Test Escape explicitly. | Focus visibility/order and keyboard usability are recorded. Escape cancellation is mandatory. Other keyboard usability is assessed as usability evidence without inventing a complete keyboard spec absent from the brief. |
| B11 | Open settings, make a distinct draft edit, resize through all three prescribed sizes and back; then Apply or Cancel. | No crash, missing input, stale layout, spontaneous commit or draft loss from resizing. The final action retains the required commit/discard behavior. |
| B12 | Review runtime/browser logs during the above. | No relevant script/runtime failures. No disk persistence or sound playback is triggered. Authoritative wiring to the immutable root `model` is verified separately by the coordinator's source compliance check after blind visual review; snapshot appearance alone cannot prove ownership. |

The immutable model's prior-pause invariant is tested in isolation by `test_tools.gd`: both Apply and Cancel restore a previously paused state, and closed-but-paused Brew is blocked. The UI has no brief-authorized way to create a prior pause. Therefore this model test does not prove that either candidate wires every action correctly or handles a prior pause in its live UI.

## Layout and input checks at every size

| ID | Measured and rendered check | Pass condition / evidence |
| --- | --- | --- |
| L01 | Actual control type and required names from the common probe. | Each of MusicSlider, SfxSlider, MotionToggle, LanguageSelect, ApplyButton, CancelButton, CloseButton, BrewButton, PrefsToggle identifies one actual native interactive Control; no duplicate or proxy substitutes. Input succeeds on that control. |
| L02 | Global transformed rects, clipping intersections, parent transforms, pointer centers and screenshots. | Relevant targets have at least 44×44 logical pixels of interactive area where accessible. Slider may use its full actual interactive Control rect. Check transformed edge lengths if rotated; an AABB alone can overstate target size. Target area may extend beyond the painted icon/track without stretching artwork. A wholly clipped/inaccessible part cannot supply a usable target. |
| L03 | English and all three exact Extended label texts, slider numbers, checkbox text, language choices and action labels. | Text remains readable without unintended overlap, truncation, ellipsis or clipping of required content. Intentional wrapping/scrolling preserves the full meaning. Label line counts, visible-line counts, min-size clues and unwrapped width are diagnostics, verified against pixels. |
| L04 | Modal edges, footer, close button, scroll behavior and language popup. | At desktop, portrait and short landscape all settings/actions are reachable; no accidental offscreen trap or unusable scroll area. Menu items are legible/reachable and select correctly. Horizontal page overflow is investigated, not inferred solely from unused world art. |
| L05 | Click ordinary centers and near edges of representative targets; inspect modal/world hierarchy. | Decoration does not steal input. The backdrop/modal blocks the world. Sliders/toggle/options work at each size; visible target geometry agrees with pointer action. Geometry does not reveal occlusion or prove hit testing by itself. |
| L06 | Close modal, reopen, switch language, resize repeatedly. | No accumulating offsets, shrinking target scale, hidden persistent PrefsToggle, detached numeric values, stale focus blocker, or controls left in the wrong visible state. |

## Blind visual review, separate from mandatory acceptance

Use the same screenshot set for both candidates: initial English desktop/portrait/landscape; Extended labels desktop/portrait/landscape; closed world desktop; one language popup; and any failure evidence. Do not select only favorable moments.

Score each dimension 0 (weak/incoherent), 1 (adequate), or 2 (strong/intentional), with a brief pixel-grounded rationale:

- Hierarchy and task clarity: title, heading, supporting text, setting labels/values and primary/secondary actions are distinguishable.
- Typography and readability: sizing, contrast, line length and long-label treatment suit the three layouts.
- Spacing and responsive composition: alignment, grouping, breathing room, modal proportions and touch targets remain balanced.
- Material and restrained decoration: midnight ink, parchment, sage and brass/amber feel coherent, with decoration supporting legibility.
- World context and original visual polish: moonlit botanical/alchemy workshop remains evident behind the modal without overpowering the task.

Report the 0–10 visual score alongside hard acceptance results, never as a substitute. Do not assume a skill advantage, causal generalization, production performance result, or universal design quality from two implementations. Disclose this is a controlled one-pass comparison under one brief and toolchain.

## Shared tooling and limitations

- `harness/probe.gd` may be a root child with `set_target(app_root)`, or an autoload which discovers `current_scene.get_probe_state()`. Its only browser write is inert JSON text in `<script type="application/json" id="ui-study-probe">`. It records the viewport, whitelisted model snapshot, exact named controls, slider values/ranges, button/option text, parent transforms, visible clipped AABBs, target centers, labels and scroll ranges. It does not dispatch input, change focus/state, write files, or fabricate rendered output. Resource/file-looking text is omitted.
- Browser code can read `JSON.parse(document.getElementById('ui-study-probe').textContent)`. This cannot control the application. Prefer actual observed coordinates and a fresh sample before each pointer action.
- The probe's `visible_rect` intersects the viewport and clipping Control ancestors; it is a transformed axis-aligned approximation. It does not subtract overlapping siblings, shadows, opaque overlays, nonrectangular clips, shader masks, native popup occlusion, or inspect glyph pixels. `visible` means the node's visibility chain, not guaranteed perceivability. Font metrics are explicit estimates, not clipping verdicts.
- The language popup's own visibility/position/size/options are exposed, but native popup row hit areas must be checked in the rendered browser. Root/world decoration implemented by drawing code has no semantic geometry in this probe.
- `harness/collect_headless.gd` instantiates the frozen candidate's configured main scene in a headless process, resizes the viewport and collects geometry after repeated stable samples. Its JSON explicitly says `rendered_acceptance=false`. Headless font/layout behavior may differ from Web; no UI acceptance is claimed from it.
- `harness/test_tools.gd` tests the immutable model and synthetic native controls only. Success validates the evaluation tooling's basic assumptions, not a candidate. No candidate source is loaded by this test.
- Rendered browser actions and source compliance checks are still required. Saved-state snapshots can reveal behavior but cannot establish absence of hidden state, filesystem calls, external assets, or forbidden implementation technology.

Example commands, after assembling a frozen candidate from `shared/` and one variant directory (see README):

```sh
"$GODOT" --headless --audio-driver Dummy --log-file "$OUT/tool-check.godot.log" --path "$PROJECT" --script "$HARNESS/test_tools.gd"
"$GODOT" --headless --audio-driver Dummy --log-file "$OUT/geometry.godot.log" --path "$PROJECT" --script "$HARNESS/collect_headless.gd" -- --sizes=1280x800,390x844,844x390 --out="$OUT/geometry.json"
```

These commands collect local test evidence. No source commit, upload, native window, fabricated screenshot, model persistence, or candidate modification is part of them.

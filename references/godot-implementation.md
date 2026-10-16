# Godot controls, state and UI feedback

Use the engine/version and node conventions actually present in the project. Check layout, state ownership and rendered results separately.

## Control and layout ownership

Choose a clear layout model: measured canvas for a fixed illustration, Containers for flowing/localized content, and anchors for viewport-relative regions. A hybrid is fine when each area's owner is explicit. Container-owned children can be repositioned by sorting; do not assume arbitrary manual offsets will persist.

- Use native Button, OptionButton and HSlider/VSlider controls for their intended behavior and connect their real input signals to the existing action path. Use Label text and font resources for changing content.
- Keep presentation separate from authoritative progress, economy, rewards and audio preferences. Read shared values; do not recreate a price table or grant a reward from animation completion.
- Set font/theme, minimum sizes, state styles and native grabber dimensions before rectangles. Font shaping and deferred container sorting can leave already-clamped rectangles too large; reapply layout after that work when a reproduction demonstrates the need.
- Inspect fresh startup and live resize at compact portrait/landscape, plus the widest supported text/value. A Control can report the new small minimum while retaining its previous larger size. Check actual text bounds and centers as well as input rectangles. Wrapped labels can also expand to their new minimum height while the parent card keeps its old height: verify containment within the intended card/inset, not merely the viewport. Derive the card height and following positions from settled wrapped content, or use an approved scroll/ellipsis policy. Test a string that actually crosses the line-wrap threshold; a longer-looking single line is not that test.
- Keep visible artwork uniformly scaled where required. Expand touch targets independently and choose a minimum for the actual input/platform requirement. For example, a project may use 44 logical pixels as a starting hit-area convention; it is not a universal threshold or permission to stretch art. Check device/display scaling and overlap at the target viewport. Allocate shared empty space between adjacent targets instead of expanding each symmetrically without constraint. If the targets cannot fit, use the approved compact/reflow/scroll fallback; do not fix a conflict by shrinking below the chosen minimum. Validate settled runtime global rectangles together using the [hit-region checker](../scripts/check_hit_regions.py) described in [Acceptance](acceptance.md#neighboring-hit-regions), then click the closest edges.
- Decorative layers generally ignore pointer input. Use native focus styles and a sensible keyboard/controller order where those inputs are supported. Hover must not be the sole indication available to touch users.
- Let UI consume its input before the game's unhandled playfield-input path. Inspect existing global `_input` handlers for accidental activation beneath a control or modal rather than rewriting unrelated input code.
- Cover normal, focus, pressed, disabled and pending states as applicable. Make unavailable actions legible and truthful; reserve unsupported settings without offering fake functionality.

## Modal lifecycle and input

Define whether opening blocks gameplay input, camera movement and simulation. Preserve the actual pre-open state; closing a menu must not unpause a game that was already paused. Match the project's focus-loss policy, and verify close, cancel, confirm, return and scene-switch paths.

If the UI temporarily masks or defocuses an underlying interface, preserve and restore the original properties. Repeated open/resize events must not overwrite the snapshot with the already-hidden state. Avoid letting refresh logic or duplicate aliases invalidate the captured values.

For repeated-click or reward issues, trace the native event to the authoritative transaction. Use the existing operation/state guard for at-most-once actions, handle success/failure/pending, and make visual feedback reflect that result. A button lock alone must not be mistaken for durable reward correctness.

## Drawing, import and shaders

Custom `_draw` resources must outlive the deferred draw command: retain textures, atlas sources, StyleBoxes and meshes in script/member/cache ownership. Keep TextureRect textures/materials alive through their actual owner too. A font character coverage check cannot prove an illustrated caption rendered.

Check texture regions, per-asset slice boundaries, alpha, color modulation, filtering and display scale in actual frames. In a Godot 4 CanvasItem fragment shader, incoming `COLOR` already contains the default texture sample. `texture(TEXTURE, UV) * COLOR` therefore applies that texture twice and can darken the artwork. If changing only alpha, preserve incoming RGB; if resampling, pass the vertex tint in a varying and multiply it once. Compare an unchanged opaque source-color patch with the rendered patch to catch unintended tinting. See the [Godot COLOR contract](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html#color-and-texture). Large source images and low-alpha fringes may need rendering-aware filtering rather than destructive asset changes. Do not claim an engine limitation without documentation or a minimal reproduction.

For texture or screen-reading blur, inspect high-contrast scenery edges at native screenshot scale at every tested size. Widely spaced 5/9-tap cross samples can produce repeated edges or grids even when the screen looks soft in a thumbnail. Prefer a verified prefiltered/mipmap path (texture mipmaps must actually be generated) or a proper separable filter. For screen reads, see [Godot mipmap blur](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html). Capture before/after from the actual renderer; importing or compiling the shader does not verify the filter. Control the captured layer order so unwanted HUD/menu elements are not baked into the blur. Do not add blur unless the visual direction or readability needs it.

## Feedback and motion

Start from the interaction's meaning: input acknowledgment, a state change, successful action/reward or an error. Use clear state styling first; add a small number of purposeful motion/audio layers that fit the game's material and existing motion tone.

- Button press/selection: responsive local depression, scale or highlight; keep the hit rectangle stable and text readable.
- Modal open/close: a brief, interruptible transition; preserve the established dismissal/input semantics.
- Reward or unlock: a stronger focal accent is appropriate, driven by the actual successful result. Keep the next action accessible.
- Error or unavailable action: truthful local feedback without pretending the action succeeded.

Use the project's tween/animation approach. Replace or cancel conflicting transitions; define rest values, interrupted/repeated input behavior and cleanup on hide, scene change or free. Avoid cumulative scale/position drift and callbacks firing after their UI state has changed.

Animate a visual child when the parent is owned by a layout Container or defines the hit rectangle; preserve the layout and interaction geometry while adding the visible response.

Classify time ownership. Some essential menu feedback must work while the battle is paused; decorative/world-linked movement should follow existing pause and focus rules. Specify the needed process policy explicitly. Respect existing reduced-motion and sound settings without adding new settings solely for this task.

Combat shake, global hit-stop, knockback and simulation-speed changes belong to separately requested gameplay work. UI polish should preserve confirmed gameplay boundaries, including timing, damage, economy and progression. Heavy screen-wide effects and repeated animation must be justified by the player's task and tested for legibility/performance.

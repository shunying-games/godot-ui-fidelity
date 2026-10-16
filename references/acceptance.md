# Rendered and functional acceptance

Keep subjective feel, functional correctness and visual fidelity distinct. Capture enough source, state and environment information to reproduce each result.

## Select evidence proportional to the change

For a visual-only adjustment, relevant actual screenshots/comparisons may be sufficient unless the repository requires more. For changed input, sizing, lifecycle or state, run focused regression checks and exercise the real action. Reuse the existing SceneTree/GUT/gdUnit framework; do not introduce mandatory TDD, a new framework or an unrelated full-game suite.

Headless tests can check control geometry, input routing, pause/restoration, model/state changes and resource ownership. A dummy renderer cannot provide real visual evidence. A headless configuration with a real rendering backend may provide captures when supported; verify the backend and inspect the output rather than inferring rendered quality from a passing test.

For fresh isolated Godot copies, import before running suites that need generated resources. Use runners that count failures and exit nonzero on failure, preserve stdout/stderr and bound execution. For asynchronous checks, observe signals before triggering the action and bound the wait; use tolerances appropriate to scaled/float geometry rather than exact equality without justification.

## Capture the correct state

Use an isolated project and test namespace with audio muted for background verification, following repository testing policy. Preserve normal player files; retain the source version/hash, viewport/display scale and state used for each candidate. Use an authorized browser surface or renderer suitable for the target platform. Keep generated shots, raw reports, caches and builds outside Git unless the repository explicitly maintains a reviewed fixture.

Capture the actual Godot implementation. A generated concept, HTML replica, empty headless texture or screenshot of the menu after the dialog vanished is not evidence of the requested UI. A static presentation fixture may keep a screenshot stable, but label its lock and verify production dismissal separately.

For adaptive UIs, include the requested/base size, fresh compact portrait, fresh short landscape and a live resize while the surface is open. Compare equal control states; inspect longest supported labels/values and applicable enabled/disabled/focus/pressed/pending/error states. Pick relevant cases rather than exercising every imaginable input combination. For wrapped content, include a case that adds another rendered line and inspect its padding within the owning card, plus the next section. If browser IME tooling cannot enter the exact fixture string, record that limitation and use a separate documented data seed to test layout; continue exercising native controls, and do not claim the seed proves text entry.

## Isolated renderer setup

Inspect existing project helper commands and their prerequisites before reusing a temporary test session. Match the engine, import cache, export templates and source version needed for the target build. A missing cache or expired artifact path requires a fresh setup rather than an invented report.

For Web capture, prepare a fresh isolated export with compatible templates and a separate test origin/save namespace. For native capture, use the project's supported renderer and test data location. Keep export success separate from runtime, browser and visual acceptance; old captures apply only when their source, fixture and rendering environment remain compatible.

## Visual comparison and review

Compare the full composition at matching viewport/aspect/state, then aligned crops/overlays where needed. Preserve aspect ratio in QA comparisons and label any diagnostic normalization; do not hide a stretched implementation through distorted comparison images.

Check silhouette, hierarchy, character/icon scale, font ink and legibility, spacing, materials/lighting, alpha/cropping, decoration inventory, background separation and the real playfield. Check surrounding scenery after resize too. A global pixel score can miss an absent button label or small important icon.

When delegation is available, let an independent reviewer inspect the approved source and actual render without leading it toward a pass. Ask for concrete remaining differences and their player/design impact. Record agreed reference/data exceptions; do not reclassify a wrong shape, unreadable typography or missing important art as optional polish to force acceptance.

For a new design without an approved picture, judge the brief, thematic consistency, hierarchy, real task completion and playfield protection. Do not invent a pixel-similarity target. For motion, record observable behavior separately from the user's subjective judgment of feel.

## Neighboring hit regions

For scaled or expanded targets, export the visible, currently active controls' settled global rectangles and viewport in the same coordinate space. Supply those rectangles to `python3 <skill>/scripts/check_hit_regions.py <input.json>`; see its `--help` for the small JSON schema. Set the minimum per target for the actual input requirement. Select relevant sibling actions; do not blindly include parent containers, decorative nodes or controls disabled by an active modal. Any intentional overlap needs an explicit pair and reason.

The checker fails on out-of-bounds, undersized or overlapping targets. Preserve the failing result and retest the same state after correction. A zero exit only proves the supplied geometry: it does not establish correct mouse filters, z-order, transform mapping, drag behavior or active-target selection. Click adjacent target edges and drag a slider in the actual runtime as well. Never call layout fully passed from per-control minimum/bounds tests while a known overlap remains.

## Exercise the actual behavior

Use real pointer/keyboard/touch-style input through the shipping controls for input-sensitive checks. Calling a handler, setting a value or emitting `pressed` directly can test state logic but cannot prove hit geometry, focus or drag behavior.

Choose relevant paths: open/close/cancel/return; prior pause and focus loss; scene changes; slider endpoints and independent channels; disabled/pending actions; repeated input; preference reload where changed; supported languages and longest values. An input action with no effect requires fresh state/diagnosis, not blind repetition.

Keep bugs and test-harness defects distinct. Preserve a failing report and its diagnosis; if a fixture is corrected, describe why and rerun the meaningful check. Reused evidence needs the exact compatible source/fixture boundary stated. Silent console/game errors prevent a technical pass.

## Iterate and retain the best

After an observed failure, name the largest mismatch or behavior defect, make a targeted change and recapture/check the affected state. Keep a recoverable source/asset version of the best reviewed candidate; a good screenshot alone cannot restore its implementation.

Respect the user's iteration/time/cost limits. State how meaningful candidates are counted, including design/asset attempts when they are part of the same requested budget. Transport retries and builds are technical attempts, not fake extra design versions. Stop when the target is met, or select the best actual reviewed candidate at the limit and report unresolved issues.

If capture is blocked, continue independent authorized work, preserve artifacts and state visual acceptance is pending. Do not use an alternate browser/control path to bypass a denied approval. Resuming requires an authorized, available path; elapsed time is not approval.

## Handoff

Report the actual artifact/runtime screenshot, selected source/candidate, what changed and why, verification scope and remaining differences. Separate visual, interaction and technical outcomes; give subjective game-feel observations their own boundary. A design-only artifact is complete within that scope without being called a deployed game change. Do not promise pixel-identical generated extraction or full-device performance from a single screenshot.

# Design direction and asset handoff

Use the game's visual language and a measurable asset handoff. A design service is optional; local Godot assets and an approved screenshot can supply the same contract.

## New design

Start with the player's task: what they need to know, decide and do on this surface. Record the game's genre/fantasy, camera/viewpoint, input method, existing material/font/palette, persistent vs temporary information and desktop/mobile expectations.

- Establish hierarchy using real game importance. Separate action, state and explanation; give the primary action a clear visual priority. Use the game's existing vocabulary and component language.
- Protect the active playfield: inspect actual paths, build slots, combat focus, pickups and camera/drag boundaries. Use compact edge clusters and contextual prompts where useful. Do not import a fixed 3D HUD coverage quota into a 2D game or a full-screen menu.
- For requested alternatives, vary useful decisions such as hierarchy, composition, disclosure or material treatment. Keep the same content and player task so variants are comparable. Produce only the requested/justified number; do not make color-only variants or start speculative image batches.
- Bind a numbered selection to the actual displayed image order, then record its exact file/result identity. Do not implement another image because its tool-generation order or descriptive name was similar.
- A design-only request ends with designs, a prototype or a handoff. Implement the selected version when the user's scope authorizes implementation. If they already selected a version, proceed from that selection.

Use reusable Godot Theme resources and components for common font roles, colors, spacing and state styles. Keep an illustrated unique panel's measured geometry where it matters rather than forcing every asset into one interchangeable capsule.

Design readable text over the real moving scene. Complement color-coded status with icon/text/shape cues, keep control names understandable, and include focus/disabled feedback for supported inputs. Check reduced-motion alternatives and supported text lengths as part of the same design.

## Approved design contract

Inspect the actual reference before deriving assets or coding. Distinguish the authoritative target from earlier alternatives and style inspiration. For a structured design file, obtain available node measurements, typography, component states and exports; inspect image context too. Avoid treating generated Web code as production-ready Godot implementation.

Record only the information needed to implement and review:

- reference identity/version, canvas/viewport, camera context and visible state;
- component rectangles/centers, font ink bounds, silhouettes, decoration inventory and layering;
- dynamic fields, actual data sources, available languages and control states;
- scaling/flow rules, visual bounds vs hit bounds, stretchable centers and fixed corners;
- opening/closing behavior and how gameplay input/pause behaves behind the surface.

For a flattened concept image, decide the handoff first. A screenshot can define a visual contract without providing separated production assets. Reference errors in dynamic data, such as a slider position inconsistent with its number, should be documented and resolved in favor of the live authoritative value while retaining the component's appearance.

## Raster assets

Prefer existing suitable runtime assets, layered exports or editable native sources. For new illustrated bitmaps or edits, choose an available image-creation workflow that fits the task. With a generative workflow, label each input as edit target, visual reference or supporting insert. When preserving a selected design, use an edit target and state exactly what may change and what must stay fixed.

Before generation, read [Texture budgets](texture-budgets.md). Include the asset's role, maximum screen occupancy at the target viewport, aspect ratio, alpha requirement, readable silhouette, lighting/material, border/decorations, empty text/data regions and required state variants. Record the high-resolution source target separately from the intended runtime budget. Ask the generator for a clean, appropriately detailed source; obtain a tiny runtime icon through the approved import/derivative workflow instead of requesting a 128-pixel generation. Ask for true alpha rather than a painted checkerboard. Keep toggle thumbs, slider thumbs and state bases distinct when the target distinguishes them.

Inspect output before implementation: silhouette, composition, details, text accuracy, alpha halos/stray scenery, shadows, padding and state consistency. Reject drift; do not describe regeneration as exact extraction. Prefer a targeted edit after an observed defect to another unrelated style generation.

Save selected project-bound assets into the repository, record prompts/source/hash and use/rights information as applicable, and retain the import settings needed to reproduce rendering. Assets must not depend on a personal generation-output path. Preserve approved source art and its source hash; keep discarded previews and raw QA material in the repository-approved local artifact location. When the user authorizes dimension optimization, deterministic import limits or reproducible runtime derivatives may prepare that preserved art without changing its approved composition. New art or creative edits follow the chosen image-creation workflow and any project requirements.

## Handoff checklist

Each used component needs an asset/source, reference rectangle, aspect/stretch rule, state variants and its Godot role. A small manifest is useful for decorated multi-part interfaces; use an existing project format when available instead of creating a new schema for each surface.

Prefer live fonts for labels, numbers and translations. With subset fonts, check the characters used by every changed reachable state, including closed/success/error or test-result messages, not only the first open screen. Rebuild from the approved font source or use a verified fallback when needed, and inspect those states in the actual exported renderer; host font fallback or one screenshot can hide missing coverage. Fixed approved lettering art is appropriate only where the task warrants it: retain semantic text, hold the texture persistently, inspect glyph/alpha rendering and define how missing assets or future localization will be handled. A whole baked screenshot cannot provide a working menu.

Measure nine-slice boundaries per asset. Use scalable center areas for flexible panels and preserve complex crests/embedded art at designed proportions. Apply the source/import coordinate conversion and quality checks in [Texture budgets](texture-budgets.md#keep-coordinate-semantics). A runtime budget is accepted only when the intended material, alpha edges and detail survive the actual renderer.

# Raster dimensions and runtime texture budgets

Use this reference before creating game bitmaps, choosing import limits, or resizing an existing texture/atlas. The budget follows its largest meaningful use in the game, including animation; source-file dimensions alone do not establish excess resolution.

## Measure displayed pixels

Record the asset path and source hash, original dimensions, useful alpha/content bounds, actual imported dimensions/format/mipmaps, and all places that draw it. Measure the largest displayed content rectangle across the relevant states, target viewports, camera zoom, selected/hover scale, character or object variants and squash/stretch. For an atlas, evaluate each frame's useful content and padding, then preserve the grid; a large sheet can contain appropriately sized frames.

Use physical render pixels once. If geometry is already measured in a 2560×1440 framebuffer or screenshot, it already includes that render scale. If starting from CSS/logical pixels, convert with the actual effective renderer scale/DPR once. A HiDPI desktop setting is not a reason to multiply an already physical viewport again.

For a 2560×1440 baseline and the same layout at 3840×2160, 4K uses 1.5 times as many pixels along each dimension. Re-measure layouts that reflow or change camera framing. Select a runtime texture at least large enough for the supported maximum content size, allowing modest filtering/detail headroom where it helps the material. Compare the rendered result before reducing further; extra dimensions do not recover missing source detail.

Budget the useful crop, not transparent canvas alone. Keep the aspect ratio and original alpha margins required for shadows, deformation and atlas sampling. Example: a character reaching 320 pixels wide during deformation at 1440p can reach 480 at 4K with the same framing. A 512-pixel useful crop may be a starting candidate, subject to the actual texture's padding, filtering and rendered detail.

## Example starting budgets

These hypothetical examples illustrate measurement, not universal import limits. “Long edge” refers to useful cropped content. Re-measure larger gallery views, new animation/cameras, changed layouts and target platforms.

| Asset/use | Measured largest content at target viewport | Candidate runtime budget to compare |
|---|---|---|
| Small HUD icon | 48 px long edge | 128 px long edge |
| Animated character | 320 px wide, including deformation | At least 512 px useful width, including headroom |
| Reward card panel | 400×520 px | 768–1024 px long edge, preserving aspect ratio |
| Background | Already enlarged from source at the target viewport | Preserve current resolution; assess source detail before resizing |

Review these categories separately:

- Illustrated panels near a 1:1 source/display relationship may need their existing detail and slice contract.
- Small packed parts and atlas frames need per-frame measurement rather than a blanket limit on the sheet.
- Large effects need enough resolution for their maximum range, zoom and motion.
- Water/flow data or vector-field maps encode shader/simulation values. Preserve their data semantics, sampling and grid resolution; visual sprite budgets do not automatically apply.
- An imported texture may already be smaller than its source. Inspect actual imported dimensions, including any larger preview use, before proposing another reduction.

## Keep source and runtime separate

Preserve the selected PNG, its provenance and source SHA-256. Prefer `process/size_limit` in the source's Godot `.import` when a lower imported texture is enough; this keeps the approved art and makes the decision reproducible. Verify the actual imported dimensions after an isolated re-import rather than assuming that a requested limit equals the final width/height.

A reproducible runtime derivative is useful when cropping atlas padding or changing packing provides a concrete benefit. Keep the original/derivative relationship, crop, scale, frame layout and hashes in the project's existing asset metadata or a focused budget manifest. Retain required sources, runtime assets, import settings, licenses and tooling in Git; generated engine caches and QA artifacts remain outside Git.

Use the project's existing budget manifest, integrity checker and texture-coordinate helpers when present. Keep their paths in project-local documentation and inspect their current implementation rather than copying historical values into a new asset. Dimension optimization preserves approved composition; new artwork or creative changes remain a separate part of the requested scope.

## Keep coordinate semantics

A reduced import changes texture pixel coordinates. Inspect every consumer before applying the import limit:

- Source-authored crop rectangles and atlas regions must be converted with the actual imported width/source width and height/source height. Store source dimensions or normalized regions so later import changes preserve the intended crop. Account for integer rounding and validate that the region stays inside the imported texture.
- Nine-slice margins measured on the source must scale to imported pixels. Preserve the final screen-space border thickness and content inset; scaling the pixel margins without checking the panel's drawing transform can double-adjust the decoration.
- Name the aspect convention explicitly: height/width requires `height = width × aspect`; width/height requires `height = width ÷ aspect`. Check each consumer's final draw rectangle against authored geometry, including previews and rotated/deformed poses; a correct resource ratio alone does not prove that its caller uses the same convention.
- Custom `draw_texture`/`draw_texture_rect_region`, TextureRects, anchored parts, pivots and rotation axes may depend on the original texture dimensions. Preserve their screen-space rectangles and apply source/import transform conversion once. Explicit destination rectangles often keep their size, while native-size drawing needs an adjusted draw scale.
- Atlas frame padding must still protect neighboring frames under filtering and mipmaps. Keep frame content, anchors and grid boundaries aligned. Treat a packed sheet as a collection of frame budgets, not as one oversized icon.

Godot 4.6 floors an `AtlasTexture`'s fractional region size for actual rectangular drawing/image extraction; a boundary can differ by nearly one imported pixel per axis even when the float `resource.region` stays source-normalized. See the [engine implementation](https://raw.githubusercontent.com/godotengine/godot/4.6/scene/resources/atlas_texture.cpp). Metadata/UV checks establish the intended mapping, not pixel-identical sampling. Compare unscaled before/after runtime captures at the same viewport, state and framing, especially alpha edges; adjust the crop or sampling path only when the rendered difference warrants it.

Complete a category only after every runtime consumer retains the same intended crop, silhouette, aspect, position and display scale. Avoid changing gameplay timing, collision, range, economy or progression to compensate for a rendering change.

## Texture-memory estimates

PNG file size measures compressed storage. Godot Lossless import can reduce disk/download size while the decoded texture still occupies pixel memory. Use the actual imported format, dimensions and mipmap setting for estimates:

- RGBA8 without mipmaps: `width × height × 4` bytes.
- A full mip chain is roughly `4/3` of that base amount; small/non-power-of-two textures have rounding differences.
- RGB8 uses 3 bytes per pixel; VRAM-compressed formats have their own block sizes. Identify the actual format instead of applying the RGBA8 formula universally.

A 1024×1024 RGBA8 texture is about 4 MiB before mipmaps; 512×512 is about 1 MiB. Count unique resident textures rather than every draw call. Distinguish an all-assets storage estimate from the textures loaded together in one scene. These figures exclude driver overhead, duplicate CPU copies, temporary buffers and other resources.

Report pixel-memory savings as an estimate or measured imported-image payload with its scope. Frame-rate improvement needs an actual performance comparison under representative load; dimensions or PNG compression alone do not demonstrate it.

## Creation and acceptance

Before image creation, describe purpose, screen occupancy at the target viewport, expected largest animation/zoom use, transparent-background needs, readable outline, material and source/runtime budgets. For example: “A transparent coin for a HUD shown up to 48 physical pixels at the target viewport, recognizable after reduction, with clean separated highlights and alpha edges; preserve a detailed source and compare a 128-pixel runtime long edge.” For a generative workflow, use a generator-supported source size; derive/import the small runtime texture later.

For an optimization, save the source/hash and before/after import inventory. Run checks in an isolated project with muted audio and separate test saves. Verify actual imported dimensions, source integrity, crop/atlas bounds, display rectangles and relevant existing regressions. Inspect actual renders at the target and supported larger viewports for halos, lost material, aliasing, edge bleed and incorrect nine-slice/pivot scale. Compare the same game state and framing; dummy-renderer geometry checks support technical acceptance but do not prove visual quality. Record remaining visual evidence as pending when it has not been captured.

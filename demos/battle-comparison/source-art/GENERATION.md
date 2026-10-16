# Source art provenance

Four built-in image-generation calls were made for this demo, in order: full battle-screen visual reference; a targeted edit removing HUD/actors to create a clean map; a transparent tower/enemy source atlas using the design as visual reference; a transparent empty HUD-chrome atlas using the same reference. The built-in tool does not expose a pinned image-model identifier in its result. Do not claim a verified specific model/version beyond built-in GPT Image generation.

The design and map preserve a 1672×941 frame. The map is an AI edit with small scene differences, not an exact layer extraction. Its path/build-pad anchors are frozen in the shared model. The source atlases were not laid out at the requested exact grid dimensions: actors are1254×1254 and chrome2172×724, so actual measured source crops are recorded in ASSETS.json. Deterministic atlas slicing, alpha-bound crop/padding and uniform runtime resizing preserve these generated silhouettes. Source PNGs are retained; no actors/UI are baked into the runtime map.

Cinzel is downloaded from the official google/fonts repository with its SIL Open Font License. It is used for the HUD typography. Other captions use Godot's bundled font. No assets from a private game project, personal paths, credentials or normal game saves are required.

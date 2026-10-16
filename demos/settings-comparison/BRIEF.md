# Frozen brief — Mosslight Atelier

Build an original, polished and usable Godot 4.6.3 settings interface for a cozy botanical alchemy game. A moonlit workshop/playfield remains visible behind the modal; use midnight ink, warm parchment, sage green and brass/amber accents. Typography, hierarchy, spacing, restrained decoration and material should feel intentional. You may invent native vector decoration. No supplied game art or third-party asset dependency.

## Same requirements for both implementations

- Start with settings open. Include an appealing application title, background workshop/world context, and an underlying Brew action that increments brew_count when settings are closed.
- The modal has a heading, short supporting copy, Music and Sound effects sliders with changing numeric values, a Reduced motion CheckButton, a Language OptionButton (English and Extended labels), a primary Apply button, secondary Cancel, and close (X).
- Extended labels mode must visibly switch the music label to "Background music volume during exploration", the effects label to "Sound effects volume for tools and discoveries", and the motion label to "Reduce decorative motion and transition effects". Use English text throughout so no new font dependency is needed. Keep all settings accessible.
- Adapt to 1280×800 desktop, 390×844 portrait and 844×390 short landscape. The interface must stay readable and interactive. Use touch targets of at least 44×44 logical pixels where relevant. Sliders may count their full interactive Control rect. The prescribed minimum is an input requirement, not an artwork distortion requirement.
- Use the immutable settings_model.gd as the sole state owner. Instantiate it as a root member named model. Calling open_settings, cancel_settings, apply_settings and brew controls all authoritative state. Write slider/toggle/language changes into model.draft. Cancel/X/Escape discards draft; Apply commits once. Opening/closing restores a prior pause state; model handles that invariant. Do not persist to disk or play sound.
- Name the actual interactive controls exactly MusicSlider, SfxSlider, MotionToggle, LanguageSelect, ApplyButton, CancelButton, CloseButton, BrewButton and PrefsToggle. The root script provides get_probe_state() -> Dictionary, returning model.snapshot(). This is read-only evidence, not an input bypass. All actual actions must work by normal pointer/keyboard controls.
- UI decoration must not intercept input. The modal must block the Brew action. When closed, a persistent PrefsToggle can reopen it. Support Escape cancellation.
- Use native Godot Controls for text and input. No HTML replica, baked screenshot UI, Web UI framework, or imitation of an existing finished implementation.

## Deliverable and allowed work

Create main.gd and any additional source scenes/scripts needed in your assigned directory. Do not edit the shared model or project settings. Make one complete implementation pass; you may run import/headless checks and fix syntax/runtime failures you observe. Do not inspect the other candidate or request cross-candidate feedback. Do not create the expected evaluation result. Stop when the standalone implementation is ready; the coordinator will run the same rendered acceptance for both candidates and freeze the first submitted source.

Output only a concise handoff with changed files, actual checks and any known limitation. Keep generated logs outside source. Do not commit/push. The same tools/model and this same brief apply to both candidates; the separate assignment defines only whether to read the skill.

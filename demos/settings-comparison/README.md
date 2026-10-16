# Settings comparison: Mosslight Atelier

[English overview](../../README.md) · [中文介绍](../../README.zh-CN.md)

Two independent implementations of one original botanical-alchemy settings brief, built with native Godot Controls and procedural GDScript scenery. One implementer read Godot UI Fidelity; the other used general Godot knowledge without loading the skill. The baseline was asked to make its best polished implementation.

## See the results

![Desktop UI detail: without skill on the left, with skill on the right](../../docs/demo/comparison-desktop.webp)

![Portrait first launches: without skill on the left, with skill on the right](../../docs/demo/comparison-mobile.webp)

These are actual Godot Web screenshots. The desktop detail uses the same center crop for both; portrait uses the full frame. Both figures show the initial English state. Captions, uniform resampling and WebP encoding are the only image processing. They are approximately 43 KB and 49 KB; no engine binary or Web export is stored in Git.

## What this run shows

| Observation | Without skill | With skill |
|---|---|---|
| Default visual treatment | Spacious single panel and restrained section labels | Inset cards, stronger section grouping, more workshop scenery |
| Actual pointer/keyboard checks | 8/8 observed checks passed | 8/8 observed checks passed |
| Anonymous visual review | 8/10 | 8/10 |
| Portrait Extended labels | Required text wraps cleanly | Motion label overlaps its helper copy |
| Short landscape | Lower content is reachable by scrolling | Lower content is reachable by scrolling; footer is visually tight |

The eight browser checks cover Cancel discarding edits, reopen restoring saved values, a single Apply transaction, Brew while closed, modal blocking Brew, Escape cancellation, preserving a draft during resize, and scrolling to the lower slider. Native sliders, toggle, options and buttons are visible in the probe. Geometry alone is not an input test.

The independent reviewer assessed pixels before receiving measured corroboration, without the source, mapping or skill. It rated the outputs equally overall: the skill version has stronger world context/grouping, while the baseline handles the portrait long-label case better. The known overlap is deliberately retained in the frozen first pass and is not hidden by the initial-state showcase images. The long motion label occupies y515..590, while its helper occupies y561..581 in the 390×844 Extended state.

This is a small, honest example, not proof that a skill always makes better UI. One pair cannot establish a general causal effect, statistical significance, production readiness, all-device performance, or the user's subjective preference. The value of the package includes a reproducible design/implementation/review workflow; inspection remains necessary.

## Run the actual demo

Install official Godot 4.6.3.stable and its matching non-threaded Web export templates. From this skill repository, supply the executable and the directory containing `web_nothreads_release.zip` and `web_nothreads_debug.zip`:

```sh
python3 scripts/build_comparison.py \
  --godot /path/to/Godot \
  --templates /path/to/4.6.3.stable \
  --output "$(mktemp -d)" \
  --probe --serve
```

Open the local URL printed by the command. The comparison shell switches between real exported Godot applications. View each variant's `index.html` directly for an exact browser viewport. Use 1280×800, 390×844 and 844×390. Select **Extended labels** in the native Language menu to reproduce the stress case. Use normal held pointer clicks when testing a Web canvas.

The builder uses isolated project/engine copies and a new test data namespace. It never opens a native window or writes normal game saves. The two models store preferences only for the current runtime; reloading resets the demo. The tested build environment was macOS; other platforms are not claimed validated.

For Godot Editor exploration, copy `shared/` to a separate working directory and overlay either variant directory into it. The identical shared `main.tscn` loads that variant's `main.gd`. Keep generated `.godot/` caches outside this source package.

## Reproduce and audit

- [Exact shared brief](BRIEF.md)
- [Predeclared evaluation plan](EVALUATION.md)
- [Run conditions and limitations](PROTOCOL.json)
- [Frozen source hashes](SOURCE-SHA256.json)
- [Without-skill source](without-skill/main.gd) · [With-skill source](with-skill/main.gd)
- `harness/probe.gd` publishes read-only UI evidence in an inert DOM element. It does not dispatch commands, change focus/state, persist data or render a substitute UI.
- `harness/test_tools.gd` validates the shared model and synthetic controls. Its 27 checks do not prove either candidate's pixels or real input.

The exact backend model identifier and random seed were not surfaced by the harness. Both agents inherited the same coordinator model selection with no override and no prior conversation history. No candidate was revised after external review. Export-preset and screenshot-readiness fixes changed the common harness only.

Run the shared model and probe checks from the repository root, with `$GODOT` set to the Godot executable. This copies the small fixture to a temporary directory so engine caches and logs stay outside the checkout:

```sh
CHECK_DIR="$(mktemp -d)"
cp -R demos/settings-comparison/shared "$CHECK_DIR/shared"
cp -R demos/settings-comparison/harness "$CHECK_DIR/harness"
"$GODOT" --headless --audio-driver Dummy \
  --log-file "$CHECK_DIR/checks.log" --path "$CHECK_DIR/shared" \
  --script "$CHECK_DIR/harness/test_tools.gd"
```

The expected summary is `SHARED_TOOL_TESTS checks=27 failures=0; candidate_ui_acceptance=false`.

Raw captures, logs and reports stay outside Git. Only the two reviewed small WebP figures are included. To regenerate figures from fresh actual captures with the documented names, install Pillow and run `python3 scripts/compose_comparison.py --captures CAPTURE_DIRECTORY --output IMAGE_DIRECTORY --font /path/to/latin.ttf`; inspect the resulting pixels and update the precise publication hash allowlist after review.

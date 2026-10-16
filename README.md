# Godot UI Fidelity

[English](README.md) · [简体中文](README.zh-CN.md)

An agent skill for designing, implementing, and validating Godot game interfaces. It covers new UI, faithful implementation of approved designs, native input and state, raster texture budgets, and visual acceptance.

The package contains instructions and small Python helpers. It is not a Godot add-on, an asset pack, or an automatic UI generator. Actual implementation and rendering use your project's engine and authorized tools.

## What it helps with

- Turn a UI brief or approved reference into a measured Godot implementation.
- Keep dynamic labels, rewards, focus, pause, and modal behavior connected to real state.
- Preserve artwork proportions while checking adjacent touch targets together.
- Plan source and imported texture sizes, atlas regions, and nine-slice coordinates.
- Report visual, interaction, and technical evidence separately.

## Install in Codex

For a user-wide editable checkout:

```sh
mkdir -p "$HOME/.agents/skills"
git clone https://github.com/shunying-games/godot-ui-fidelity.git "$HOME/.agents/skills/godot-ui-fidelity"
```

For a versioned project dependency, run from your project repository:

```sh
git submodule add https://github.com/shunying-games/godot-ui-fidelity.git .agents/skills/godot-ui-fidelity
git add .gitmodules .agents/skills/godot-ui-fidelity
git commit -m "Add Godot UI Fidelity skill"
```

On another machine, initialize the dependency with `git submodule update --init --recursive`. Choose one discovery location per project to avoid duplicate skill names. Codex also follows symlinked skill folders. See [official skill documentation](https://learn.chatgpt.com/docs/build-skills). Changes are usually detected automatically; restart Codex if the skill does not appear.

Other agents can use the same `SKILL.md` package through their supported skill loader; automatic discovery varies by host. The helpers require Python 3.10 or newer and only use its standard library. No API key, cloud account, or design service is required by this package. Image creation and rendering capabilities depend on your environment.

## Use

```text
Use $godot-ui-fidelity to implement this approved settings design.
Preserve current gameplay and verify the result in the actual renderer.
```

```text
Use $godot-ui-fidelity to investigate overlapping touch targets in this HUD.
```

The entry point routes to references for [design](references/design-and-assets.md), [implementation](references/godot-implementation.md), [texture budgets](references/texture-budgets.md), [acceptance](references/acceptance.md), and [skill evaluation](references/skill-evaluation.md).

## Keep project rules separate

Put project-specific references, engine/export commands, asset paths, save isolation, and confirmed gameplay constraints in your project's `AGENTS.md` or documents it links to. The skill reads applicable project policy before work. Keep personal paths, credentials, and raw QA output outside this public checkout.

Example project instruction:

```markdown
For Godot UI work, use godot-ui-fidelity and read docs/agent-guides/godot-ui.md
for this project's reference assets, rendering setup, and gameplay boundaries.
```

This separation lets reusable improvements go upstream without publishing project data. A project's private notes stay with that project; they are not dependencies of this package.

## Contribute and update

Work directly in the installed Git checkout so changes have one source. For a submodule, create or switch to a development branch inside it before editing; fresh submodule checkouts can be detached. Enable the repository's local hooks once per checkout:

```sh
python3 scripts/install_hooks.py
python3 -B -m unittest discover -s scripts -p 'test_*.py'
git add SKILL.md references scripts
python3 scripts/check_publication.py --staged
git diff --cached
git commit -m "Improve Godot UI guidance"
git push origin HEAD:main
```

Use your fork and a pull request when you do not have write access. Stage only intended files. Before publishing, configure Git with your GitHub noreply email; both author and committer metadata are checked. The local hooks check the staged snapshot and outgoing commit history. CI repeats tests and history checks after upload; CI alone cannot prevent an initial disclosure.

After updating a submodule, commit its new revision in the parent project. For updates from upstream, use `git pull --ff-only` on the skill's branch. Publication is a deliberate Git action, not a background file watcher.

## Privacy checks and limits

`scripts/check_publication.py` checks tracked file paths/content, commit messages, and author/committer email for recognized sensitive patterns. Diagnostics report locations and categories without printing matching values. Tests include staged content and secrets hidden in older outgoing commits.

The checks do not prove that every secret or private fact is absent. Review names, business information, examples, and the staged diff yourself. Local hooks can be bypassed and are not installed automatically by Git. Do not put real credentials in examples or tracked test fixtures. If a real credential was already published, revoke it and arrange history cleanup; deleting it from the latest file does not remove earlier copies.

## License and sources

[MIT](LICENSE). See [ACKNOWLEDGMENTS.md](ACKNOWLEDGMENTS.md) for workflow influences and technical sources. No third-party skill packages, Godot binaries, project art, or game code are bundled.

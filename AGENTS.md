# Maintaining this skill

This repository is the reusable Godot UI skill. Keep project-specific asset paths, gameplay decisions, local helper commands, credentials, and raw QA artifacts in the consuming project's own documentation or ignored local storage. Read `SKILL.md` when changing the skill's behavior.

Before a commit, run `python3 -B -m unittest discover -s scripts -p 'test_*.py'`, stage only intended files, run `python3 scripts/check_publication.py --staged`, and review the staged diff. Use `python3 scripts/install_hooks.py` to enable local pre-commit and pre-push checks. Check outgoing history before publication and use a GitHub noreply author email. Diagnostics and reports must not print sensitive matches.

Keep English and Chinese READMEs consistent when installation or maintenance behavior changes. Explain what was verified; these deterministic checks do not demonstrate all-game visual quality or guarantee the absence of private facts. Commit/push only within the user's authorized scope, to the explicitly selected branch; preserve unrelated changes and remote history.

The README comparison uses frozen independent first-pass demo sources. Preserve their source hashes and the disclosed known limitations; do not rewrite them to manufacture a stronger benchmark result. New trials belong in a separately described run. Generated logs, raw captures and exports stay outside Git. Only the two reviewed `docs/demo/comparison-*.webp` figures may be included, with exact reviewed hashes retained in the publication guard. Review image pixels and strip metadata before updating that allowlist; retain approved older hashes needed for full-history verification.

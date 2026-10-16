# Evaluate and improve this skill

Use this mode when evaluating the skill itself, not as mandatory overhead on every UI task.

Freeze the skill, task brief, permitted resources and source assets. Predeclare meaningful acceptance conditions before seeing outputs. Keep first-candidate source/build hashes, real screenshots, inputs and failure records outside Git; retain reproducible authored fixtures/tooling where the repository requires them.

Choose a small varied set of tasks: an approved-reference implementation, a new interface with real state/input, and a transfer scenario after any revision. For fidelity, avoid letting the implementer copy the already-correct screen being tested. Give independent implementers the task and skill without the expected answer. Review pixels before reading their self-assessment. If delegation is unavailable, state that limitation rather than describe a self-review as independent.

Distinguish failure causes: unclear/missing guidance, an explicit rule not followed, insufficient source assets, a test-harness defect, or an unavailable renderer. Missing evidence stays pending. Generic warnings that are repeatedly missed should become a focused example or executable check when practical; do not accumulate rules unrelated to observed failures.

Calibrate checks with a known bad artifact or seeded defect. The hit-region checker should reject overlapping runtime regions; the visual reviewer should reject missing labels even if most pixels match. Preserve that failed outcome rather than repairing the sample before review.

Change the smallest relevant part of the skill. Re-run the failing task with the revised skill, then check a fresh viewport/state or task that was not used to choose the correction. Retain the best reproducible candidate and respect the user's iteration limit. Do not iterate indefinitely or silently lower the rubric to declare success.

Report visual, interaction, technical and scope outcomes separately. Two passing prototypes support usefulness on those cases; they do not prove all-game quality, user aesthetic preference, real-device performance, production integration or causal improvement over using no skill. A causal claim needs a comparable no-skill control under the same model/input/budget, not just a before/after repair.

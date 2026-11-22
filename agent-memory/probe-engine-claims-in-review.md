---
name: probe-engine-claims-in-review
description: "In code reviews, probe any Godot engine-behaviour claim (ERROR lines, culling) on 4.7.2 before patching for it"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 397bbbcf-eb62-482a-a505-da3e40f5e9cb
  modified: 2026-11-19T06:56:29.843Z
---

Before you patch code for a reviewer's claim about Godot engine behaviour, check it with a short headless probe (`godot --headless -s probe.gd` in the scratchpad) or a red check. Claims like "this prints an engine ERROR" or "the renderer culls by X" count.

**Why:** in the 1.12 review (2026-11-19), all three reviewer layers agreed that setting `global_position` on a node under an out-of-tree parent prints `ERROR: !is_inside_tree()`. On 4.7.2 it prints nothing: the transform is computed from the detached parent chain. The "fix" would have been churn for a non-bug. Red checks also catch this: R1 stayed green without the fix.

**How to apply:** at triage, mark engine-behaviour claims as unverified. Probe them (or run a red check in a scratch copy of `game/`) before you classify them as patches. Record the probe's result in the story's Review Findings. Related: [[readiness-needs-work]] (story progress).

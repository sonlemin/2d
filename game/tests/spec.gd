extends RefCounted
## Design guarantees as numbers (AR49, Architecture → Design Guarantees as Tests). Tests compare
## against these, never against the tuning value under test, so loosening tuning fails the suite.
## A helper, not a test (no test_/smoke_ prefix): `const Spec := preload("res://tests/spec.gd")`.
## No class_name, so game code can't depend on it. Changing a value means changing the GDD
## first, with sonlm. Every const cites its GDD line (test_lint checks the `## GDD` comment).

const TELEGRAPH_MIN := 0.75  ## GDD Predators: Lurker: "Telegraph: 0.9 s (never below 0.75 s)"; Core Gameplay Loop step 3 (Pillar 2: every hunt is telegraphed).
const BOT_MIN_CHAIN := 5  ## GDD Level Progression: "an automated bot must reach a chain of ≥ 5 in every spine shaft", plain movement, no dash.
const BASE_LIGHT := 40.0  ## GDD Attack, pogo and chain: Chain-Light "40 px at 0 links"; never noticed, since a lurker wakes only at ≥ 80 px.
const NOTICE_MIN_RADIUS := 80.0  ## GDD Predators: Lurker: "Wakes: when your light radius is ≥ 80 px (4 links)"; a floor: a lurker may wake later, never earlier.
const LEDGE_FALL_TIME := 1.5  ## GDD Level Types: spine shaft "ledges every ≤ 1.5 s of fall"; Sequence Breaking: "a ledge or wall to cling to within a 210 px/s fall of 1.5 s".
const LEDGE_FALL_MAX := 315.0  ## GDD Level Types / Sequence Breaking: 1.5 s at 210 px/s = 315 px; spine ledges and hazard pits are measured in rows against it.

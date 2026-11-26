extends RefCounted
## Design guarantees as numbers (AR49, Architecture → Design Guarantees as Tests). Tests compare
## against these, never against the tuning value under test, so loosening tuning fails the suite.
## A helper, not a test (no test_/smoke_ prefix): `const Spec := preload("res://tests/spec.gd")`.
## No class_name, so game code can't depend on it. Changing a value means changing the GDD
## first, with sonlm. Every const cites its GDD line (test_lint checks the `## GDD` comment).

const TELEGRAPH_MIN := 0.75  ## GDD Predators: Lurker: "Telegraph: 0.9 s (never below 0.75 s)"; Core Gameplay Loop step 3 (Pillar 2: every hunt is telegraphed).
const BOT_MIN_CHAIN := 5  ## GDD Level Progression: "an automated bot must reach a chain of ≥ 5 in every spine shaft", plain movement, no dash.
const BASE_LIGHT := 40.0  ## GDD Attack, pogo and chain: Chain-Light "40 px at 0 links"; never noticed, since a lurker wakes only at ≥ 80 px.
const NOTICE_MIN_RADIUS := 80.0  ## GDD Predators: Lurker: "Wakes: when your light radius is ≥ 80 px (4 links)"; test_sensing holds the rule exact (79.9 px never, 80 px does); the room guarantees read it as a floor (never earlier).
const NOTICE_FACTOR := 1.6  ## GDD Predators: Lurker: "Wakes: … it is within radius × 1.6 of you" and Hunt: "you are within radius × 1.6"; exact: the reach of every light-sensing predator.
const STIR_STEP := 0.35  ## GDD Predators: Lurker: "The eye is half-open at once and fully open 0.35 s later, and it steps open or closed at most once per 0.35 s"; exact: s between two steps of a lurker's stir (reviewed at the CP2 gate, 1.30).
const STIR_REACH := 96.0  ## GDD Predators: Lurker: "Stirs (off screen): if it would wake but sits just off screen (within 96 px of the edge)"; exact: how far past the play area a lurker still warns.
const LEDGE_FALL_TIME := 1.5  ## GDD Level Types: spine shaft "ledges every ≤ 1.5 s of fall"; Sequence Breaking: "a ledge or wall to cling to within a 210 px/s fall of 1.5 s".
const LEDGE_FALL_MAX := 315.0  ## GDD Level Types / Sequence Breaking: 1.5 s at 210 px/s = 315 px; spine ledges and hazard pits are measured in rows against it.
const NARROW_MIN := 6  ## GDD Level Types: Narrow stretch "6–10 tiles wide; no ledges; walls always within reach": the narrowest open run in a cling= stretch row.
const NARROW_MAX := 10  ## GDD Level Types: Narrow stretch "6–10 tiles wide": the widest open run in a cling= stretch row, so both walls stay in reach.
const LIGHTS_ON_SCREEN_MAX := 6  ## GDD Open Questions: "The light budget is ≤ 6 `PointLight2D` on screen and flares always keep theirs" (architecture AR46), confirmed at the CP1 gate (1.15); a ceiling: never loosen it without the GDD.
const FLASH_HZ_MAX := 3.0  ## GDD Accessibility: "Flash safety: no more than 3 flashes per second anywhere" (NFR8, UX-DR125); a ceiling for every effect.
const POGO_GAP_MIN := 1.0 / FLASH_HZ_MAX  ## GDD Accessibility: "Flash safety: no more than 3 flashes per second anywhere" (NFR8): s of real time between two pogo hits, since each hit plays its sparks, light swell, popup and shake once; a floor on the bot's line in every spine room.
const PULSE_HZ_MAX := 2.0  ## GDD Predators: Lurker: eyes "pulse at 2 Hz", the gutter frame "pulsing … (≤ 2 Hz)" (UX-DR125: pulses ≤ 2 Hz).
const BLINK_HZ := 2.5  ## GDD Combat damage table: crawler contact "0.6 s invulnerable (blinking at 2.5 Hz)" (UX-DR125: blinks 2.5 Hz).
const MAX_HP := 4  ## GDD Health and damage (M2): "Health: 4 HP"; the respawn's HP (FR13).
const DAMAGE := {&"crawler": 1, &"boss": 1, &"lurker": 2, &"hazard": 1}  ## GDD Health and damage (M2) table: crawler contact 1, boss attack 1, hunting lurker 2, spikes and hazards 1 (FR10).
const INVULN_S := 0.6  ## GDD Health and damage (M2): crawler contact "0.6 s invulnerable (blinking at 2.5 Hz)"; every hit gives the same (FR10).
const BANK_HEAL_MIN := 10  ## GDD Health and damage (M2): Healing "+1 HP when you bank a chain of 10 or more" (FR12; [ASSUMPTION: playtest]).
const FLARE_MIN_LINKS := 2  ## GDD Flare Toss (M2): "Requirement: at least 2 links" (FR14); under it a tap does nothing.
const FLARE_BURN := 4.0  ## GDD Flare Toss (M2): "The flare: burns for 4.0 s" (FR15), counted from the throw.
const FLARE_FADE := 1.0  ## GDD Flare Toss (M2): "In its last 1.0 s it fades out smoothly, with no flashing"; s of the fade, and the floor every gear keeps the burn above.
const FLARE_THROW := Vector2(180.0, -160.0)  ## GDD Flare Toss (M2): "Throw: an arc in the facing direction, 180 px/s forward and −160 px/s up" (FR14).

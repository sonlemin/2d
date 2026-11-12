---
stepsCompleted: [1, 2, 3, 4, 5, 6]
status: complete
completed: 2026-11-12
verdict: NEEDS WORK
documentsIncluded:
  gdd:
    - _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md
    - _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/epics.md
    - _bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md
  architecture:
    - _bmad-output/game-architecture.md
  epics:
    - _bmad-output/planning-artifacts/epics.md
  ux:
    - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md
    - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md
    - _bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/mockups/
  supporting:
    - _bmad-output/narrative-design.md
    - _bmad-output/implementation-artifacts/m1-playtest-findings.md
    - _bmad-output/project-context.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-11-12
**Project:** pixel_art_game (The Unbroken Chain)
**Assessor:** gds-check-implementation-readiness

## Document Inventory

| Type | Document | Size | Modified |
|---|---|---|---|
| GDD | `planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md` | 56 KB | 2026-11-12 10:36 |
| GDD (epic section) | `planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/epics.md` | 14 KB | 2026-11-12 10:36 |
| GDD (decisions) | `planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/decision-log.md` | 21 KB | 2026-11-12 10:36 |
| Architecture | `_bmad-output/game-architecture.md` | 91 KB | 2026-11-11 23:38 |
| Epics & Stories | `planning-artifacts/epics.md` | 283 KB | 2026-11-12 10:36 |
| UX (look) | `planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md` | 49 KB | 2026-11-11 16:26 |
| UX (behaviour) | `planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md` | 50 KB | 2026-11-12 01:41 |
| UX mockups | `planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/mockups/` (6 key screens) | — | 2026-11-11 16:26 |
| Supporting | `_bmad-output/narrative-design.md` | 52 KB | 2026-11-12 01:28 |
| Supporting | `implementation-artifacts/m1-playtest-findings.md` | — | — |
| Supporting | `_bmad-output/project-context.md` | 15 KB | 2026-11-12 01:35 |

**Discovery notes**

- No whole-vs-sharded duplicates.
- The architecture lives in `_bmad-output/`, outside `planning_artifacts`; included by hand.
- The GDD folder's `epics.md` is the GDD's own high-level epic section (source); `planning-artifacts/epics.md` is the story breakdown (subject). Not duplicates.
- `ux-designs/.../.working/` holds byte-identical draft copies of the 6 mockups; `mockups/` is authoritative.
- `EXPERIENCE.md` predates the 2026-11-12 epic-planning GDD update; checked in UX alignment.

## GDD Analysis

**Read in full:** `gdd.md` (808 lines, `status: final`, updated 2026-11-12), the GDD's `epics.md` (high-level E1–E7) and `decision-log.md` (2026-11-10 → 2026-11-12).

**Numbering.** The GDD writes requirements as prose and tables, not numbered FRs. The canonical numbering is the inventory in `planning-artifacts/epics.md` (FR1–FR81, NFR1–NFR19), drawn from the GDD plus the UX, narrative and architecture docs. This assessment adopts that numbering and checks it against an independent full read of the GDD (findings under GDD Completeness Assessment). The lists below are copied verbatim from that inventory.

### Functional Requirements

**Movement and core kit (M1, carried into M2)**

FR1: Movement uses the M1 tuning: run 110 px/s (ground accel 900 px/s², air accel 1500 px/s²); jump −330 px/s (apex ≈ 60 px), early release = velocity ×0.45; gravity 900 px/s² rising, ×0.6 falling, max fall 210 px/s; coyote time 0.08 s; jump buffer 0.10 s. [M1]
FR2: Air dash: 260 px/s for 0.12 s, horizontal, ignores gravity; once per airtime, refreshed by landing or a pogo hit. [M1]
FR3: The camera leads 70 px downward while falling. [M1]
FR4: Slash (Attack on the ground): active 0.12 s, cooldown 0.22 s, hitbox 22×16 px in front. Attack in the air always pogoes: armed 0.22 s, hitbox 26×24 px below the feet; a hit bounces the player at −300 px/s, adds 1 link and freezes 75 ms (hitstop); a pogo on the same frame as touching the ground adds nothing. Player body 10×20 px, hurtbox 8×18 px. [M1]
FR5: Chain: +1 link per pogo hit without touching the ground, capped at 20. Chain-Light radius = 40 + 22·√links px. Blade Bloom scales slash and pogo hitboxes ×(1 + 0.18·√links), max ×1.8, never the hurtbox. [M1]
FR6: Chain-end rules: landing breaks (held → carried, light → 40 px); Snuff (hold Light past the tap window) breaks (held → carried, light 12 px while held); wall cling pauses the chain for 1.0 s per chain (a pogo hit refills it), then breaks (held kept, then → carried; light 40 px while clinging); any hit breaks (held → carried); Flare Toss halves (FR14); crossing a room exit with a live chain banks it exactly like a landing (ADR-2 backstop; The Fall is the only exception); death breaks and held embers are lost. [M1 + E1]
FR7: Wall cling: hold Jump while touching a side wall and falling (vy ≥ 0); slide 18 px/s, never climbs; release Jump kicks off at (150 away, −260 up) px/s with no steering for 0.15 s; Down drops straight off. [M1]
FR8: Embers: pogo link *k* pays *k* embers (a chain of *n* pays n(n+1)/2); hits past the 20-link cap keep paying. [M1]
FR9: Light: holding Light past the tap window is Snuff; a tap must never break the chain (a tap is Flare Toss). [M1, window setting E1]

**Health and damage (E1)**

FR10: The player has 4 HP. Damage: crawler contact 1 (knockback 150 px/s, −150 px/s), boss attack 1, hunting lurker 2 (only while it hunts the player), spikes/hazards 1 (respawn at the last safe ledge in the same room). After a hit: 0.6 s invulnerability, blinking at 2.5 Hz. [E1]
FR11: Any hit breaks the chain and moves held embers to carried; only death loses held embers. [E1]
FR12: Healing: full at a Lift Station rest and on arriving home; +1 HP (up to max) when banking a chain of ≥ 10 (threshold is an assumption to playtest). [E1]
FR13: At 0 HP the player dies and respawns, with full HP, at the deeper of the last lit lantern anchor or Lift Station. Death does not reload the scene. [E1]

**Flare Toss (E1)**

FR14: Tap Light (released inside the tap window; default 0.12 s, setting 0.12 / 0.2 / 0.3 s) with ≥ 2 links throws a flare. Cost: half the chain rounded up (8 → 4, 5 → 2); held embers move to carried in proportion to the links spent; the remaining chain keeps going; the light shrinks to the new chain. [E1]
FR15: The flare flies in an arc in the facing direction (180 px/s forward, −160 px/s up, normal gravity), sticks to the first surface hit, burns 4.0 s with a radius equal to the player's light radius before the toss, and fades out smoothly over its last 1.0 s with no flashing. It deals no damage. [E1]
FR16: Predators that sense a flare treat it as the player (lurkers telegraph and hunt it); the Weaver is repelled instead (FR45). A lurker switching from the player to a flare needs no telegraph. [E1]

**Lurker (M1, changed in E1)**

FR17: A lurker wakes when the light radius is ≥ 80 px (4 links), it is within radius × 1.6, and it is on screen (inside the play area between the gutters). [M1]
FR18: Off-screen stirring: a lurker that would wake but sits just off screen (within 96 px of the play-area edge) shows a half-open eye at the play-area edge, level with the lurker, that opens wider as it stirs, plus a red glow with a minimum strength. It cannot hunt until it is on screen and has telegraphed. (Its panned sound arrives in E3.) [E1]
FR19: Telegraph: 0.9 s (never below 0.75 s); eyes open with an animation, pulse at 2 Hz and cast red light on the wall; both HUD gutters show a pulsing red frame (≤ 2 Hz) and a small eye icon; HUD values are not recoloured. [M1 + E1]
FR20: Hunt: 95 px/s straight at its target, through walls. It senses the player while the light radius is ≥ 80 px and within radius × 1.6. When it can't sense its target it stops at once and is harmless, waits 0.6 s, then returns home. A Snuff, landing or cling taken in time always saves the player. [M1]
FR21: Retargeting: a lurker hunting a flare or the Ember Cache that switches to the player telegraphs again from the start (≥ 0.75 s) before it can hurt the player. Lurkers are not killable in M2. [E1]

**Embers, Ember Cache, difficulty (E1)**

FR22: Three ember stages: held (current chain) → carried (the chain ended safely: landing, Snuff, cling timeout, a hit, a room exit) → deposited (Lift Station rest or arriving at the hub; safe forever). [E1]
FR23: On death (Normal): held embers are lost; carried embers drop as an Ember Cache where the player died; touching it returns them to carried; dying again before recovering it destroys it. At most one cache exists. [E1]
FR24: The Ember Cache glows amber and wakes lurkers by the same rule as the player's light (glow radius ≥ 80 px, lurker within radius × 1.6 and on screen). The glow radius is tuned in the E1 playtest; below 80 px it draws nothing. [E1]
FR25: Difficulty tiers change only the cost of death: Easy (held → carried, carried kept), Normal (held lost, carried dropped as a cache), Hard (both lost). Never damage, telegraphs or chain rules. Chosen at New Game, changeable any time in Options. [E1]

**Interact, anchors, stations (E1 placeholder, E4 final)**

FR26: ↓ while standing still on the ground is interact: rest at a station, talk to an NPC, read a journal object. ↓ on a wall still drops; ↑ stays Jump. [E1]
FR27: Lantern anchors are lit by touch and become the respawn point (respawn only: no heal, no deposit). About one every 4–6 screens (≈ 5 in Layer 1). [E1, placed in E4]
FR28: Lift Station: touching it lights it (respawn point). ↓ to rest: full heal, deposit carried embers, open the fast-travel menu (hub and repaired stations), respawn the layer's enemies, autosave. A placeholder station in E1; the final one in E4. [E1 → E4]

**Saving (E1)**

FR29: Autosave at every Lift Station rest, on arriving at the hub, and when the player quits at a lit lantern anchor (position saved; carried embers stay at risk until a station). [E1]
FR30: Three save slots. The slot picker shows depth, best chain, play time and difficulty; Continue loads the most recent slot; Load on the title opens the picker; New Game picks a slot and a difficulty. A failed save is shown to the player ("Not saved") and never crashes or pauses the game. [E1]

**Controls, pause and options**

FR31: Default keyboard: arrows move, Z or ↑ jump, X attack, C dash, V light, Esc or P pause. Default gamepad: left stick / d-pad move, A jump, X attack, RB dash, B light (tap Flare Toss, hold Snuff), Start pause. Every action is one button; no chords. [E1]
FR32: The game pauses on Esc / P / Start, when the window loses focus, and when a gamepad that was in use disconnects. [E1]
FR33: Options open from the Pause menu; tabs that have not landed are hidden. E1: Game (difficulty) and Accessibility (reduce flashing; screen shake on/off; reduced motion, following the OS setting on web; Light tap window 0.12 / 0.2 / 0.3 s; hold→press toggles for Cling and Snuff). E1 also adds a 4-level Brightness choice (UX A1, decided 2026-11-12), since the M1 F1 brightness hotkey is removed in E1. E3: Audio (volume sliders). E7: Video (Brightness moves here beside fullscreen and scale) and Controls (rebind every action, keyboard and gamepad); Accessibility adds large HUD, text scale, timing assists and visual sound cues. [E1 / E3 / E7]
FR34: Snuff toggle mode (Accessibility): Light only throws Flare Tosses (any press, no tap window); Snuff moves to its own key (default Shift; pad LB), pressed once to start and again to end. Snuff still ends the chain. Quick Wick has no extra effect in this mode. [E1]
FR35: Timing assists and game speed (E7) are separate from difficulty; runs that use them are kept out of Guild records. [E7]

**HUD and feedback (E1)**

FR36: HUD v2 lives in two ~60 px side gutters (play area ~360 px): HP, held and carried embers, chain number and meter, lurker alert (pulsing red frame + eye icon). [E1]
FR37: Field Journal death line: on death, one line naming what killed the player and how to avoid it. The cause may carry island idiom; the avoidance is always plain. Written in the narrative voice after sonlm approves the death-card voice anchors. [E1]
FR38: Feel rules: freeze frames and sparks on every pogo hit; creature deaths dissolve into sparks in their own tint that turn amber as they fade, never blood; slow motion only at boss climaxes (The Fall start and the Weaver's defeat: 0.5 s at ×0.3); screen shake can be turned off. [E1 / E4 / E6]
FR39: The M1 shaft is rebuilt at 22 tiles (352 px) wall to wall, side walls included, with camera limits that keep it inside the play area; E1's playable is that shaft with a placeholder station at the top, two anchors and the full kit. [E1]

**The Weaver (E2 prototype → E6 final)**

FR40: Arena: 30 × 34 tiles (two screens tall), scrolling horizontally inside the ~360 px view; 4 web strands span it wall to wall at different heights. Strands can be pogoed (+1 link, no damage). Each strand has an anchor at both ends; slashing an anchor twice weakens that strand (frayed sprite, sag). [E2 → E6]
FR41: Light-shy states: Bright (light ≥ 80 px) → retreats to the ceiling anchor at 120 px/s and drops a spiderling every 2.0 s (at most 3 alive). Dark (light ≤ 40 px: base, Snuff or cling) → descends along the strands at 70 px/s and bites (0.9 s telegraph: legs rear up, eyes glow; 1 damage). Behaviour at 62–78 px of light (1–3 links) is decided in the E2 prototype. [E2]
FR42: Light-burst stun: reaching chain 3 within 96 px of the Weaver stuns it for 2.5 s; hits deal 1 each, at most 3 per stun. [E2]
FR43: Strand drop: if the Weaver stands on a weakened strand and the player slashes its second anchor, the strand drops: 2 damage plus a 2.5 s stun (hits during it count). [E2]
FR44: HP 12. Re-Weave at 9 HP: a 3.0 s telegraph (silk threads glow along the new paths), then every strand is rebuilt in a new pattern and weakened strands are restored; the player is not harmed; spiderlings keep dropping. No health bar: health reads in the world (segments fray and fall off, threads sag). E2 stubs The Fall: the fight ends at 6 HP. [E2]
FR45: Flare herding: the Weaver flees a flare along the strands to the farthest point inside the flare's radius × 1.5, at 110 px/s (exact flee target decided in E2). [E2]
FR46: Spiderling: drops from the Weaver while the player is bright; falls slowly, then crawls; 1 HP, 1 contact damage; chain fuel. [E2]
FR47: The Fall (at 6 HP): the Weaver cuts its anchors and the web floor gives way; 0.5 s at ×0.3; about 6 s of free fall with debris and web clumps to pogo (the chain is kept across the room change: the one scripted exception; it pays embers); the player lands in the Layer 2 landing arena (one screen, Bright Moon palette). [E6]
FR48: Phase 2 (6 → 0 HP, landing arena): 2 strands; bite telegraph 0.75 s; descent 90 px/s; Re-Weave at 3 HP rebuilds the 2 strands. The Bright Moon rule is off in the landing arena. [E6]
FR49: Weaver deaths: dying respawns the player at the Hollow Station (the station before the arena) with full HP and the fight reset. Dying in phase 2 resumes the fight from phase 2 in the landing arena (respawn point decided in E6). The arena can't be left mid-fight and can always be won with the starting kit; Flare Toss is optional. [E2 / E6]
FR50: Defeat: reads as a win first (0.5 s at ×0.3, a burst of light, the landing-arena Lift Station repairs for free), then a coda where the Weaver dims and withdraws downward into the dark in sparks (bosses are never shown dying). It drops Weaver Silk (Swing unlocked); the repaired station returns the player to the hub; the way down into Layer 2 stays sealed; sets `weaver_defeated`. [E6]

**Swing (E6)**

FR51: Swing: with Swing unlocked, pressing Dash within 56 px of a silk anchor (a level object visible at base light) grabs the rope; holding Dash stays on; the rope attaches at the current distance clamped to 32–96 px; the player swings like a pendulum, left/right adds pump; releasing Dash launches with the current velocity ×1.1. Out of range, Dash is the air dash (no hold threshold, no delay). Swinging doesn't touch the ground, so the chain continues and the player stays bright. [E6]
FR52: Three silk anchors (in A, S2 and C) each guard one Swing-only secret: Silk Grip gear (+0.25 s cling grace), the Memorial clue (the Guild tag of Oda's dive partner, which adds the partner's name to the Memorial Wall) and an Ember Hoard. [E6]

**Layer 1 world (E4)**

FR53: Rooms and screen transitions: levels are text room files; spine shafts are 22 tiles (352 px) wall to wall and never scroll sideways; wider rooms scroll horizontally; the camera leads downward and its limits keep each room inside the play area. [E4]
FR54: The Layer 1 spine, about 23 screens, in fixed order: S1 The Lip (screens 0–3: run, jump, slash, first pogo over safety nets, landing banks embers; Lip Station; no lurkers); S2 Scaffold Drop (4–9: the first lurker with its eyes opening right above a ledge; wall cling in a narrow stretch with no ledges; Flare Toss taught in a lurker pocket; branch to A); S3 The Lantern Door (10–12: chain gate 1 ≥ 4 on the main path, a row of hoverers above it teaches the run-up); S4 Explorers' Grave (13–18: lurker rooms testing Flare Toss and cling under pressure; The Last Entry; branches to B and C); S5 Weaver's Hollow (19–22: the Weaver is heard and glimpsed before the arena; Hollow Station before the arena). [E4]
FR55: Side areas (optional, each ends in a reward): [A] Rope Works off S2 (old rope yard; Ember Hoard ≈ 60, 2 journal entries, a Swing secret); [B] Old Mine off S4 (dark galleries with ≥ 1 lurker per screen; Ember Hoard ≈ 80, 1 Cartographer hint, 1 journal entry); [C] Sky Ledge off S4 (open cliff in daylight; behind chain gate 2 ≥ 8: a shortcut up to the hub, the only safe mid-layer deposit; Ember Hoard ≈ 100; a Swing secret). How each side area exits back to the spine is decided in E4. [E4]
FR56: Chain gate (a lantern door): reads the chain when touched; if it is high enough the door opens for good; if not, it stays shut, glows the required number and bounces the player off without breaking the chain. Gate 1 ≥ 4, gate 2 ≥ 8. Gate rooms have a hoverer run-up that makes the required chain reachable on the first try with plain movement and no dash. [E4]
FR57: Level rules: ledges every ≤ 1.5 s of fall in spine shafts; narrow stretches 6–10 tiles wide with no ledges and walls always in reach; station rooms have no enemies within 2 screens and a lit lantern visible from the shaft above; every lurker telegraph happens on screen; every predator-heavy stretch has an escape (ledge, wall, room to Snuff) in reach; every hazard pit has a ledge or wall within a 1.5 s fall at 210 px/s; exits sit behind a landing, never inside a chain run; each new move appears first with a safe exit in view and is tested 2–4 screens later. [E4]
FR58: Enemies: crawler walker (patrols a ledge, turns at edges; 1 HP, 1 contact damage); crawler hoverer (drifts 10 px side to side over 2.4 s, phase from position; 1 HP, 1 damage); lurkers set in the walls. Enemies respawn on a station rest or on leaving the layer. A third regular enemy is added only if the E4 walk-through shows the need. [E4]
FR59: Palette zones down the spine: S1 + A dusk (`#2b1d14 #6b4a2f #b08a5a #d8c3a0`); S2–S3 umber (`#1e1714 #4a3a33 #7d6a5c #a99a8c`); S4–S5 + B + C cold violet (`#0d0b14 #2a2440 #4f5d75 #a9b4c2`). Ledge rims glow faintly; old lamps in the layers are dead or a cold tint (amber burns only in the hub and on lantern anchors). [E4]
FR60: Map screen: fills in screens as they are visited; Lift Stations and lit anchors are always shown; the Cartographer's Layer 1 map also reveals unvisited screens, gate locations and secret markers; it shows per-layer counts of each reward type found (no overall percentage in M2). [E4 / E5]
FR61: Journal objects: 3 entries by the island's lost (A ×2, B) plus *The Last Entry* in S4 (Oda's unsigned camp and half-written journal; her cold lantern is the lantern anchor `anchor_s4_oda`; it counts as a journal entry). ↓ reads; reading a document pauses play. The Memorial Wall name list is written in E4 alongside the documents so names match. [E4]
FR62: Ember Hoards: 4 in Layer 1 (A ≈ 60, B ≈ 80, C ≈ 100, one in a Swing secret). [E4 / E6]
FR63: Story flags `last_entry_read` and `lurker_met` are set from E4 and saved until the hub shows their payoff. [E4]

**Hub: Abyss Island (E5)**

FR64: The hub is a walkable village 2 screens wide on flat ground (no enemies, chain or platforming), laid out Smith, Cartographer, Lift, Naturalist, Guild + Memorial Wall, Oda's house; relic crates stamped for shipping sit by the lift. Arriving home deposits all carried embers, heals fully and autosaves. [E5]
FR65: Fast travel by lift between the hub and every repaired Lift Station; none to lantern anchors. [E5]
FR66: The Watching Departure: riding the lift up has a fixed duration; the full gathering (creatures at the edge of the light, watching) plays once per station layer and only after `lurker_met` (`departure_l1_seen`, `departure_l2_seen`); later rides show a few eyes; fast travel down or sideways has none. [E5]
FR67: Cartographer: Layer 1 map (60 embers); 3 hints (25 each) pointing to a side area, gate 2 and a Swing secret. [E5]
FR68: Smith gear, always on (no slots), as data: Quick Wick (200: instant Snuff; the light starts dimming the moment Light is pressed, and a release inside the tap window still throws a flare; the window doesn't change); Long Wick (250: flare 4 → 6 s); Steady Grip (300: cling slide 18 → 10 px/s). Silk Grip is found, not sold. Gear bends a rule, never adds raw power. [E5]
FR69: Naturalist: copies each new journal entry and pays 10 embers for the copy (originals stay with the player); sells 2 cosmetic palettes (75, 150). [E5]
FR70: Guild records and Memorial Wall: deepest depth, best chain, most embers banked in one chain, deaths; Oda's all-time depth record shown as the target; the Memorial Wall lists lost explorers' names, Oda Vell among them; the partner's name is added after the Memorial clue (E6). [E5 / E6]
FR71: Minimal Journal tab: creature entries with "new" marks, so the Naturalist payout reads. [E5]
FR72: Oda's house: a small interior beside the Guild (bed, Oda's empty chair, her gear wall with flag-gated pinned pages such as `prop_house_page_last_entry`); props and lines only, not a save or rest point. A new game opens here: Glim wakes beside the empty chair, ↓ is taught on the door, and Tessaly's First Dive registration is the only required talk. Until E5, New Game starts in S1. [E5]
FR73: NPC dialogue framework: ≤ 3 lines per flag, one idle line, then the shop; a per-NPC `{seen, idle}` record in `SlotState`; one story-flag registry in `rules/` with a validator for every `requires_flag`; a length validator that measures speech lines in the UI font (≤ 2 rows). [E5]
FR74: M2 closing beat: the first ride up from the landing arena plays the full Watching Departure; at home Old Tessaly logs the player's depth, still short of Oda's record. [E6]

**Audio (E3, composed music E7)**

FR75: SFX script pipeline: text parameter files → Python → WAV, kept in git and built on the server alongside the sprite pipeline. [E3]
FR76: Core SFX set: pogo hit (soft synth strike; pitch +1 semitone per link up to +12 at 12 links); embers banked (a chime that grows longer with the amount); lurker telegraph (low breath or growl as the eyes open, panned to its side, always above the music); off-screen stirring (quiet, panned); hunting lurker (rising hiss that follows its position); Snuff (light blown out, then muffled silence); cling (rope or wood creak); Flare Toss (whoosh, then a sizzle while it burns); Weaver (strands twang; a hiss when light makes it retreat); chain gate (a resonant tone that rises to the required count and opens on a chord, or a dull thud if the chain is too short). [E3]
FR77: Chain-reactive music: at rest only the ambient soundscape; stems fade in over 0.5 s at 3 links (pulse), 6 (melody) and 10 (full layer theme); a safe chain break resolves on a chord within 0.3 s; death cuts the music with a muffled, dissonant tail. The hub, the Weaver fight and The Fall get their own themes. E3 sketches the shared abyss motif as a placeholder hub stem so layer stems can quote it (narrative: "compose the hub theme first"); composed hub, Weaver and Fall themes land in E7. [E3 → E7]

**Slice polish and ship (E7)**

FR78: Full Field Journal: death log, lore, records and polish (the death line ships in E1, the minimal Journal tab in E5). [E7]
FR79: Title screen logo art replaces the E1 text placeholder. [E7]
FR80: Art pass: about 10 player animations (idle, run, jump, fall, pogo, slash, dash, cling, swing, hurt); hub and Layer 2 landing palettes; HUD polish. [E7]
FR81: First shared build (web + Windows + Linux), a playtest round with about 5 testers against the GDD Success Metrics, and the Steam vs itch.io decision. [E7]

Total FRs: 81

### Non-Functional Requirements

NFR1: Performance: 60 FPS sustained at 480×270 scaled ×3 (1440×810) on the developer laptop and on an Intel HD Graphics 620-class iGPU, measured over a 10-minute Layer 1 run including the Weaver fight; no frame over 20 ms outside the intentional 75 ms hitstop.
NFR2: Input is read every frame; no input is dropped during a 75 ms hitstop (presses during hitstop are buffered).
NFR3: Load time under 2 s from the hub to a Lift Station on the laptop.
NFR4: Memory ≤ 512 MB RAM on desktop, ≤ 300 MB in a web tab.
NFR5: Web build: 60 FPS in desktop Chrome or Firefox on the laptop at the 960×540 (×2) embed; download under 30 MB; playable within 10 s on a 50 Mbps link; pauses when the tab loses focus.
NFR6: Display: 480×270 viewport, integer scaling only (×2, ×3, ×4), nearest filtering, letterboxed; on web, if the window is below ×2 the click-to-play gate suggests fullscreen.
NFR7: Platforms: Windows and Linux desktop, web/itch.io for playtests; Godot 4.7.2, GDScript only, GL Compatibility renderer.
NFR8: Flash safety: no more than 3 flashes per second anywhere (pulses ≤ 2 Hz, blinks 2.5 Hz); every flashing, shaking, pulsing or easing effect honours reduce flashing, screen shake and reduced motion; the cap is checked for every new effect from E1 on.
NFR9: Colour is never the only signal: every telegraph also has a shape, a motion and a sound cue. Reserved colours: chain-light amber `#ffd27a` (the player's light, embers, flare, chain popups, the menu cursor; nothing else) and predator red `#d9473f` (light-hunting danger only).
NFR10: Pillar 2 fairness guarantees (tested): every predator hunt of the player is telegraphed on screen for ≥ 0.75 s; an escape taken in time (landing, Snuff, cling) always works; no off-screen ambush.
NFR11: Determinism: no randomness in level behaviour (only camera shake may use `randf`).
NFR12: Steam Deck legibility: at ×2 (960×540, letterboxed) the HUD and all text are readable; checked in E1 with the font choice, full pass in E7.
NFR13: World progress is never lost (opened gates, stations, abilities, deposited embers, map, journal, bosses); saves are atomic and a failure is surfaced, never a crash.
NFR14: Zero softlocks in M2, checked by the reachability bot and the playtest; automated tests stay green on every commit.
NFR15: Audio mix: predator cues have the highest priority (music ducks 6 dB under them); no sound effect comes close to clipping during a 75 ms hitstop.
NFR16: Accessibility of input: fully playable on keyboard and on gamepad, one button per action, no chords; UI shows glyph prompts, never hard-coded key names; every action rebindable (E7).
NFR17: All player-facing text is localisable (string keys), names shapes rather than colours, and fits the 8 px UI font.
NFR18: Licences and provenance: the font licence (OFL 1.1) ships in every build; AI-assisted art, audio and text pipelines are disclosed on store pages with provenance kept in git.
NFR19: Originality: no names, creatures, places or plot beats borrowed from any existing work. Creature deaths dissolve into sparks, never blood (low age rating).

Total NFRs: 19

### Additional Requirements

Not repeated here; the epics inventory also carries, and later steps check against:

- **AR1–AR58** from `game-architecture.md` + `project-context.md` (migration, foundations, state objects, rooms, sensing, input, clock, saves, UI, audio, lighting, tests, export, dev tools).
- **UX-DR1–UX-DR150** from `DESIGN.md` + `EXPERIENCE.md` (checked in UX Alignment).
- **NR1–NR25** from `narrative-design.md` (gates, systems, M2 content, style rules).
- **Cross-document resolutions R1–R13** (epics.md, step 1) and the GDD's 8 indexed assumptions and Open Questions, each owned by a named epic or pass.

GDD constraints that sit outside the FR/NFR lists: solo, 5–10 h/week, no deadline; Godot 4.7 GDScript only, Compatibility renderer; headless server for tests and pipelines, builds played on the laptop; every number a starting value to tune in M2 playtests; no procedural generation (Pillar 3); originality rule; ≈ 5 outside testers assumed for E7.

### GDD Completeness Assessment

**Overall: strong.** Final status; every mechanic has numbers; pillars are ranked with explicit rulings; every assumption (A1–A8) and Open Question names the epic or pass that resolves it; the decision log traces each later change (UX, architecture, narrative, epic planning) back into the text.

**Independent cross-check, GDD → FR/NFR inventory.** Every GDD mechanic, rule, value and budget was traced to an FR, NFR, AR or story AC. Spot checks of the less obvious items all landed: the Snuff free-bank and tap-vs-hold watch items (Story 1.30), the store and marketing plan (7.17), load time and memory budgets (7.13), the landing-arena palette (6.5), cosmetic palettes (5.12), NPC sprites (5.5), the hub tileset (5.3). Gaps and drift found:

| # | Finding | Severity |
|---|---|---|
| G1 | **Sequence-breaking stance only half captured.** GDD → Sequence Breaking allows two known skips: a cling-kick + air dash into the [A] Rope Works and [B] Old Mine entrances early. Story 4.21 keeps the A skip ("that skip is allowed"); Story 4.22 has no matching AC for B, so room authoring could close it off by accident. | Minor |
| G2 | **Stale line inside `epics.md`: AR2** still says "F1 brightness moves to Options in E7". R1, FR33 and the GDD (2026-11-12) put Brightness in **E1**. AR2 is cited by the migration stories, so a dev agent could read the old plan. | Minor |
| G3 | **E1 playtest question drift.** GDD Epic Structure: "Do HP, Flare Toss **and lantern anchors** keep deaths fair?"; GDD `epics.md`: "…and retries short?"; `planning-artifacts/epics.md` E1: "do HP and Flare Toss keep deaths fair?" (anchors moved to E4's question). Defensible, since final anchor placement is E4, but the three wordings should agree. | Minor |
| G4 | **GDD-internal leftover:** the Economy sinks table and starting prices list "Lift Station repairs (Guild), 150" although M2 has no broken Layer 1 station and the Hub table says the Guild has no shop. Already scoped out ("Layer 2 onward"); informational only. | Info |

## Epic Coverage Validation

**Method.** Read the FR Coverage Map and the epic summaries in `epics.md`, then parsed every story's acceptance criteria (137 stories, lines 1318–4271) for FR / NFR / AR / NR / UX-DR citations, and checked that each FR is cited by at least one story in every epic the map assigns it to.

### Coverage Matrix

| FR | Requirement (map label) | Map epics | Stories citing it | Status |
|---|---|---|---|---|
| FR1 | Movement tuning carried from M1, preserved through the migration | E1 | 1.3, 1.8 | ✓ Covered |
| FR2 | Air dash carried from M1 | E1 | 1.3, 1.8 | ✓ Covered |
| FR3 | Downward camera lead carried from M1 | E1 | 1.3, 1.6 | ✓ Covered |
| FR4 | Slash, pogo, hitstop and boxes carried from M1 | E1 | 1.2, 1.3 | ✓ Covered |
| FR5 | Chain, Chain-Light radius, Blade Bloom carried from M1 | E1 | 1.3, 1.20 | ✓ Covered |
| FR6 | Chain-end rules incl. any-hit and room-exit backstop | E1 | 1.3, 1.7 | ✓ Covered |
| FR7 | Wall cling carried from M1 | E1 | 1.3, 1.8 | ✓ Covered |
| FR8 | Ember earning curve carried from M1 | E1 | 1.3 | ✓ Covered |
| FR9 | Light tap vs Snuff with the configurable tap window | E1 | 1.8 | ✓ Covered |
| FR10 | 4 HP and the damage table | E1 | 1.19, 2.4 | ✓ Covered |
| FR11 | Any hit breaks the chain, held → carried | E1 | 1.19 | ✓ Covered |
| FR12 | Healing at rest and bank-heal (E1); on arriving home (E5) | E1→E5 | 1.19, 1.30, 5.3 | ✓ Covered |
| FR13 | Death and respawn without scene reload | E1 | 1.19, 1.24 | ✓ Covered |
| FR14 | Flare Toss input and cost | E1 | 1.23 | ✓ Covered |
| FR15 | Flare flight, burn and fade | E1 | 1.23 | ✓ Covered |
| FR16 | Predators treat a flare as the player (E1); the Weaver is repelled (E2) | E1→E2 | 1.23, 2.7 | ✓ Covered |
| FR17 | Lurker wake rule on the play rect | E1 | 1.20 | ✓ Covered |
| FR18 | Off-screen stirring edge eye (sound in E3) | E1 | 1.20, 1.27, 3.4 | ✓ Covered |
| FR19 | Telegraph and gutter alert | E1 | 1.20, 1.27 | ✓ Covered |
| FR20 | Hunt, lose-scent and escape guarantee | E1 | 1.20 | ✓ Covered |
| FR21 | Retarget telegraph; lurkers not killable | E1 | 1.20, 1.23 | ✓ Covered |
| FR22 | Three ember stages | E1 | 1.22 | ✓ Covered |
| FR23 | Ember Cache on death | E1 | 1.22 | ✓ Covered |
| FR24 | Cache glow wakes lurkers | E1 | 1.22, 1.30 | ✓ Covered |
| FR25 | Difficulty death-cost tiers | E1 | 1.22, 1.36 | ✓ Covered |
| FR26 | ↓ interact | E1 | 1.8, 1.24 | ✓ Covered |
| FR27 | Lantern anchor object (E1); ≈ 5 placed in Layer 1 (E4) | E1→E4 | 1.24 | ⚠️ Partial (E4 placement has no story) |
| FR28 | Placeholder Lift Station rest (E1); final station with fast travel (E4) | E1→E4 | 1.24, 4.8 | ✓ Covered |
| FR29 | Autosave at rest and anchor quit (E1); on arriving home (E5) | E1→E5 | 1.34, 5.3 | ✓ Covered |
| FR30 | Three save slots, picker, Continue, Load, failure state | E1 | 1.38 | ✓ Covered |
| FR31 | Default keyboard and gamepad mappings | E1 | 1.37 | ✓ Covered |
| FR32 | Pause triggers incl. focus loss and pad disconnect | E1 | 1.34, 1.37 | ✓ Covered |
| FR33 | Options: Game, Accessibility, Brightness (E1); Audio (E3); Video, Controls, a11y additions (E7) | E1→E3→E7 | 1.35, 1.36, 3.8, 7.2, 7.3 | ✓ Covered |
| FR34 | Snuff toggle mode | E1 | 1.35, 5.10 | ✓ Covered |
| FR35 | Timing assists kept out of Guild records | E7 | 7.5 | ✓ Covered |
| FR36 | HUD v2 in the gutters | E1 | 1.25 | ✓ Covered |
| FR37 | Field Journal death line | E1 | 1.29 | ✓ Covered |
| FR38 | Pogo freeze/sparks and shake toggle (E1); creature spark dissolve (E4); boss-climax slow-mo (E6) | E1→E4→E6 | 1.16, 4.6, 6.6, 6.9 | ✓ Covered |
| FR39 | M1 shaft rebuilt at 22 tiles with placeholder station and 2 anchors | E1 | 1.5, 1.24 | ✓ Covered |
| FR40 | Arena, strands and anchors (prototype → final) | E2→E6 | 2.1, 2.2, 6.3, 6.4 | ✓ Covered |
| FR41 | Weaver light-shy states and bite | E2 | 2.3, 2.4, 2.5, 2.12, 6.2 | ✓ Covered |
| FR42 | Light-burst stun | E2 | 2.6, 2.11, 2.12 | ✓ Covered |
| FR43 | Strand drop | E2 | 2.8, 2.11, 2.12 | ✓ Covered |
| FR44 | HP 12, Re-Weave, diegetic health (E2 stubs The Fall at 6 HP) | E2→E6 | 2.6, 2.9, 2.11, 2.12, 6.3 | ✓ Covered |
| FR45 | Flare herding | E2 | 2.7, 2.12, 6.2 | ✓ Covered |
| FR46 | Spiderling | E2 | 2.5 | ✓ Covered |
| FR47 | The Fall | E6 | 6.6, 6.15 | ✓ Covered |
| FR48 | Phase 2 in the landing arena | E6 | 6.5, 6.7, 6.15 | ✓ Covered |
| FR49 | Fight reset on death (E2); phase-2 checkpoint (E6) | E2→E6 | 2.10, 6.8, 6.15 | ✓ Covered |
| FR50 | Defeat presentation, Silk, station repair, `weaver_defeated` | E6 | 6.9, 6.15 | ✓ Covered |
| FR51 | Swing | E6 | 6.10, 6.15 | ✓ Covered |
| FR52 | Inert silk anchors and sealed alcoves with ids (E4); activation and rewards (E6) | E4→E6 | 4.10, 4.21, 4.23, 6.12, 6.15 | ✓ Covered |
| FR53 | Rooms and transitions | E4 | 4.7 | ✓ Covered |
| FR54 | Spine S1–S5 | E4 | 4.9, 4.10, 4.12, 4.16, 4.26 | ✓ Covered |
| FR55 | Side areas A, B, C | E4 | 4.21, 4.22, 4.23, 4.26 | ✓ Covered |
| FR56 | Chain gates (glow; tone via E3's pipeline) | E4 | 4.11, 4.12, 4.23, 4.26 | ✓ Covered |
| FR57 | Level design rules | E4 | 1.5, 4.10, 4.16, 4.19, 4.22, 4.24, 4.26 | ✓ Covered |
| FR58 | Layer 1 enemies and respawn | E4 | 1.3, 4.6, 4.8, 4.13 | ✓ Covered |
| FR59 | Palette zones, ledge rims, dead lamps | E4 | 4.5 | ✓ Covered |
| FR60 | Map tab (E4); Cartographer reveal (E5) | E4→E5 | 4.20, 5.11 | ✓ Covered |
| FR61 | Journal objects and The Last Entry | E4 | 4.15, 4.17, 4.18 | ✓ Covered |
| FR62 | Ember Hoards in A, B, C (E4); Swing-secret hoard (E6) | E4→E6 | 4.14, 6.12 | ✓ Covered |
| FR63 | Story flags `last_entry_read`, `lurker_met` | E4 | 4.4 | ✓ Covered |
| FR64 | Hub village, deposit + heal on arrival | E5 | 5.3 | ✓ Covered |
| FR65 | Fast travel to the hub and stations | E5 | 5.4 | ✓ Covered |
| FR66 | The Watching Departure | E5 | 5.15 | ✓ Covered |
| FR67 | Cartographer | E5 | 5.11, 5.16 | ✓ Covered |
| FR68 | Smith gear | E5 | 5.10, 5.16 | ✓ Covered |
| FR69 | Naturalist | E5 | 5.12, 5.16 | ✓ Covered |
| FR70 | Guild records and Memorial Wall (E5); partner name (E6) | E5→E6 | 5.13, 6.12 | ✓ Covered |
| FR71 | Minimal Journal tab | E5 | 5.12 | ✓ Covered |
| FR72 | Oda's house and the new-game opening | E5 | 4.9, 5.14 | ✓ Covered |
| FR73 | NPC dialogue framework | E5 | 5.6 | ✓ Covered |
| FR74 | M2 closing beat | E6 | 6.13 | ✓ Covered |
| FR75 | SFX script pipeline | E3 | 3.1 | ✓ Covered |
| FR76 | Core SFX set | E3 | 3.2, 3.3, 3.4, 3.9 | ✓ Covered |
| FR77 | Chain-reactive music and motif sketch (E3); composed themes (E7) | E3→E7 | 3.5, 3.6, 3.9, 7.12 | ✓ Covered |
| FR78 | Full Field Journal | E7 | 7.7 | ✓ Covered |
| FR79 | Title logo art | E7 | 7.11 | ✓ Covered |
| FR80 | Art pass | E7 | 7.8, 7.9, 7.10 | ✓ Covered |
| FR81 | Shared build, tester round, distribution decision | E7 | 7.15, 7.16, 7.17 | ✓ Covered |

### Missing Requirements

**No FR is missing.** Every FR1–FR81 is mapped to an epic and cited by at least one story AC; no FR appears in the epics that the GDD lacks (the UX- and narrative-sourced FRs were all carried into the GDD by its 2026-11-11 and 2026-11-12 updates).

#### Partial coverage

**FR27 (E4 half): about 5 lantern anchors placed through Layer 1, one every 4–6 screens.**
- The map says "Epic 1 → Epic 4 - Lantern anchor object (E1); ≈ 5 placed in Layer 1 (E4)", but only Story 1.24 cites FR27. No E4 story places anchors except Oda's `anchor_s4_oda` (Story 4.17). The spine stories (4.9, 4.10, 4.12, 4.16, 4.19), the room-flow story (4.7) and the full-layer bot (4.24) are silent on anchor spacing.
- Impact: **Major.** Anchors are the retry-length lever, and Story 4.26 asks "do anchors keep retries short?" with nothing that guarantees they exist at the GDD's spacing. A respawn gap of 10+ screens would fail the playtest for a planning reason.
- Recommendation: add an AC to each spine story naming its anchor ids (e.g. `anchor_s2_1`), and a check in Story 4.24 that no stretch between respawn points (anchor or station) exceeds 6 screens, against a new `Spec` const with a GDD citation.

#### Related (not FR gaps)

- **AR4** (foundation order) is the only requirement of any family not cited by a story AC. It is honoured by story order instead (1.2 Log + Clock → 1.3 Tuning → 1.4 state objects + Game → 1.5–1.6 RoomLoader + World → 1.8 PlayerInput → 1.9 runner + lint), which is acceptable.
- **G1** from the GDD analysis (the Old Mine sequence-break skip) is a level-design rule, not an FR; it belongs in Story 4.22.

### Coverage Statistics

- Total GDD FRs: 81
- FRs covered in epics: 81 (80 fully, 1 partially: FR27)
- Coverage percentage: 100 % mapped; 98.8 % fully covered at story level
- Other families cited by ≥ 1 story AC: NFR 19/19 · AR 57/58 (AR4 by order) · NR 25/25 · UX-DR 150/150

## UX Alignment Assessment

### UX Document Status

**Found.** `DESIGN.md` (look; `status: final`, updated 2026-11-11) and `EXPERIENCE.md` (behaviour; `status: final`, updated 2026-11-11, last touched 2026-11-12 in commit 8f1c134), 6 key-screen mocks, a UX validation report and two review reports. All 150 UX design requirements were extracted into `epics.md` as UX-DR1–UX-DR150, and every one is cited by at least one story AC (step 3).

**Method.** Checked each document's date against the decisions made after it: GDD UX carry-back (2026-11-11), architecture (2026-11-11 23:38), narrative design (2026-11-12 01:28), epic planning R1–R13 (2026-11-12). Searched the UX spines and the architecture for every term those decisions changed.

**UX ↔ GDD.** The GDD carried every UX decision back on 2026-11-11 (gutters and 360 px framing, 22-tile spines, tap window, Cling/Snuff toggles, 3 save slots, alert frame and edge eye, no Weaver health bar, font, 960×540 web baseline, Deck check in E1). The UX "Notes for GDD" are all applied, including Quick Wick.

**UX ↔ Architecture.** The architecture supports the UX surfaces:
- `ScreenRouter`: one screen at a time, pause via `SceneTree.paused`, UI on `PROCESS_MODE_ALWAYS`.
- Gutters that rebind on `player_spawned`.
- The death-card flow and the save-failure state.
- `devices.gd`: glyph swap and disconnect pause.
- DPR integer scaling, the web gate, the `palettes.gd` zone cross-fade, and `map=` room headers for the Map tab.

The UX performance needs are within the architecture's budget: 60 FPS HUD, unshaded readability, ≤ 6 `PointLight2D`, decided by the E1 perf scene.

### Alignment Issues

| # | Issue | Where | Severity |
|---|---|---|---|
| U1 | **Brightness still listed as E7.** Expected; the GDD decision log left it here on purpose. `EXPERIENCE.md` line 84 (Options table: Video, "E7 [ASSUMPTION] brightness may move earlier"), line 313 (Accessibility floor: "Options > Video … E7"), line 532 (A1). Since R1 (2026-11-12), Brightness ships in **E1** on the Accessibility tab and moves to Video in E7. The same stale owner text sits in the `epics.md` inventory: UX-DR78, UX-DR133 ("Owner: E7 (A1 maybe earlier)"), Assumption A1, Ambiguity 1, and AR2 (see G2). Stories 1.36 and 7.2 are already correct. | `EXPERIENCE.md`, `epics.md` | Minor |
| U2 | **The architecture never mentions Brightness.** There is no `Settings` field and no apply mechanism. Story 1.4 maps M1's `ambient_index` to `Settings`, and 1.36 adds the control. Nothing states that Brightness changes only the ambient level: never light radii, the notice rule, or the reserved colours. | `game-architecture.md`, Story 1.36 | Minor |
| U3 | **The UX spines predate the narrative design.** J1 (UX-DR104) sends New Game straight into the shaft. Oda's house, Tessaly's First Dive registration, lift-ride timing and the speech box (O5) are missing. This is scheduled: Story 5.2 (UX update at E5 start) owns it, and until E5 New Game starts in S1 (FR72), which matches today's J1. | `EXPERIENCE.md` J1 | Minor (scheduled) |
| U4 | **The reserved-amber rule lacks the narrative clarifications.** `DESIGN.md` says amber is always the player, with the menu cursor as the only stated exception. The GDD (2026-11-12) adds: ember lanterns burn amber **on lantern anchors** and in the hub; hit creatures' sparks turn amber as they fade. Lantern anchors are built in **E1** (Story 1.24) and creature sparks in **E4** (Story 4.6), both before the E5 UX update. A dev agent following `DESIGN.md` could tint lit anchors wrongly or treat amber anchors as a rule violation. | `DESIGN.md`, Stories 1.24, 4.6 | Minor |
| U5 | **The architecture predates the narrative design** (23:38 vs 01:28). Missing: the story-flag registry and `set_story_flag` (Story 4.4); the per-NPC `{seen, idle}` record in `SlotState` (5.6); a room id for **Oda's house** (AR26 lists only `hub/island`, and 5.14 doesn't say whether the interior is its own room; ids are save data and never renamed); the new-game opening and M2 closing beat in the moments list. The stories carry the details, but `gds-create-story` loads the architecture as context, so it would see none of them. | `game-architecture.md`, Stories 4.4, 5.6, 5.14, 6.13 | Minor |
| U6 | **E7 Large HUD, text scale and visual sound cues have no architectural shape.** UX O12 and O14 stay open until Stories 7.4 and 7.6. Risk: the E1 UI kit (1.31) and gutter HUD (1.25, 1.26) hard-code 8 px geometry (e.g. values at x 412), which would make E7 text scale a rewrite. | Stories 1.25, 1.26, 1.31, 7.4 | Low |
| U7 | **Stale frontmatter dates.** Both spines say `updated: 2026-11-11`, but `EXPERIENCE.md` changed on 2026-11-12. | UX spines | Info |

### Warnings

- No missing UX documentation; UI is fully specified for E1, with mock-before-build UX updates scheduled at the start of E4 (Story 4.2) and E5 (Story 5.2).
- Open UX items all have owners: O2, O3 → E4; O5–O7 → E4/E5; O8 → E5/E6; O9 → E5/E6; O10 → E2/E6; O11, O12, O15, O19 → E7; O14 → E3/E7; **O20** (a Snuff cost needs a HUD cue) → Story 1.30. Only O18 (CJK) is post-M2.
- The E1 defaults D1–D15 are reviewed in the build by Story 1.40, a human gate.

## Epic Quality Review

**Method.**
- **Mechanical scan of all 137 stories:**
  - Type line present: 137/137.
  - Given/When/Then: 137/137.
  - Cross-epic forward references: 0.
  - Within-epic forward references: 25, all of the form "until Story X lands, Y applies". Each was read: they are staging notes, not dependencies.
- **Story-by-story reads by four independent reviewers.** Slices: 1.1–1.29, 1.30–3.9, 4.1–5.17 and 6.1–7.17. Each reviewer read every story in its slice and checked the numbers against the GDD, the architecture, project-context, the UX spines, the narrative doc and the M1 code.
- **The highest-risk claims were then re-verified here:**
  - `tests/smoke_shaft.gd` and `tests/screenshot.gd` both preload `res://scenes/shaft.tscn`.
  - `player.gd` writes `Engine.time_scale` four times.
  - The M1 actors have 44 `@export` tuning values.
  - The M1 scenes have no `uid=` attributes.
  - On Godot 4.7.2, `JSON.parse_string()` and `ConfigFile.load()` print `ERROR:` on bad input and `JSON.new().parse()` does not (tested headless).
  - Story 6.8 promises a saved checkpoint that no save trigger writes.
  - No document ships Godot's licence notices.
  - Stories 4.8 and 5.3 strand placeholder-hub saves.
  - Hub purchases have no save trigger.

All GDD numbers quoted in the stories match their sources: every Weaver value, audio value, price, threshold, Swing value and performance budget. The problems are about ordering, state edge cases, unstated methods, and design calls left to the dev agent.

### Epic Structure

| Check | E1 | E2 | E3 | E4 | E5 | E6 | E7 |
|---|---|---|---|---|---|---|---|
| Delivers player value | ✓ (CP1 1.1–1.15 are technical stories inside a player-value epic: the brownfield migration the architecture requires) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Independent of later epics | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No forward story dependencies | ✗ 1.6, 1.12, 1.37 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Stories sized for one session | ✗ 1.6, 1.12, 1.26 | ~ 2.10 | ✓ | ~ 4.10, 4.16 | ✗ 5.12 | ✗ 6.2 unbounded | ✗ 7.8, 7.13, 7.14 open-ended |
| Data created when first needed | ✗ `DiveState.killed` | ✓ | ✓ | ✗ story-flag store, v2 fixture | ✗ placeholder-hub remap | ✗ checkpoint persistence | ✗ seen-set, assist marker |
| Clear, testable ACs | ~ | ~ state interactions | ~ | ~ level rules unchecked | ~ edge cases | ~ | ~ measurement methods |
| Traceability to FRs | ✓ | ✓ | ✓ | ✓ (FR27 partial) | ✓ | ✓ | ✓ |

**Brownfield check.** There is no starter template. Story 1.1 is the M1 migration and keeps `test_chain_state` green, which is correct. The integration risk sits in 1.1–1.10 (see C1).

### Cross-cutting Themes

These recur across epics; fixing each one once clears several findings.

| # | Theme | Stories |
|---|---|---|
| T1 | **Hardware measurements inside `dev` stories.** The server is headless, so the agent can't measure FPS, memory or load time, and would be tempted to invent numbers. | 1.12, 7.13 (also 1.15) |
| T2 | **State that must survive a quit has no save trigger.** AR38 allows saves only at a rest, the hub arrival and an anchor quit. | 6.8 phase checkpoint, 6.9 defeat + Swing, 5.9–5.14 hub purchases and flags, 5.15 Departure flag mid-ride, 1.36 difficulty change |
| T3 | **Save schema timing.** Fields are needed before any migration creates them, created twice, or tested only against default fixtures. | 1.4 `DiveState.killed`; 4.1/4.4/5.1/6.1 story-flag store; 4.1 v2 fixture; 4.20 per-screen visits; 5.1 placeholder-hub remap; 7.1/7.7 seen-set and assist marker; 1.41 no schema guard |
| T4 | **Boss HP thresholds use exact values.** Hits of 2 or 3 jump over 9, 6 and 3, and no clamp rule exists. | 2.9, 2.10, 6.6, 6.7, 6.8 |
| T5 | **Content typed as `dev`, with no sonlm approval.** | 1.5 shaft layout, 1.26 chain numerals, 2.1–2.5 arena and placeholder sprites, 3.2–3.4 SFX, 5.12 palette variants, 5.14 house props |
| T6 | **Design calls left to the dev agent.** There is no UX update at the head of E7, and the E4/E5 UX updates are missing screens. | 4.2 (document screen, gate number display), 5.2 (Memorial view, palette equip, tab intro, payout feedback), E7 (no `ux-update` story: text scale, sound-cue markers, rebinding capture and clash, Journal sections, logo), 7.5 assist list, 5.10 Quick Wick timing |
| T7 | **Persistent ids unnamed.** Ids are save data and can't be renamed once testers have saves. | `gate_s3_1`, Oda's journal, the B hint pickup, the Swing rewards, the Silk pickup, the NPC id pattern, `JOURNAL_<ID>_BODY` doubling |
| T8 | **GDD level rules with no check and no named reviewer.** | Ledge spacing ≤ 1.5 s (1.5, 4.x), exits behind a landing, teach → test within 2–4 screens (S2 cling and Flare are first tested in S4), the station no-enemy radius vs S1 (4.9), lantern-anchor spacing (FR27) |

### 🔴 Critical Violations (5)

| # | Story | Violation | Remediation |
|---|---|---|---|
| C1 | **1.6** (with 1.8, 1.10) | Deleting `shaft.tscn` turns `run_tests.sh` red. `smoke_shaft.gd` (every M1 movement, lurker and bot test) and `screenshot.gd` preload it, and their replacement only lands in 1.10. 1.8 then requires M1 movement tests to "still pass" with no file to run in. 1.6 is also oversized: World, camera rig, gutters, ScreenRouter, play_rect, death flow, shaft retirement and the F-key removal. | Split 1.6 into (a) World + play_rect + death flow and (b) shaft retirement. (b) ports `smoke_shaft.gd` and `screenshot.gd` to load `m1_shaft` through `RoomLoader`, pulled forward from 1.10, with the AC "every M1 smoke test still passes against `m1_shaft`". |
| C2 | **1.12** | It requires exclusion from release presets and a web debug build, but `export_presets.cfg` is created in **1.13**. The URL-query entry from 1.11 has the same problem. | Swap 1.12 and 1.13 (export pipeline first). AR5's "early in E1" still holds. |
| C3 | **1.12** | It is a `dev` story whose ACs are laptop and browser FPS measurements, with no human gate named. The CP1 verdict in 1.15 depends on those numbers. It also hides a runtime light-budget fallback system. | The agent writes the scene and `docs/perf.md`. Add "sonlm runs the procedure and records the numbers (human gate)", or move the measuring into 1.15. Split the light-budget fallback into its own small dev story with a test. |
| C4 | **1.37** | It asks for "the J6 gamepad session works end to end", and J6 step 2 is "Load slot 2 with A". Load and multiple slots only arrive in **1.38**. | Verify J6 step 2 in 1.38 (or 1.40), or move 1.38 before 1.37. This is a one-line fix. |
| C5 | **7.13** | It is typed `dev`, but every AC is a measurement on the laptop, an HD 620-class iGPU or a browser, with no method for the 10-minute run, the 10 s load at 50 Mbps or web-tab memory. Story 1.12 made the HD 620 machine "if available". | Retype it as `dev, playtest` and split it. The dev part: a frame-time logger in DevTools, a scripted route (bot plus the Weaver win path), and Playwright throttled load and memory sampling on a release web export. The playtest part: sonlm runs it and records the results. Add a substitute rule for when no HD 620-class machine is available. |

### 🟠 Major Issues

**Epic 1**

| Story | Issue | Remediation |
|---|---|---|
| 1.3 | "cling grace 1.0 s per **link**": GDD, FR6, M1 and the architecture all say per cling (refilled by a pogo hit). | Fix the wording. |
| 1.3, 1.1, 1.15 | The chain curve constants (`BASE_RADIUS`, `SNUFF_RADIUS`, `MAX_CHAIN`, `BASE_BLOOM`) are read directly by `test_chain_state`; moving them to `Tuning` breaks the "unchanged" gate. The count of M1 `@export` values is 44, not "≈ 28". | `ChainState` keeps its curve constants. The regression test iterates over a fixture of all 44 M1 defaults. |
| 1.1 | M1 scenes have no uids, and moved files are referenced by `res://` paths in `.tscn`, `.gd` and tests. `--import` doesn't fix those paths, and scenes can't be "re-saved" headless. | Rewrite the moved paths (list them), then import; "no `ERROR:` on load". `test_chain_state` is unchanged "except its preload path". |
| 1.6, 1.7, 1.22 | No AC sends death through `enter_room(respawn room, …)` (AR25). In the one-room shaft the Ember Cache never respawns, so J3 can't be played or tested. | 1.7 AC plus a smoke test: "die on Normal → after respawn the cache exists". |
| 1.4, 1.7, 1.24 | `DiveState.killed` is never created, but 1.6 and 1.24 depend on "killed enemies stay dead" and "rest respawns them". | Add the field and `mark_killed()` in 1.4, make room builds skip killed cells in 1.7, and add a test. |
| 1.24 | The shaft is one-way, so after the first anchor the player can't get back to `station_m1_top`: no rest, deposit, heal or save, and the enemies run out. That undermines the CP2 playtest. | **Decide before dev (sonlm):** a bottom lift back to the top, or a second placeholder station at the bottom. |
| 1.6, 1.24 | M1's per-frame "last ledge" `checkpoint` becomes the respawn point, and no AC ends that rule. If it survives, anchors mean nothing. | 1.6: respawn at the room spawn until anchors land. 1.24: only stations and anchors set the respawn point. |
| 1.11, 1.9, 1.13 | `world.gd` must reference DevTools, which breaks the lint rule. A `preload` would also break release exports that exclude `scripts/dev/*`. | Use a path-string `load()` inside `if OS.is_debug_build()`, an explicit lint allowance, and a release-export check. |
| 1.4, 1.21, 1.9 | **Verified on 4.7.2:** `JSON.parse_string()` and `ConfigFile.load()` print `ERROR:` on corrupt input, so the corrupt-file tests fail the 1.9 runner. | Parse with `JSON.new().parse()` and pre-validate `settings.cfg`, or give the runner an expected-error allowlist with its own test. |
| 1.21 | A damaged or newer-version slot 1 is overwritten by the next autosave. | Refuse saves to that slot (`save_failed`) until the picker lands; add a test. |
| 1.22 | "Out of reach" cache placement is undefined, and mid-air death is the common case. | The cache always sits at the last safe ground in that room. Test hazard, mid-air and normal deaths. |
| 1.16 | The hit flash and bank burst don't exist in M1 and no story creates them. "Short dim", "toned down" and "smaller" have no numbers. | Create them here with numbers, or scope the AC to existing effects. |
| 1.26 | 40 hand-pixelled numeral grids (UX) are art content inside a `dev` story with no approval. The story also bundles 8 HUD behaviours. | Split out a `content` story for the numerals, approved by sonlm. |
| 1.29 | UX puts cause and tip on separate lines, but the story uses one `DEATH_<CAUSE>` key, and `death_log`'s format freezes in `slot_v1`. `damaged` carries no cause. The skip input predates the `menu_*` actions (1.31). | Use `DEATH_<CAUSE>_LINE` and `_TIP`, store the cause id in `death_log`, use `damaged(amount, cause)`, and name the interim skip action. |
| 1.5 | Rebuilding a 30-column shaft into 22 columns is level design that both CP1 and CP2 are judged on. "Keeps the intent" is subjective, and ledge spacing is untested. | Type it `dev, content` with sonlm's approval of the layout, plus a `smoke_rooms` ledge-spacing check. |
| 1.41 | The `slot_v1` fixture test only proves loading; a quietly added field passes. | Add a schema guard: `to_dict()` keys can't change without a version bump, migration and fixture. Assert fixture values. |
| 1.34 | Pause or focus loss while the death card, the rest sequence, the station menu or the title is open is undefined, and so is pausing during hitstop or slow-mo. | "Never opens a second screen; the remaining Clock requests resume." Add a test. |

**Epic 2**

| Story | Issue | Remediation |
|---|---|---|
| 2.8 | A strand can be dropped without the Weaver on it and stays down until a Re-Weave. If all four go before 9 HP: no pogo fuel → no stun → no damage → **softlock**, which contradicts FR49. | Drop only while the Weaver is on the strand, or re-weave an empty drop after N s. Add a test. State the slash count and the Weaver's landing behaviour. |
| 2.3–2.9 | FSM states are added one story at a time and no priority or interrupt table exists: a flare during the bite telegraph or a stun, bright during a stun, 9 HP mid-stun, damage during Re-Weave. | Add a transition table to 2.3 and extend it in each story, with a test for each pair. |
| 2.7 | Lurker `Sensing` needs radius ≥ 80, but chain-2/3 flares are 70–78 px and would never herd. FLEE has no end condition, and several flares are undefined. The architecture contradicts itself (L409 "brightest light" vs L896 "brightest flare"). | Weaver flare sensing has no 80 px minimum (or update the GDD). FLEE ends at burnout; it flees the brightest flare. Fix architecture L409. |
| 2.4 | "Bite reach" has no number anywhere, and the on-screen half of NFR10 isn't checked in the only arena that scrolls on both axes. | Add a `weaver_bite_reach` Tuning value with boundary tests. The telegraph stays inside `play_rect()` for ≥ `Spec.TELEGRAPH_MIN`. |
| 2.11 | The winnability test covers default tuning only; the tune-after-play options (2.3, 2.6) aren't proven winnable. | Run the scripted win per option; an option that fails can't be chosen. |
| 2.6 | Trigger mode 2 can stun-lock. "Hits outside a stun deal 0", the core restraint rule, is never stated. | Re-arm only after the chain breaks. Add a 0-damage-outside-stun AC with deflect feedback. |
| 2.10 | "Without locking input longer than the moment needs" contradicts NR12 (keep input live, add no time). The intro replays on every attempt. A cache dropped in the arena isn't handled by the reset. | Full control, no added time, first entry per session only. The Weaver ignores `cache` lights; place the arena cache on safe ground. |
| 2.1–2.5, 3.2–3.4 | Arena layout, sprite grids and all core SFX are authored in `dev` stories, so sonlm never approves them, yet E3 asks "does sound make the pogo feel great?". | Type them `dev, content` with sonlm's approval (by ear for SFX), or state an explicit placeholder exemption for E2 art. |

**Epic 3**

| Story | Issue | Remediation |
|---|---|---|
| 3.6 | Chain *decreases* have no music AC: a Flare halving 10 → 5, a hit break, a cling timeout. | Stems above the new count fade out over 0.5 s with no chord. Add tests. |
| 3.6 | The ambient soundscape (rope, wind, dripping, iron) has no owner story. | Assign it to the SFX pipeline (3.1) or 3.5's list. |
| 3.3 | The clipping and web-pitch checks have no method. Headless Godot can't capture the mix without a bus effect (ADR-5), and −1 dBFS isn't in Spec. | `tools/check_mix.py` sums the WAVs offline against a new Spec const. The web smoke reads back `pitch_scale`. |

**Epic 4**

| Story | Issue | Remediation |
|---|---|---|
| 4.1, 4.4, 5.1, 6.1 | `lurker_met` and `last_entry_read` are saved from 4.4, but v2 creates no store for them. 5.1 then adds "departure flags" as a separate field while 5.7 puts them in the registry: two stores for one concept. | Add a generic `story_flags` set to v2. `set_story_flag` is idempotent. Drop the separate field from 5.1. |
| 4.1 | The v2 fixture is committed before any E4 data exists (default values only), and E4 has no close-out story like 1.41. | Hand-build a fixture with every field non-default, and add an E4 close-out AC that captures a full-layer slot. |
| 4.7, 4.8, 4.17 | Depth is never switched to `map=` rows, so "the deeper respawn point", picker depth and records can't compare rooms. 4.8 and 4.17 say "becomes the respawn point" unconditionally. | Define depth from `map=`. Change to "if deeper (FR13)", tested. |
| 4.19 | The Weaver reveal plays on entering S5, which also happens on every Weaver-death respawn at `station_hollow`. | Play once per slot (a flag in v2), entering only from S4. |
| 4.12, 4.15, 4.17, 4.22, 5.5 | Ids are missing or irregular: gate 1, Oda's journal, the B hint pickup; `npc_smith` breaks AR26; `JOURNAL_<ID>_BODY` doubles "JOURNAL". | Name them now (`gate_s3_1`, `journal_s4_oda`, `hint_b_1`, …) and fix the key rule. |
| 4.22, 4.6, 4.20, 5.11 | No story builds the B hint pickup (script, sprite, flag, map marker). Overlap with the sold hints is undefined. | Add it to 4.22. 5.11 skips any hint the pickup already revealed. |
| 4.24 | Side areas, early-entry skips and return drops aren't on the bot's route. "Zero softlocks" has no method. | Add a graph check over the exits in the room headers, and have the bot reach each side area's reward and exit. |
| 4.9–4.23 | Four FR57 rules have no check and no reviewer: ledges ≤ 1.5 s apart, exits behind a landing, the station lantern visible from above, teach → test in 2–4 screens. S2's cling and Flare lessons are first tested in S4. | Add smoke checks for spacing and exits, and sonlm's layout approval on each room story. Add a committed cling and Flare test in lower S2 or S3. |
| 4.9 | The station "no enemies within 2 screens" rule vs a 4-screen S1 that must teach the pogo and give the bot chain ≥ 5. | **Decide before dev (sonlm):** does the radius apply only to the approach from above? |
| 4.2, 4.15, 4.11 | The document screen (125–170 words at 8 px) and the gate's number display have no spec; re-reading has no AC. | Add both to 4.2's scope. Re-reading counts once. |
| 4.17 | The Last Entry moment has no trigger or content. `lock()` mid-chain conflicts with "never stop a live chain". | Describe the beat. Lock only when grounded with chain 0. |
| 4.20 | Map visits are per room (E1) but the map fills per screen. Pins are "about 10" with no cap behaviour. Nothing writes the last death point. | Decide the granularity (a v2 field if per screen), cap pins at 10 with stated behaviour, and have `World` store the death point. |
| FR27 (step 3) | No E4 story places the ≈ 5 lantern anchors or checks their spacing. | AC per spine story plus a spacing check in 4.24. |

**Epic 5**

| Story | Issue | Remediation |
|---|---|---|
| 5.1 (4.8, 5.3) | **Verified:** E4 saves autosave in the `placeholder` hub, 5.3 deletes that room, and 5.1 doesn't remap it. Tester saves would load into nothing. | Remap in 5.1 the way 4.1 did for `m1_shaft`, with a fixture test. |
| 5.9–5.14 | **Verified:** purchases, `first_dive` and payouts have no save trigger after the arrival autosave. A purchase or a second buy of an owned item is undefined. | **Decide before dev (sonlm):** autosave after each hub transaction, or make the hub quit a save point (an architecture change to AR38). Owned items can't be bought again. |
| 5.4, 5.15 | The ride's input, pause and quit behaviour is unspecified. When the Departure flag is set is unspecified (quitting mid-ride could lose the one-time gathering). The watchers might be live lurkers. | Scripted transition with `lock()`. The flag is set on completion. The watchers are props outside the predator and light groups. Add a test. |
| 5.10 | Quick Wick: does the dimmed radius count for sensing during the tap window, and when does the chain bank? If it banks on press, "a tap never breaks the chain" fails. | **Decide before dev (sonlm),** then one test per case. |
| 5.6 | Read literally, a talk with new lines never opens the shop (breaks J4). Pending flags have no order or cap; first-visit lines have no flag. | After-talk runs after new or idle lines. Play in list order. An empty `requires_flag` means the first talk. |
| 5.13 | Nothing updates "most embers banked in one chain" or deepest depth. The first Wall read doesn't play Tessaly's lines. | Add record writers, the Memorial talk on first read, and a "beaten" mark. |
| 5.14 | "Required talk" isn't enforced, the tab intro needs a once-only flag, the 2-minute target is a playtest measure, and the props are content. | The lift refuses until `first_dive`. Add `tabs_introduced` to 5.1 and the registry. Move the timing check to 5.17. Type it `dev, content`. |
| 5.2 | The UX update's scope misses the Memorial view, palette equipping, payout feedback, the tab intro, the cue for the required talk, and documents in the Journal tab. | Add them to the list. |
| 5.12 | Four features in one story. Equipping a palette and building the sprite variants are unowned. The payout trigger is unstated. | Split palettes into a `dev, content` story. State the payout trigger. |

**Epic 6**

| Story | Issue | Remediation |
|---|---|---|
| 6.6, 6.7, 6.8 | Exact 6 HP and 3 HP checks are jumped by 2- and 3-damage hits. | Clamp at the threshold; The Fall starts when the stun ends. Tests at 7 HP + strand drop and 8 HP + 3 hits. |
| 6.8, 6.9 | **Verified:** "the checkpoint is saved in the slot" and `weaver_defeated` have no save trigger. Quitting in phase 2 or before the first rest loses a beaten phase or the win (NFR13). | **Decide (sonlm, an architecture change):** autosave at The Fall landing and at the defeat, or end the defeat in an auto-rest. Add a quit-and-reload test. |
| 6.4, 6.8 | S5's door is undefined with the checkpoint set (after a rest and a trip home) and after `weaver_defeated`. Where a cache dropped in The Fall or the arena goes is undefined. | Define both door states (sealed / scripted descent) and the cache rule; the bot checks them. |
| 6.6 | 6 s of fall is about 1,200 px at 210 px/s, but the arena is 544 px tall. The fall staging is undecided. The debris has no fixed-pattern rule (NFR11) and there's no chain-pay test. | **Decide before dev:** the staging. Fixed debris pattern, a pogo bot reaches chain ≥ N, duration 5.5–6.5 s. |
| 6.3 | Fray-and-sag means both "the Weaver is hurt" and "this strand can be dropped", which confuses the core strike. | HP shows on the body and legs only (a band table in the GDD); sag means a weakened strand. |
| 6.2 | If E2 answered "no", this one story becomes open-ended redesign with a playtest inside it. | Keep it as triage. A "no" goes through `gds-correct-course` into sized stories plus a recheck playtest. |
| 6.10 | Swing edge cases: a hit while on the rope, rope vs solid tiles, its interaction with the dash, the ground grab, a press toggle (Cling and Snuff have one). | Add an AC for each, decided and tested. |
| 6.12, 6.1 | What opens a sealed alcove is never stated. The reward ids (Silk Grip, the 4th hoard, the partner tag) are unnamed. | Name the ids per AR26 and put an opened secret in the v4 fixture. |

**Epic 7**

| Story | Issue | Remediation |
|---|---|---|
| 7.1, 7.5 | "The run used assists" has no meaning in a persistent slot: when it clears and which records it blocks are unstated. The assist list and levels are design calls. | Define `slot.assist_used` in 7.1. **Decide before dev (sonlm):** the assist list. |
| 7.3 | Rebound keys have no glyphs, a required action can be left unbound, menu-action rebinding and capture cancel are unstated, Esc on web, the Snuff-toggle key. | Add an AC for each. |
| 7.7, 7.1 | "New" marks outside creature entries need a saved seen-set that v5 doesn't add. | Add it to the v5 migration, or no marks outside creature entries. |
| E7 | No `ux-update` story at the head. Text-scale layouts, sound-cue markers, rebinding screens, Journal sections and the logo would be designed by the dev agent. | Add **Story 7.0 (ux-update)** before 7.2. |
| 7.8, 7.14 | The chain-cap cue is decided but never built or tested. The polish list is unknown when the story file is written. The length validator ignores text scale and lives inside a test pass. | Add a build/test AC for the cue and freeze the list at story creation. Run the validator at every text scale in 7.4 or 7.15. |
| 7.15, 7.11 | The release web build and the desktop builds are never boot-tested; the PCK contents are "inspected" with no method. **Verified:** Godot's MIT notice and its third-party notices ship nowhere (NFR18 covers only the font). | Boot checks for the release builds, a PCK content script, and Godot notices in the Credits and in `export.sh`. Extend NFR18. |
| 7.16 (6.15) | The metrics (attempts, best chain, % of deaths named) can't be measured from interviews, and "how to avoid it" was dropped. Earlier testers aren't excluded. There's no rule for < 5 testers. "Clue volume is tuned" breaks NR23's exactly-three-clues rule. | A tester-stats export, exclusion and shortfall rules. A clue miss becomes a `content` story for the next milestone. |

### 🟡 Minor Concerns

- **E1:**
  - 1.2: four `time_scale` writes, not three; re-requesting an active Clock id has no stated behaviour.
  - 1.8: the Light tap timer must run on real time across hitstop.
  - 1.4, 1.11: `Settings` writes files from the pure `rules/` layer and on every change; tests would overwrite the real `settings.cfg`; `--set` persists.
  - 1.25: no reduce-flashing variant for the HP pips; the held-row flicker has no rate.
  - 1.27: the M1 alert colour and the English "+N banked" / "-N lost" popups live in `shaft.gd` / `fx.gd` and bypass `tr()`.
  - 1.19: bank-heal edge cases (Flare Toss, exit, cling timeout) and the `bank_heal_min` Tuning key aren't stated.
  - 1.10: no `spine=true` header; `rooms/dev/*` falls into the fairness sweep; standalone rooms have no `play_rect()` provider.
  - 1.39: the save retry semantics; "once per session" vs AR38's "once per failure".
  - 1.36: a difficulty change only persists at the next save trigger.
  - 1.31: builds a Slider that no E1 screen uses until 3.8.
  - 1.41: "GDD shows E1 as L" is already done.
- **E2/E3:**
  - 3.2, 3.7: pool players' pause mode; no story makes the menu sounds.
  - 3.2, 3.6: "muffled" invites a bus effect, which ADR-5 bans; pre-render it instead.
  - 2.5 vs 2.9: spiderlings during Re-Weave.
  - 2.10: bundles four concerns, and its restart input is undefined.
  - 2.12: must be a debug web export; missing 2.6's decision; record path differs from the convention.
  - 3.4, 3.7: "above the music" can't be tested before 3.6, and the ducking cue list is unstated.
  - 2.6: the light burst bypasses the Fx gate; 96 px has no defined measuring points.
- **E4/E5:**
  - 4.23: the zone is unstated (the GDD says daylight, FR59 says cold violet), and there's no run-up AC.
  - 4.14: per-item prices are ranges; the hoard flag is set while its embers are only carried (a Hard death loses it for good).
  - 4.13: a "Decide before dev" call that can't be made before the walk-through.
  - 5.8: no story writes shop item names or descriptions.
- **E6/E7:**
  - 6.9: the Silk can be left un-picked-up; the defeat burst has no flash-safety AC.
  - 6.5, 6.7: "the Bright Moon rule is off" is untestable; there's no ceiling under the open sky.
  - 6.14: "played" in a dev story; smoke tests can't cross `scripted_cut`.
  - E7: no findings-intake story for an E3 or E6 "no".
  - 7.2: Scale vs DPR on web; the Brightness settings key must carry over from E1.
- **Doc hygiene (steps 2–4):** G1–G4, U1, U4, U7.

### Counts

| Severity | E1 | E2 | E3 | E4 | E5 | E6 | E7 | Total |
|---|---|---|---|---|---|---|---|---|
| 🔴 Critical | 4 | 0 | 0 | 0 | 0 | 0 | 1 | **5** |
| 🟠 Major | 17 | 8 | 3 | 13 | 9 | 8 | 7 | **65** |
| 🟡 Minor | 11 | 4 | 3 | 3 | 1 | 3 | 2 | **27** |

(Some rows span stories in two epics; each is counted once, under its first story.)

## Summary and Recommendations

### Overall Readiness Status

**NEEDS WORK.** Fix Epic 1 before sprint planning; the later epics can be fixed one epic at a time.

**What is strong.**
- **Requirements coverage:** all 81 FRs are mapped and cited by story ACs, and so are all NFRs, NRs and UX-DRs; 57 of 58 ARs are cited, and AR4 is satisfied by story order.
- **Structure:** every epic delivers player value; no epic depends on a later one; no story references a later epic.
- **Numbers:** every GDD value quoted in the stories matches its source.
- **Conventions:** story types, human gates, decide-before-dev, tune-after-play, migration-first epics and playtest records are unusually rigorous for a solo project.
- **Documents:** the GDD is final, with every assumption owned.

**What is not ready.**
- Epic 1 starts next, and the dev agent would hit four ordering defects in its first 37 stories:
  - deleting the scene the M1 tests load (C1);
  - an export preset needed before it exists (C2);
  - a laptop measurement disguised as dev work (C3);
  - a Load step needed before Load exists (C4).
- Epic 1's playable has three holes:
  - no route back to the station;
  - a cache that never appears after a death;
  - killed enemies with no state.
- `slot_v1` freezes at the end of E1, so the death-log format, the save triggers and the state shape must be right before then.

### Critical Issues Requiring Immediate Action

1. **E1 ordering (C1, C2, C4):**
   - split Story 1.6 and port `smoke_shaft.gd` and `screenshot.gd` to `m1_shaft` before deleting `shaft.tscn`;
   - swap Stories 1.12 and 1.13;
   - move J6 step 2 (Load slot 2) out of Story 1.37.
2. **Hidden human gates (C3, C5, T5):**
   - Stories 1.12 and 7.13 must say that sonlm measures on real hardware;
   - content written in `dev` stories (1.5 layout, 1.26 numerals, E2 placeholder art, E3 SFX, 5.12 palettes, 5.14 props) needs sonlm's approval or an explicit placeholder exemption.
3. **E1 playable holes (1.24, 1.6/1.7/1.22, 1.4):**
   - decide how the player gets back to `station_m1_top`;
   - route death through `enter_room`;
   - add `DiveState.killed`;
   - end the M1 last-ledge checkpoint.
4. **The engine conflicts with the test runner (verified):** use `JSON.new().parse()` and pre-validated config loads, or a runner allowlist, before Story 1.9's runner makes corrupt-save tests fail.
5. **Fix the save format before `slot_v1` freezes (1.29, 1.41, T2):**
   - store death-log entries as cause ids with separate `_LINE` and `_TIP` keys;
   - add a schema guard test;
   - decide the save-trigger policy (hub transactions, The Fall landing, the Weaver defeat), because it changes AR38 and the architecture.

### Recommended Next Steps

1. **Patch `epics.md` for Epic 1 now:** the four Critical findings and the 17 Major findings in Stories 1.1–1.41, plus the Minor fixes that are one-liners (1.2, 1.3 wording, 1.19 Tuning key). Ask sonlm to decide two questions while patching: the shaft's return route (1.24) and the save-trigger policy (T2).
2. **Settle the cross-cutting decisions that touch the architecture, once:**
   - save triggers (T2);
   - a generic `story_flags` set in v2 (T3);
   - the Weaver's flare sensing below 80 px (2.7; fix architecture L409 to "brightest flare");
   - Godot licence notices (extend NFR18).

   Then apply the document fixes:
   - G2: AR2 Brightness wording;
   - U1: `EXPERIENCE.md` Brightness lines 84, 313, 532 and A1;
   - U2: Brightness changes only the ambient level;
   - U4: `DESIGN.md` amber exception for lit anchors and creature sparks;
   - U5: the architecture's narrative systems and the Oda's-house room id.
3. **Run `gds-sprint-planning`** once Steps 1 and 2 are done. A quick re-check of Epic 1 is optional.
4. **Before each later epic's first `gds-create-story`, apply that epic's punch list from this report.** Use `gds-correct-course` where scope changes. Stories to add:
   - 7.0 (`ux-update`);
   - an E7 findings intake;
   - an E4 close-out with a full-layer v2 fixture;
   - lantern-anchor placement ACs and a spacing check (FR27);
   - the B hint pickup.

   Stories to split: 1.6, 1.12, 1.26, 5.12, and 6.2 into triage plus correct-course.
5. **Name every persistent id before E4 ships to testers (T7):** `gate_s3_1`, `journal_s4_oda`, `hint_b_1`, the Swing rewards, the Silk pickup and the NPC pattern.

### Final Note

This assessment identified **108 issues across 4 categories**:
- requirement coverage: 1 partial FR (FR27);
- document alignment: 11 (G1–G4, U1–U7);
- epic structure: clean;
- story quality: 97 (5 critical, 65 major, 27 minor; FR27 is counted here too).

Five Critical issues and the E1 Majors must be fixed before implementation starts. The E2–E7 findings can be fixed just in time, one epic at a time. The findings can be used to improve the artifacts, or you may choose to proceed as-is with the risks listed here.

**Assessor:** gds-check-implementation-readiness (Claude), with four independent story reviewers; high-risk claims re-verified against the M1 code and a headless Godot 4.7.2 run. **Date:** 2026-11-12.

## Remediation Log

### 2026-11-12: Epic 1 fixed (sonlm chose "Fix Epic 1")

**Decisions (sonlm), recorded as R14–R16 in `epics.md` and in the GDD decision log**

- **R14 Progress saves.** Difficulty change, purchase, story flag, phase checkpoint and boss defeat save world progress, without moving the resume point or making carried embers safe. Updated: AR38, FR29, the GDD (Saves), the architecture (Data Persistence, save triggers, API example) and project-context.
- **R15 Settings as JSON.** `user://settings.json`, parsed with `JSON.new().parse()`. Updated: AR14, AR37, AR38, the architecture (four places), project-context, and Stories 1.4, 1.11, 1.36, 3.8, 7.2.
- **R16 E1 shaft loop.** The bottom exit leads to the shaft's own top entry and banks the chain. Updated: Stories 1.5, 1.7, 1.24.

**Story fixes in `epics.md`**

- **C1 fixed.** Shaft retirement moved from 1.6 to 1.7 (retitled "Room swaps, physics interpolation and retiring `shaft.gd`"). 1.7 ports `smoke_shaft.gd` and `screenshot.gd` to `m1_shaft` before deleting `shaft.gd` and `shaft.tscn`, so the suite stays green. This also happens before the 1.9 lint, which would otherwise fail on `shaft.gd`'s `KEY_F` and raw `Input`. No story was renumbered.
- **C2 fixed.** 1.12 runs in the editor and desktop debug builds. Its web run and its release-preset exclusion move to 1.13, which also adds a PCK-contents check and the release web boot check.
- **C3 fixed.** 1.12 delivers the procedure and the overlay readout. sonlm takes the measurements in 1.15, a human gate, with the HD 620 gap recorded if no machine is available.
- **C4 fixed.** J6 step 2 (Load slot 2) moved from 1.37 to 1.38.
- **E1 Majors, all 17 fixed:**
  - 1.3: cling wording; `ChainState` keeps its curve constants; fixture of all 44 M1 values.
  - 1.1: path rewrite instead of uids; the test's preload-path exception.
  - Death goes through `enter_room` (1.7).
  - `DiveState.killed` (1.4, AR14).
  - The shaft loop (R16).
  - The respawn point no longer follows the M1 last ledge (1.4, 1.6).
  - DevTools loaded by path string, with a lint allowance and a release check (1.11, 1.13).
  - JSON parsing that prints no errors (1.4, 1.21).
  - Damaged and newer-version slots are write-protected (1.21).
  - Cache placement and the cache smoke test (1.22).
  - Hit flash and bank burst defined with reduce-flashing variants (1.16, 1.19, 1.26; reviewed in 1.30).
  - Numerals typed `dev, content` with sonlm approval (1.26).
  - Death keys `_LINE` / `_TIP` and `death_log` storing the cause id, which freezes in v1 (1.29; also NR3, 2.10, narrative-design).
  - The shaft layout typed `dev, content` with sonlm approval, plus a ledge-spacing smoke check (1.5, 1.10).
  - Schema guard and value-asserting fixture (1.41).
  - Pause over other screens and during hitstop (1.34).
- **E1 Minors fixed:**
  - 1.2: four writes; re-request refreshes.
  - 1.8: real-time Light timer.
  - 1.4, 1.11: settings I/O in `core/`, injectable path, session-only `--set`.
  - 1.25: reduce-flashing pips and flicker rate.
  - 1.27: real colour sites.
  - 1.19: `damaged(amount, cause)`, `bank_heal_min`, which chain ends count, bite knockback.
  - 1.10: `spine=true`, `rooms/dev` only validated, `play_rect()` stub.
  - 1.39: retry as a progress save.
  - 1.41: stale "GDD shows E1 as L" removed.
- **Left as is:** 1.31 Slider (harmless) and 1.36's difficulty persistence (now covered by R14).

**Document fixes done along the way**

- G2: AR2 Brightness wording.
- U1, in the `epics.md` inventory only: UX-DR78, UX-DR133, A1 and Ambiguity 1 marked resolved.
- NFR18 and Story 1.17: Godot's MIT licence and third-party notices ship from E1 (`GODOT_LICENSES.txt`).

**Mechanical re-check.**
- 41 E1 stories, all with a Type line and Given/When/Then.
- 28 within-epic forward references, all staging ("until Story X lands" or "reviewed in Story X"); none is a dependency.

### 2026-11-12: optional doc fixes and an Epic 1 re-review

**Document fixes**
- **U1:** `EXPERIENCE.md` shows Brightness in E1 Accessibility, moving to Video in E7; A1 is marked decided; `updated:` 2026-11-12.
- **U2:** the architecture and Story 1.36 say Brightness changes only the ambient level, and a test proves radii, `Sensing`, the reserved colours and the HUD are identical at every level.
- **U4:** `DESIGN.md` Reserved allows in-world amber for lit anchors, hub lanterns and fading creature sparks; Story 1.24 cites it.

**Independent re-review of Stories 1.1–1.41.** The reviewer confirmed 21 of the 26 claimed fixes and marked 5 partial or wrong. It also found one new Critical, verified here on Godot 4.7.2.

- **F1 (Critical): fixed by R17 (sonlm).** Under `--script`, a test that touches the `Game` autoload fails to compile: it hangs (`preload`), or exits 0 with no output (`class_name` hint), which the M1 runner reports as green. Tests now extend `Node` and run as scenes through `tests/runner.tscn`, and a test with no `PASS` line or running over 120 s fails. Updated: Story 1.2, Story 1.9, AR47, Story 1.15 wording, project-context (Tests, Testing Rules, Screenshots), the architecture's test runner rule.
- **F2: C1 fully closed.** The M1 smoke and screenshot tests are ported to `m1_shaft` at the end of Story 1.5, before 1.6 switches the lurker to `play_rect()`. Story 1.7 only deletes `shaft.gd` and `shaft.tscn`.
- **F3:** a rest rebuilds the room (`enter_room(current room, station)`), so killed enemies come back. Kills are recorded with `mark_killed`, and a test covers a kill surviving a death and the loop (1.7, 1.24, AR25, architecture).
- **F4:** Story 1.8 first adds the M1 movement checks that don't exist yet (run, coyote, buffer, air dash), then switches to intents.
- **F5:** the respawn point is per dive and moves only when the new point is deeper. A rest sets it to the station (1.24).
- **F6:** `death_log` stores `{cause, room}` everywhere (AR25, UX-DR86, the architecture), and the 1.41 schema guard checks the entry shape and the cache.
- **F7:** `save_progress()` reports success or failure like `save_now()` and keeps the cache as of the last resume save. AR11 and UX-DR112 are updated.
- **Minors:**
  - F8: URL-query unit test, plus a Playwright `?room=` boot.
  - F9: the real M1 colour sites (`shaft.gd`, `player.gd`).
  - F10: `get_license_info()` added.
  - F11: lint allows `print(` in `core/log.gd`.
  - F12: injectable save directory for tests.
  - F13: a `--glow` debug arg.
  - F14: AR1, AR3, and the architecture lines on `ConfigFile`, `preload` of DevTools and re-saving scenes.
  - F15: how the ledge-gap check measures.
  - The first save skips the `.bak` copy, avoiding an engine error.
- **Rejected:** the J6 step-count nit. J6 has 7 steps, so "steps 1 and 3–7" is correct.

**Re-check.** All 41 E1 stories have a Type line and Given/When/Then. All 29 forward references are staging. **Epic 1 is ready for sprint planning and story creation.**

### Still open

- **Before sprint planning:** nothing blocking. The E1 fixes are in.
- **Before E2's first story:**
  - the E2 punch list (2.8 softlock, FSM priority, HP thresholds, flare sensing below 80 px plus architecture L409, bite reach, winnability per option, stun-lock, staging input, arena cache, content typing);
  - U2: Brightness changes only the ambient level, and the architecture should mention Brightness.
- **Before E3, E4, E5, E6 and E7:** each epic's punch list in Epic Quality Review, plus:
  - T3: a generic `story_flags` set in v2 (Story 4.1);
  - T7: name the persistent ids;
  - FR27: anchor placement;
  - G1: the Old Mine skip;
  - U4: the `DESIGN.md` amber exception, before E1's anchors are drawn if possible;
  - U5: the architecture's narrative systems;
  - U1: `EXPERIENCE.md` lines 84, 313, 532;
  - add the missing stories (7.0 `ux-update`, E7 intake, E4 close-out).

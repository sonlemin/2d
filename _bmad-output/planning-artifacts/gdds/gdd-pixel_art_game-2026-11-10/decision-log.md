# Decision Log — The Unbroken Chain GDD

## 2026-11-10 — v0.1 workspace created (Create mode)

- **Intent:** Create the GDD. Immediate goal: plan Milestone 2 (the vertical slice).
- **Inputs:** the game brief plus addendum and decision log (2026-11-08); the M1 playtest findings (2026-11-10), which supersede the brief on controls, wall cling and embers.
- **Plan style:** the user chose "Full GDD first" over a lean M2 plan or a brainstorm.

## 2026-11-10 — Situational read

- **Game type:** Metroidvania (descent) as the primary genre. Action-platformer feel conventions (movement-feel table, hit/hurt boxes, coyote/buffer, checkpoint cadence) fold into the genre section. `needs_narrative` = true (the guide recommends it); offer `gds-create-narrative` at Finalize.
- **Contradictions resolved by precedence (M1 findings supersede the brief):**
  1. Pogo = any Attack in the air. Down+Attack is dropped.
  2. Snuff = hold Light for at least 0.12 s; tap Light is reserved for Flare Toss.
  3. Cling = 1 s grace per chain (a pogo refills it); the light drops to base radius; release = kick, Down = drop; slide only.
  4. The last-ledge respawn is interim. Lift Stations replace it in M2.
- **Still open (to walk):** embers vs the brief's currency and haul, and the death-drop tiers; the Weaver's scope inside M2 ("The Fall" to Layer 2?); crafting is parked, but the Weaver's reward is Silk; the Flare Toss cost; which hub NPCs come first; what a Lift Station does; the boss-lesson wording; Dive Boons cut vs deferred.

## 2026-11-10 — Economy (walked)

- **Embers are the single currency** and replace the brief's "haul" and "currency".
- **Risk stages (user's choice):** held, then carried, then deposited.
  - Held: lost on death.
  - Carried: dropped as a cache that can be recovered once.
  - Deposited (at a Lift Station or the hub): safe.
- **Difficulty tiers** map the brief's Easy / Normal / Hard onto these stages.
- **Sinks (user picked all four):**
  - maps and hints (Cartographer);
  - Lift Station repairs (Guild);
  - gear (Smith), with the rule "bends a rule, never raw power";
  - journal and cosmetics (Naturalist).
- **Prices** are starting values, tagged [ASSUMPTION] until the M2 playtest.
- **Deferred to the designer:** the idea that a cache glows and draws lurkers.

## 2026-11-10 — Weaver scope, Silk, health, Flare Toss (walked)

- **Weaver:** the full fight is in M2. "The Fall" at half health is the finale: you fall into one landing arena at the top of Layer 2, and the rest of Layer 2 is not built.
- **Silk:** unlocks **Swing** (hold Dash near a silk anchor). It works as a direct ability unlock, so crafting stays parked.
- **Player health:** 4 HP.
  - Damage: crawler or boss 1, hunting lurker 2.
  - Healing: full at a Lift Station; +1 for banking a chain of 10+ [ASSUMPTION].
  - This replaces M1's one-touch death.
- **Flare Toss:** tap Light, needs at least 2 links, costs half the chain (rounded up). A share of the held embers moves to carried.
  - The flare burns 4 s with the pre-toss light radius, and predators treat it as the player.
- **Mechanics written with numbers:** movement, pogo, chain (M1 values), cling, Flare Toss, Swing, health, lurker. Controls table updated; no chords.

## 2026-11-10 — Weaver fight loop (walked)

- **Flare vs Weaver:** a flare **repels** the light-shy Weaver, so you can herd it. A flee onto a weakened strand plus cutting its anchor drops the strand: 2 damage and a stun. The Weaver is the exception to "predators treat a flare as the player".
- **Loop:** bright → it retreats and drops spiderlings; dark → it descends and bites; a burst to chain 3 within 96 px → stun 2.5 s, up to 3 damage.
- **HP 12; Re-Weave at 9 HP; The Fall at 6 HP.** The Fall includes about 6 s of free-fall chain section, then phase 2 in the Layer 2 landing arena.
  - Phase 2: 2 strands, 0.75 s telegraph, Re-Weave at 3 HP.
- **Phase checkpoint:** dying in phase 2 resumes at phase 2.
- **Reward:** Silk (Swing), plus a free Lift Station back to the hub. The way down into Layer 2 stays sealed in M2.
- **Spiderling** added as a Weaver-fight enemy.
- **Open:** whether Layer 1 needs a third regular enemy (deferred to Level Design).

## 2026-11-10 — Layer 1 map (walked)

- **Shape:** a spine (main descent) with side branches.
- **Length:** 45–60 min to the Weaver; about 23 spine screens plus 3 optional side areas (A Rope Works, B Old Mine, C Sky Ledge).
- **Chain gates:** 2.
  - Gate 1 (≥ 4) is on the main path in S3.
  - Gate 2 (≥ 8) guards Sky Ledge's **shortcut to the hub**, the only mid-layer deposit (user's change from "big cache").
- **Flare Toss is in the starting kit** (user's change from an S4 pickup); it is taught in S2.
- **Midway Station is cut** (user's change): the stations are Lip, Hollow and the landing-arena station. As a result, M2 has no Layer 1 station repair; the repair sink starts in Layer 2.
- **Respawn:** lantern anchors every 4–6 screens give respawn only. Lift Stations give respawn, full heal, deposit and fast travel. Chosen to avoid the restart tedium from M1.
- **Swing secrets:** 3 (in A, S2 and C), holding the Silk Grip gear (+0.25 s cling), a Memorial clue and a cache.
- **Chain-gate rule:** a gate that fails does not break your chain.

## 2026-11-10 — Hub and Lift Station (walked)

- **M2 NPCs (user picked all four):** Cartographer, Smith, Naturalist, Guild + Memorial Wall.
- **Hub:** a small walkable village 2 screens wide on flat ground. Arriving home deposits embers and heals.
- **Smith gear in M2** (always on, no slots):
  - Quick Wick: Snuff hold 0.08 s, 200 embers.
  - Long Wick: flare 6 s, 250 embers.
  - Steady Grip: cling slide 10 px/s, 300 embers.
  - Silk Grip is found, not sold.
- **Naturalist:** 10 embers per new journal entry; 2 palettes (75, 150).
- **Lift Station:** touch lights it (respawn point). Rest heals, deposits, opens fast travel and **respawns enemies**.
- **Correction:** the user chose "press ↑ to rest", but ↑ is Jump (an M1 request). Interact is **↓ on the ground** instead; flagged to the user.
- **The Watching Departure** is kept as the lift-up moment.

## 2026-11-10 — Derived sections drafted (for review)

- **Drafted from earlier decisions:** win/loss, progression, difficulty curve, level types and progression, tech specs, assets, metrics, out of scope, assumptions.
- **New proposals in the drafts (to confirm):**
  - Difficulty settings change only the cost of death, never damage or telegraphs.
  - 60 FPS on a 2016-era integrated GPU; a web build under 30 MB.
  - Autosave at a station rest.
  - Keep the reachability bot as a level-validation rule.
  - Metrics are based on about 5 testers.
  - Dive Boons are listed as cut [NOTE].
- **Still to walk:** Art and Audio; Development Epics.

## 2026-11-10 — Art and audio (walked)

- **Layer 1 palette:** warm at the top, cold below. Dusk brown (S1) → muted umber (S2–S3) → the M1 cold violet (S4–S5). Resolves the conflict between the brainstorm's warm palette and the M1 violet.
- **Reserved colours:** amber `#ffd27a` = the player's light; predator red `#d9473f` = danger. Every telegraph also has a shape, motion and sound cue.
- **Sound style:** an organic world with synthetic light.
- **Music is chain-reactive:** pulse at 3 links, melody at 6, full theme at 10. A bank resolves the music; a death cuts it. The hub, the Weaver and The Fall have their own themes.
- **Pogo pitch:** +1 semitone per link, up to +12.
- **Lurker telegraph sound:** always above the music (6 dB ducking).
- **Pipeline:** SFX from a script (params → Python → WAV). Music is composed on the laptop as stems.
- **[ASSUMPTION] tags:** the Layer 2 landing and hub palettes.

## 2026-11-10 — Epics (walked)

- **Order:** risk-first (user's choice). E1 Kit v2 → E2 Weaver prototype → E3 Audio → E4 Layer 1 → E5 Hub → E6 Weaver final → E7 Polish and ship.
- Each epic ends in something playable and has one playtest question. A "no" is fixed before the next epic.
- **Size estimate:** M2 ≈ 9–18 months at 5–10 h/week [ASSUMPTION].
- **Files:** `epics.md` holds the details and a coverage table; `gdd.md` holds the summary.
- **Status:** the draft is complete. Next is Finalize (log audit, input reconciliation, validation, open items).

## 2026-11-10 — Finalize: reconciliation and validation (autofixes applied)

- **Checks run:** 3 input reconciliations (brief, brainstorm, research) and 1 checklist validator. Verdict: PASS WITH FIXES.
- **Autofixes:**
  - Hit and hurt boxes (M1 values).
  - Removed `ember_value` (an engine-style name).
  - Contradictions fixed: Swing gating, defense list, Naturalist and Smith rows and prices, lurker "senses", palette count, asset enemies, S2 secret, backtracking via the Lip, epic sum (8–17 months).
  - Vague quantifiers replaced with numbers; the GPU is named; memory and web budgets added.
  - Assumption index renumbered to A1–A7.
  - World caches renamed **Ember Hoard**; **Ember Cache** is the death drop only. Sky Ledge gets a hoard (≈ 100).
  - Pillar 4 reworded ("new abilities reuse the same buttons").
  - Feel rules added: slow motion only at boss climaxes, deaths dissolve without blood.
  - Snuff rationale added (cash-out, not a toggle) with playtest watch items.
  - The Bright Moon rule is off in the Weaver landing arena.
- **Added from the inputs:**
  - The 7-layer table and the sanctuary base rule.
  - Narrative and Tone: three reveals, originality rule, the Anchor lore, the Last Explorer's record, *The Last Entry* in S4.
  - Risks section and Open Questions section; Expedition Loadout replaced by gear; relic kept as a story motif.
- **epics.md:**
  - Flash-safety cap, reduce-flashing toggle and the Field Journal death line moved to **E1**, because the brief says "from day one" and Pillar 2 needs them.
  - Journal entry count fixed.
  - A devlog after each epic.

## 2026-11-10 — Finalize: designer decisions (batch 1)

- **Any hit** breaks the chain and moves held embers to carried. Only death loses held embers.
- **Dash/Swing:** within 56 px of a silk anchor, Dash grabs the rope; otherwise it is the air dash. No hold threshold, so dashes have no delay.
- **Gamepad in M2:** the default mapping ships in E1; a Steam Deck pass in E7 (×2 scaling, HUD readability). Reverses the brief's "controller later", following the research.
- **Off-screen stirring:** a lurker that would wake just off screen gives a panned stirring sound and an edge glow, but it can't hunt until it is on screen and has telegraphed.

## 2026-11-10 — Finalize: designer decisions (batch 2)

- **Session length:** quitting at a lit lantern anchor saves your position, so the 45–60 min first descent can span two sessions.
- **Price target:** $15–20 premium.
- **Marketing:** no section and no marketing work before M2 (designer's call). Decided in E7.
- **Dive Boons:** parked, not cut.

## 2026-11-10 — v1.0 FINAL

- **Open-items triage:** there are no phase blockers left. These 3 notes are deliberately deferred:
  - a third Layer 1 enemy, decided in E4;
  - the glowing Ember Cache that draws lurkers, an E1 playtest idea;
  - narrative details, decided in the narrative pass.
- The A1–A7 assumptions and the Open Questions table each name the epic or pass that resolves them.
- **Polish:** no `doc_standards` are configured, so it was skipped. There are no external handoffs.
- **Narrative handoff:** `needs_narrative` is set. `gds-create-narrative` was offered to the user.
- **Status:** gdd.md `status: final`. Next step: `gds-game-architecture`, in a fresh session.

## 2026-11-11 — Update: UX decisions carried back

Source: `ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md` (Notes for Other Docs) and its `.decision-log.md`. These are newer designer decisions, so they win over the v1.0 text. The UX spines are added to the gdd.md `inputs`.

- **Light tap window** is a player setting: 0.12 s (default), 0.2 s or 0.3 s (UX 2026-11-11). Flare Toss, Controls and the chain table now cite 0.12 s as the default. Lands in E1.
- **Quick Wick** changes the Snuff response, not the tap window (UX 2026-11-11). **Reverses** the Hub line "Snuff hold 0.12 → 0.08 s". Its new effect is not defined yet; added to Open Questions (E5).
- **Reserved amber:** the menu selection cursor counts as the player's lantern, so amber in menus is allowed (UX 2026-11-10). Art Style table updated.
- **Ember Cache glow:** the cache glows and draws nearby lurkers (UX 2026-11-10). Turns the deferred designer note into a decision. Glow radius and pull are a new assumption (A8), tuned in E1.
- **Lurker alert:** "the HUD turns red" **is replaced by** a pulsing red gutter frame (≤ 2 Hz) plus an eye icon; HUD values are not recoloured (UX 2026-11-11).
- **Off-screen stirring:** a half-open edge eye that opens as the lurker stirs, plus a glow with a minimum strength. Glow alone is not enough (UX 2026-11-11).
- **Weaver:** no health bar; health reads from fraying, falling segments and sagging threads (UX 2026-11-11).
- **Pause:** Esc or P on keyboard, Start on gamepad (UX 2026-11-11). Added to Controls.
- **Timing assists** are separate settings, not difficulty. "Difficulty never changes telegraphs" still holds; assisted runs stay out of Guild records (UX 2026-11-10). Resolves the "Assist options for Easy" open question.
- **Difficulty** is chosen at New Game and changeable any time in Options (UX 2026-11-10).
- **Gutters:** the HUD sits in ~60 px side gutters, leaving ~360 px of play area. Rooms are framed for 360 px; wider rooms scroll. Noted in Movement, Art Style and Level Design Framework for level design and the camera.
- **Options rollout:** a small Options screen ships from E1 (Game + Accessibility: reduce flashing, screen shake, reduced motion, tap window, Cling/Snuff hold→press toggles). Audio in E3. Video and Controls in E7. The brightness F1 hotkey is removed. **Changes** epics E1, E3 and E7 (screen shake moves from E7 to E1).
- **Cling/Snuff toggles** ship in E1 (UX log, Update O13). Full rebinding stays in E7.
- **Saves:** 3 slots instead of one profile; slot picker, Continue, Load; failed saves are shown (UX 2026-11-10/11). **Reverses** "One profile in M2".
- **Web baseline:** the itch embed is 960×540 (×2); Performance and Platform-Specific Details updated.
- **Steam Deck:** the Deck-size legibility check moves to E1 with the font choice; the full pass stays in E7.
- **UI font:** Fusion Pixel Font 8px, proportional latin build, OFL 1.1 (UX log, Update O1). Added to Art Style and E1.
- **Journal:** a minimal Journal tab (creature entries, "new" marks) moves to E5; E7 keeps the death log, lore, records and polish.
- **Not carried over (architecture notes):** death card line storage, save-failure UI details, slot delete, and devicePixelRatio scaling stay with the architecture.
- **Status:** stays `final`; `updated: 2026-11-11`.

## 2026-11-11 — Designer decisions on the two UX-update follow-ups

- **Quick Wick = instant Snuff.** The light starts dimming the moment Light (V) is pressed. A release inside the player's tap window still becomes a Flare Toss. The tap window does not change. Replaces the E5 Open Question added earlier today. Updated: Hub gear table, epics E5.
- **Spine shafts narrow from 26 tiles (416 px) to 22 tiles (352 px),** so they fit the ~360 px view between the gutters with no sideways scrolling. The Weaver arena stays 30 tiles (480 px) and scrolls horizontally with the camera ("one screen wide" removed). Updated: Level Types, the gutter framing note, the Weaver arena, epics E2 and E4. The M1 findings give no shaft widths, so nothing there conflicts.

- 2026-11-11 — Snuff toggle mode (from UX): with the Accessibility Snuff toggle On, Light only throws Flare Tosses and Snuff moves to its own key (default Shift; pad LB) as a press-toggle. It still ends the chain. Pillar 4's "no new buttons" holds for the default scheme; the extra key exists only in this accessibility mode.

## 2026-11-12 — Follow-ups from the game architecture

Source: `_bmad-output/game-architecture.md`, Validation → Follow-ups.

- **Room-exit backstop:** crossing a room exit with a live chain banks it like a landing (ADR-2). Added as a row in the chain table, with a note that level design keeps exits out of chain runs and The Fall is the only exception.
- **Retargeting needs a fresh telegraph:** a lurker that switches from a flare or cache to the player telegraphs again (≥ 0.75 s). Added to Predators: Lurker.
- **Ember Cache wake rule:** the cache wakes lurkers only if its glow radius is ≥ 80 px (same notice rule as the player). Added to Economy; the radius stays an E1 tuning assumption.
- **Spine width wording:** "22 tiles of open space" → "22 tiles wall to wall, side walls included". Updated: Level Types, the gutter framing note, epics E1 and E4.
- **Open questions:** added a cap on simultaneous flares (E1 perf scene + playtest); the bloom question records the architecture's answer and moves to the E1 perf scene.
- **Status:** stays `final`; `updated: 2026-11-12`.

## 2026-11-12 — Narrative design follow-ups

Source: `_bmad-output/narrative-design.md` (gds-create-narrative, complete), Production Planning → changes required.

- **Cast and lore:** Glim, Oda Vell, Old Tessaly; embers are the abyss's light (coin and fuel); "you take too". Added to Narrative and Tone, which now points to the narrative doc (the designer note is resolved).
- **Clue budget:** Layer 1 has exactly three pointed clues (Tessaly First Dive, The Watching Departure, Tessaly after the Weaver). Updated Narrative and Tone; added a story-clue row to Gameplay Metrics.
- **Hub:** Oda's house added (interior beside the Guild; not a save point); new games open there from E5.
- **Memorial clue changed:** it is now the Guild tag of Oda's dive partner, not "the first name tied to the Last Explorer" (Oda is known from the start). **Changes** the Guild row and E6.
- **The Last Entry** is Oda's unsigned camp; her cold lantern is a lantern anchor (S4 row, E4).
- **Naturalist** copies entries and pays for the copy.
- **Lift ride up:** fixed duration; full Watching Departure once per station layer after meeting a lurker.
- **Boss defeat:** win first, then a dim-and-withdraw coda; bosses are never shown dying.
- **Amber rule clarified:** lit ember lanterns only in the hub and on anchors; layer lamps dead or cold; creature sparks turn amber as they fade.
- **Epics:** E1 death lines follow the narrative voice; E4 adds the Memorial name list, `anchor_s4_oda` and story flags; E5 adds a UX update first, Oda's house and opening, story text, flag registry and text validators, and grows **M → L**; E6 adds the partner tag, defeat presentation and the M2 closing beat.
- **Status:** stays `final`; `updated: 2026-11-12`.

## 2026-11-12 — Owners for deferred work

- **Mechanic ideas list** (parry, phase dash, cash in chain, pogo directions, climbing): owner is the M2 retrospective, before the Layer 2 GDD update. Out of Scope updated. The ledger's "parry: top candidate for M2" corrected to "after M2".
- **Chain-bending upgrades:** closed, absorbed by always-on Smith gear and the parked Dive Boons.
- **Death line and HUD polish:** marked as owned by E1 in the ledger.
- **UX O15 accessibility pass and O19 title logo:** added to E7.

## 2026-11-12 — Epic-planning follow-ups

Source: `planning-artifacts/epics.md` (gds-create-epics-and-stories, complete), follow-up 1.

- **E1 grows M → L** (the M1 migration plus the CP1–CP3 foundations). Updated: Epic Structure.
- **M2 estimate 44–88 weeks (about 10–20 months):** the sum of the size bands for four L epics and three M. Corrects "36–72", which predated E5's M → L. The "≈ 40–80" in `planning-artifacts/epics.md` (the sum before E1 grew) is corrected to match.
- **Playtest "no" rule changed:** a "no" blocks only the epics that build on that answer; its fix becomes the first story of the next dependent epic; independent epics proceed. **Replaces** "fix it before starting the next epic". Updated: Epic Structure, Risks, `epics.md` intro.
- **Dependencies added** to Epic Structure: E1 → every epic · E2 → E3 (the Weaver sounds and the test-arena theme) and E6 · E4 → E5, E6 · E5 → E6 · E1–E6 → E7. E3 blocks nothing before E7. Updated: `epics.md` E3.
- **Brightness ships in E1** (R1, decided by sonlm 2026-11-12; UX A1): 4 levels in the Accessibility tab, replacing the M1 F1 hotkey that E1 removes; it moves to the Video tab in E7. Fixes the earlier text that had F1 removed in E7. Updated: Options rollout, `epics.md` E1 and E7.
- **Not changed here:** UX `EXPERIENCE.md` still lists Brightness as an E7 assumption (A1). Left for the readiness check or a UX update.
- **Status:** stays `final`; `updated: 2026-11-12`.

## 2026-11-12 — Implementation-readiness decisions (Epic 1 fixes)

Source: `planning-artifacts/implementation-readiness-report-2026-11-12.md` (verdict NEEDS WORK). Recorded as R14–R16 in `planning-artifacts/epics.md`.

- **R14 Progress saves (sonlm):** besides the resume saves (station rest, hub arrival, quit at a lit anchor), the slot is saved at progress moments: a difficulty change, a purchase, a story flag, the Weaver phase checkpoint and its defeat. These never move the resume point or make carried embers safe. Updated: Platform-Specific Details → Saves; architecture Data Persistence; project-context.
- **R15 Settings as JSON (sonlm):** `user://settings.json` replaces `settings.cfg`, parsed with the silent `JSON.new().parse()`. Godot 4.7.2 prints an engine `ERROR:` on a corrupt `ConfigFile`, which fails the test runner. Architecture and project-context only; no GDD text named the file.
- **R16 E1 shaft loop (sonlm):** the rebuilt M1 shaft's bottom exit leads to its own top entry, banking the chain like a landing, so the E1 kit build can rest, deposit and redive at the placeholder station. E1 only; Layer 1 (E4) is unaffected.
- **Status:** stays `final`; `updated: 2026-11-12`.

## 2026-11-12 — Implementation-readiness decisions (Epic 2 fixes)

Recorded as R18–R20 in `planning-artifacts/epics.md`.

- **R18 Strand drop (sonlm):** a weakened strand drops only while the Weaver stands on it; slashing the second anchor otherwise does nothing. Without this, dropping all 4 strands before 9 HP was a softlock (no pogo fuel, no stun, no damage). Updated: Weaver loop table.
- **R19 Flare vs bite (sonlm):** a flare the Weaver senses cancels a bite that is in telegraph, and it flees. Updated: Weaver loop table.
- **R20 Flare size (sonlm):** the Weaver flees any burning flare (a chain-2 flare is 71 px), with no 80 px minimum; it ignores the Ember Cache. Updated: Weaver loop table; architecture Light Sensing.
- **Also fixed in the stories (no GDD change):** HP damage clamps at the 9 and 6 thresholds and ends a stun in progress; hits outside a stun deal 0 (a deflect); the bite reach is a tuned value (default 24 px).
- **Status:** stays `final`; `updated: 2026-11-12`.

## 2026-11-22 — Story 1.19 decisions (health and the damage table)

Source: `implementation-artifacts/1-19-health-4-hp-and-the-damage-table.md` (Q1, Q2, Q3; answered by sonlm at story creation).

- **Q1 Hit flash vs the flash cap (sonlm):** the white hit flash shows at most once per second; the reduce-flashing dim and the 2.5 Hz invulnerability blink are unchanged. **Why:** simulated per tick with the M1 blink, hits back to back as each 0.6 s invulnerability ends (a hunting lurker can do it) reach 4.0 flashes in some one-second window (3.5 at 40 ticks apart, 3.0 at 48); with the white flash gated to once per 60 ticks every case is ≤ 3.0. Updated: Accessibility (Flash safety). UX `EXPERIENCE.md` carries a dated note.
- **Q2 Spikes while invulnerable (sonlm):** no damage, but the player is still returned to the last safe ground, never left standing in spikes. Updated: the Health and damage table's spikes row.
- **Q3 Spike readability (sonlm):** spikes were to be drawn lit like walls for now, with E4 deciding their look with real rooms. **Revised the same day** at the laptop feel check (sonlm: "I can't even see it"; then option a): lit like walls, they were invisible outside the player's light, so they are drawn unshaded, like ledge rims. E4 still decides the final look (ledger owner E4). No GDD change.
- **Also recorded:** the bank-heal threshold is the `Tuning` key `bank_heal_min` (10). Updated: Health and damage → Healing.
- **Code review, the flash gap at a death (sonlm, 2026-11-22):** the once-per-second gap carries across a death (World hands the last white frame to the new life), and a hit inside it shows no white, a killing blow included. **Why:** per life, a lethal white and a hit just after the 0.6 s respawn were 37 ticks apart; and modelled per tick, a dim or a white added to a refused killing blow reaches 3.5 flashes/s when four spike hits land back to back, over the cap of 3. With the gap carried and the killing blow plain, every modelled case reads 3.0 or less. The death card (Story 1.29) is the killing blow's feedback. Updated: Accessibility → Flash safety; `EXPERIENCE.md`'s note.
- **Code review, holding a direction into floor-level spikes (sonlm, 2026-11-22):** left as built. Measured: the player is held at the spike edge and loses 1 HP every 0.6 s, dead in 2.1 s. No real room has a spike until E4, where the return rule is decided with real rooms (ledger owner E4). No GDD change.
- **Code review, the hunting-lurker row (sonlm, 2026-11-22):** the row now says a lurker hit knocks back, gives 0.6 s of invulnerability and breaks the chain, as crawler contact does. The code already did this (`Player.hurt()` is one path for every source); the row had left it unsaid. Updated: Health and damage table.
- **Status:** stays `final`; `updated: 2026-11-22`.

## 2026-11-22 — Story 1.20 decisions (light sensing for predators)

Source: `implementation-artifacts/1-20-light-sensing-for-predators.md` (Q1, Q2, Q3; answered by sonlm at story creation, all three recommended options).

- **Q1 Where a lurker senses you once it has noticed you (sonlm, (b)):** the telegraph needs the lurker on screen on every tick (the whole warning is seen); the hunt needs only light and distance (the GDD's Hunt line had no screen test). For a lone player light the one change from M1 is a hunter that trails out of view: it keeps hunting while in reach (at most 138 × 1.6 ≈ 221 px) instead of giving up at the screen edge. Landing, Snuff and cling still save you. Updated: Predators: Lurker (Telegraph, Hunt).
- **Q2 Re-brightening inside the 0.6 s wait (sonlm, (a)):** the hunt resumes at once with no new telegraph, as M1 built it. Updated: Predators: Lurker (Hunt).
- **Q3 The stir step (sonlm, (a)):** half-open at once, open after 0.35 s, and one step per 0.35 s either way (≤ 2.9 changes a second, under the 3 flashes/s cap), reviewed at the CP2 gate (1.30). Updated: Predators: Lurker (Stirs).
- **Also recorded (calls made at story creation, sonlm may veto):** the 8 px screen-margin band stirs (no silent gap between noticing and stirring); stirring runs while a lurker returns home as well as at rest; a telegraph switching between two decoys keeps its timer (only a switch onto the player restarts it). No GDD change until sonlm confirms them. (Confirmed 2026-11-25: see the next entry.)
- **Status:** stays `final`; `updated: 2026-11-22`.

## 2026-11-25 — Story 1.20 code review decisions

Source: `implementation-artifacts/1-20-light-sensing-for-predators.md` (Review Findings; both answered by sonlm at the review, the recommended option each time).

- **The three calls made at story creation (sonlm: confirm all three):** the 8 px strip inside the play-area edge stirs; a lurker on its way home stirs like one at rest; a telegraph switching between two decoys keeps its timer. Updated: Predators: Lurker (Stirs, Retargeting).
- **A lurker hunting a decoy off screen when the player's light becomes the brighter (sonlm, (a)):** it stays on the decoy. It switches to the player only once it is on screen and can telegraph, so a flare keeps working however long the chain gets, and no telegraph ever runs where it can't be seen. As first built it entered the telegraph for one unseen tick and went home. Updated: Predators: Lurker (Retargeting).
- **Also fixed at the review, no rule change:** a hunt that follows a retarget telegraph starts from rest, as every hunt did in M1 (it kept the old hunt's 95 px/s).
- **Status:** stays `final`; `updated: 2026-11-25`.

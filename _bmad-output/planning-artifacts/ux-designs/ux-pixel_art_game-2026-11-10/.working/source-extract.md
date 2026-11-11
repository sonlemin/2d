# Source Extract for UX: The Unbroken Chain

Extraction only, no design. Precedence: **M1 findings > GDD v1.0 (final) > brief/addendum**. Abbreviations:
GDD = `gdds/gdd-pixel_art_game-2026-11-10/gdd.md`; EP = `.../epics.md`; DL = `.../decision-log.md`;
F = `implementation-artifacts/m1-playtest-findings.md`; B = `briefs/brief-pixel_art_game-2026-11-08/brief.md`;
AD = `.../addendum.md`; R = `research/domain-indie-pixel-art-pogo-descent-platformer-research-2026-11-07.md`;
CODE = `game/` (M1 prototype).

## 1. Foundation facts

- **Genre:** 2D descent Metroidvania, action-platformer feel; "*not a roguelike*" (GDD Exec Summary; Win/Loss). Never market as "roguelike" or "Downwell-like" (GDD USPs).
- **Platforms:** PC Windows + Linux; web/itch.io for playtests. Steam vs itch.io decided with M2 build in E7 (GDD frontmatter; Platform-Specific Details; EP E7).
- **Steam Deck:** test pass in E7. "At ×2 integer scaling (960×540, letterboxed) the HUD and text must be readable." "Verified" is the goal if Steam is chosen (GDD Platform-Specific Details; EP E7 "×2 scaling, HUD readability, battery"). R: "Target 'Verified' from day one", "readable UI at 800p" (R Platform-Specific Technology table).
- **Native resolution:** 480×270; 1 tile = 16 px; 1 screen = 30×17 tiles (GDD Primary Mechanics; Layer 1).
- **Scaling:** integer only (×2, ×3, ×4), nearest filtering, letterboxed (GDD Platform-Specific Details). Perf target measured at ×3 = 1440×810 (GDD Performance).
- **CODE project.godot:** viewport 480×270, window override 1440×810, stretch mode `viewport`, scale_mode `integer`, default texture filter nearest (0), `snap_2d_transforms_to_pixel=true`, renderer GL Compatibility.
- **Engine:** Godot 4.7, GDScript only, Compatibility renderer so web works (GDD Platform-Specific Details).
- **Input devices:** keyboard and gamepad, both from M2; default gamepad mapping ships in E1 (GDD Controls; DL Finalize batch 1; EP E1 story 10b). Rebinding in M2 settings (GDD Controls); listed under E7 settings (EP E7).
- **Perf/web:** 60 FPS on Intel HD 620-class; web <30 MB, pauses when tab loses focus; load hub→station <2 s (GDD Performance).
- **Saves:** auto at every Lift Station rest, on the hub, and when quitting at a lit lantern anchor; one profile in M2 (GDD Platform-Specific Details).
- **Sessions:** 20–45 min; first Layer 1 descent 45–60 min, so quit-at-anchor saves position (GDD Target Audience; Layer 1).
- **Audience:** adults who finished *Hollow Knight* or *Celeste*; secondary *Downwell*/*Celeste* precision fans (GDD Target Audience).

## 2. Pillars and tone/brand words

- **Core fantasy (verbatim):** "*Burn bright to dive deeper than anyone has, knowing that every flash of skill draws the abyss closer.*" (GDD Core Concept)
- **Target feeling:** "*Daring mastery*: 'I pushed my luck, kept the chain alive, and got away with it.'" Discovery is "the reward for daring, not the reason to play." (GDD Core Concept)
- **Pillars (priority order, GDD Game Pillars):**
  1. **Chain = Light = Danger.** "stronger, brighter, richer and hunted." "*This pillar survives any cut.*"
  2. **Every death teaches.** "Failure is fair and readable. Predators always telegraph (a sound, eyes in the dark, a glow at the screen edge)." "Darkness creates tension, not confusion." Ruling: beats off-screen ambushes.
  3. **Knowledge is power.** Fixed hand-built world, skills not XP; key gates/shortcuts open only with a long chain.
  4. **Few buttons, deep play.** "Movement plus 4 buttons (Attack, Jump, Dash, Light)... new abilities reuse the same buttons."
- **Loop slogan:** "*burn bright → cash out → hide → burn again*" (GDD Core Loop). Brief's older version: "Burn bright → land → hide → burn again" (B Core Loop).
- **Tone:** "wonder, melancholy, danger at the edge of the light"; premise "you aren't discovering the abyss; you're **coming home to it**" (GDD Narrative and Tone). Creatures "hungry, not hateful" (GDD Narrative).
- **USP lines:** "Your skill is the light source." "Depth ≠ darkness." "the chain-light is the one colour that never changes." (GDD USPs)
- **Audio brand:** "organic world, synthetic light" (GDD Audio and Music).
- **Base rule:** "the ground is a sanctuary" (GDD Interconnected World Map).

## 3. Art direction & palette

- Sprites 16–24 px; bosses from segments; 4 colours per palette zone + 2 reserved colours; sprites are text pixel grids → Python/Pillow → PNG (GDD Art Style; Asset Requirements). Brief said 4–6 colours per layer (B Content & Direction) — GDD narrows to 4 + 2.
- **Reserved colours (GDD Art Style):**
  - Chain-light amber `#ffd27a` = "*you*: light, embers, the flare, chain popups" — "never used for anything else".
  - Predator red `#d9473f` = "lurker eyes, telegraphs, the alert HUD" — "never used for anything else".
- **Colour-blind safety:** every telegraph also has shape + motion cue and a sound; "Colour is never the only signal." (GDD Art Style)
- **Layer 1 palette shift ("daylight fades as you descend"):** S1/A dusk `#2b1d14 #6b4a2f #b08a5a #d8c3a0`; S2–S3 umber `#1e1714 #4a3a33 #7d6a5c #a99a8c`; S4–S5/B/C cold violet (M1) `#0d0b14 #2a2440 #4f5d75 #a9b4c2`. Layer 2 landing "cool silver-blue" [ASSUMPTION]; hub "bright, warm, low contrast" [ASSUMPTION] (GDD Art Style). Hub: "Daylight and a warm palette set it against the dark below" (GDD Hub).
- **Readability rules (from M1):** ledge rims glow faintly; predators and light effects ignore darkness; "the player never loses track of themselves" (GDD Art Style; F item 7).
- **Light:** Chain-Light radius = 40 + 22·√links px (40/84/110/138 at 0/4/10/20); Snuff → 12 px; cling → 40 px (GDD Attack, pogo and chain). PointLight2D + CanvasModulate; HDR bloom within flash limits (AD Art pipeline notes); bloom under Compatibility renderer is an open question (GDD Open Questions).
- Flare fades smoothly over last 1.0 s, "with no flashing" (GDD Flare Toss). Chain gate "glows the required number" (GDD Ability-Gating). Weakened strand = frayed sprite + sag (GDD Weaver). Re-Weave: "silk threads glow along the new paths" (GDD Weaver). Silk anchors "visible at base light" (GDD Swing).
- Creature deaths dissolve into sparks, never blood (GDD Feel rules).
- **CODE:** spark/popup amber `Color(1,0.82,0.48)`; HUD amber `Color(1,0.8235,0.4784)`; alert `Color(1,0.35,0.3)` (≠ `#d9473f` exactly); ledge rim `Color(0.66,0.71,0.76,0.45)`; popup outline `Color(0.05,0.04,0.08)`; ambient tint keeps violet cast; 4 ambient levels `[0.07,0.16,0.28,0.45]` (scripts/shaft.gd, fx.gd).
- Brainstorm's 12×12 "Tiny Explorer" replaced by 16–24 px for readability (AD Art pipeline notes).

## 4. Controls & input

- **Final keyboard (GDD Controls and Input table):**
  - Move = Arrow keys. ↓ drops off a wall. **↓ on the ground (standing still): interact** (rest at station, talk, read). ↑ stays Jump (GDD Lift Station).
  - Jump = Z or ↑; hold for full height; at a wall while falling, hold = **cling**, release = **kick off** (150 away, −260 up), no steering 0.15 s.
  - Attack = X; ground = slash; **air = pogo (any direction held)**.
  - Dash = C; air dash; within 56 px of a silk anchor = grab rope (post-Weaver); hold = swing; release = launch ×1.1. No hold threshold, so dashes have no delay (DL batch 1).
  - Light = V; **tap (<0.12 s) = Flare Toss** (needs ≥2 links, costs half rounded up); **hold ≥0.12 s = Snuff** (light 12 px while held, breaks chain, banks).
- **Default gamepad (GDD Controls):** left stick/d-pad move, A jump, X attack, RB dash, B light (tap Flare Toss / hold Snuff), Start pause.
- "Every action is a single button (no chords)." (GDD Controls; Platform-Specific Details)
- Rebinding: every action rebindable in M2 settings (GDD Controls; EP E7 Settings).
- Smith gear changes input timings: Quick Wick Snuff hold 0.12 → 0.08 s (GDD Hub).
- **CODE input map (M1):** move_* arrows; jump Z + ↑; attack X; dash C; light V; keyboard only, no gamepad events yet. Debug keys F1 brightness cycle, F2 hide controls bar, F3 restart from top (scripts/shaft.gd).
- **Superseded:** brief's "Down + Attack = pogo" (AD Controls) → any air Attack pogoes ("clunky", F item 3). Brief's "keyboard first, controller later" (B Scope; AD Controls) → gamepad in M2/E1 (DL batch 1). Snuff tap misfired because V sits next to C → 0.12 s hold (F item 4).

## 5. HUD elements & information required

- **E1 HUD v2:** "HP, held and carried embers" (EP E1 In; story 9). E7: "HUD polish" (EP E7).
- **HP:** 4 HP max (masks out of scope M2); invuln 0.6 s blinking at 2.5 Hz (GDD Health and damage).
- **Embers, three stages:** held (lost on death) → carried (dropped as Ember Cache, recoverable once) → deposited (safe forever) (GDD Economy). Deposited total presumably needed for shops (implied by hub, not stated as HUD item).
- **Chain:** count up to 20 (hits pay past cap); chain popups are amber (GDD Art Style). M1 deferred list: "styled chain counter, light meter" (deferred-work.md "HUD polish").
- **Alert:** "the HUD turns red" during lurker telegraph (GDD Predators: Lurker; F item 7). Alert HUD uses predator red (GDD Art Style).
- **Off-screen stirring:** "faint red glow at that screen edge" + panned sound; edge glow in E1, sound in E3 (GDD Lurker; EP E1 10c).
- **Cling grace** (1 s per chain, refilled by pogo) and **Flare** burn time (4 s) are timed states; no HUD representation stated.
- **Field Journal death line:** "one line on death naming what killed you and how to avoid it" (EP E1 story 11).
- Chain gate shows required count as glow on the door (diegetic) and rising tone (GDD Ability-Gating; Audio).
- No stated HUD fade/diegetic rule beyond the above. Steam Deck ×2 readability constraint applies (GDD Platform).
- **CODE M1 HUD:** one 8 px amber Label at top (4,2): `embers N (held +N) chain N (best N) light N [SNUFF] depth N alert N deaths N`; turns red while any lurker not idle. Controls bar: 8 px grey Label at bottom y=256, full key legend (commit 0e197ca "controls bar fits 480 px again"). Chain popup on bank: `xN +E`, size 8 (<5 links) or 10 px, rises and fades 0.6 s (fx.gd). Default Godot font; no custom font.

## 6. Menus/screens mentioned (by epic)

- **E1:** Placeholder Lift Station rest; save/load; HUD v2; reduce-flashing toggle (implies a settings entry); Field Journal death line; difficulty tiers Easy/Normal/Hard (implies selection UI, not specified) (EP E1).
- **E2:** "a debug entry straight into the Weaver test arena" (EP E2).
- **E3:** "Settings: volume sliders" (EP E3).
- **E4:** Map screen (EP E4 story 8): fills by visited screens; Cartographer map reveals unvisited screens, gates, secret markers; stations and lit anchors always shown; shows per-layer count of each reward type found, no overall % (GDD Map; Exploration Rewards). Journal objects read via ↓ (GDD Lift Station). Final Lift Station (E4).
- **Lift Station rest:** heals, deposits, "opens the fast-travel menu (hub and repaired stations)", respawns enemies (GDD Lift Station).
- **E5 Hub:** NPC dialogue and shop framework (EP E5 story 2); Cartographer (map 60, hints 25), Smith (3 gear), Naturalist (journal payout 10/entry, 2 palettes), Guild records board (deepest depth, best chain, most embers banked in one chain, deaths) + Memorial Wall names; fast travel; The Watching Departure (lift-up cutscene moment) (GDD Hub; EP E5).
- **E6:** Weaver Silk unlock (Swing); post-boss flow back to hub; phase checkpoint (EP E6).
- **E7:** Settings menu (rebinding, screen shake on/off, 4 brightness levels, volume); full Field Journal (lore entries + death-line history) (EP E7).
- **Pause:** Start = pause (GDD Controls); no pause menu content specified.
- **Not mentioned anywhere:** title/main menu, death screen beyond journal line, credits, save-slot UI (one profile), quit-to-menu flow, difficulty picker placement, AI-disclosure screen.
- Death flow: respawn at last lit anchor/station (deeper one), full HP; Weaver death → station before arena, phase 2 resumes in phase 2 (GDD Respawn; Weaver Death). M1 CODE: 0.6 s delay then scene reload.

## 7. Feedback / game feel / juice

- Hitstop 75 ms on every pogo hit; no input dropped during it (GDD Attack; Performance).
- "Freeze frames and sparks on every pogo hit." Slow-mo only at boss climaxes: The Fall begins 0.5 s at ×0.3; same at Weaver defeat. Screen shake can be turned off (GDD Feel rules).
- Pogo feel "Not yet great; revisit with audio" (F Verdict).
- Camera leads 70 px downward while falling (GDD Movement; F item 7).
- Lurker telegraph 0.9 s (min 0.75 s): eyes open with animation, pulse at 2 Hz, cast red light on wall, HUD red; "eyes bigger and glowed" made them read (GDD Lurker; F Verdict). Hunt hiss follows position (GDD Audio).
- **Chain-reactive music:** pulse at 3, melody at 6, full theme at 10 links (0.5 s fade in); bank resolves on chord within 0.3 s; death cuts with muffled dissonant tail (GDD Audio).
- **SFX:** pogo soft synth +1 semitone/link up to +12; bank chime longer with amount; lurker growl panned, always above music (6 dB duck); Snuff "light blown out, then muffled silence"; cling creak; flare whoosh + sizzle; Weaver twang/hiss; chain gate tone rising to required count → chord, or dull thud (GDD Key sound effects). Predator cues highest mix priority; no clipping during hitstop (GDD Production).
- Weaver bite telegraph: legs rear up, eyes glow (GDD Weaver).
- **CODE:** camera kick 2.5 px on pogo, decays; sprite squash recovers; spark burst on crawler death; chain popup (player.gd, fx.gd).
- Brief: "Music and a rising pitch that build with the chain, so a long chain *sounds* dangerous"; "Each predator has a distinct sound cue" (B Content & Direction).

## 8. Accessibility

- **Flash cap:** ≤3 flashes/s anywhere; checked for every new effect; from E1/"day one" (GDD Platform; Risks; EP E1; B Scope). CODE: invuln blink 2.5 Hz and lurker eye pulse 2 Hz chosen to stay under cap.
- **Reduce flashing** toggle ships in E1 (EP E1; DL Finalize).
- **Screen shake** toggle; **brightness 4 levels** (F1 cycles in M1) (GDD Controls; Platform).
- **Rebinding** all actions (GDD Controls). Single-button actions, no chords (GDD Controls).
- **Colour never the only signal** (GDD Art Style).
- **Volume sliders** (EP E3).
- **Difficulty:** Easy/Normal/Hard change only death cost, never damage/telegraph/chain rules (GDD Difficulty settings).
- **Assist options for Easy** ("the brief takes Celeste's assists") — open, decide E7 (GDD Open Questions; B References).
- Research: photosensitivity is medium risk; possible GPSR coverage; EU Accessibility Act exempts microenterprise (R Regulatory Requirements).

## 9. Named player journeys / personas

- No formal personas. Segments: "Metroidvania regulars" (primary), precision-platformer / arcade-descent fans (secondary) (GDD Target Audience; B Target Players).
- Named loops/journeys: "*burn bright → cash out → hide → burn again*" (moment); "leave a Lift Station → push into the layer → find routes, secrets and chain gates → reach the next Lift Station, or die and learn → return to the hub to spend your haul" (session) (GDD Core Loop). E5 "dive → home → spend" (EP E5). Backtracking after Weaver for 3 Swing secrets (GDD Backtracking).
- Named moments: **The Watching Departure**, **The Fall**, **The Re-Weave**, **The Last Entry** (S4 set-piece), **The Final Chain** (ending), **The Anchor** (respawn lore) (GDD). Peak moments (later layers): The Speck, Riding the Giant, Felling the Canopy, The Curious Companion (AD World).
- Layer 1 segments: S1 The Lip, S2 Scaffold Drop, S3 The Lantern Door, S4 Explorers' Grave, S5 Weaver's Hollow; side areas A Rope Works, B Old Mine, C Sky Ledge (GDD Layer 1).
- Teaching rule: "teach safe → test committed"; new move with safe exit in view, tested 2–4 screens later (GDD Difficulty Curve).
- Success metric: testers can name what killed them ≥80% of deaths; use Flare Toss and cling unprompted after S2 (GDD Success Metrics).

## 10. Inspiration references & anti-patterns

- **Take/leave (B References):** *Downwell* — chain until you land, vertical descent / leave procedural, arcade runs, label. *Hollow Knight* — interconnected world, pogo, earned map, currency drop & recovery / leave charm builds, deep combat, large cast. *Spelunky* — systemic danger, deaths that tell a story / leave procgen, permadeath. *Celeste* — few buttons, fair instant failure, assist options / leave room puzzles, collectibles as goal.
- Prior art "light attracts monsters": *Last Light*, *Oshi*, *In The Shadows* (GDD USPs). *Last Light* lesson: a light toggle on top of platforming felt overwhelming (R Differentiation; GDD Snuff rationale).
- Research comps: *Well Dweller*, *MIO*, *GRIME II*, *Constance*, *Rusted Moss*, *Moonbrella*, *Pseudoregalia*, *Haiku the Robot* (R Competitive Landscape).
- **Anti-patterns stated:** off-screen ambushes (Pillar 2 ruling); darkness causing confusion (Pillar 2); colour-only signals (Art); >3 flashes/s; blood (Feel rules); XP/procgen (Pillar 3); chords/new buttons (Pillar 4); light as a toggle you leave on (Snuff rationale); "roguelike"/"Downwell-like" positioning; slots/charms for gear ("always on; no slots or charms", GDD Hub); overall completion % in M2 (GDD Exploration Rewards); unscoped web demos (R).
- Research UX asks: show the hub, map and journal within first 5 min to avoid "Downwell clone" label (GDD Risks; R Synthesis §6); "chain + glow + predators swarming" is the clip moment (R Ecosystem); "Design for the controller first, then map to keyboard" (R Controller expectations).

## 11. Contradictions & open questions (UX-relevant)

- **Pogo input:** AD "Down + Attack" vs F/GDD "any air Attack" → findings win.
- **Controller timing:** B/AD "controller later" vs GDD/DL gamepad in E1; R says controller-first design. Rebinding: GDD Controls "M2 settings menu" vs EP places Settings menu in E7 (reduce-flashing toggle in E1, volume in E3) — where settings UI first appears is unresolved.
- **Death cost wording:** B "Easy: Nothing; Hard: everything you were carrying" + "respawn at the last Lift Station" vs GDD three-stage tiers and respawn at lantern anchor or station → GDD wins.
- **Cling:** AD "~1 s pause", silent on light → F/GDD light drops to base 40 px, 1 s per chain.
- **Palette count:** B "4–6 colours per layer" vs GDD "4 + 2 reserved".
- **Haul/currency/relic:** brief terms replaced by "embers"; Ember Hoard (world) vs Ember Cache (death drop) naming (DL Finalize).
- **Interact:** user chose "↑ to rest" but ↑ = Jump → ↓ on ground (DL Hub). Edge case: ↓ also drops off walls; interact requires standing still on ground.
- **Light tap vs hold:** watch whether tap/hold mid-chain feels overwhelming (GDD Snuff rationale, E1). Snuff may gain a cost (GDD Risks) — would change what HUD must show.
- **Alert colour:** CODE uses `(1,0.35,0.3)` ≈ `#ff594d`, not GDD `#d9473f`.
- **Field Journal:** brief M1 scope had a death line; never built (deferred-work.md) → E1. Full journal in E7. B: "the death is written into the Field Journal" in every tier.
- **Open (GDD Open Questions):** assist options for Easy (E7); hub & Layer 2 palettes (E5/E6); bloom under Compatibility renderer; bank-heal threshold (+1 HP at chain ≥10) [ASSUMPTION]; glowing Ember Cache drawing lurkers (designer note); phase-2 respawn point (E6); side-area exits (E4).
- **Unspecified UX surfaces:** title/main menu, pause menu contents, difficulty selection timing and whether changeable, death screen, fast-travel menu layout, shop UI, dialogue presentation, map controls/legend, journal UI, AI-disclosure placement, how to surface cling grace / flare timer / Flare Toss eligibility (≥2 links), deposited-ember display, Guild record board presentation, text size floor for ×2 Deck, font choice (M1 uses default font at 8 px), localisation (never mentioned).

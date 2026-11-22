---
title: "The Unbroken Chain — EXPERIENCE"
status: final
created: 2026-11-10
updated: 2026-11-12
sources:
  - ../../gdds/gdd-pixel_art_game-2026-11-10/gdd.md
  - ../../gdds/gdd-pixel_art_game-2026-11-10/epics.md
  - ../../gdds/gdd-pixel_art_game-2026-11-10/decision-log.md
  - ../../../implementation-artifacts/m1-playtest-findings.md
  - ../../briefs/brief-pixel_art_game-2026-11-08/brief.md
  - ../../briefs/brief-pixel_art_game-2026-11-08/addendum.md
  - ../../research/domain-indie-pixel-art-pogo-descent-platformer-research-2026-11-07.md
---

# EXPERIENCE.md — The Unbroken Chain

This file owns how the UI behaves and what it says. DESIGN.md owns how it looks; tokens are referenced as `{path.to.token}`. The GDD owns mechanics and numbers; this file cites them.

**The spines win.** If any mock disagrees with this file or DESIGN.md, the spines are the contract. DESIGN.md lists the key-screen and exploration mocks; rows below link the relevant key mock.

## Foundation

| Item | Decision |
|---|---|
| Form factor | PC (Windows, Linux) and a web build on itch.io. Steam Deck pass in E7; Deck-size legibility check in E1. |
| Input | Keyboard first. Gamepad fully supported: every screen and prompt works on both. |
| Engine | Godot 4.7, GL Compatibility renderer (GDD Platform-Specific Details). |
| Canvas | Native `{spacing.native-width}` × `{spacing.native-height}`, whole-number scaling, letterboxed. |
| HUD posture | Always visible, compact, non-diegetic, in the side gutters. Never fades. |
| Visual identity | DESIGN.md |

## Information Architecture

### Screen map

```
[Click to play] (web only)
      ↓
    Title ── Continue ─────────────→ Play (most recent slot)
      ├── New Game → Slot picker → Difficulty step → Play
      ├── Load → Slot picker → Play
      ├── Options (5 tabs) → Credits
      └── Quit (PC only) [ASSUMPTION]

Play ── Start/pause → Pause [Pause | Map | Journal]
   │                    └── Pause tab: Resume / Options / Quit (→ Title)
   ├── ↓ at Lift Station → Rest → Station menu: Descend / Fast travel / Leave
   ├── ↓ at NPC (hub) → Speech box → Shop list
   ├── Gamepad lost → Pause ("Controller disconnected")
   └── Death → Death card → Respawn
```

| Surface | Reached from | Contents |
|---|---|---|
| Click-to-play gate | Web page load | One prompt; gives focus and unlocks audio. Below ×2 it also suggests fullscreen. |
| Title | Boot | Logo over a slowly scrolling live shaft. Continue / New Game / Load / Options / Quit |
| Slot picker | New Game, Load | 3 slots: depth, best chain, play time, difficulty |
| Difficulty step | New Game, after the slot | Easy / Normal / Hard. Says that it changes only death cost and can be changed later in Options |
| Play | Title | Gutter HUD + play area |
| Pause | Start / pause key, focus loss, gamepad disconnect | Tabs Pause / Map / Journal; Map and Journal stay hidden until they land (E4, E5) |
| Pause tab | Pause | Resume / Options / Quit; bank summary (deposited, carried, held, depth, best chain); controls reference with current bindings |
| Map tab | Pause | Room-box map, see Component Patterns |
| Journal tab | Pause | E5: creature entries with "new" marks. E7: death log by cause, lore notes + Memorial Wall names, Guild records |
| Options | Title, Pause tab | 5 tabs: Game / Video / Audio / Controls / Accessibility; Credits entry |
| Station menu | ↓ at a Lift Station, after rest | Descend / Fast travel / Leave |
| Speech box + shop list | ↓ at an NPC | Name tag, one line at a time; shop list with deposited total and prices |
| Death card | HP reaches 0 | Death line (cause + how to avoid) and the tier's ember result |
| Credits | Options | Credits and the AI disclosure line |

Landing epics are in Epic Rollout.

Navigation (log 2026-11-11): Pause replaces the view and never stacks. Options opens from Pause and returns to it. Quit in the Pause tab returns to the title. Continue loads the most recent slot; Load opens the slot picker.

Quit in the Pause tab uses the confirm step: "Quit to title?" No / Yes, with No selected. Away from a lit anchor or station it adds a line: "You will wake at the last rest." Quit on the title has no confirm. [ASSUMPTION — default, review]

### Options tabs

| Tab | Settings | Lands |
|---|---|---|
| Game | Difficulty (changeable any time) | E1 |
| Accessibility | Reduce flashing; screen shake on/off; reduced motion; Light tap window (0.12 / 0.2 / 0.3 s); Cling toggle; Snuff toggle (hold→press, both Off by default; decided 2026-11-11, O13); Brightness (4 levels; decided 2026-11-12, A1) | E1 (tap window [ASSUMPTION] E1, since Flare Toss lands there; the toggles land in E1 so public web builds are playable before E7) |
| Audio | Volume sliders | E3 |
| Video | Brightness (moves here from Accessibility), fullscreen, scale | E7 |
| Controls | Rebinding | E7 |
| Accessibility (E7 additions) | Large HUD; text scale; game-speed and timing assists; visual sound cues | E7 |

Tabs that have not landed are hidden. [ASSUMPTION] Hidden, not shown disabled. The Pause tabs follow the same rule: in E1 the tab bar holds Pause alone; Map appears in E4 and Journal in E5 (log 2026-11-11).

## HUD & Diegetic UI

The [HUD mock](mockups/key-hud.html) draws these states.

| Element | Where | Shows | Diegetic? |
|---|---|---|---|
| Gutter icon | Both gutters, top | Heart, ember, chain link in place of text labels | No |
| HP pip | Left gutter | 4 HP; empty pips are outlines | No |
| Ember counter | Left gutter | Held `+N` (flickering icon), carried count (solid icon) | No |
| Chain number | Right gutter | Links, large | No |
| Chain meter | Right gutter | 20 segments to the cap | No |
| Cling grace bar | Right gutter, beside the meter | Cling grace left | No |
| Flare notch | Right gutter, segment 2 | Flare Toss ready at ≥2 links | No |
| Flare cost hatch | Chain meter, top half of the lit stack | What a toss would cost, while a lurker stirs or hunts | No |
| Alert frame + alert eye | Both gutters; eye in the right gutter | Lurker telegraph in progress | No |
| Cling cue | By the player | Cling grace while clinging | Semi (follows player) |
| Off-screen edge cue | Play-area edge, level with the lurker | Half-open eye that opens as it stirs + red glow on the lurker's side (GDD Lurker) | No |
| Flare burn | World | The flare dims over its 4 s | Yes |
| Chain gate count | World | Glow and rising tone (GDD Ability-Gating) | Yes |
| Weaver health | World | Segments fray and fall off, threads sag (GDD weakened-strand visuals). No bar. | Yes |
| Glyph prompt | Above the object | Key/button to interact | Semi |
| Autosave icon | Left gutter, bottom [ASSUMPTION — default, review] | Saving; crossed when a save fails | No |

Hierarchy: chain number first, then HP, then embers. Deposited embers never show on the dive HUD. They show at Lift Stations, in shops and in the Pause tab bank summary.

The M1 bottom controls bar is removed; the controls reference moves into the Pause tab. Nothing hides during play. [OPEN] Whether gutters stay during cutscene moments (The Watching Departure, The Fall).

## Input Schemes

### Gameplay bindings (defaults, GDD Controls and Input)

| Action | Keyboard | Gamepad | Notes |
|---|---|---|---|
| Move | Arrow keys | Left stick / d-pad | ↓ drops off a wall |
| Interact | ↓ on the ground, standing still | Same | Rest, talk, read |
| Jump | Z or ↑ | A | Hold for height; hold at a wall while falling = cling |
| Attack | X | X | Air attack = pogo, any direction |
| Dash | C | RB | Near a silk anchor = grab rope (post-Weaver) |
| Light | V | B | Tap = Flare Toss; hold past the tap window = Snuff |
| Pause | Esc or P | Start | P is the web fallback, since Esc can leave browser fullscreen (log 2026-11-11) |

Every action is a single button, with no chords (GDD Controls).

### Menu bindings

[ASSUMPTION — default, review] Matches the menu mock footer ("Z select, X back, Arrows move").

| Action | Keyboard | Gamepad |
|---|---|---|
| Move selection | Arrow keys | D-pad or left stick |
| Confirm | Z, Enter or Space | A |
| Back | X, Backspace or Esc | B |
| Switch tab | Q / E | LB / RB |
| Change value (slider, choice) | ← / → | D-pad or stick left / right |
| Close pause | Esc, P or back on the Pause tab | Start, or B on the Pause tab |

- Repeat: holding a direction moves once, then repeats after 400 ms every 80 ms. Sliders use the same repeat, one segment per step.
- Wrap: vertical lists and the tab bar wrap end to end. Sliders and choice lists stop at their ends.
- Stick in menus: a move fires at 0.5 tilt. The stick must return below 0.3 before the next non-repeat move.

### Rules

| Rule | Decision |
|---|---|
| Rebinding | Every action, keyboard and gamepad, in Options > Controls (E7) |
| Hold↔toggle | Cling toggle and Snuff toggle in Options > Accessibility (E1, decided 2026-11-11, O13). Cling toggle turns the hold into a press. Snuff toggle: when On, Light only throws Flare Tosses (any press, no tap window) and Snuff moves to its own key (default Shift; pad LB), pressed once to start and again to end. Snuff still ends the chain, so this is not a light you leave on. Quick Wick has no extra effect in this mode. Full rebinding stays in E7. |
| Light tap window | 0.12 s (GDD default), 0.2 s or 0.3 s, in Options > Accessibility. Releasing Light inside the window is Flare Toss; holding past it is Snuff. |
| Quick Wick | Changes the Snuff response, not the tap window ([NOTE FOR GDD]). |
| Glyph swap | Prompts and the controls reference show the last-used device's glyphs. Any button press, or a stick or trigger past 0.5, switches to gamepad; any key press switches to keyboard. Stick input below 0.5 and mouse movement never flip glyphs. [ASSUMPTION — default, review] |
| Gamepad disconnect | See State Patterns. |
| Web keys | Arrows, Space and F-keys never scroll or act on the page |
| Debug keys | The M1 F1 brightness key moves into Options. [ASSUMPTION] F2/F3 debug keys are removed from player builds. |

## Voice and Tone

Terse field notes: short, factual, slightly ominous. The world speaks like an explorer's notebook. It never sounds like a tutorial.

| Context | Example | Not |
|---|---|---|
| Journal creature line | "Lurker. Waits where the light is dim." | "Lurkers are dangerous enemies!" |
| Death line | "Lurker. It waits where the light is dim. Watch the edge for an opening eye." | "You died. Try again?" |
| Death card tier line | Normal "Embers left below. Once." Hard "Nothing left below." Easy: no line (log 2026-11-11) | "You lost 40 embers!" |
| Cache lost | [ASSUMPTION] "The cache went dark." | "Ember Cache lost (-40)" |
| Gamepad lost | "Controller disconnected" (log) | Error codes |
| Difficulty step | States only what death costs on each tier, and that it can be changed later | Words like "casual" or "hardcore" [ASSUMPTION] |
| Menu labels | One or two words: Resume, Options, Load, Quit, Descend | Sentences |

**Copy rule** (decided 2026-11-11, O16): death lines, tips and cues name the shape (eye, glow, frame), never the colour. For example: "Watch the edge for an opening eye." This keeps copy true for colour-blind players and under any palette.

All strings live in a string table from day one. M2 ships English only.

## Component Patterns

Behaviour and copy only. DESIGN.md Components gives the visual spec under the same names. Game Feel & Juice owns event animations (pops, fly-ins, cracks).

| Component | Behaviour |
|---|---|
| Gutter | Always present, in every scene including the hub and the Weaver arena. Tint follows the active palette zone and cross-fades at a zone boundary (Game Feel & Juice). |
| Gutter icon | Static. Icons replace text labels, so the gutters carry no localised text. |
| HP pip | Updates on hit and heal. A lost pip becomes an outline. Invulnerability blink per Game Feel & Juice. |
| Ember counter | Held counts up with hits; its icon flickers while held embers exist. On bank, held moves to carried. On rest, carried flies to the bank. |
| Chain number | Counts links. Size steps per Game Feel & Juice. Shows 0 in the empty colour. |
| Chain meter | Fills one segment per link up to 20. During cling the links stay lit. On chain break, segments fall away and dim. |
| Cling grace bar | Appears full when a cling starts and drains over the cling grace (GDD: 1.0 s per link). A pogo hit refills it. When it empties, the chain breaks and banks (GDD cling timeout). Hidden when not clinging. |
| Flare notch | Static mark at segment `{components.flare-notch.segment}`. Once the meter reaches it, Flare Toss is allowed. |
| Flare cost hatch | Hatches the lit segments a toss would take. Shows only while a lurker is stirring or hunting and the chain is ≥ 2; hides at once when either stops being true (log 2026-11-11). A "show while V held" variant was dropped, since holding V is Snuff. |
| Alert frame | Shows on both gutters while a lurker telegraph runs, pulsing at 2 Hz or slower. Pips, numbers and meter keep their colours. |
| Alert eye | Shows and hides with the alert frame. |
| Cling cue | Appears full by the player while clinging, drains top-down in step with the grace bar, refills on a pogo hit, and hides when the cling ends. [ASSUMPTION — default, review] |
| Off-screen edge cue | Shows on the side where a lurker stirs (GDD Lurker), level with it and tracking its height. The eye opens wider as it stirs: closed, half, open (log 2026-11-11). [ASSUMPTION] The glow pulses at 2 Hz, matching the lurker eye pulse. The glow never drops below its floor (DESIGN Colors). |
| Glyph prompt | Appears above an interactable when the player is in range and hides out of range, at once, with no bob. Stays clamped inside the play area. The glyph follows the last-used device. [ASSUMPTION — default, review] |
| Speech box | Opens on ↓ at an NPC. One line at a time; confirm advances. [OPEN] Typewriter reveal or instant; skip rules; line length. |
| Shop list | Shows the deposited total and prices, with menu items and the ember cursor. [OPEN] Buy confirm and "can't afford" behaviour. |
| Menu item | Up/down moves the selection. |
| Ember cursor | Follows the selection with a 120 ms ease; jumps when reduced motion is on. |
| Tab | Pause / Map / Journal and the 5 Options tabs. Switch with Q / E or LB / RB (Menu bindings); wraps. Tabs that have not landed are hidden, in Pause as in Options. |
| Bank summary | Read-only. Deposited, carried, held, depth, best chain. |
| Controls reference | Read-only list of current bindings for the last-used device. |
| Options control | Toggles flip on confirm; sliders and choice lists change with left/right. [ASSUMPTION] Changes apply at once. [Mock](mockups/key-pause-options.html). |
| Title screen | Continue / New Game / Load / Options / Quit. First launch with no save: Continue and Load are hidden and the cursor starts on New Game. With a save, the cursor starts on Continue. [ASSUMPTION — default, review] |
| Click-to-play gate | Waits for the first click or key. If the window is below ×2, it suggests fullscreen. Copy [ASSUMPTION — default, review]: "Click to play"; suggestion "Small window. Try fullscreen." [Mock](mockups/key-web-gate.html). |
| Difficulty step | Easy / Normal / Hard, then Play. |
| Station menu | Appears after the rest finishes and replaces the play area; the gutters stay [ASSUMPTION — default, review]. Descend / Fast travel / Leave; Back = Leave. Fast travel lists the hub and repaired stations (GDD Lift Station). In M2 Layer 1 no station is broken, so every lit Layer 1 station counts. [ASSUMPTION — default, review] The cursor starts on Descend. The Fast travel list replaces the items in place: hub first, then stations top to bottom, without the current station or unlit ones. Back returns to the station menu. During the rest the deposited total counts up at the top of the play area, and the menu then shows it there. [Mock](mockups/key-station-menu.html). |
| Map tab | Pan with arrows/stick. Two zoom levels: layer view and close view. Up to ~10 player pins. The Ember Cache and last death point are marked automatically. Rooms the Cartographer revealed but you haven't visited are dotted outlines. Icons for stations, anchors, Ember Cache, chain gates. Per-layer reward counts, no % total (GDD Map). [OPEN] Pin place/remove controls. |
| Journal tab | E5: creature entries (sketch, how it hunts, how to beat it); entries the Naturalist pays for are marked new. E7: death log grouped by cause; lore notes + Memorial Wall names; Guild records; polish. |
| Guild records board | Shows deepest depth, best chain, most embers banked in one chain, deaths (GDD Hub). [OPEN] Board or panel. |
| Slot picker | 3 slots with depth, best chain, play time, difficulty. The cursor starts on the most recent slot (or slot 1). From New Game, an empty slot goes to the difficulty step and a filled slot asks "Overwrite slot N?" (confirm step, No default). From Load, empty slots read "Slot N — Empty" (e.g. "Slot 3 — Empty") and the cursor skips them; C (keyboard) or Y (gamepad) on a filled slot asks "Delete slot N?" (No default). Back returns to the title. [ASSUMPTION — default, review] [Mock](mockups/key-title-slots.html). |
| Death card | See State Patterns. |
| Credits screen | Scroll or page through the credits; back returns to Options. |
| Autosave icon | Shown while saving, for at least 1000 ms, steady (no blink). [ASSUMPTION — default, review] On failure (log 2026-11-11): the icon turns into the crossed icon, the field note "Not saved" shows for 3 s, and the crossed icon stays until a save succeeds. The save retries at the next rest, and the Pause note in the Pause tab explains the fix. |
| Large HUD | Accessibility option. Swaps the gutter layout (DESIGN Layout & Spacing); numbers and icons double and the ember block stacks in the lower left gutter. No behaviour change. |

## State Patterns

| State | Trigger | UI response |
|---|---|---|
| Alert | Lurker telegraph (GDD Lurker) | The alert frame pulses on both gutters (≤ 2 Hz) and the alert eye shows. Lasts the telegraph, at least 400 ms. Overlapping telegraphs merge: the frame stays until the last one ends, and the pulse does not restart. [ASSUMPTION — default, review] |
| Stirring | Lurker stirs off-screen | Off-screen edge cue on that side (E1) + panned sound (E3). With visual sound cues on (E7), an edge marker shows too. |
| Invulnerability | Hit taken | Pips blink for 0.6 s (Game Feel & Juice); steady transparency under reduce flashing. |
| Cling | Holding Jump at a wall while falling | Links stay lit; the grace bar and the cling cue drain; at empty the chain breaks and banks. Light drops per GDD. |
| Flare ready | Chain ≥2 | The meter has reached the notch at segment 2. |
| Flare thrown | Tap Light inside the tap window | Half the chain goes (GDD Flare Toss); the meter drops; the flare dims in the world over 4 s. |
| Chain bank | Landing / Snuff / cling timeout | Held → carried with popup and chord; the meter empties. |
| Chain break | Chain lost | Meter segments fall away and dim. No flashing. The number returns to 0. |
| Chain 0 | No links | The number shows 0 in the empty colour; all segments are outlines; the notch stays visible. |
| Chain at cap | 20 links | Meter full; hits still pay (GDD). [OPEN] Any extra cue at cap. |
| Death | HP 0 | Short fade, then the death card: the play area dims, the death line is centred, ember losses show in the left gutter, and the tier line follows (DESIGN Components; [mock](mockups/key-death-card.html)). Buttons held at the moment of death are ignored. A fresh press skips only after 0.6 s. The card auto-advances after about 3 s. Respawn at the last lit anchor or station (GDD Respawn); for the Weaver, see J5. Every line is also kept for the Journal death log. |
| Cache lost | Normal only: die again before recovery | The death card says the cache is gone, in a line after the tier line. |
| Rest | ↓ at Lift Station | One press: heal, embers fly into the bank with a count-up, autosave icon, then the station menu ([mock](mockups/key-station-menu.html)). |
| Autosave | Station rest, hub, quit at a lit anchor (GDD) | Autosave icon. |
| Save failed | A save does not complete (web storage blocked or full, disk error) | Crossed autosave icon and the field note "Not saved"; retries at the next rest; the Pause note explains the fix, e.g. "Saves are blocked. Allow site storage for this page, then rest again." (log 2026-11-11; copy [ASSUMPTION]) |
| Zone change | The camera centre crosses a palette-zone boundary (E4) | Gutter fill, rules and every zone-role UI colour cross-fade to the new zone over 500 ms, with no flash (Game Feel & Juice). Under reduced motion they snap. Amber and red never change. |
| Paused | Pause key, or focus loss | The game stops and the Pause tab opens. Web auto-pauses on focus loss. |
| Gamepad disconnected | Pad lost mid-play | Auto-pause with "Controller disconnected". Glyphs switch to keyboard. Reconnecting the pad or pressing any key resumes. |
| Web cold load | Page open | Click-to-play gate until the first click or key; fullscreen suggestion below ×2 ([mock](mockups/key-web-gate.html)). |
| Empty slot | No save in slot | "Slot 3 — Empty" (log 2026-11-11) in the label colour, no details line. Load skips it. [ASSUMPTION — default, review] |
| Empty journal / map | Nothing found yet | [OPEN] |

### Death card by difficulty

From the GDD Economy difficulty tiers. The death line is the same on every tier.

| Tier | Held embers | Carried embers | Card shows | Tier line (log 2026-11-11) | Map |
|---|---|---|---|---|---|
| Easy | Moved to carried (nothing lost) | Kept | Death line; the gutter shows the new carried total | None (nothing lost) | Last death point only |
| Normal | Lost | Dropped as an Ember Cache (recoverable once) | Death line + tier line; the gutter shows held lost and carried dropped | "Embers left below. Once." | Cache + last death point |
| Hard | Lost | Lost | Death line + tier line; the gutter shows held and carried lost | "Nothing left below." | Last death point only |

The tier line is the third body line, under the tip. Any further per-tier copy follows the voice rules and is written with the string table. [ASSUMPTION]

## Interaction Primitives

| Primitive | Rule |
|---|---|
| Interact | ↓ on the ground while standing still. Never ↑ (Jump). On a stick, ↓ fires when tilt down is ≥ 0.6 and sideways tilt is ≤ 0.35, and must return below 0.3 before it can fire again. Movement deadzone is 0.2; "standing still" means sideways tilt below it. [ASSUMPTION — default, review] |
| Confirm / back | Z / X on keyboard (plus Enter, Space / Backspace, Esc), A / B on gamepad. See Menu bindings. |
| Skip death card | Fresh press after 0.6 s; held buttons ignored; auto-advance at about 3 s. |
| One-press rest | A single ↓ runs the full rest sequence, with no menu until it ends. |
| Hold vs tap | Light: release inside the tap window = Flare Toss; hold past it = Snuff. Window set in Accessibility. With the Snuff toggle On, Light is Flare Toss only and Snuff is a press-toggle on its own key (Shift / LB). |
| Resume after disconnect | Reconnect the pad or press any key. |

## Game Feel & Juice

UI-side decisions only. This table owns event → response, and other sections point here. World feel (hitstop 75 ms, sparks, slow-mo at boss climaxes, camera lead, music layers) follows GDD Feel rules and GDD Audio and Music.

| Event | UI response | Under reduced motion |
|---|---|---|
| Link gained | Chain number moves up 1 px for 67 ms, then returns; one meter segment fills | Same |
| Chain 3 / 6 / 10 | Chain number steps 24 → 26 → 28 → 32 px with the music layer (DESIGN Typography) | Same |
| Bank | The bank popup rises and fades over 600 ms, then ember sprites fly from the player into the left-gutter counter, which counts up | Popup does not rise |
| HP lost | Pip cracks and shakes, then becomes an outline | No shake |
| Invulnerable | Pips blink at 2.5 Hz | Same |
| Chain break | Segments fall away and dim, no flash | Same |
| Rest | Embers count into the bank | Same |
| Menu move | Ember cursor eases 120 ms and flickers | Cursor jumps |
| Alert | Gutter frame pulses ≤ 2 Hz, eye shows | Same |
| Zone boundary (decided 2026-11-11, O4) | When the camera centre crosses the boundary, gutter tint and UI role colours cross-fade over 500 ms; no flash | Snaps in one frame |

Reduced motion (Accessibility, E1) stops cursor easing, rising popups and UI shake, and makes the zone cross-fade snap. On web it defaults to the OS setting. [ASSUMPTION] On PC it defaults to off.

Reduce flashing (Accessibility, E1) changes these effects (log 2026-11-11):

| Effect | Default | Under reduce flashing |
|---|---|---|
| Hit flash | Flash | A short dim |
| Pogo sparks | Full | Smaller |
| Alert frame | Pulses ≤ 2 Hz | Solid, no pulse |
| Invulnerability | Pips (and player) blink at 2.5 Hz | Steady transparency |
| Bank burst and bloom | Full | Toned down |

Note (2026-11-22, Story 1.19, sonlm): the white hit flash (67 ms) shows at most once per second; a hit inside that second shows only the blink. With the 2.5 Hz blink, hits back to back at the 0.6 s invulnerability would otherwise reach 4 flashes per second. The dim under reduce flashing (60% for 100 ms) shows on every hit.

## Accessibility Floor

| Item | Decision | Lands |
|---|---|---|
| Flash cap | ≤3 flashes/s anywhere, checked for every effect (GDD) | E1 |
| Reduce flashing | Toggle in Options > Accessibility. Scope in Game Feel & Juice. | E1 |
| Screen shake | On/off in Options > Accessibility | E1 |
| Reduced motion | Toggle in Options > Accessibility; scope in Game Feel & Juice; OS default on web | E1 |
| Light tap window | 0.12 / 0.2 / 0.3 s | E1 [ASSUMPTION] |
| Contrast | 4.5:1 text, 3:1 UI shapes, per-zone overrides (DESIGN Colors) | E1 |
| Colour | Never the only signal (GDD Art Style). Alert = frame + pulse + eye. Empty = outline. Held = `+` and flicker; carried = solid icon. Toss cost = diagonal hatch. Save failed = crossed icon. | E1 |
| Off-screen cue | Half-open eye that opens as the lurker stirs, plus the glow floor; never glow alone | E1 |
| Death card | Held input ignored, skip lockout and auto-advance (Interaction Primitives); lines kept for the death log | E1 |
| Brightness | 4 levels in Options > Accessibility, replacing the M1 F1 hotkey; moves to Options > Video in E7. It changes only the world's ambient level: never light radii, what predators sense, the reserved colours or the HUD | E1 (decided 2026-11-12, A1) |
| Rebinding | Every action, both devices | E7 |
| Hold↔toggle | Cling toggle and Snuff toggle in Options > Accessibility (O13) | E1 |
| Large HUD | Numbers and icons ×2, ember block stacked in the lower left gutter (DESIGN Layout & Spacing) | E7 |
| Text scale | Menus, speech, journal. [OPEN] Layout. | E7 |
| Timing assists | Game speed and timing assists. Separate settings, not difficulty. Runs that use them are kept out of Guild records. | E7 |
| Visual sound cues | On-screen markers for predator sounds | E7 [ASSUMPTION] |

Difficulty only changes death cost. It never changes telegraphs (GDD Difficulty settings).

## Responsive & Platform

| Platform | Rules |
|---|---|
| Web (itch.io) | Embed `{spacing.embed-width}` × `{spacing.embed-height}` (×2). If the window is still below ×2, the click-to-play gate suggests fullscreen. Whole-number scaling stays. Web key rules are in Input Schemes. Auto-pause on focus loss. Fullscreen toggle in Options, plus the itch fullscreen button. Size and performance per GDD Performance. HiDPI: the canvas backing size is the CSS size × devicePixelRatio, and the whole-number scale is picked from physical pixels (a 960×540 embed at DPR 1.5 runs at ×3). Below 480×270 physical pixels, the game fits the window with a fractional nearest-neighbour downscale, still letterboxed, and the gate and Pause tab suggest fullscreen. [ASSUMPTION — default, review] [Gate mock](mockups/key-web-gate.html). |
| PC | Window at whole-number scale (M1 default ×3, 1440×810). Fullscreen is letterboxed. The minimum window size is 480×270, so PC never drops below ×1. HiDPI displays use physical pixels, as on web. [ASSUMPTION — default, review] |
| Steam Deck | E1: a Deck-size legibility check (×2, 960×540 on a 7" panel or equivalent) with Fusion Pixel Font 8px. E7: the full Deck pass (GDD Platform-Specific Details). Uses gamepad glyphs. |

Room framing: rooms are framed for 360 px of visible width. Spine shafts are 22 tiles (352 px) and never scroll sideways; wider rooms (the Weaver arena, the hub) scroll horizontally (GDD Level Types).

## Localization

M2 leaves room for localization and ships English only.

- All strings in a string table from day one.
- Gutter labels are icons, so the HUD has no localised text and no text growth to plan for. Only numbers remain.
- Menu, speech and journal text sits in the 360 px column. [OPEN] Tab widths by measure, and scripts that need more than 8 px (CJK).
- Vietnamese is not needed now (log 2026-11-11). The Fusion 8 px build lacks stacked Vietnamese marks; a later localisation could use the Fusion 10 px or 12 px builds (DESIGN Typography).
- Font and text-in-sprite rules are in DESIGN.md Typography.

## Inspiration & Anti-patterns

| Reference | Take for UX |
|---|---|
| Downwell | Minimal side gutters, limited palette, prominent combo (chain) counter |
| Celeste | Near-invisible HUD, crisp menus, strong assist options |

Anti-patterns (from the GDD and research):

- Off-screen ambushes with no telegraph (Pillar 2).
- Darkness that confuses instead of building tension (Pillar 2).
- Colour as the only signal.
- More than 3 flashes per second.
- Chords or new buttons for new abilities (Pillar 4).
- A light toggle you leave on (GDD Snuff rationale).
- Completion percentage (GDD Exploration Rewards).
- Gear slots or charms (GDD Hub).
- A boss health bar (the Weaver's health is diegetic).
- Calling the game "roguelike" or "Downwell-like" in any UI or store text.

## Key Flows

Persona: **Son**, the developer as playtester. Laptop keyboard, web build first, later the PC build and a gamepad.

### J1 — First 5 minutes

1. Son opens the itch page and clicks to play ([gate mock](mockups/key-web-gate.html)). The title shows the slowly scrolling shaft, and the menu lights under the ember cursor ([title mock](mockups/key-title-slots.html)).
2. Son picks New Game, a slot, then Normal. The difficulty step says it only changes what death costs and can be changed later.
3. Son drops into the first shaft. Glyph prompts teach jump, slash and pogo. [OPEN] These are tutorial prompts, not object prompts. The right-gutter meter starts filling.
4. Son lands at chain 6. The chain banks: held moves to carried in the left gutter, with a popup and a chord.
5. Son reaches the first Lift Station, presses ↓, rests and watches the embers count into the bank. The autosave icon appears ([station mock](mockups/key-station-menu.html)).
6. **Climax:** the station menu offers Fast travel. Son rides up to the hub, sees the Cartographer and the Field Journal, and realises there is a whole world.
7. Son opens pause and sees the bank summary and the Map tab.

*M2 caveat: the Map tab is E4 and the hub is E5. In M2 builds before those land, J1 ends at step 5.*

Failure path: Son dies before the station. The death card names the cause, and Son respawns at the last lit anchor.

### J2 — Greedy chain, near death

1. Son is at chain 15. The light is wide, the music plays the full theme, and the chain number is at peak size.
2. A small half-open red eye appears at the left play-area edge, with a red glow and a panned growl. It opens wider as the lurker stirs. With visual sound cues on, an edge marker shows too.
3. Son clings to a wall. The light drops. The links stay lit, and the grace bar and the cling cue start to drain.
4. The lurker telegraphs: its eyes open, the gutter frame pulses red and the alert eye shows for 0.9 s.
5. **Climax:** Son taps V for Flare Toss. The meter is past the notch, so the toss is allowed. The hatched top half of the lit stack goes, and the flare draws the lurker while it dims over 4 s.
6. Son pogoes to a ledge. The chain banks and the music resolves on a chord.

Failure path: the bite lands. An HP pip cracks and becomes an outline, the pips blink, and the chain breaks (segments fall away and dim).

### J3 — Death and cache run (Normal)

1. Son holds +30 embers and carries 40. A crawler hit and a lurker bite take the last HP.
2. Short fade. The death card reads "Lurker. It waits where the light is dim. Watch the edge for an opening eye." Below it is the tier line "Embers left below. Once." The left gutter shows held embers lost and the 40 carried dropped as an Ember Cache ([death card mock](mockups/key-death-card.html)). Son is still holding X, so the card stays. After 0.6 s a fresh press could skip it; Son reads it and it advances at about 3 s.
3. Son respawns at the last lit anchor with full HP.
4. Son goes back down. The Cache glows amber in the world, and that glow has stirred nearby lurkers. Their edge cues show they are waiting.
5. **Climax:** Son builds a chain for light and timing, then dives for the Cache. One touch restores the 40 to carried, and the lurkers start to hunt.

Failure path: Son dies again before touching the Cache. The Cache is gone, and the death card says so.

J3 by difficulty (GDD Economy):

| Tier | Step 2 card | Steps 4–5 |
|---|---|---|
| Easy | No tier line; nothing lost, the 30 held move to carried (70 carried) | No cache. Son continues with 70 carried. |
| Normal | As above, with "Embers left below. Once." | As above |
| Hard | "Nothing left below."; held 30 and carried 40 lost | No cache, so no cache run. The cost is the embers and the climb back. |

### J4 — Station → hub → spend

The UX expansion of the EP E5 loop "dive → home → spend".

1. Son rests at a Lift Station: full heal, embers deposited, autosave.
2. Son picks Fast travel → Hub from the station menu.
3. Son talks to the Smith. The speech box appears at the bottom of the play area, and the shop list shows the deposited total and prices.
4. The Naturalist pays for new journal entries, and the Journal tab (minimal, E5) marks them as new.
5. **Climax:** Son checks the Guild records board and sees that this run beat their best chain.
6. Son descends again from the station menu.

Failure path: Son can't afford an item. [OPEN] Shop response.

### J5 — Weaver fight

Son plays the PC build on keyboard, on Normal. All fight facts come from GDD Boss: the Weaver.

1. Son rests at the Hollow Station before the arena: heal, deposit, autosave. Son has heard and glimpsed the Weaver on the way down.
2. Son drops into the arena. It is one-way and can't be left mid-fight. The gutters stay, and the Weaver's own theme plays. There is no boss bar.
3. Son stays bright. The Weaver retreats to the ceiling and drops spiderlings. Son pogoes them and the strands (each strand bounce adds 1 link, no damage) and slashes an anchor twice. The strand frays and sags.
4. Son snuffs. In the dark the Weaver descends and rears up for a bite (0.9 s, legs rear up, eyes glow). [OPEN] Whether the alert frame shows for the Weaver's bite telegraph.
5. Son reaches chain 3 within 96 px of it. The light burst stuns it for 2.5 s, and Son lands hits. The Weaver's segments fray and fall off: that is its health.
6. At 9 HP the Re-Weave runs: silk threads glow along the new paths for 3 s, and the strands rebuild. Son is not harmed.
7. **Climax:** at 6 HP the Weaver cuts its anchors. Slow motion for 0.5 s, then about 6 s of free fall with debris to pogo. The chain meter climbs toward the cap as Son falls into the Layer 2 landing arena under the Bright Moon sky. [OPEN] Gutters during The Fall, and the landing arena's UI palette.
8. Phase 2: 2 strands, a faster 0.75 s bite and a Re-Weave at 3 HP. Son herds the Weaver with a Flare Toss (it flees the flare) and drops a weakened strand under it.
9. On defeat: slow motion, Weaver Silk drops (Swing unlocked), and the broken landing-arena station is repaired and returns Son to the hub. [OPEN] How the Swing unlock is shown.

Failure path: Son dies in phase 2. The death card shows the Normal result. Son respawns at the Lift Station before the arena with full HP, and the fight resumes from phase 2 in the landing arena (GDD Weaver Death). [OPEN] How the respawn reaches the landing arena (GDD open question, E6). A death in phase 1 resets the fight.

### J6 — Gamepad session

Son plays the PC build and picks up a gamepad mid-session.

1. Son starts on the keyboard, and the title shows keyboard glyphs. Son moves the pad's stick: the glyphs switch to gamepad, and the d-pad moves the ember cursor.
2. Son picks Load. The slot picker shows 3 slots with depth, best chain, play time and difficulty. Son loads slot 2 with A; B would go back.
3. In play, glyph prompts show pad glyphs. At a Lift Station the prompt shows ↓ as the pad's down, and one press runs the rest.
4. Son presses Start. The Pause tab's controls reference lists the pad bindings. Son opens Options > Accessibility, turns on reduced motion (the cursor now jumps) and sets the Light tap window to 0.2 s.
5. Back in play, Son builds a chain and taps B for Flare Toss inside the wider window.
6. **Climax:** mid-chain, the pad's battery dies. The game auto-pauses with "Controller disconnected", and the glyphs switch to keyboard. Son plugs the pad back in, and play resumes with the chain intact.

Failure path: Son has no cable. Son presses any key, and play resumes on the keyboard with keyboard glyphs. The chain is as it was at the pause.

## Epic Rollout

| Epic | UX surfaces |
|---|---|
| E1 Kit v2 | Gutter HUD v2: gutter icons, HP pips with outlined empties, held/carried ember counter (flicker vs solid), chain number, chain meter, cling grace bar, flare notch, flare cost hatch, cling cue, alert frame + eye, off-screen edge cue with glow floor. Contrast floors and per-zone UI tokens. Fusion Pixel Font 8px integrated (OFL files shipped) and the Deck-size check run with it. Gutter outer rule. Options with Game + Accessibility tabs (reduce flashing, screen shake, reduced motion, Light tap window [ASSUMPTION], Cling toggle and Snuff toggle). Pause tab (Resume / Options / Quit, bank summary, controls reference). Gamepad defaults, glyph swap, disconnect pause. Glyph prompts. Death card (timing, 3 tiers, layout). Placeholder station rest and station menu. Save/load with save-failure handling, autosave icon, difficulty step. Menu bindings (keys, repeat, wrap) and confirm step. String table. 960×540 embed with fullscreen suggestion. [ASSUMPTION] Title (with Load), slot picker and click-to-play gate also land here, since save/load does. |
| E2 Weaver prototype | Debug entry into the Weaver arena (dev only). Gutters in the arena. Diegetic Weaver health (no bar). |
| E3 Audio | Options > Audio volume sliders. Stirring sound for the off-screen edge cue. |
| E4 Layer 1 world | Map tab; full station menu with fast travel; journal objects read via ↓; zone-tinted UI across Dusk, Umber and Cold violet, with the 500 ms zone cross-fade. Map tab: mock before build via gds-ux Update. |
| E5 Hub | Speech box, shop list, Guild records board, minimal Journal tab (creature entries, "new" marks for Naturalist payouts), fast travel to hub. Speech box, shop list and Journal tab: mock before build via gds-ux Update. |
| E6 Weaver final | Post-boss return flow to hub; phase checkpoint; final fray-and-fall health visuals. |
| E7 Slice polish and ship | Options Video and Controls tabs; rebinding; large HUD; text scale; timing assists; visual sound cues; full Journal tab (death log, lore, records, polish); HUD polish; Steam Deck pass; Credits with AI disclosure [ASSUMPTION]. |

## Notes for Other Docs

| Tag | Note |
|---|---|
| [NOTE FOR LEVEL DESIGN] / [NOTE FOR ARCHITECTURE] | The M1 shaft was built for a 480 px view. Gutters leave 360 px. Camera and room widths must account for the gutters. Resolved in the GDD 2026-11-11: shafts are 22 tiles (352 px); wider rooms scroll horizontally; E1 rebuilds the M1 shaft at 22 tiles. |
| [NOTE FOR GDD] | Timing assists are separate settings, not difficulty. "Difficulty never changes telegraphs" still holds. Resolves the GDD open question on Easy assists. |
| [NOTE FOR GDD] | The Ember Cache's amber glow draws nearby lurkers, so recovering it is a risk. Adopts the designer note in GDD Open Questions as a decision. |
| [NOTE FOR ARCHITECTURE] | The GDD implies one profile; the save system must support 3 slots, plus a Load path from the title. |
| [NOTE FOR GDD] | Add to the Art Style reserved-colour rule: menu selection counts as the player's lantern, so amber in menus is allowed. |
| [NOTE FOR GDD] | Quick Wick changes the Snuff response, not the tap window. GDD Hub says it lowers the Snuff hold to 0.08 s; reword it. |
| [NOTE FOR GDD] | The Light tap window is a player setting (0.12 / 0.2 / 0.3 s). GDD Flare Toss and Controls should cite 0.12 s as the default. |
| [NOTE FOR GDD] | "The HUD turns red" (GDD Lurker, Art Style) becomes a pulsing red gutter frame (≤ 2 Hz) plus an eye icon. HUD values are not recoloured. |
| [NOTE FOR GDD] | The off-screen stirring cue is a half-open eye at the play-area edge that opens as the lurker stirs, plus a glow with a minimum strength. A faint glow alone is not enough (GDD Lurker). |
| [NOTE FOR GDD] | The Weaver has no health bar. Health reads from fraying, falling segments and sagging threads. |
| [NOTE FOR GDD] | The itch embed is 960×540 (×2). GDD Platform-Specific Details and Performance should state ×2 as the web baseline. |
| [NOTE FOR GDD] | A minimal Journal tab moves to E5 (creature entries, "new" marks); E7 keeps the death log, lore, records and polish. Update EP E5 and E7. |
| [NOTE FOR GDD] | The Deck-size legibility check moves into E1 (run with Fusion Pixel Font 8px); the Deck pass stays in E7. Update EP E1. |
| [NOTE FOR GDD] | E1 Accessibility gains a reduced-motion toggle (OS default on web), the Light tap window, and the Cling and Snuff hold→press toggles (moved from E7, O13). Update EP E1 and E7, Snuff toggle mode: Light = Flare Toss only; Snuff on its own key (Shift / LB), press to start and end (decided 2026-11-11). Applied to GDD Controls. |
| [NOTE FOR ARCHITECTURE] | Death card lines are stored from E1 so the E7 Journal death log has them. |
| [NOTE FOR ARCHITECTURE] | Saves must report failure to the UI (crossed icon, "Not saved", retry at next rest) and support slot delete. Web scaling picks the whole-number scale from physical pixels (devicePixelRatio). |
| [NOTE FOR GDD] | Pause is Esc or P on keyboard, Start on gamepad. GDD Controls should list it. |
| [NOTE FOR ARCHITECTURE] | The UI font is Fusion Pixel Font 8px (SIL OFL 1.1). Every build, web included, ships `OFL.txt` and the upstream `LICENSES/` folder, and the credits name the font. The font may not be sold on its own; a modified copy must drop the Reserved Font Name. |

## Open Questions

IDs: D = E1 default to review, A = assumption, O = open question. Mocks cite these IDs.

### E1 defaults to review

The open-item triage filled these (log 2026-11-11). Each is tagged `[ASSUMPTION — default, review]` where it is specified. To change one, edit its line here and the spec it points to.

| # | Item | Default | Spec |
|---|---|---|---|
| D1 | Chain number steps and pop | Hand-pixelled numerals at 24 / 26 / 28 / 32 px for 0–2 / 3–5 / 6–9 / 10+ links; pop = up 1 px for 67 ms | DESIGN Typography |
| D2 | Text outline | 1 px, 4-sided, zone surface colour, only for text and cues over the play area | DESIGN Typography |
| D3 | Cling cue and grace-bar colour | Cue = 2 × 8 px bar beside the player, drains top-down; both in the zone HP colour | DESIGN Components |
| D4 | Icon art and ember header | 7 × 7 heart and chain link, 7 × 5 eye, 7 × 7 lantern (pixel art in Shapes); no ember section icon | DESIGN Shapes |
| D5 | Glyph prompt | 12 px keycap, HP-colour outline and label on a surface backing; long keys up to 32 px; 4 px above the object; clamped 4 px inside the play area | DESIGN Components |
| D6 | Menu keys, repeat, wrap | Z/Enter/Space confirm, X/Backspace/Esc back, Q/E tabs; pad A/B, LB/RB; repeat 400 ms then 80 ms; lists and tabs wrap, sliders stop | Input Schemes |
| D7 | Glyph swap and ↓ deadzone | Swap on any button/key or stick/trigger past 0.5; ↓ interact at ≥ 0.6 down, ≤ 0.35 sideways, re-arms below 0.3; move deadzone 0.2 | Input Schemes, Interaction Primitives |
| D8 | Alert hold on overlap | Minimum 400 ms; overlapping telegraphs merge; pulse does not restart | State Patterns |
| D9 | Slot picker states and confirms | "Slot N — Empty" in the label colour (decided); overwrite and delete (C / Y) confirms with No default; Load skips empty slots; Continue/Load hidden with no save | Component Patterns, DESIGN Components |
| D10 | Quit confirm | "Quit to title?" No / Yes, No default; adds "You will wake at the last rest." away from a lit anchor or station; no confirm on the title | Information Architecture |
| D11 | Autosave icon | 7 × 7 lantern, HP colour, left gutter bottom (y 252); shown ≥ 1000 ms, steady | DESIGN Components, Component Patterns |
| D12 | Options toggle and slider | Toggle = 7 px box (filled On / outline Off) + text; slider = 10 segments of 4 × 6; values right-aligned at x 412 | DESIGN Components |
| D13 | Menu zone outside play | Dusk | DESIGN Components |
| D14 | Station menu placement | Replaces the play area; gutters stay; deposited total on top | DESIGN Components |
| D15 | HiDPI and small windows | Scale from physical pixels (DPR); below 480×270, fractional nearest fit + fullscreen suggestion; PC minimum window 480×270 | Responsive & Platform |

Key-mock defaults (log 2026-11-11): the positions and colours chosen in the key mocks are now spec. DESIGN tags them `[ASSUMPTION — default, review]` in Layout & Spacing (Menu positions, In-world UI positions) and Components.

### Decided 2026-11-11

No longer open: pause key, off-screen edge eye, flare cost hatch, reduce-flashing scope, death card layout, save failure, death card tier lines, "Slot 3 — Empty", controls-reference row pitch (14 px), Pause tabs hidden until they land, mock coverage, bank popup.

- Bank popup: keep the M1 popup (DESIGN Components).
- Mock coverage: key-screen mocks in `mockups/` cover the HUD, death card, title and slot picker, Pause and Options, station rest and menu, and the click-to-play gate. Map (E4), Journal, speech box and shop (E5) are mocked at epic start via gds-ux Update, once their open layout questions are decided. Quit confirm, controller-disconnected pause and credits stay spine-only.

### Decided 2026-11-11 (update)

- O1. Font: Fusion Pixel Font 8px, proportional (latin build), OFL 1.1; cap 6 / x-height 4 / descender 2 (DESIGN Typography). The Deck-size check still runs in E1. *Update 2026-11-22 (Story 1.18): the check ran and passed with notes; see DESIGN Typography and the deferred-work ledger.*
- O4. Zone change: gutter tint and UI colours cross-fade over 500 ms when the camera centre crosses a zone boundary; no flash; snaps under reduced motion (Game Feel & Juice, State Patterns).
- O13. Motor access: Cling toggle and Snuff toggle (hold→press) ship in Options > Accessibility in E1; full rebinding stays in E7 (Options tabs).
- O16. Copy rule: name the shape (eye, glow, frame), never the colour (Voice and Tone).
- O17. Gutters get a 1 px outer rule in the zone's index-1 colour, matching the inner rule (DESIGN Layout & Spacing, Components).

### Assumptions

- A1. ~~[ASSUMPTION] Brightness may move into Options > Video before E7, since F1 is removed for web.~~ **Decided 2026-11-12 (sonlm, epic planning R1):** Brightness ships in E1 under Accessibility and moves to Video in E7.
- A2. [ASSUMPTION] Gutter fill = zone index 0 darkened to 55% (mock value).
- A3. [ASSUMPTION] Title (with Load), slot picker and click-to-play gate land in E1 with save/load.
- A4. [ASSUMPTION] Credits with AI disclosure land in E7.
- A5. [ASSUMPTION] Quit on the title is PC only.
- A6. [ASSUMPTION] Options tabs not yet landed are hidden, not disabled.
- A7. [ASSUMPTION] F2/F3 debug keys are removed from player builds.
- A8. [ASSUMPTION] Visual sound cues land in E7.
- A9. [ASSUMPTION] Example copy: "The cache went dark."; the difficulty step avoids "casual"/"hardcore"; per-tier death card copy is written with the string table.
- A10. [ASSUMPTION] The Light tap window lands in E1; 0.12 s is the default.
- A11. [ASSUMPTION] Reduced motion defaults to off on PC.
- A12. [ASSUMPTION] The off-screen edge cue's glow pulses at 2 Hz.
- A13. [ASSUMPTION] Options changes apply at once.
- A14. [ASSUMPTION] Layout values in DESIGN: 7 × 7 heart and chain icons, alert-eye spot, 2 px grace bar, 1 px alert frame.
- A15. [ASSUMPTION] Rules and dividers are decorative and exempt from the 3:1 shape floor.
- A16. [ASSUMPTION] Large HUD doubles the 8 px numbers; the chain number keeps its sizes.

### Open, blocks E1

None (O1 decided 2026-11-11).

### Open, later epic

- O2. [OPEN] Tutorial prompts in J1 step 3: spec them or use in-world signs (E4).
- O3. [OPEN] Map room colours, icon art, pin controls (E4).
- O5. [OPEN] Speech box frame, reveal, pace and line length (E5).
- O6. [OPEN] Shop buy confirm and can't-afford response (E5).
- O7. [OPEN] Empty journal and map states; "new" mark art; Guild records board form (E4/E5).
- O8. [OPEN] Gutters during cutscene moments (The Watching Departure, The Fall) (E5/E6).
- O9. [OPEN] Hub and Layer 2 palettes (GDD open), their UI tokens and floor checks (E5/E6).
- O10. [OPEN] Whether the Weaver's bite telegraph shows the alert frame; how the Swing unlock is shown; how a phase-2 respawn reaches the landing arena (E2/E6).
- O11. [OPEN] Extra cue at chain cap (E7).
- O12. [OPEN] Large HUD ember display above 4 digits; text scale layout for menus, speech and journal (E7).
- O14. [OPEN] Hearing: mono audio and separate sliders (E3); the full list of visual sound cues (E7).
- O15. [OPEN] An accessibility persona or test pass (colour-blind sim, sound off, ×2) (E7).
- O18. [OPEN] Tab widths and CJK glyph size for later localisation.
- O19. [OPEN] Title logo art (E7; E1 uses a text placeholder).
- O20. [OPEN] If Snuff gains a cost (GDD Risks), the HUD must show it.

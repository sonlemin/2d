# Validation Report — The Unbroken Chain

- **DESIGN.md:** `/home/sonlm/project/pixel_art_game/_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/DESIGN.md`
- **EXPERIENCE.md:** `/home/sonlm/project/pixel_art_game/_bmad-output/planning-artifacts/ux-designs/ux-pixel_art_game-2026-11-10/EXPERIENCE.md`
- **Run at:** 2026-11-11T00:03:43+07:00

## Overall verdict

The pair holds together. Almost every decision-log entry made it into the spines, all hex values are present and match the GDD and the mocks (gutter hex = zone 0 × 0.55 checks out exactly, and the contrast table matches recomputed WCAG ratios), and open items are tagged honestly instead of being filled in. It is not yet a clean contract for E1 implementation. The zone-role colour tokens don't resolve mechanically. Several E1 components (flare cost tint, cling cue, edge glow, glyph prompt) have no colour or form. The death card assumes Normal difficulty. "Reduced motion" is referenced but has no setting. A few untagged behaviours were invented (Pause replaces the view, Quit goes to title, slot picker from Continue).

The two adversarial reviewers shift the picture from "draft with gaps" to "E1 has blockers". All three criticals are about whether text can be read at all: the death line card is too short and is dismissed by inputs already held at death; integer scaling falls to ×1 in common itch embeds, where 8 px text has about half the minimum visual angle; and the promised HUD ×2 text assist cannot physically fit 60 px gutters. A shared pattern runs through the highs: decisions that E1 locks (the 8 px type token, the gutter coordinates, the font face, the alert recolour) are only checked in E7 (Deck ×2, scaling, motor and hearing assists). Moving a ×2 / Deck / ×1 layout check and a contrast floor into E1 acceptance resolves or de-risks most of them. After merging 10 cross-reviewer overlaps, the unique findings are: critical 3 · high 10 · medium 30 · low 21 (64 total, from 77 raw).

## Category verdicts

- Flow coverage — adequate
- Token completeness — adequate
- Component coverage — thin
- State coverage — adequate
- Visual reference coverage — thin
- Bloat & overspecification — adequate
- Inheritance discipline — adequate
- Shape fit — strong

## Findings by severity

After dedupe: critical 3 · high 10 · medium 30 · low 21 (64 unique, from 77 raw). IDs: `R-*` rubric, `A11Y-*` accessibility, `HUD-*` HUD legibility, `X*` merged across reviewers.

### Critical (3)

**[State coverage]** X6 — Death line card: too short to read, skipped by held inputs, and Normal-difficulty only (§ EXPERIENCE State "Death", "Cache lost", J3 step 2; DESIGN death-line-card; decision log l.25)
Timing (accessibility): the card auto-advances after about 1.5 s and any input skips it. The 16-word example line needs about 4–5 s at 200–250 wpm, longer for dyslexic or low-vision players, and players are usually mashing attack or holding a direction at the moment of death, so the card is often dismissed on its first frame. It carries Pillar 2 ("every death teaches") and the ≥80 % name-the-killer metric, and the full death log only lands in E7, so nothing recovers a missed line (WCAG 2.2.1, GAG basic). Content (rubric): the card and "Cache lost" assume Normal. On Easy held moves to carried and nothing is lost (no cache); on Hard both are lost and there is no cache run.
Fix: Timing: ignore inputs held at death and accept skip only after a short lockout (~0.4 s); or wait for confirm with a quick-respawn option; or scale duration by word count (1 s + 0.25 s/word) with a "Wait for input on death" toggle; and/or pull a minimal "last death" line into the Pause tab in E1. Content: add a per-tier row (Easy "nothing lost"; Normal as now; Hard "all embers lost", no cache marker on the map). Related: HUD M4 (box density at 360 px), A11Y-21 (copy).
Merged from: A11Y-01 (critical), R-State-1 (high)

**[HUD legibility reviewer]** X7 — Whole-number scaling drops to ×1 in common web cases, and nothing in the spines covers ×1 (§ EXPERIENCE Responsive & Platform (web row); DESIGN Layout ("×2, ×3, ×4"))
Integer scaling falls to ×1 whenever the device-pixel viewport is below 960×540: any itch iframe under 960×540 on a DPR-1 screen, and under 640×360 CSS on DPR 1.5. itch's default embed is, as far as the reviewer knows, 640×360 (verify). At ×1, 8 px HUD text is 7.6–7.9′, about half the 16′ minimum; the 5×5 ember icon is the same, and held vs carried is effectively unreadable. A 1080p laptop at 150% cannot fit a 960×540 iframe plus the itch header, and arrow keys are blocked from scrolling. Below 480×270, Godot's integer stretch clamps to ×1 and crops (verify on 4.7). XAG 101.
Fix: Set the itch viewport to 960×540 with the fullscreen button and a "Play fullscreen" option on the click-to-play gate; declare ×1 unsupported with a "Window too small — go fullscreen" overlay below ×2 (and a minimum-size message below 480×270); or allow one explicit fractional "fit" exception with nearest filtering; or a ×1 profile without labels and with bigger digits; document ×2 as the minimum supported scale in the spines and GDD Platform.
Merged from: HUD C1 (critical), A11Y-07 (medium), HUD L5 (low)

**[HUD legibility reviewer]** X5 — The HUD ×2 text-scale assist cannot fit 60 px gutters (§ decision log [ASSUMPTION] HUD ×2; EXPERIENCE Accessibility Floor, Open Assumption 1; DESIGN Layout l.258, l.267–285)
Measured at 16 px against 59 usable px: `EMBERS` is 70 px; `CHAIN` 56 with no margin; held `+1240` is 60 px of text plus icon and gap (~76 px); the chain number at ×2 puts `20` at 72–96 px wide; a 4-pip column at 10 px pitch doubles to 80 px; a ×2 meter is 360 px tall on a 270 px screen. This is not a "layout check": the promised assist cannot be built inside 60 px gutters at native resolution, yet the spines only flag it as an assumption. XAG 101, GAG intermediate.
Fix: Scale only text and pips, keep a thicker ×1 meter, and replace labels with icons (heart, ember, chain); stack ember rows in the empty lower-left gutter (y 120–270); render the HUD on a window-resolution layer (costs pixel consistency); widen gutters to ~80 px under the assist (needs horizontal camera follow); use letterbox / `expand` space where available; or rename it "large text in menus, journal and speech" with a separate high-visibility HUD mode. Whichever: do the ×2 check before E1 locks coordinates, not in E7.
Merged from: HUD C2 (critical), A11Y-06 (high)

### High (10)

**[Token completeness]** R-Token-1 — Zone-role tokens are prose, not tokens (§ DESIGN frontmatter l.94–104)
`components.zone-roles.hp: 'zone index 3'` and `gutter: 'gutter-{zone}'` resolve to strings. About 25 component colour fields point at them (`hp-pip.full`, `menu-item.selected`, `tab.active`, `bank-summary.label`, …), so a resolver or a coder mirroring the spine gets "zone index 3" instead of a colour. A resolver will also read `gutter-{zone}` as a broken `{zone}` reference.
Fix: Make the zone the explicit parameter: either per-zone role tokens (`hud-hp-dusk: '{colors.zone-dusk-3}'` …) or one `zone-roles` sub-map per zone with real `{colors.…}` refs, keeping the "resolve by active zone" rule in prose.

**[Token completeness]** X1 — No contrast floor; labels, idle items and empty states sit under common targets (§ DESIGN Colors "Measured contrast" [OPEN]; EXPERIENCE Open Q 4)
Cold-violet labels are 3.03:1 and Umber 3.76:1 on the gutter; idle menu items are 3.44 / 2.93:1 (Umber / Violet); red alert text is 4.40:1 on the dusk gutter. Empty pips and segments are 2.37 / 1.79 / 1.37:1, under WCAG 1.4.11's 3:1, and in Violet an empty pip is nearly invisible although HP left is read from the empty pips. All of this is 8 px pixel text with 5 px of ink, so even 3:1 is too low for it. The mocks' 1 px drop shadow (`#05040a` on `#07060b`) adds nothing. The palette darkens with depth, so the hardest-to-read HUD appears in the hardest content, and E1 HUD v2 builds against these values.
Fix: The developer picks a floor before E1; all three reviewers converge on 4.5:1 for 8 px text and 3:1 for non-text HUD state. Then, per zone that fails: override the role mapping (e.g. a lifted `label-violet`, or labels at zone-3 with reduced weight); map label/idle to an idx2–idx3 blend; draw empty pips and segments as 1 px outlines; put a lighter backing behind label rows; or add a "High-contrast HUD" toggle.
Merged from: R-Token-2 (high), A11Y-03 (high), HUD M3 (medium)

**[Token completeness]** X9 — Body text has zero leading (8 px font, 8 px line height) (§ DESIGN typography.body-line, menu-item, hud-value)
With 5 px caps placed at em rows 4–8, descenders reach row 10. At 8 px pitch the next line's caps start 1–2 px below the previous line's descenders, and accented capitals (É, rows 1–3) overlap them. Every multi-line surface uses this token: speech box, death line card, journal entries, slot details.
Fix: Set body-line line height to 12 px (1.5×; 24 px pairs keep the 8 px grid) or 10 px as the minimum that clears descenders and accents; or keep 8 px only for single-line HUD values and split into `hud-*` and `text-*` tokens.
Merged from: R-Token-5 (low), HUD H4 (high)

**[Component coverage]** X2 — Colour-only HUD alert and flare cost tint break the spines' own rule (§ DESIGN Do's l.336, Components "Flare cost tint"; EXPERIENCE Accessibility Floor "Colour", State "Alert")
DESIGN Do's says alert, empty and cost states "also change shape, position or motion". But the HUD alert is a pure recolour of pips, held text, chain number and meter; the non-colour cues EXPERIENCE cites (telegraph sound, eye motion) are world cues, and sound only lands in E3, so deaf or muted players lose it. The cost tint is a tint only, and "pairs with the notch" fails because the notch is static and does not encode the cost. Measured: amber→red on the chain number is 3.00:1 in every zone and under deuteranopia reads as a yellow shift (ΔE 33); Umber alert vs normal pips are 1.56:1 (1.37 deutan). A hue tint over amber-filled segments will be weak under deutan. XAG 103, GAG basic.
Fix: Alert: a shape change (hollow or eye-shaped pips, a 1 px bracket or underline on the chain number), a single 1 px HUD jolt at onset (respects the shake toggle, no repeating blink), or a fixed pixel-eye icon in the gutter. Cost tint: a 1 px dither or hollow pattern, or a ≥3:1 brightness drop, over the segments to be spent, or a bracket beside the cost range; avoid red. Weakest option: narrow the rule to say world cues carry the alert. Related: HUD H1 (the recolour also collapses full-vs-empty contrast).
Merged from: R-Component-1 (high), A11Y-02 (high), A11Y-19 (low)

**[State coverage]** X4 — Reduced motion is referenced but no setting triggers it (§ EXPERIENCE Component Patterns, Interaction Primitives, Accessibility Floor vs Options tabs)
The cursor "jumps under reduced motion" and that lands in E1, but the Options tabs list only reduce flashing and screen shake. The mock used the browser's `prefers-reduced-motion`, which a Godot desktop build doesn't get. The decision log has the same gap, so this is inherited, not invented. Other motion the setting should cover: the scrolling title shaft behind text, the 1 px ember cursor flicker, the chain number pop, ember fly-to-gutter, meter segments falling away, popup rise (WCAG 2.3.3, XAG 116).
Fix: Ask the developer: its own Accessibility toggle in E1 with a listed scope, or fold it into screen shake renamed "Motion"; on web, default it from `prefers-reduced-motion`. Then add it to the Options tabs table.
Merged from: R-State-2 (high), A11Y-09 (medium)

**[Accessibility reviewer]** A11Y-04 — Off-screen "stirring" telegraph is a faint red glow, alone until E3/E7 (§ DESIGN l.313; EXPERIENCE l.95, l.184, l.243)
In E1 the only stirring cue is a "faint" red edge glow; panned sound lands in E3 and the edge marker in E7 (only with visual sound cues on). Under protanopia red becomes dark olive at about 3.3–3.5:1 against the gutter even at full strength; at "faint" alpha it drops well under 3:1 and may vanish. This is the Pillar 2 protection against off-screen ambush, and the death line itself tells players to "watch for the red glow".
Fix: Give the glow a shape or motion signature (slow 1 Hz chevrons, a pixel eye) in E1; define a minimum peak contrast (≥3:1 against the zone's darkest colour) and size; make the E7 edge marker on by default or part of a colour-blind setting; rephrase the death line away from the colour word (A11Y-21).

**[Accessibility reviewer]** A11Y-05 — Light tap/hold window is fixed and gear makes it tighter (§ EXPERIENCE l.117, l.135, l.211)
Flare Toss only if Light is released before 0.12 s, else Snuff (which breaks and banks the chain). Quick Wick lowers it to 0.08 s, so buying gear makes Flare Toss harder for players with tremor, slow release or switch hardware. A misfire is high-cost at J2's climax. Hold↔toggle (E7) doesn't address it. GAG basic/intermediate, XAG 107.
Fix: An adjustable Light threshold (0.08–0.30 s) in Accessibility, with Quick Wick relative to it; optional separate Flare/Snuff bindings; make Quick Wick shorten the Snuff animation instead; bring the setting forward to E1, since misfires were an M1 finding.

**[HUD legibility reviewer]** HUD-H1 — Alert red recolour collapses full-vs-empty contrast on pips and meter when HP matters most (§ EXPERIENCE State "Alert"; DESIGN hp-pip and chain-meter `alert`)
Full pips and filled segments turn `#d9473f` while empty ones stay zone-1: full vs empty drops from 4.62:1 to 1.86:1 in Dusk (1.49 protan) and 2.53:1 in Umber, during the 0.9 s before a bite. Red text on the gutter falls from 7–11:1 to 4.4–4.7:1. Amber→red on the number is mostly a brightness drop, so red-green CVD players read "the HUD dimmed". Recolouring four elements also removes the amber vs zone separation between chain and HP. (Distinct from X2: even with a shape cue, the recolour itself destroys HP readability.)
Fix: Keep pips and meter in normal colours and signal alert with a red gutter-edge rule or chain-number outline; tint only the empty pips/segments red; recolour only the at-risk values (chain number, held embers); add a shape change; or a lighter alert tint for text (needs a GDD "predator-red light" token).

**[HUD legibility reviewer]** HUD-H2 — On Steam Deck ×2, 8 px HUD text is below the legibility minimum, and the check is scheduled for E7 (§ EXPERIENCE Responsive & Platform (Deck row); Epic Rollout E7)
1280×800 fits only ×2 (51 % of screen). 8 px text has 1.18 mm caps: 13.5′ at 30 cm, 10.1′ at 40 cm, below 16′. The 10 device-px cap height may pass Valve's ~9 px guidance while still being uncomfortable. The font face and 8 px token are chosen in E1.
Fix: Move a Deck-equivalent check into E1 HUD v2 acceptance; on Deck use `expand` at ×2 (640×400) and give the extra width to the gutters (also solves X5; extra height is a fairness question); pick an E1 font with 6–7 px caps in its 8 px cut; make "large HUD" the Deck default.

**[HUD legibility reviewer]** HUD-H3 — HiDPI, fractional DPR and browser zoom behaviour is unspecified (§ EXPERIENCE web row)
If Godot ignores DPR, a 960×540 canvas at DPR 1.25/1.5 or 110–125 % zoom is browser-stretched: glyph stems and 1 px rules alternate 2/3 px, text shimmers, and the whole-number promise fails silently. If DPR is honoured, the same iframe gives ×3 at DPR 1.5.
Fix: Specify `display/window/dpi/allow_hidpi = true` for web and compute integer scale from device pixels; a web QA matrix (DPR 1/1.25/1.5/2 × 640×360 and 960×540 × zoom 90–125 %); show the current ×N in Options > Video; recompute on resize and DPR change.

### Medium (30)

**[Flow coverage]** R-Flow-1 — No Key Flow covers the Weaver fight (§ EXPERIENCE Key Flows; Epic Rollout E6)
The arena with gutters, boss death respawning at the station before the arena, phase-2 resume and the post-boss return to hub are in the GDD (Respawn / Weaver Death) and the E6 rollout, but no journey reaches them.
Fix: Add J5 "Weaver attempt" with a failure path (death in phase 2), or log the omission as deliberate.

**[Flow coverage]** R-Flow-2 — No flow exercises gamepad or a device switch (§ EXPERIENCE J1–J4; Foundation)
All four flows are keyboard on the web build. Gamepad is "fully supported" and the glyph swap is a stated rule, but no flow covers a device switch, gamepad menus or the Steam Deck ×2 check.
Fix: Add a gamepad variant step to one flow (e.g. J4 on a pad; glyphs swap on first stick input).

**[Token completeness]** R-Token-3 — E1-critical visuals have no colour or token (§ DESIGN frontmatter; DESIGN Components rows)
`flare-cost-tint.color`, `glyph-prompt.color`, `map-room-box.visited` and `autosave-icon.spec` are `[OPEN]`. Cling cue and off-screen edge glow have no component token at all.
Fix: Add `cling-cue` and `edge-glow` entries (even as `[OPEN]`) so the token set lists every component, and route the E1 ones (tint, cling cue, glyph prompt, edge glow) as phase blockers.

**[Component coverage]** R-Component-2 — Surfaces with behaviour but no visual spec (§ DESIGN Components)
Missing from DESIGN.Components: Shop list, Controls reference, Journal tab (entries, the "new" mark), bank popup (GDD "chain popups are amber"), Guild records board, Difficulty step, Click-to-play gate, Credits, and the Options controls (toggle, slider).
Fix: Add rows, `[OPEN]` where undecided.

**[Component coverage]** R-Component-3 — Surfaces with visuals but no behaviour spec (§ EXPERIENCE Component Patterns)
Missing from EXPERIENCE.Component Patterns: Title screen, Menu screen, Off-screen edge glow (only in State Patterns), Difficulty step, Click-to-play gate, Options toggles and sliders (adjust keys, live preview), Guild records board, Credits.
Fix: Add rows or point each to its State Patterns row.

**[Component coverage]** R-Component-4 — Tutorial prompts are used but not specified (§ EXPERIENCE Component Patterns "Glyph prompt" vs J1 step 3)
The glyph prompt appears "above an interactable when the player is in range", but J1 step 3 uses glyph prompts to teach jump, slash and pogo. A tutorial prompt is not tied to an object or range, and nothing specs it.
Fix: Spec a "tutorial prompt" (trigger, dismissal, placement inside the 360 px play area), or reword J1 to in-world signs read with ↓. See also HUD M5.

**[Component coverage]** R-Component-5 — DESIGN's glow and gutter rules contradict its own components (§ DESIGN Do's; Elevation; Components)
"Don't add glows … to UI" sits beside the GDD-mandated red Off-screen edge glow. "Keep every HUD element inside the gutters … except in-world prompts and the speech box" omits the cling cue, the edge glow and a possible station-menu overlay.
Fix: List the allowed exceptions (edge glow, cling cue) explicitly in both rules.

**[State coverage]** R-State-3 — Chain meter semantics during cling are ambiguous (§ EXPERIENCE Component Patterns "Chain meter", State "Cling")
The meter is one segment per link, yet it "drains from the top during cling grace". Unstated: whether the drain shows grace time (1 s per link) or lost links, what the chain number does meanwhile, what a pogo refill does, and how the timeout (which banks the chain) shows.
Fix: State it, e.g. "the meter shows remaining grace; the number keeps the link count; on timeout the bank state plays".

**[State coverage]** R-State-4 — E1 critical-path save states are [OPEN] (§ EXPERIENCE State "Empty slot", "Autosave"; Open Q 15, 16)
Empty slot, first launch with no save (Continue disabled, hidden, or skip to New Game?), overwrite and web save failure are open, but save/load and the slot picker land in E1.
Fix: Treat them as phase blockers at Finalize triage.

**[State coverage]** R-State-5 — Menu background has no zone outside play (§ DESIGN Components "Menu screen"; EXPERIENCE IA)
`menu-screen.background` is "`zone-roles.surface` of the current zone", but Title, Options-from-Title, slot picker and Credits have no current zone.
Fix: Name the default zone for out-of-play menus (e.g. Dusk, or the slot's last zone).

**[Visual reference coverage]** R-Visual-1 — Mocks are referenced only as code spans into hidden `.working/` (§ DESIGN preamble; EXPERIENCE IA "Pause tab", HUD & Diegetic UI)
EXPERIENCE links no mock, although the menu mock shows the Pause tab layout, bank summary, tab bar and cursor easing, and the HUD mock shows the HUD hierarchy.
Fix: At Finalize, promote the 3 mocks to `mockups/` and add inline relative links in DESIGN Layout/Components and EXPERIENCE IA/HUD, each naming what it illustrates.

**[Bloat & overspecification]** R-Bloat-1 — UI juice specified three times; the 120 ms cursor ease four times (§ EXPERIENCE Component Patterns, State Patterns, Interaction Primitives, Game Feel & Juice)
Repeated timing values invite drift.
Fix: The Game Feel table owns event→response; other sections reference it.

**[Inheritance discipline]** R-Inherit-1 — Invented, untagged behaviours (§ EXPERIENCE IA, Foundation; DESIGN Elevation)
Not in the log or sources: (a) "Pause replaces the view; it never stacks", echoed by DESIGN Elevation, which also pre-empts the `[OPEN]` station-menu placement; (b) "Quit in the Pause tab returns to the title"; (c) New Game order slot → difficulty; (d) "Control nodes for HUD and menus"; (e) DESIGN Elevation's three-layer ordering.
Fix: Confirm each with the developer and log it, or tag it `[ASSUMPTION]`.

**[Inheritance discipline]** R-Inherit-2 — No defined way to load an older slot (§ EXPERIENCE IA table)
The slot picker is "reached from New Game (and Continue when choosing)", but the log says Continue loads the most recent slot and never mentions choosing.
Fix: Ask the developer for the load-other-slot path (e.g. a "Load" item, or the picker from Continue with a key) and log it.

**[Inheritance discipline]** R-Inherit-3 — Journal timing contradicts itself (§ EXPERIENCE IA, Epic Rollout E5/E7, J4 step 4)
The Journal tab lands in E7, but E5 and J4 step 4 need it to mark new entries for the Naturalist payout.
Fix: Move a minimal Journal tab to E5, or show the "new" marks elsewhere (Naturalist dialogue) until E7.

**[Inheritance discipline]** R-Inherit-4 — Component names drift between spines and sections (§ DESIGN Components; EXPERIENCE Component Patterns, HUD, State)
"HP pip"/"HP pips"; "Tab"/"Tabs"; "Menu item" and "Ember cursor" (two rows) vs one combined row; "Off-screen edge glow" vs "Off-screen stirring" vs "Stirring"; "Map room box" vs "Map".
Fix: One canonical name per component, matching the frontmatter key (e.g. `hp-pip` → "HP pip").

**[Accessibility reviewer]** X3 — Held vs carried embers are told apart by colour and a "+" only (§ DESIGN ember-counter, Do's and Don'ts; EXPERIENCE l.87–88)
Held is amber `#ffd27a`, carried is zone idx3; in Dusk (`#d8c3a0`) they are 1.21:1 in luminance and both pale warm tones. The "+" prefix and row position help, but the icons break the stated colour rule. Held is what you lose on death, carried is what drops as cache, and deposited is a third state not shown, so this is cognitive load as well as colour.
Fix: Give the carried icon a different shape (pouch, or hollow vs solid ember); add tiny row labels ("HELD"/"PACK"); or drop the carried icon and keep the number under a divider. Explain the three ember states once in the Pause bank summary. Related: R-Token-6.
Merged from: A11Y-11 (medium), HUD M2 (medium)

**[Accessibility reviewer]** X8 — Alert on/off timing is undefined; overlapping telegraphs can exceed the flash cap (§ EXPERIENCE State "Alert" l.183–185; DESIGN off-screen edge glow [OPEN])
Alert "lasts the telegraph" (0.9 s, min 0.75 s). Staggered lurker telegraphs, or alert overlapping the 2.5 Hz invulnerability blink and the 2 Hz red wall light, can toggle four HUD elements more than 3 times per second; a 4-element recolour is effectively a flash. The cap is checked per effect, but WCAG 2.3.1 counts all flashes in any 1 s window. If the red edge glow draws over the gutter, a red HUD sits on a red glow and both lose contrast.
Fix: Alert is the union of active telegraphs, with a minimum hold (400–500 ms after the last ends) and no re-trigger within 300 ms; define the cap as screen-wide and add it to the test plan; suppress the pip blink while alert is active; draw the edge glow on the play-area side of the gutter rule only; optionally fade the alert over 80–120 ms (no fade under reduce flashing).
Merged from: A11Y-10 (medium), HUD M6 (medium)

**[Accessibility reviewer]** A11Y-08 — "Reduce flashing" has no defined scope (§ EXPERIENCE l.229, l.236, Open 23)
The toggle ships in E1 but nothing says what it changes (pip blink, eye pulse with red wall light, HDR bloom, hit sparks, flare ignition, chain-gate glow, bank popup, Re-Weave glow). "The blink still runs because it is under the cap" misreads the purpose: players who turn this on often react below 3 Hz too. XAG 118.
Fix: List every effect it softens; under it, replace the pip blink with a steady dim/outline and the eye pulse with a steady glow; cap bloom and spark brightness; consider on-by-default at first launch with a photosensitivity notice.

**[Accessibility reviewer]** A11Y-12 — Brightness arrives in E7 for a deliberately dark game (§ EXPERIENCE l.76, l.238; Assumption 2)
The M1 F1 hotkey is removed, so E1–E6 web builds (likely public) have no brightness control, though low-vision players and dim laptop panels need it most in the darkest zones. GAG basic.
Fix: Land a 4-level brightness in E1 (it existed in M1); keep F1 on PC until E7; add a base light-radius floor option.

**[Accessibility reviewer]** A11Y-13 — All motor accommodations land in E7 (§ EXPERIENCE l.77, l.130–131, l.239–242)
Rebinding, hold↔toggle, game speed and timing assists are all E7. Cling is a hold of up to ~20 s at cap; Snuff and swing are holds. Default arrows + ZXCV make one-handed play impossible before E7. GAG basic, XAG 107.
Fix: Ship keyboard rebinding (even a simple list) in E1; ship cling toggle in E1; or a second preset layout (WASD + JKL;) in E1.

**[Accessibility reviewer]** A11Y-14 — Hearing support is thin and partly sound-only (§ EXPERIENCE l.75, l.95, l.184, l.243)
Visual sound cues are E7 and only for predator sounds. Other sound-carried info: lurker hiss that follows position, Weaver twang/hiss telegraph, cling creak, Snuff confirm, chain-gate tone. No mono option although stirring relies on panning; volume sliders unspecified. XAG 103, 105.
Fix: Widen visual sound cues to every gameplay sound and list them; mono toggle and separate Music / SFX / Predator cue sliders in E3; a direction arrow on the edge marker.

**[Accessibility reviewer]** A11Y-15 — Menu input rules are undefined (§ EXPERIENCE l.118, l.124, l.168–169, l.208, Open 9, 18)
Confirm, back, tab switch, wrap and key-repeat are all open; long lists are tiring without repeat; Esc both pauses and exits browser fullscreen on web.
Fix: Repeat delay ~400 ms, rate ~80–100 ms, menu actions rebindable; accept Z/Enter/Space confirm and X/Backspace/Esc back; pause on Esc and P (prefer P on web); wrap lists.

**[Accessibility reviewer]** A11Y-16 — No accessibility persona or test plan (§ EXPERIENCE l.289)
The only persona is the developer on a laptop keyboard. Nothing checks the HUD at ×2 on Deck, with a colour-blind filter, with sound off or one-handed, and the ≥80 % killer metric is not tested under these conditions.
Fix: Add a second persona (e.g. low vision + deuteranopia, plays muted); a per-epic check (CVD-simulated zone screenshots, sound-off run, ×1 web check); recruit at least one disabled tester before release.

**[HUD legibility reviewer]** HUD-M1 — Chain-number size tiers don't match what is crisp and fits (§ DESIGN Typography [OPEN] 3/6 steps; EXPERIENCE Chain number)
Four states (0–2, 3, 6, 10) but a bitmap 8 px-grid font is crisp only at 8/16/24/32/40, and 40 px `20` (60 px) overflows the gutter. The spine base is 24 but the mock draws 16 below 3 links. A "1 px per link" pop cannot grow a bitmap glyph, only offset it.
Fix: 16 / 24 / 24 + outline / 32; or 16 / 24 / 32 with the 6-link step as colour weight or an underline; define the pop as a 1 px upward offset for 2 frames.

**[HUD legibility reviewer]** HUD-M4 — Speech box and death line density at 360 px is unspecified; ×2 text takes over the play area (§ DESIGN speech-box [OPEN]; EXPERIENCE Speech box, Death line card)
The 83-character example death line is 425 px at 8 px, so 2 rows in a ~340 px box; ×2 text makes it 4 rows and ~80 px tall (30 % of play height). "One line at a time" is ambiguous (sentence or row). The journal drops from ~50 to ~25 characters per line at ×2. Related: X6, X9.
Fix: Define a line as ≤2 wrapped rows and cap strings near 110 English characters; let the box grow upward and cover the play area only in the threat-free hub; show the death card full-width over the gutters; a scrolling journal pane with the sketch above the text at ×2.

**[HUD legibility reviewer]** HUD-M5 — Glyph prompts have no size, outline, clamping or long-key rule (§ DESIGN glyph-prompt [OPEN]; EXPERIENCE Glyph prompt)
Prompts sit over amber light pools, zone rock or dark, so neither amber nor a zone colour is guaranteed to read. `SPACE` (29 px) and `ENTER` (28 px) are ~6× wider than `Z`. Face-button glyphs need 9–11 px. Objects near the play edge push prompts into the HUD-only gutter, and the downward camera lead clips prompts near the top.
Fix: An 11×11 keycap with a 1 px dark outline plus zone-0 backing, clamped inside the play area; abbreviated caps (`SPC`, `ENT`) or icons; zone-3 on zone-0 (neither amber nor red); flip below the object when it would clip.

**[HUD legibility reviewer]** HUD-M7 — Zone recolour while falling fast can read as a HUD event (§ decision log theme C; DESIGN zone-roles)
Diving into Umber or Cold violet changes gutter tint, labels, pips and empty segments at once, in peripheral vision, mid-combat; it can be mistaken for alert or damage, and nothing defines when or how the swap happens.
Fix: Crossfade roles over 300–500 ms at the boundary; swap only at room transitions; or keep HP and value roles constant across Layer 1.

**[HUD legibility reviewer]** HUD-M8 — Flare-ready info is ~210 px from the player and split from the chain number (§ DESIGN gutter coordinates; EXPERIENCE J2 step 5)
Gutter content is ~16° from the player at ×3 desktop. The number sits at y ~24–57 while the notch and cost tint are at y ~249–264, so "can I toss?" during J2's cling needs two glances 200 px apart; flare readiness has no near-player cue.
Fix: A small flare pip on the chain number when ≥2; a lantern spark on the player; show the cost tint only while Light is pressed; or move the meter origin to the top under the number.

**[HUD legibility reviewer]** HUD-M9 — Localisation headroom is checked by character count, not glyph height or width (§ decision log Localisation; DESIGN Typography)
Latin labels fit (`EMBERS` +30 %, `BRAISES`, `KETTE`, `CHAÎNE`), `+12400` touches the rule. But accented capitals need 3 px headroom (collides under X9); CJK is not legible on an 8 px grid (needs 10–12 px), contradicting "8 px grid, wide coverage"; Options tabs at 70 px pitch overrun with `Barrierefreiheit` (81 px), and five tabs at ×2 are impossible.
Fix: Limit later localisation to Latin and Cyrillic with CJK needing a 12 px fallback layout; lay out tabs by measured width, scrolling at ×2; cap embers at `9999+` or use `12.4k`.

### Low (21)

**[Flow coverage]** R-Flow-3 — Options, Credits, slot overwrite and most of the Map tab are reached by no journey (§ EXPERIENCE IA; J1 step 7)
Options (all 5 tabs), Credits, slot overwrite and the Map tab beyond a glance are never walked.
Fix: One short flow for "change difficulty / toggle reduce flashing from Pause", or log these as spine-only.

**[Flow coverage]** R-Flow-4 — Failure-path format is inconsistent (§ EXPERIENCE J3 step 6, J4)
J3 numbers its failure path as step 6 instead of the separate `Failure path:` line J1/J2 use; J4's failure path is `[OPEN]`.
Fix: Normalise the format; J4 resolves with Open Q 11.

**[Flow coverage]** R-Flow-5 — J4 name drifts from the GDD loop name (§ EXPERIENCE J4)
"Station → hub → spend" is close to EP E5 "dive → home → spend" but not the same; source names should be mirrored verbatim when they exist.
Fix: Rename, or note that J4 is the UX expansion of that loop.

**[Token completeness]** R-Token-4 — Counts stored in the spacing scale (§ DESIGN spacing.meter-segments, spacing.notch-segment)
`meter-segments: '20'` and `notch-segment: '2'` are counts in a dimension scale.
Fix: Move them into `components.chain-meter` / `components.flare-notch`.

**[Token completeness]** R-Token-6 — `chain-amber` usage wording is wider than the tokens (§ DESIGN Colors "Reserved" vs frontmatter ember-counter)
The Colors table says `chain-amber` is used for "ember icons", but `ember-counter.carried-icon` is `zone-roles.hp`, so only the held icon is amber.
Fix: Say "held ember icon" and note that carried embers use the zone colour by design (theme C). See also X3.

**[Visual reference coverage]** X10 — Mock and spine drift will mislead implementers (§ DESIGN Layout "Gutter HUD coordinates"; promoted mocks)
DESIGN's HUD coordinate table says "from mock C", but the flare notch position and zone role colours come from theme C. Mock C draws labels in the HP colour while theme C uses the label role; mock C draws chains below 3 at 16 px while the spine base is 24; the theme-C mock's held text `+24` is tied to nothing; the menu mock's footer keys are undecided.
Fix: Cite the mock per value, or state that the theme mock wins on colour; at promotion, annotate each divergent element with a "spine wins" callout or regenerate the mock C canvas from spine tokens.
Merged from: R-Visual-2 (low), HUD L4 (low)

**[Visual reference coverage]** R-Visual-3 — Several surfaces have no mock (§ Finalize checklist)
No mock exists for title, death line card, station menu, slot picker, speech box or map, and the Finalize step "mock coverage confirmed" hasn't run.
Fix: Ask the spine-only question at Finalize and log the answer.

**[Visual reference coverage]** R-Visual-4 — "Spines win on conflict" is stated in both files (§ DESIGN preamble; EXPERIENCE)
Harmless duplication.
Fix: Optional: keep it in EXPERIENCE only, since that one covers both.

**[Bloat & overspecification]** R-Bloat-2 — Gameplay bindings restate the GDD Controls table (§ EXPERIENCE Input Schemes)
Inheritance should be by reference.
Fix: Cite the GDD and keep only the UX deltas (pause key, menu bindings, glyph swap, web keys).

**[Bloat & overspecification]** R-Bloat-3 — Cross-doc and intra-doc duplication (§ EXPERIENCE Localization, Accessibility, Input Rules, Responsive, IA)
Localization restates DESIGN Layout and Typography; the HUD ×2 assumption appears three times; web key rules twice; the IA "Lands" column repeats Epic Rollout.
Fix: One owner each, cross-references elsewhere.

**[Inheritance discipline]** R-Inherit-5 — `sources:` omits two inputs (§ EXPERIENCE / DESIGN frontmatter `sources:`)
The brief addendum and the GDD `decision-log.md` are confirmed inputs but not listed.
Fix: Add them, or note that they are reached through the GDD.

**[Accessibility reviewer]** A11Y-17 — Glyph swap may flip on stick drift (§ EXPERIENCE l.132)
"Switches on the first input from the other device": a drifting stick or resting finger flickers glyphs.
Fix: Require a press or a stick move past a deadzone; let players lock the glyph set.

**[Accessibility reviewer]** A11Y-18 — Interact needs "↓ while standing still" (§ EXPERIENCE l.113, l.207)
On a stick ↓ often registers diagonal, and standing still may fail with tremor.
Fix: Generous interact deadzone; accept ↓ at low horizontal speed; a bindable dedicated interact key.

**[Accessibility reviewer]** A11Y-20 — Chain number at 0 is near-invisible in Violet (§ DESIGN l.308; EXPERIENCE l.191)
idx1 on the Violet gutter is 1.37:1; "0" reads as missing UI.
Fix: Use idx2 for 0, or keep idx1 and outline the digits.

**[Accessibility reviewer]** A11Y-21 — Copy relies on a colour word and an ambiguous idiom (§ EXPERIENCE l.144–145)
"Watch for the red glow at the screen edge" is colour-reliant for protans; "The cache went dark." doesn't say embers were lost or how many.
Fix: "Watch for the glow at the screen edge."; "The cache went dark. 40 embers gone."; or pair terse copy with a number line.

**[Accessibility reviewer]** A11Y-22 — Destructive actions lack confirmation (§ EXPERIENCE l.67, l.175, Open 15, 17)
Quit away from an anchor, slot overwrite and slot delete are open; accidental activation is likelier for motor-impaired players.
Fix: Confirm with the default on "No"; hold-to-confirm only as an option.

**[Accessibility reviewer]** A11Y-23 — Gamepad disconnect behaviour is open (§ EXPERIENCE l.201)
XAG 107 and platform guidance expect auto-pause.
Fix: Auto-pause with a "Reconnect controller" message that keyboard can dismiss.

**[Accessibility reviewer]** A11Y-24 — Speech box reveal and pace unspecified (§ EXPERIENCE l.166, Open 10)
No text speed, advance or backlog rule.
Fix: Instant text by default or a text-speed setting; never auto-advance; a backlog of the last few lines.

**[HUD legibility reviewer]** HUD-L1 — The mock's 1 px text shadow is invisible on the gutters (§ mocks; DESIGN Elevation)
`#05040a` on `#07060b`–`#18100b`; it only matters for text over the world.
Fix: Drop shadows in the gutters; use an outline only for in-world text.

**[HUD legibility reviewer]** HUD-L2 — Pip crack-and-shake and 1 px pop details vanish at ×1 and ×2 (§ EXPERIENCE Game Feel)
A 1 px crack inside a 7 px pip is 0.24 mm at ×1.
Fix: Collapse the lost pip into an outline (a shape change); or briefly enlarge it to 9 px before it empties.

**[HUD legibility reviewer]** HUD-L3 — Near-black gutters merge with the letterbox at small scales (§ DESIGN Layout)
Cold-violet `#07060b` against a black letterbox makes the frame look 360 px wide and shifts the HUD visually.
Fix: A 1 px zone-1 rule on the gutter's outer edge; or a letterbox colour distinct from the gutter.

## Cross-reviewer overlaps

- **X1** Contrast floor (high) ← R-Token-2 (high), A11Y-03 (high), HUD M3 (medium)
- **X2** Colour-only HUD alert and flare cost tint (high) ← R-Component-1 (high), A11Y-02 (high), A11Y-19 (low)
- **X3** Held vs carried embers by colour only (medium) ← A11Y-11 (medium), HUD M2 (medium)
- **X4** Reduced-motion setting missing (high) ← R-State-2 (high), A11Y-09 (medium)
- **X5** HUD ×2 assist vs 60 px gutters (critical) ← HUD C2 (critical), A11Y-06 (high)
- **X6** Death line card (timing/skip + per-tier content) (critical) ← A11Y-01 (critical), R-State-1 (high)
- **X7** Web scaling falls to ×1 (critical) ← HUD C1 (critical), A11Y-07 (medium), HUD L5 (low)
- **X8** Alert timing / combined flash cap (medium) ← A11Y-10 (medium), HUD M6 (medium)
- **X9** Body line height has no leading (high) ← R-Token-5 (low), HUD H4 (high)
- **X10** Mock vs spine drift (low) ← R-Visual-2 (low), HUD L4 (low)

Related but kept separate:

- HUD H1 (alert recolour collapses full/empty contrast) kept separate from X2: same trigger, different defect.
- HUD M4 (speech box / death card density) kept separate from X6: it is mainly about the speech box and journal.
- HUD H2 (Deck ×2 legibility) kept separate from X5: it is about base 8 px text, not the assist.
- HUD M5 (glyph prompt form) and R-Component-4 (tutorial prompt) and R-Token-3 (glyph-prompt colour) touch the same component but different gaps.

## Mechanical notes

- Broken refs: none real. `gutter-{zone}` (DESIGN `zone-roles.gutter`) is a pattern a resolver will read as a broken `{zone}` reference (see R-Token-1).
- Tag inconsistency: the Pause key row reads "[OPEN] Esc assumed" (Input Schemes), but the same item is `[ASSUMPTION]` #8 in Open Questions; OPEN #9 (keyboard pause key vs browser Esc) overlaps it (see also A11Y-15).
- The decision log is internally ambiguous on theme C ("HP pips and labels use the zone's lightest colour; labels use the zone's mid colour"). The spines resolve it to label = index 2, matching the mock; the log should be cleaned up.
- Empty meter segments on the gutter are 2.4 / 1.8 / 1.4:1 (dusk / umber / violet); folded into X1.
- Both files are `status: draft`, `updated: 2026-11-10`. Neither has Mermaid; the screen map is an ASCII block, which is fine.
- No contradictions between the spines and the log entries for input, settings timing, gutter layout, cling/flare signals, deposited embers, title, difficulty, death, pause, station, dialogue, prompts, map, journal, accessibility, voice, theme C, font rules, web build, localisation, saves, AI disclosure, Options tabs, juice, menu style B and amber-in-menus.
- Dedupe: 77 raw findings across three reviewers merged to 64 unique. Merged findings take the highest source severity and are listed once, in the section of their primary source; the other reviewer's section points to them.

## Reviewer files

- `review-rubric.md`
- `review-accessibility.md`
- `review-hud-legibility.md`

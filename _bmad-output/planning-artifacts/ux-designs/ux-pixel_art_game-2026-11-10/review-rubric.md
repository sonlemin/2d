# Spine Pair Review — The Unbroken Chain (pixel_art_game)

Reviewer: rubric walker (`references/validate.md`). Inputs: `DESIGN.md`, `EXPERIENCE.md` (both `status: draft`), checked against `.decision-log.md` (canonical), `.working/source-extract.md`, the three `.working/` mocks, `SKILL.md` and `references/design-md-spec.md`. Spines not edited.

## Overall verdict

The pair holds together. Almost every decision-log entry made it into the spines, all hex values are present and match the GDD and the mocks (gutter hex = zone 0 × 0.55 checks out exactly, and the contrast table matches recomputed WCAG ratios), and open items are tagged honestly instead of being filled in. It is not yet a clean contract for E1 implementation. The zone-role colour tokens don't resolve mechanically. Several E1 components (flare cost tint, cling cue, edge glow, glyph prompt) have no colour or form. The death card assumes Normal difficulty. "Reduced motion" is referenced but has no setting. A few untagged behaviours were invented (Pause replaces the view, Quit goes to title, slot picker from Continue).

Severity counts: critical 0 · high 5 · medium 16 · low 12.

## 1. Flow coverage — adequate

Checked: the sources have no formal UJ names (source-extract §9). The GDD names loops ("burn bright → cash out → hide → burn again", the session loop, EP E5 "dive → home → spend"). The log names J1–J4 with persona Son. All four flows have a named protagonist, numbered steps and a bold climax beat. J1 and J2 have failure paths; J3's is inline; J4's is `[OPEN]`.

### Findings
- **medium** No Key Flow covers the Weaver fight (E2/E6): the arena with gutters, boss death respawning at the station before the arena, phase-2 resume, and the post-boss return to hub (GDD Respawn / Weaver Death; EXPERIENCE Epic Rollout E6 lists them, but no journey reaches them). *Fix:* add J5 "Weaver attempt" with a failure path (death in phase 2), or log the omission as deliberate.
- **medium** All four flows are keyboard on the web build. Gamepad is "fully supported" (Foundation) and the glyph swap is a stated rule, but no flow exercises a device switch, gamepad menus or the Steam Deck ×2 check. *Fix:* add a gamepad variant step to one flow (e.g. J4 on a pad, glyphs swap on first stick input).
- **low** Surface closure: Options (all 5 tabs), Credits, slot overwrite and the Map tab beyond a glance (J1 step 7) are reached by no journey. *Fix:* one short flow for "change difficulty / toggle reduce flashing from Pause", or log these as spine-only.
- **low** J3 numbers its failure path as step 6 ("6. Failure path: …") instead of the separate `Failure path:` line J1/J2 use, and J4's failure path is `[OPEN]` (EXPERIENCE J3 step 6, J4). *Fix:* normalise the format; J4 resolves with Open Q 11.
- **low** J4 "Station → hub → spend" is close to EP E5 "dive → home → spend" but not the same name (SKILL: mirror source names verbatim when they exist). *Fix:* rename, or note that J4 is the UX expansion of that loop.

## 2. Token completeness — adequate

Checked: 48 `{…}` references in DESIGN.md and 11 in EXPERIENCE.md, all resolved by script against the frontmatter. Every one resolves except `gutter-{zone}` (a pattern, not a reference) and EXPERIENCE's literal `{path.to.token}` syntax note (fine). All 17 colour tokens have hex. There is no light/dark pairing, which is correct for this product. Contrast was recomputed and matches the stated table (e.g. cold-violet label 3.0:1, idle menu text 2.9:1, red on dusk gutter 4.4:1).

### Findings
- **high** The zone-role tokens are prose, not tokens. `components.zone-roles.hp: 'zone index 3'` and `gutter: 'gutter-{zone}'` resolve to strings. About 25 component colour fields point at them (`hp-pip.full`, `menu-item.selected`, `tab.active`, `bank-summary.label`, …), so a resolver or a coder mirroring the spine gets "zone index 3" instead of a colour (DESIGN frontmatter lines 94–104). *Fix:* make the zone the explicit parameter. Either define per-zone role tokens (`hud-hp-dusk: '{colors.zone-dusk-3}'` …) or give `zone-roles` one sub-map per zone with real `{colors.…}` refs, and keep the "resolve by active zone" rule in prose.
- **high** No contrast floor, yet load-bearing pairs sit near or under 3:1: cold-violet labels 3.0:1, umber/violet idle menu text 3.4/2.9:1, red alert 4.4:1 on the dusk gutter. All of it is 8 px pixel text that the GDD requires to be readable at Steam Deck ×2 (DESIGN Colors "Measured contrast"; Open Q 4). E1 HUD v2 builds against these values. *Fix:* the developer picks a floor (e.g. 4.5:1 for text, 3:1 for non-text HUD marks) before E1, then adjusts the role mapping or gutter factor for the zones that fail.
- **medium** E1-critical visuals have no colour: `flare-cost-tint.color`, `glyph-prompt.color`, `map-room-box.visited` and `autosave-icon.spec` are `[OPEN]`. Cling cue and off-screen edge glow have no component token at all (DESIGN frontmatter; DESIGN Components rows). *Fix:* add `cling-cue` and `edge-glow` entries (even as `[OPEN]`) so the token set lists every component, and route the E1 ones (tint, cling cue, glyph prompt, edge glow) as phase blockers.
- **low** `spacing.meter-segments: '20'` and `spacing.notch-segment: '2'` are counts in a dimension scale (design-md-spec: spacing → dimensions). *Fix:* move them into `components.chain-meter` / `components.flare-notch`.
- **low** `body-line` and `menu-item` have `lineHeight` equal to `fontSize` (8/8). That gives zero leading for the multi-line surfaces (death line card, speech box, journal entries). *Fix:* confirm or set a body line height (e.g. 10–12 px on the 8 px grid, or state the line pitch in spacing).
- **low** The Colors table says `chain-amber` is used for "ember icons", but `ember-counter.carried-icon` is `zone-roles.hp`, so only the held icon is amber. The GDD reserves amber for "embers" generally (DESIGN Colors Reserved vs frontmatter `ember-counter`). *Fix:* say "held ember icon" and note that carried embers use the zone colour by design (mock C theme).

## 3. Component coverage — thin

Checked: every component name in both spines against DESIGN.Components (visual) and EXPERIENCE.Component Patterns (behaviour).

### Findings
- **high** The colour-only rule is broken by the specs themselves. DESIGN Do's says "Alert, empty and cost states also change shape, position or motion". But the flare cost tint is a tint only, and the HUD alert state is a pure recolour of the HUD (its non-colour cues, sound and eye motion, are in the world, not the HUD). EXPERIENCE Accessibility Floor says "cost tint pairs with the notch", but the notch is static and does not encode the cost (DESIGN Do's; DESIGN Components "Flare cost tint"; EXPERIENCE Accessibility Floor "Colour"). *Fix:* give the cost preview a shape cue (e.g. the segments to be spent shift 1 px or get a pattern) and the HUD alert a motion or shape cue, or narrow the rule to say world cues carry the alert.
- **medium** Missing from DESIGN.Components (no visual spec): Shop list, Controls reference, Journal tab (entries, the "new" mark), bank popup (GDD "chain popups are amber"; EXPERIENCE says "held moves to carried with a popup"), Guild records board, Difficulty step, Click-to-play gate, Credits, and the Options controls (toggle, slider; E1 Accessibility and E3 Audio). *Fix:* add rows, `[OPEN]` where undecided.
- **medium** Missing from EXPERIENCE.Component Patterns (no behaviour spec): Title screen, Menu screen, Off-screen edge glow (only in State Patterns), Difficulty step, Click-to-play gate, Options toggles and sliders (adjust keys, live preview), Guild records board, Credits. *Fix:* add rows or point each to its State Patterns row.
- **medium** The glyph prompt is defined as appearing "above an interactable when the player is in range", but J1 step 3 uses glyph prompts to teach jump, slash and pogo. A tutorial prompt is not tied to an object or a range, and nothing specs it (EXPERIENCE Component Patterns "Glyph prompt" vs J1 step 3). *Fix:* either spec a "tutorial prompt" (trigger, dismissal, placement inside the 360 px play area) or reword J1 to in-world signs read with ↓.
- **medium** DESIGN contradicts itself. "Don't add glows … to UI" sits beside the Off-screen edge glow component, which is a GDD-mandated red glow. "Do keep every HUD element inside the gutters … except in-world prompts and the speech box" omits the cling cue (by the player), the edge glow (screen edge) and a possible station-menu overlay (DESIGN Do's; Elevation; Components). *Fix:* list the allowed exceptions explicitly (edge glow, cling cue) in both rules.

## 4. State coverage — adequate

Checked: each IA surface (gate, title, slot picker, difficulty, play/HUD, pause tabs, options, station, speech/shop, death card, credits) against empty, first-run, loading, error, disconnect and focus-loss states.

### Findings
- **high** The death line card and Death state assume Normal difficulty: "held embers lost, carried dropped as Ember Cache". In the GDD, Easy moves held to carried and loses nothing (no cache). Hard loses both (no cache, so there is no cache run). The card's content, the "Cache lost" state and J3 differ by tier and none of that is specified (EXPERIENCE State Patterns "Death", "Cache lost"; J3; DESIGN `death-line-card`; GDD Economy tier table). *Fix:* add a per-tier row for death card content (Easy: "nothing lost", Normal: as now, Hard: "all embers lost", no cache marker on the map).
- **high** "Reduced motion" has no trigger. The cursor "jumps under reduced motion" (EXPERIENCE Component Patterns, Interaction Primitives, Accessibility Floor, landing E1), but no Options tab has a reduced-motion setting. The mock used the browser's `prefers-reduced-motion`, which a Godot desktop build doesn't get. The decision log has the same gap, so this is inherited, not invented. *Fix:* ask the developer whether reduced motion is its own Accessibility toggle (E1) or folded into "screen shake off", then add it to the Options tabs table.
- **medium** Chain meter semantics during cling are ambiguous. The meter is defined as one segment per link, yet it "drains from the top during cling grace". The spines don't say whether the drain shows grace time (1 s per link, GDD) or lost links, what the chain number does meanwhile, what happens on a pogo refill, or how the drain shows when grace runs out (GDD: cling timeout banks the chain) (EXPERIENCE Component Patterns "Chain meter", State Patterns "Cling"). *Fix:* state it ("the meter shows remaining grace; the number keeps the link count; on timeout the bank state plays").
- **medium** E1 critical-path states are `[OPEN]`: empty slot, first launch with no save (does Title show Continue disabled, hidden, or skip to New Game?), overwrite, and web save failure. Save/load and the slot picker land in E1 (EXPERIENCE State Patterns "Empty slot", "Autosave"; Open Q 15, 16). *Fix:* treat them as phase blockers at Finalize triage.
- **medium** `menu-screen.background` is "`zone-roles.surface` of the current zone", but Title, Options-from-Title, slot picker and Credits have no current zone (DESIGN Components "Menu screen"; EXPERIENCE IA). *Fix:* name the default zone for out-of-play menus (e.g. Dusk, or the slot's last zone).

## 5. Visual reference coverage — thin

Checked: `imports/` is empty (logged). `mockups/` and `wireframes/` don't exist yet. `.working/` holds 3 HTML mocks plus the journeys draft and source extract.

### Findings
- **medium** The mocks are referenced only in DESIGN's preamble, as code spans pointing into hidden `.working/` rather than relative links. EXPERIENCE links none, although the menu mock shows the Pause tab layout, bank summary, tab bar and cursor easing, and the HUD mock shows the HUD hierarchy (DESIGN preamble; EXPERIENCE IA "Pause tab", HUD & Diegetic UI). *Fix:* at Finalize, promote the 3 mocks to `mockups/` and add inline relative links in DESIGN Layout/Components and in EXPERIENCE IA/HUD, each naming what it illustrates.
- **low** DESIGN's HUD coordinate table says "from mock C", but the flare notch position and the zone role colours come from `ui-color-themes` (theme C). In the HUD mock C, labels use the HP colour, not the zone label colour (DESIGN Layout "Gutter HUD coordinates"). *Fix:* cite the mock per value or say the theme mock wins on colour.
- **low** No mock exists for title, death line card, station menu, slot picker, speech box or map. The Finalize step "mock coverage confirmed" hasn't run. *Fix:* ask the spine-only question at Finalize and log the answer.
- **low** "Spines win on conflict" is stated in both files (validate.md: once). Harmless. *Fix:* optional; keep it in EXPERIENCE only, since that one covers both.

## 6. Bloat & overspecification — adequate

### Findings
- **medium** UI juice is specified three times in EXPERIENCE (Component Patterns, State Patterns, Game Feel & Juice). The 120 ms cursor ease appears in four places (log entry, Component Patterns, Interaction Primitives, Game Feel), which invites drift. *Fix:* the Game Feel table owns event→response, and the other sections reference it.
- **low** Input Schemes "Gameplay bindings" restates the GDD Controls table (SKILL: inherit by reference). *Fix:* cite the GDD and keep only the UX deltas (pause key, menu bindings, glyph swap, web keys).
- **low** Cross-doc and intra-doc duplication: EXPERIENCE Localization restates DESIGN Layout and Typography (30 % labels, no text in sprites, glyph coverage). The HUD ×2 assumption appears three times (DESIGN Layout, EXPERIENCE Accessibility, Open Q 1). The web key rules appear twice (Input Rules, Responsive). The IA "Lands" column repeats Epic Rollout. *Fix:* one owner each, cross-references elsewhere.

## 7. Inheritance discipline — adequate

Checked: all 5 `sources:` paths resolve. Glossary (embers held/carried/deposited, Ember Cache, Lift Station, Flare Toss, Snuff, Field Journal, Guild records) is consistent with the GDD. Every decision-log entry was traced to the spines.

### Findings
- **medium** Invented, untagged behaviours (not in the log or the sources): (a) "Pause replaces the view; it never stacks. Options opens from Pause and returns to it" (EXPERIENCE IA), echoed by DESIGN Elevation "Full-screen menus, which replace the view". That rule also pre-empts the `[OPEN]` station-menu placement. (b) "Quit in the Pause tab returns to the title" (EXPERIENCE IA). (c) New Game order slot → difficulty (screen map; the journeys draft had no slot step). (d) "Control nodes for HUD and menus" (Foundation). (e) DESIGN Elevation's three-layer ordering. *Fix:* confirm each with the developer and log it, or tag it `[ASSUMPTION]`.
- **medium** The slot picker is "reached from New Game (and Continue when choosing)" (EXPERIENCE IA table), but the log says "Continue loads the most recent slot", and the log never mentions choosing a slot from Continue. The only way to load an older slot is undefined. *Fix:* ask the developer for the load-other-slot path (e.g. a "Load" item or a slot picker reached from Continue with a key) and log it.
- **medium** Journal timing contradicts itself. The Journal tab lands in E7 (IA, Epic Rollout, log "Map and Journal tabs (from E4 / E7)"), but E5 Rollout and J4 step 4 need "the Journal tab marks [new entries] as new" for the Naturalist payout. *Fix:* move a minimal Journal tab to E5, or show the "new" marks elsewhere (Naturalist dialogue) until E7.
- **medium** Component names drift between spines and sections: "HP pip" / "HP pips"; "Tab" / "Tabs"; "Menu item" and "Ember cursor" (DESIGN, two rows) vs "Menu item / ember cursor" (EXPERIENCE, one row); "Off-screen edge glow" (DESIGN) vs "Off-screen stirring" (EXPERIENCE HUD) vs "Stirring" (State); "Map room box" vs "Map"; "Glyph prompt" (both, fine). *Fix:* use one canonical name per component, matching the frontmatter key (e.g. `hp-pip` → "HP pip").
- **low** `sources:` omits two inputs the log confirms: the brief addendum and the GDD `decision-log.md` (source-extract cites both). *Fix:* add them, or note that they are reached through the GDD.

## 8. Shape fit — strong

Checked: DESIGN body order is Brand & Style → Colors → Typography → Layout & Spacing → Elevation & Depth → Shapes → Components → Do's and Don'ts, which is canonical. A short "Visual references" preamble comes first, which is acceptable. DESIGN frontmatter has `name`, `description`, `colors`, `typography`, `rounded`, `spacing` and `components`. EXPERIENCE has all eight required defaults. The triggered game sections are present: HUD & Diegetic UI, Input Schemes, Game Feel & Juice, Responsive & Platform, and Inspiration & Anti-patterns (triggered by Downwell/Celeste in the log). Invented sections earn their place: Localization (log decision), Epic Rollout (landing timing is load-bearing for stories), Notes for Other Docs, and Open Questions. No findings beyond the mechanical notes.

## Mechanical notes

- Broken refs: none real. `gutter-{zone}` (DESIGN `zone-roles.gutter`) is a pattern that a resolver will read as a broken `{zone}` reference; see Token finding 1.
- Tag inconsistency: the Pause key row reads "[OPEN] Esc assumed" (Input Schemes), but the same item is `[ASSUMPTION]` #8 in Open Questions. The OPEN #9 "keyboard pause key vs browser Esc" overlaps it.
- The decision log is internally ambiguous on theme C: "HP pips and labels use the zone's lightest colour; labels use the zone's mid colour". The spines resolve it to label = index 2, which matches the mock. That's correct, but the log should be cleaned up.
- Contrast: empty meter segments on the gutter are 2.4 / 1.8 / 1.4:1 (dusk / umber / violet). Readable as "empty" only next to an amber fill; the cap length may vanish in cold violet. Worth adding to the contrast-floor decision.
- Both files are `status: draft`, `updated: 2026-11-10`. Neither has Mermaid. The screen map is an ASCII code block, which is fine.
- No contradictions found between the spines and these log entries: input, settings timing, gutter layout, cling/flare signals, deposited embers, title, difficulty, death, pause, station, dialogue, prompts, map, journal, accessibility, voice, theme C, font rules, web build, localisation, saves, AI disclosure, Options tabs, juice, menu style B, amber-in-menus rule. All are faithfully carried.

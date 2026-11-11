---
title: "The Unbroken Chain — DESIGN"
status: final
created: 2026-11-10
updated: 2026-11-11
sources:
  - ../../gdds/gdd-pixel_art_game-2026-11-10/gdd.md
  - ../../gdds/gdd-pixel_art_game-2026-11-10/epics.md
  - ../../gdds/gdd-pixel_art_game-2026-11-10/decision-log.md
  - ../../../implementation-artifacts/m1-playtest-findings.md
  - ../../briefs/brief-pixel_art_game-2026-11-08/brief.md
  - ../../briefs/brief-pixel_art_game-2026-11-08/addendum.md
  - ../../research/domain-indie-pixel-art-pogo-descent-platformer-research-2026-11-07.md
name: The Unbroken Chain
description: Dark, zone-tinted pixel UI at 480x270 where amber is always the player and red is always a predator.
colors:
  # Reserved (GDD Art Style). Constant in every zone.
  chain-amber: '#ffd27a'
  predator-red: '#d9473f'
  # Layer 1 palette zones (GDD Art Style), index 0 = darkest, 3 = lightest.
  zone-dusk-0: '#2b1d14'
  zone-dusk-1: '#6b4a2f'
  zone-dusk-2: '#b08a5a'
  zone-dusk-3: '#d8c3a0'
  zone-umber-0: '#1e1714'
  zone-umber-1: '#4a3a33'
  zone-umber-2: '#7d6a5c'
  zone-umber-3: '#a99a8c'
  zone-violet-0: '#0d0b14'
  zone-violet-1: '#2a2440'
  zone-violet-2: '#4f5d75'
  zone-violet-3: '#a9b4c2'
  # Gutter fill: zone index 0 darkened to 55%. [ASSUMPTION] factor 0.55 (mock value).
  gutter-dusk: '#18100b'
  gutter-umber: '#110d0b'
  gutter-violet: '#07060b'
  # UI role colours per zone (UI only, never world art). Overrides are marked; see Colors > Contrast floors.
  ui-hp-dusk: '#d8c3a0'      # zone index 3
  ui-hp-umber: '#a99a8c'     # zone index 3
  ui-hp-violet: '#a9b4c2'    # zone index 3
  ui-label-dusk: '#b08a5a'   # zone index 2, passes as is
  ui-label-umber: '#8f7e70'  # override: index 2 lightened 41% toward index 3
  ui-label-violet: '#6e7b8f' # override: index 2 lightened 34% toward index 3
  ui-empty-dusk: '#836548'   # override: index 1 lightened 22% toward index 3
  ui-empty-umber: '#726258'  # override: index 1 lightened 42% toward index 3
  ui-empty-violet: '#5c5c73' # override: index 1 lightened 39% toward index 3
  ui-rule-dusk: '#6b4a2f'    # zone index 1, decorative
  ui-rule-umber: '#4a3a33'   # zone index 1, decorative
  ui-rule-violet: '#2a2440'  # zone index 1, decorative
typography:
  hud-value:
    fontFamily: 'Fusion Pixel Font 8px, proportional (latin build)'  # decided 2026-11-11 (O1); OFL 1.1; Godot size 8; cap 6 / x-height 4 / descender 2
    fontSize: 8px
    lineHeight: 8px
  hud-value-large:
    fontFamily: '{typography.hud-value.fontFamily}'
    fontSize: 16px
    lineHeight: 16px
  # Chain number: 0-2 links 24, 3-5 26, 6-9 28, 10+ 32. [ASSUMPTION — default, review]
  chain-number:
    fontFamily: 'Chain numerals (digits 0-9 hand-pixelled at each height, matched to Fusion Pixel Font)'
    fontSize: 24px
    lineHeight: 24px
  chain-number-step3:
    fontFamily: '{typography.chain-number.fontFamily}'
    fontSize: 26px
    lineHeight: 26px
  chain-number-step6:
    fontFamily: '{typography.chain-number.fontFamily}'
    fontSize: 28px
    lineHeight: 28px
  chain-number-peak:
    fontFamily: '{typography.chain-number.fontFamily}'
    fontSize: 32px
    lineHeight: 32px
  menu-item:
    fontFamily: '{typography.hud-value.fontFamily}'
    fontSize: 8px
    lineHeight: 8px
  body-line:
    fontFamily: '{typography.hud-value.fontFamily}'
    fontSize: 8px
    lineHeight: 12px
rounded:
  none: 0px
  DEFAULT: 0px
spacing:
  grid: 8px
  native-width: 480px
  native-height: 270px
  embed-width: 960px
  embed-height: 540px
  gutter-width: 60px
  gutter-usable: 58px  # 60 minus the inner and outer 1 px rules (O17, 2026-11-11)
  play-area-width: 360px
  rule: 1px
  outer-rule: 1px  # decided 2026-11-11 (O17): gutter edge facing the letterbox
  line-pitch: 12px
  gutter-icon: 7px
  ember-icon: 5px
  icon-top: 10px
  value-top: 24px
  pip-size: 7px
  pip-pitch: 10px
  ember-row-pitch: 12px
  ember-text-offset: 8px
  meter-segment-width: 12px
  meter-segment-height: 6px
  meter-pitch: 9px
  meter-base-y: 258px
  notch-width: 3px
  notch-height: 6px
  notch-offset: 2px
  grace-bar-width: 2px
  grace-bar-gap: 2px
  alert-frame: 1px
  alert-eye-top: 68px
  large-icon: 14px
  large-ember-icon: 10px
  large-stack-top: 120px
  menu-row-pitch: 24px
  menu-text-x: 64px
  cursor-gap: 9px
  tab-pitch: 70px
  tab-underline-y: 30px
  tab-divider-y: 36px
  summary-row-pitch: 14px
  # E1 defaults added 2026-11-11. [ASSUMPTION — default, review]
  chain-pop: 1px
  text-outline: 1px
  eye-width: 7px
  eye-height: 5px
  edge-cue-inset: 2px
  edge-cue-margin: 8px
  cling-cue-width: 2px
  cling-cue-height: 8px
  cling-cue-gap: 2px
  hatch-pitch: 3px
  glyph-size: 12px
  glyph-max-width: 32px
  glyph-lift: 4px
  glyph-clamp: 4px
  autosave-icon: 7px
  autosave-top: 252px
  value-right: 412px
  toggle-box: 7px
  slider-segment-width: 4px
  slider-segment-height: 6px
  slider-pitch: 5px
  slot-row-pitch: 40px
  death-text-width: 328px
  # Decided 2026-11-11 (mock gap defaults).
  controls-row-pitch: 14px
  # Positions chosen in the key mocks (mockups/), added 2026-11-11. [ASSUMPTION — default, review]
  menu-top: 64px
  title-menu-top: 104px
  tab-left: 60px
  tab-top: 18px
  bank-left: 280px
  bank-right: 420px
  bank-top: 72px
  bank-divider-y: 118px
  bank-stats-top: 126px
  controls-top: 172px
  controls-glyph-x: 120px
  pause-note-top: 136px
  pause-note-width: 208px
  toggle-x: 387px
  toggle-text-width: 15px
  control-text-gap: 3px
  popup-lift: 6px
  station-text-x: 80px
  station-total-top: 40px
components:
  zone-roles:
    note: 'One map per zone. Component fields below show Dusk; at runtime swap dusk for the active zone (umber, violet), cross-fading over 500 ms at a zone boundary (EXPERIENCE Game Feel & Juice). Only chain-amber and predator-red stay constant.'
    dusk:
      hp: '{colors.ui-hp-dusk}'
      label: '{colors.ui-label-dusk}'
      empty: '{colors.ui-empty-dusk}'
      rule: '{colors.ui-rule-dusk}'
      surface: '{colors.zone-dusk-0}'
      gutter: '{colors.gutter-dusk}'
    umber:
      hp: '{colors.ui-hp-umber}'
      label: '{colors.ui-label-umber}'
      empty: '{colors.ui-empty-umber}'
      rule: '{colors.ui-rule-umber}'
      surface: '{colors.zone-umber-0}'
      gutter: '{colors.gutter-umber}'
    violet:
      hp: '{colors.ui-hp-violet}'
      label: '{colors.ui-label-violet}'
      empty: '{colors.ui-empty-violet}'
      rule: '{colors.ui-rule-violet}'
      surface: '{colors.zone-violet-0}'
      gutter: '{colors.gutter-violet}'
  gutter:
    width: '{spacing.gutter-width}'
    fill: '{components.zone-roles.dusk.gutter}'
    rule-width: '{spacing.rule}'
    rule-color: '{components.zone-roles.dusk.rule}'
    outer-rule-width: '{spacing.outer-rule}'  # decided 2026-11-11 (O17)
    outer-rule-color: '{components.zone-roles.dusk.rule}'  # same index-1 colour as the inner rule
    zone-change: 'all zone-role colours cross-fade over 500 ms at a zone boundary; snap under reduced motion (EXPERIENCE Game Feel & Juice)'
  gutter-icon:
    set: 'heart (HP), ember (embers), chain link (chain)'
    size: '{spacing.gutter-icon}'
    ember-size: '{spacing.ember-icon}'
    color: '{components.zone-roles.dusk.label}'
    art: 'heart 7 x 7; chain link 5 x 7 outline centred in 7 x 7; ember 5 x 5 blob (see Shapes)'  # [ASSUMPTION — default, review]
    ember-section-icon: 'none; the held and carried row icons act as the header'  # [ASSUMPTION — default, review]
  text-outline:  # [ASSUMPTION — default, review]
    width: '{spacing.text-outline}'
    color: '{components.zone-roles.dusk.surface}'
    neighbours: '4 (no diagonals)'
    applies-to: 'text and cues drawn over the play area; never gutter or menu text'
  hp-pip:
    size: '{spacing.pip-size}'
    pitch: '{spacing.pip-pitch}'
    count: '4, vertical'
    full: '{components.zone-roles.dusk.hp}'
    empty-outline: '{components.zone-roles.dusk.empty}'
    empty-outline-width: '{spacing.rule}'
  ember-counter:
    type: '{typography.hud-value}'
    held-icon: '{colors.chain-amber}'
    held-icon-motion: 'flicker'
    held-prefix: '+'
    held-text: '{colors.chain-amber}'
    carried-icon: '{components.zone-roles.dusk.hp}'
    carried-icon-motion: 'none (solid)'
    carried-text: '{components.zone-roles.dusk.hp}'
  chain-number:
    type: '{typography.chain-number}'
    type-step3: '{typography.chain-number-step3}'
    type-step6: '{typography.chain-number-step6}'
    type-peak: '{typography.chain-number-peak}'
    pop: '{spacing.chain-pop}'
    color: '{colors.chain-amber}'
    color-zero: '{components.zone-roles.dusk.empty}'
  chain-meter:
    segments: '20'
    segment: '{spacing.meter-segment-width} x {spacing.meter-segment-height}'
    pitch: '{spacing.meter-pitch}'
    filled: '{colors.chain-amber}'
    empty-outline: '{components.zone-roles.dusk.empty}'
    empty-outline-width: '{spacing.rule}'
  cling-grace-bar:
    width: '{spacing.grace-bar-width}'
    gap: '{spacing.grace-bar-gap}'
    color: '{components.zone-roles.dusk.hp}'  # [ASSUMPTION — default, review]
  flare-notch:
    segment: '2'
    size: '{spacing.notch-width} x {spacing.notch-height}'
    color: '{components.zone-roles.dusk.label}'
    offset: '{spacing.notch-offset}'
  flare-cost-hatch:
    pattern: '1 px diagonal lines over the lit segments a toss would remove'
    shows: 'only while a lurker is stirring or hunting and the chain is 2 or more'
    color: '{components.zone-roles.dusk.gutter}'  # [ASSUMPTION — default, review]
    pitch: '{spacing.hatch-pitch}'  # [ASSUMPTION — default, review]
  cling-cue:  # [ASSUMPTION — default, review]
    form: 'vertical bar beside the player, drains top-down'
    size: '{spacing.cling-cue-width} x {spacing.cling-cue-height}'
    gap: '{spacing.cling-cue-gap}'
    color: '{components.zone-roles.dusk.hp}'
    outline: '{components.text-outline.color}'
  alert-frame:
    width: '{spacing.alert-frame}'
    color: '{colors.predator-red}'
    pulse-max: '2 Hz'
    reduce-flashing: 'solid, no pulse'
  alert-eye:
    color: '{colors.predator-red}'
    top: '{spacing.alert-eye-top}'
    size: '{spacing.eye-width} x {spacing.eye-height}'  # [ASSUMPTION — default, review]
    art: 'open eye (see Shapes)'  # [ASSUMPTION — default, review]
  edge-cue:
    color: '{colors.predator-red}'
    glow-floor: '3:1 against zone index 0'
    form: 'half-open eye at the play-area edge, level with the lurker; opens wider as it stirs; same art as the alert eye'
    size: '{spacing.eye-width} x {spacing.eye-height}'
    inset: '{spacing.edge-cue-inset}'  # [ASSUMPTION — default, review]
    margin: '{spacing.edge-cue-margin}'  # [ASSUMPTION — default, review]
  glyph-prompt:  # [ASSUMPTION — default, review]
    type: '{typography.hud-value}'
    size: '{spacing.glyph-size}'
    max-width: '{spacing.glyph-max-width}'
    label: '{components.zone-roles.dusk.hp}'
    outline: '{components.zone-roles.dusk.hp}'
    backing: '{components.zone-roles.dusk.surface}'
    lift: '{spacing.glyph-lift}'
    clamp: '{spacing.glyph-clamp}'
  bank-popup:
    color: '{colors.chain-amber}'
    type: '{typography.hud-value}'
    lift: '{spacing.popup-lift}'  # [ASSUMPTION — default, review] bottom edge above the player sprite's top
  speech-box:
    type: '{typography.body-line}'
    frame: '[OPEN]'
  shop-list:
    item: '{components.menu-item}'
    cursor: '{components.ember-cursor}'
  ember-cursor:
    size: '{spacing.ember-icon}'
    color: '{colors.chain-amber}'
    gap: '{spacing.cursor-gap}'
  menu-item:
    type: '{typography.menu-item}'
    selected: '{components.zone-roles.dusk.hp}'
    idle: '{components.zone-roles.dusk.label}'
    pitch: '{spacing.menu-row-pitch}'
  tab:
    type: '{typography.menu-item}'
    active: '{components.zone-roles.dusk.hp}'
    idle: '{components.zone-roles.dusk.label}'
    underline: '{components.zone-roles.dusk.hp}'
    divider: '{components.zone-roles.dusk.rule}'
    pitch: '{spacing.tab-pitch}'
    left: '{spacing.tab-left}'  # [ASSUMPTION — default, review]
    top: '{spacing.tab-top}'  # [ASSUMPTION — default, review]
    not-landed: 'hidden (Pause and Options tabs alike)'
  bank-summary:
    label: '{components.zone-roles.dusk.label}'
    value: '{components.zone-roles.dusk.hp}'
    held-value: '{colors.chain-amber}'
    divider: '{components.zone-roles.dusk.rule}'
    pitch: '{spacing.summary-row-pitch}'
    left: '{spacing.bank-left}'  # [ASSUMPTION — default, review]
    right: '{spacing.bank-right}'  # [ASSUMPTION — default, review]
    top: '{spacing.bank-top}'  # [ASSUMPTION — default, review]
    divider-y: '{spacing.bank-divider-y}'  # [ASSUMPTION — default, review]
    stats-top: '{spacing.bank-stats-top}'  # [ASSUMPTION — default, review]
  controls-reference:
    type: '{typography.body-line}'
    label: '{components.zone-roles.dusk.label}'
    value: '{components.zone-roles.dusk.hp}'
    pitch: '{spacing.controls-row-pitch}'
    left: '{spacing.menu-text-x}'  # [ASSUMPTION — default, review]
    top: '{spacing.controls-top}'  # [ASSUMPTION — default, review]
    glyph-x: '{spacing.controls-glyph-x}'  # [ASSUMPTION — default, review]
  pause-note:  # [ASSUMPTION — default, review]
    type: '{typography.body-line}'
    color: '{components.zone-roles.dusk.hp}'
    left: '{spacing.menu-text-x}'
    top: '{spacing.pause-note-top}'
    width: '{spacing.pause-note-width}'
  options-control:  # [ASSUMPTION — default, review]
    item: '{components.menu-item}'
    value-right: '{spacing.value-right}'
    toggle: '{spacing.toggle-box} box plus On/Off text; On = filled, Off = 1 px outline'
    toggle-on: '{components.zone-roles.dusk.hp}'
    toggle-off: '{components.zone-roles.dusk.empty}'
    slider: '10 segments of {spacing.slider-segment-width} x {spacing.slider-segment-height} at {spacing.slider-pitch}; filled = on, 1 px outline = off; value number at the right'
    slider-filled: '{components.zone-roles.dusk.hp}'
    slider-empty: '{components.zone-roles.dusk.empty}'
    choice: 'value text between 3 x 5 arrows in the label colour; an arrow hides at the end of the list'
    value-idle: '{components.zone-roles.dusk.label}'  # [ASSUMPTION — default, review] On/Off and choice text
    value-selected: '{components.zone-roles.dusk.hp}'  # [ASSUMPTION — default, review]
    toggle-x: '{spacing.toggle-x}'  # [ASSUMPTION — default, review]
    toggle-text-width: '{spacing.toggle-text-width}'  # [ASSUMPTION — default, review]
    text-gap: '{spacing.control-text-gap}'  # [ASSUMPTION — default, review] box to text, arrow to text
  confirm-step:  # [ASSUMPTION — default, review]
    question: '{typography.body-line}'
    item: '{components.menu-item}'
    default: 'No'
    question-color: '{components.zone-roles.dusk.hp}'  # [ASSUMPTION — default, review]
    top: '{spacing.menu-top}'  # [ASSUMPTION — default, review] question row; No / Yes follow at menu-row-pitch
  menu-screen:
    background: '{components.zone-roles.dusk.surface}'
    zone-outside-play: 'dusk (title, options from title, slot picker, credits, click-to-play gate)'  # [ASSUMPTION — default, review]
  title-screen:
    item: '{components.menu-item}'
    logo: '[OPEN]'
    menu-top: '{spacing.title-menu-top}'  # [ASSUMPTION — default, review]
    gutters: 'none'  # [ASSUMPTION — default, review]
  click-to-play-gate:
    type: '{typography.body-line}'
    color: '{components.zone-roles.dusk.hp}'
    suggestion-color: '{components.zone-roles.dusk.label}'  # [ASSUMPTION — default, review]
    placement: 'centred in the 480 x 270 frame; no gutters'  # [ASSUMPTION — default, review]
  difficulty-step:
    item: '{components.menu-item}'
    text: '{typography.body-line}'
  death-card:
    type: '{typography.body-line}'
    layout: 'play area dims; cause and tip centred in the 360 px play area; ember losses in the left gutter'
    dim: '{components.zone-roles.dusk.surface} at 70% over the play area'  # [ASSUMPTION — default, review]
    width: '{spacing.death-text-width}'  # [ASSUMPTION — default, review]
    cause: '{components.zone-roles.dusk.hp}'  # [ASSUMPTION — default, review]
    tip: '{components.zone-roles.dusk.label}'  # [ASSUMPTION — default, review]
    tier-line: '{components.zone-roles.dusk.label}'  # [ASSUMPTION — default, review] colour; copy decided
    tier-copy: 'Normal: Embers left below. Once. / Hard: Nothing left below. / Easy: none'
    held-zero: '+0; on Easy the held icon stays solid and still'  # [ASSUMPTION — default, review]
  station-menu:
    item: '{components.menu-item}'
    cursor: '{components.ember-cursor}'
    placement: 'replaces the play area only; gutters stay'  # [ASSUMPTION — default, review]
    background: '{components.menu-screen.background}'
    bank: '{components.bank-summary}'
    text-x: '{spacing.station-text-x}'  # [ASSUMPTION — default, review] keeps the cursor out of the gutter
    total-top: '{spacing.station-total-top}'  # [ASSUMPTION — default, review]
    items-top: '{spacing.menu-top}'  # [ASSUMPTION — default, review]
  map-tab:
    visited: '[OPEN]'
    revealed-unvisited: 'dotted outline'
  journal-tab:
    type: '{typography.body-line}'
    new-mark: '[OPEN]'
  guild-records-board:
    spec: '[OPEN]'
  slot-picker:
    item: '{components.menu-item}'
    cursor: '{components.ember-cursor}'
    details: '{typography.body-line}'
    pitch: '{spacing.slot-row-pitch}'  # [ASSUMPTION — default, review]
    top: '{spacing.menu-top}'  # [ASSUMPTION — default, review]
    details-offset: '{spacing.line-pitch}'  # [ASSUMPTION — default, review] line 2 below line 1
    details-color: '{components.zone-roles.dusk.label}'  # [ASSUMPTION — default, review]
    empty-text: 'Slot N — Empty'
    empty-label: '{components.zone-roles.dusk.label}'  # [ASSUMPTION — default, review]
    confirm: '{components.confirm-step}'
  credits-screen:
    type: '{typography.body-line}'
  autosave-icon:
    art: 'lantern, 7 x 7 (see Shapes)'  # [ASSUMPTION — default, review]
    size: '{spacing.autosave-icon}'  # [ASSUMPTION — default, review]
    top: '{spacing.autosave-top}'  # [ASSUMPTION — default, review]
    color: '{components.zone-roles.dusk.hp}'  # [ASSUMPTION — default, review]
    failed: 'same icon crossed by a 1 px diagonal stroke; field note "Not saved"'
    failed-color: '{components.zone-roles.dusk.hp}'  # [ASSUMPTION — default, review] cross and note
    note: '{typography.body-line}'
  large-hud:
    icon: '{spacing.large-icon}'
    ember-icon: '{spacing.large-ember-icon}'
    number: '{typography.hud-value-large}'
    stack-top: '{spacing.large-stack-top}'
---

# DESIGN.md — The Unbroken Chain

The GDD owns the game's art direction (GDD Art and Audio Direction). This file owns the look of the UI: HUD, menus and screen text. EXPERIENCE.md owns behaviour and copy.

**The spines win.** If any mock disagrees with DESIGN.md or EXPERIENCE.md, the spines are the contract and the mock is wrong.

Key-screen mocks are drawn at 480×270 native, shown at ×2. Each page lists the spine sections it shows and what it assumed.

- [In-game HUD](mockups/key-hud.html): normal, lurker alert, cling, bank, Dusk zone, large HUD, save failed.
- [Death card](mockups/key-death-card.html): Normal (cache dropped), Normal (cache gone), Easy, Hard.
- [Title and slot picker](mockups/key-title-slots.html): title, Load slot picker, delete confirm.
- [Pause and Options](mockups/key-pause-options.html): Pause tab (E1), Options > Accessibility, control specimens, save-failure note.
- [Station rest and menu](mockups/key-station-menu.html): rest count-up, station menu, Fast travel list.
- [Click-to-play gate](mockups/key-web-gate.html): gate at ×2, gate below ×2 with the fullscreen suggestion.

Exploration mocks record how decisions were made. They are not spec.

- [HUD placement mock, variant C](.working/hud-chain-placement-2026-11-10.html): side-gutter HUD (chosen). Geometry source.
- [UI colour themes mock, theme C](.working/ui-color-themes-2026-11-10.html): zone-matched colours (chosen). Colour source.
- [Menu directions mock, direction B](.working/menu-directions-2026-11-10.html): ember cursor (chosen).
- [Font candidates](.working/font-candidates-2026-11-11.html): four 8 px faces rendered in the gutter strip, the Dusk menu and at Deck size; Fusion Pixel Font 8px chosen (O1).

## Brand & Style

Dark screens lit by a small warm light. The UI is quiet, flat and pixel-exact, so the chain-light stays the brightest thing on screen. It borrows Downwell's minimal side gutters and big chain number, and Celeste's crisp, nearly invisible HUD and plain menus.

Two colours carry meaning everywhere: amber is the player and red is a predator. Every other UI colour comes from the current palette zone, so the HUD darkens and cools with the world as you descend (GDD "daylight fades as you descend").

## Colors

### Reserved

| Token | Hex | Used for | Never used for |
|---|---|---|---|
| `chain-amber` | `#ffd27a` | Chain number, filled meter segments, the held ember icon and count, bank popup, the ember cursor | Anything not the player's light |
| `predator-red` | `#d9473f` | Alert frame and alert eye, off-screen edge cue | Damage, errors, low HP, decoration, text |

The ember cursor counts as the player's lantern, so amber is allowed in menus (log 2026-11-10; [NOTE FOR GDD] in EXPERIENCE.md). Carried embers use the zone HP colour, so held and carried look different (theme C). The M1 code uses `#ff594d` for the alert. It must move to `{colors.predator-red}`.

### Layer 1 zones

| Zone | Segments | 0 | 1 | 2 | 3 | Gutter |
|---|---|---|---|---|---|---|
| Dusk | S1, A | `#2b1d14` | `#6b4a2f` | `#b08a5a` | `#d8c3a0` | `#18100b` |
| Umber | S2–S3 | `#1e1714` | `#4a3a33` | `#7d6a5c` | `#a99a8c` | `#110d0b` |
| Cold violet | S4–S5, B, C | `#0d0b14` | `#2a2440` | `#4f5d75` | `#a9b4c2` | `#07060b` |

The GDD leaves the hub and Layer 2 palettes open. Their UI tokens are added when the palettes exist, and must pass the same floors.

### Zone-matched UI roles

Each role has one token per zone (`ui-<role>-<zone>`), mapped in `components.zone-roles.<zone>`. Swap the zone part for the active zone.

| Role | Tokens | Base index | Used for |
|---|---|---|---|
| HP | `ui-hp-*` | 3 | Full HP pips, carried count and icon, selected menu item, active tab, bank values |
| Label | `ui-label-*` | 2, lightened where needed | Gutter icons, idle menu items, idle tabs, bank labels, flare notch |
| Empty | `ui-empty-*` | 1, lightened | Empty pip and segment outlines, chain number at 0 |
| Rule | `ui-rule-*` | 1 | 1 px rules and dividers (decorative) |
| Surface | `zone-*-0` | 0 | Menu screen background |
| Gutter | `gutter-*` | 0 at 55% | Gutter fill |

### Contrast floors

Floors (log 2026-11-11): **4.5:1 for text, 3:1 for UI shapes**. Each role is checked against the zone's gutter fill and against its play area (zone index 0, the darkest world colour, which is also the menu surface). A role that misses gets a UI-only override: the zone colour blended toward its index 3 by the smallest step that passes both. Overrides keep the zone's hue.

| Zone | Role | Hex | On gutter | On play area | Floor | Note |
|---|---|---|---|---|---|---|
| Dusk | HP | `#d8c3a0` | 10.94 | 9.49 | 4.5 | index 3 |
| Dusk | Label | `#b08a5a` | 5.93 | 5.14 | 4.5 | index 2, no override |
| Dusk | Empty | `#836548` | 3.51 | 3.04 | 3.0 | override (index 1 was 2.37 / 2.05) |
| Umber | HP | `#a99a8c` | 7.08 | 6.47 | 4.5 | index 3 |
| Umber | Label | `#8f7e70` | 4.96 | 4.53 | 4.5 | override (index 2 was 3.76 / 3.44) |
| Umber | Empty | `#726258` | 3.32 | 3.03 | 3.0 | override (index 1 was 1.79 / 1.64) |
| Cold violet | HP | `#a9b4c2` | 9.61 | 9.30 | 4.5 | index 3 |
| Cold violet | Label | `#6e7b8f` | 4.71 | 4.55 | 4.5 | override (index 2 was 3.03 / 2.93) |
| Cold violet | Empty | `#5c5c73` | 3.11 | 3.01 | 3.0 | override (index 1 was 1.37 / 1.33) |

Label carries the text floor because it also colours idle menu text. Empty carries the shape floor. The chain number at 0 uses Empty too; at 24 px or more it counts as large text, where 3:1 applies.

| Constant colour | Dusk gutter / play | Umber gutter / play | Violet gutter / play | Use |
|---|---|---|---|---|
| `chain-amber` | 13.20 / 11.45 | 13.58 / 12.42 | 14.19 / 13.72 | text and shapes |
| `predator-red` | 4.40 / 3.82 | 4.53 / 4.14 | 4.73 / 4.58 | shapes only (frame, eye, edge cue) |

Edge cue glow floor: at its peak, the glow must reach 3:1 against zone index 0. Over a flat zone 0 that takes about 83% predator red in Dusk (`#bb4038`, 3.03:1), 79% in Umber (`#b23d36`, 3.04:1) and 75% in Cold violet (`#a63834`, 3.01:1). The eye itself is solid predator red.

Rules and dividers stay at index 1 (1.3–2.4:1). [ASSUMPTION] They are decorative, so the shape floor does not apply.

## Typography

| Rule | Value |
|---|---|
| Fonts | One pixel font for HUD and menus |
| Grid | 8 px grid; base size `{typography.hud-value.fontSize}` |
| Face | **Fusion Pixel Font 8px, proportional (latin build)**, `{typography.hud-value.fontFamily}` (decided 2026-11-11, O1). Godot font size 8, antialiasing and hinting off. Metrics: cap 6, x-height 4, descender 2 (6 + 2 fills the 8 px row). Digits are 5 px, uniform width, so counters do not jitter. The Deck-size check still runs in E1 with this face. |
| Text blocks | `{typography.body-line}`: 8 px glyphs on a 12 px line pitch. Used by the death card, speech box, journal entries, slot details, controls reference and credits. |
| Single lines | HUD values and menu items stay 8 / 8; menu rows sit at `{spacing.menu-row-pitch}`. |
| Chain number | Digits 0–9 hand-pixelled at four heights, because an 8 px font scales cleanly only to 24 and 32. 0–2 links `{typography.chain-number}` (24 px), 3–5 `{typography.chain-number-step3}` (26 px), 6–9 `{typography.chain-number-step6}` (28 px), 10+ `{typography.chain-number-peak}` (32 px). Two digits at 32 px are about 42 px wide and fit the 58 px usable gutter. Glyphs are never scaled by fractions. At a step, the new size replaces the old in one frame, then the pop runs. Pop: on each link the number moves up `{spacing.chain-pop}` for 67 ms (4 frames at 60 fps), then returns. [ASSUMPTION — default, review] |
| Gutter text | None. Gutter labels are icons; only numbers remain. |
| Text in sprites | None. All text is rendered from the string table. |

**Measured widths** (Fusion 8 px, from the [font candidates page](.working/font-candidates-2026-11-11.html)) against the `{spacing.gutter-usable}` usable gutter:

| String | Width | Where | Fits |
|---|---|---|---|
| `0123456789` | 50 px | Any gutter number | Yes |
| `+999` (held row) | about 20 px, from x 22 to x 42 | Left gutter | Yes |
| `+1240` (held row) | about 25 px, to x 47 | Left gutter | Yes |
| `x12 +24` (bank popup) | 33 px | Play area | Yes |
| `EMBERS` (old text label) | 31 px | Not used; labels are icons | n/a |

Licence: SIL OFL 1.1. The font may ship inside the game but may not be sold on its own; `OFL.txt` and the upstream `LICENSES/` folder ship with every build (see the [NOTE FOR ARCHITECTURE] in EXPERIENCE.md Notes for Other Docs).

Coverage: Latin-1 and Latin Extended-A are covered. The 8 px build lacks stacked Vietnamese marks (ầ ồ ở) and Cyrillic. Vietnamese is not needed now (English first, log 2026-11-11); a later localisation could use the Fusion 10 px or 12 px builds from the same release.

**Text outline** [ASSUMPTION — default, review]: text and cues drawn over the play area get a `{spacing.text-outline}` outline on 4 sides (no diagonals) in the zone surface colour (`{components.text-outline.color}`). This covers the bank popup, death card text, the "Not saved" note and the cling cue. Glyph prompt labels sit on a backing, so they are exempt. Gutter and menu text sit on flat fills and get no outline.

## Layout & Spacing

- Native canvas `{spacing.native-width}` × `{spacing.native-height}`. Whole-number scaling only (×2, ×3, ×4), nearest filtering, letterboxed (GDD Platform-Specific Details). The itch embed is `{spacing.embed-width}` × `{spacing.embed-height}` (×2).
- Two side gutters of `{spacing.gutter-width}` frame a play area of `{spacing.play-area-width}`. Each gutter has two 1 px rules in the zone's index-1 colour: the inner rule on the play-area edge and the outer rule (`{spacing.outer-rule}`, decided 2026-11-11, O17) on the letterbox edge, so the frame reads against black letterboxing. Usable gutter width is `{spacing.gutter-usable}` (left gutter x 1–58, right gutter x 421–478). Gutters appear everywhere, including the hub and the Weaver arena.
- Menus use the same 360 px column, from x = 60 to x = 420.

### Gutter HUD coordinates (native px)

Geometry comes from the [HUD mock C](.working/hud-chain-placement-2026-11-10.html) (exploration) and colours from the [theme mock C](.working/ui-color-themes-2026-11-10.html) (exploration). The [HUD key mock](mockups/key-hud.html) renders both.

| Element | Gutter | Position |
|---|---|---|
| Heart icon | Left | 7 × 7, centred x 30, top y `{spacing.icon-top}` |
| HP pips ×4 | Left | x 26, y 24 + 10·n (n = 0–3), ends y 60 |
| Ember icon (section) | Left | None. The row icons act as the header; y 80 stays empty. [ASSUMPTION — default, review] |
| Held row | Left | Flickering icon x 14, y 96; `+N` text x 22, y 95 |
| Carried row | Left | Solid icon x 14, y 108; text x 22, y 107 |
| Autosave icon | Left | 7 × 7, centred x 30, top y `{spacing.autosave-top}` [ASSUMPTION — default, review] |
| Chain icon | Right | 7 × 7, centred x 450, top y `{spacing.icon-top}` |
| Chain number | Right | Centred x 450, top y `{spacing.value-top}` (ends by y 56 at 32 px) |
| Alert eye | Right | Centred x 450, top y `{spacing.alert-eye-top}` |
| Chain meter | Right | x 444; segment n top at y 258 − 9·(n − 1); segment 1 spans y 258–263, segment 20 top is y 87 |
| Cling grace bar | Right | x 440–441, `{spacing.grace-bar-gap}` left of the meter, alongside the lit segments |
| Flare notch | Right | x 458, beside segment 2 (y 249–254) |
| Alert frame | Both | 1 px predator-red border around each gutter's edges, drawn over the inner and outer rules while it shows |

[ASSUMPTION] This file sets these layout values: the 7 × 7 heart and chain link icons, the alert-eye spot, the 2 px grace bar and the 1 px frame. Default icon art is in Shapes and may be redrawn to match Fusion Pixel Font.

### In-world UI positions (native px) [ASSUMPTION — default, review]

| Element | Position |
|---|---|
| Cling cue | `{spacing.cling-cue-width}` × `{spacing.cling-cue-height}`, `{spacing.cling-cue-gap}` outside the player sprite on the side away from the wall, top level with the sprite's head |
| Off-screen edge cue | Eye `{spacing.edge-cue-inset}` inside the play-area edge (x 62 left, x 411 right), level with the lurker, clamped `{spacing.edge-cue-margin}` from the top and bottom of the play area. Stays on the play-area side of the gutter rule. |
| Glyph prompt | Centred above the object, bottom edge `{spacing.glyph-lift}` above the object's top; clamped `{spacing.glyph-clamp}` inside the play area (x 64–416, y ≥ 4) |
| "Not saved" note | Bottom-left of the play area, x 64, level with the autosave icon |
| Death card text | Centred in the play area, `{spacing.death-text-width}` wide (16 px margins), block centred vertically. See the [death card mock](mockups/key-death-card.html). |
| Bank popup | Bottom edge `{spacing.popup-lift}` above the top of the player sprite, centred on it, then rises (HUD mock). [ASSUMPTION — default, review] |

### Menu positions (native px) [ASSUMPTION — default, review]

The key mocks set these positions (log 2026-11-11, mock gap defaults). Text x is `{spacing.menu-text-x}` unless stated; y is the top of the text row.

| Screen | Element | Position |
|---|---|---|
| Title ([mock](mockups/key-title-slots.html)) | Menu items | First row y `{spacing.title-menu-top}`, then `{spacing.menu-row-pitch}`. No gutters on the title. |
| Slot picker ([mock](mockups/key-title-slots.html)) | Slot rows | First row y `{spacing.menu-top}`, rows at `{spacing.slot-row-pitch}`; details line `{spacing.line-pitch}` below line 1 |
| Confirm step ([mock](mockups/key-title-slots.html)) | Question, No / Yes | Question at y `{spacing.menu-top}`; No and Yes on the next two menu rows |
| Pause and Options ([mock](mockups/key-pause-options.html)) | Tabs | Labels from x `{spacing.tab-left}`, top y `{spacing.tab-top}`, at `{spacing.tab-pitch}`; underline y `{spacing.tab-underline-y}`; divider y `{spacing.tab-divider-y}` across x 60–420 |
| Pause tab | Menu items | First row y `{spacing.menu-top}`, then `{spacing.menu-row-pitch}` |
| Pause tab | Bank summary | x `{spacing.bank-left}`–`{spacing.bank-right}` (value right-aligned); rows from y `{spacing.bank-top}` at `{spacing.summary-row-pitch}`; divider y `{spacing.bank-divider-y}`; depth and best chain from y `{spacing.bank-stats-top}` |
| Pause tab | Controls reference | Action at x `{spacing.menu-text-x}`, glyph column x `{spacing.controls-glyph-x}`, from y `{spacing.controls-top}`, rows at `{spacing.controls-row-pitch}` (decided: 12 px keycaps need more than the 12 px body pitch) |
| Pause tab | Pause note | x `{spacing.menu-text-x}`, y `{spacing.pause-note-top}`, wrapped to `{spacing.pause-note-width}` so it clears the bank column |
| Options | Rows | First row y `{spacing.menu-top}`; value right edge x `{spacing.value-right}`; toggle box x `{spacing.toggle-x}` (a `{spacing.toggle-text-width}` On/Off slot keeps boxes aligned); `{spacing.control-text-gap}` from box or arrow to text |
| Station menu ([mock](mockups/key-station-menu.html)) | Deposited total, items | Deposited row at x `{spacing.station-text-x}`, y `{spacing.station-total-top}`, value right-aligned at x 400; items from y `{spacing.menu-top}` at `{spacing.menu-row-pitch}`. Text x is `{spacing.station-text-x}` because at x 64 the ember cursor would sit at x 50, inside the left gutter. |
| Click-to-play gate ([mock](mockups/key-web-gate.html)) | Lines | Centred at x 240; one line at y 131; with the fullscreen suggestion, two lines at y 125 and 137 |

### Large HUD layout (native px)

An Accessibility option (EXPERIENCE.md). It doubles only numbers and icons. Pips, meter, notch, grace bar and frame keep their ×1 size. The ember block moves into the empty lower left gutter. The meter fills the lower right gutter, so nothing stacks there.

| Element | Gutter | Position |
|---|---|---|
| Heart icon | Left | 14 × 14, centred x 30, y 8–21 |
| HP pips ×4 | Left | x 26, y 28 + 10·n, ends y 64 (×1 size) |
| Held icon | Left | 10 × 10, centred x 30, top y `{spacing.large-stack-top}`, flickers (no section icon, as in the default layout) |
| Held `+N` | Left | `{typography.hud-value-large}`, centred x 30, top y 132 |
| Carried icon | Left | 10 × 10, centred x 30, top y 154, solid |
| Carried count | Left | `{typography.hud-value-large}`, centred x 30, top y 166 (block ends near y 182) |
| Chain icon | Right | 14 × 14, centred x 450, y 8–21 |
| Chain number | Right | Top y 26, sizes unchanged |
| Alert eye | Right | ×2, centred x 450, top y 66 |
| Meter, notch, grace bar | Right | As the default layout |

[ASSUMPTION] "Numbers doubled" means the 8 px numbers. The chain number is already 24–32 px; doubled, `20` would be about 96 px wide and would not fit in 58 px.

Rechecked with Fusion's 5 px digits (2026-11-11): at 16 px, `+999` is about 40 px and `+1240` about 50 px; both fit the 58 px usable gutter. Six characters (`+12400`) are about 60 px and do not. [OPEN] Ember display above 4 digits in the large HUD (O12).

## Elevation & Depth

Flat. The UI has no shadows or gradients. Depth comes from three layers:

1. World (play area).
2. Gutters and in-world UI: glyph prompts, the cling cue, the off-screen edge cue.
3. Full-screen menus, which replace the view (pause never stacks). The speech box sits inside the play area. The station menu and the death card replace or dim only the play area, and the gutters stay.

The menu's "lantern glow" is the ember cursor alone, with no halo or light band (directions A and C were rejected).

## Shapes

All corners are square: `{rounded.none}`. Shapes are whole-pixel rectangles. The ember is a 5 × 5 blob (rows 3-5-5-5-3). Rules and outlines are 1 px.

Empty states are outlines, never dim fills. An empty pip or meter segment is a 1 px outline of its full size in the zone's empty colour.

Default icon art, `X` = drawn pixel. [ASSUMPTION — default, review]

```
Heart 7×7      Chain link 7×7   Eye open 7×5   Eye half 7×3   Lantern 7×7
.XX.XX.        ..XXX..          ..XXX..        .XXXXX.        ..XXX..
XXXXXXX        .X...X.          .X...X.        X..X..X        .X...X.
XXXXXXX        .X...X.          X..X..X        .XXXXX.        .X.X.X.
XXXXXXX        .X...X.          .X...X.                       .X.X.X.
.XXXXX.        .X...X.          ..XXX..        Eye closed     .X...X.
..XXX..        .X...X.                         7×1: XXXXXXX   .XXXXX.
...X...        ..XXX..                                        ..X.X..
```

The off-screen edge cue steps closed → half → open as the lurker stirs. The alert eye in the gutter uses the open frame. The crossed autosave icon adds a 1 px diagonal across the lantern, from top-left to bottom-right.

## Components

Visual specs only. EXPERIENCE.md Component Patterns gives behaviour and copy for the same components, under the same names.

| Component | Visual spec |
|---|---|
| Gutter | Flat `zone-roles.<zone>.gutter` strip, `{spacing.gutter-width}` wide, with a 1 px rule in `zone-roles.<zone>.rule` on the play-area edge and a matching `{spacing.outer-rule}` outer rule on the letterbox edge (decided 2026-11-11, O17). Fill and rules cross-fade with the zone (EXPERIENCE Game Feel & Juice). |
| Gutter icon | Heart (HP), ember (embers), chain link (chain), in the label colour. They replace the old HP / EMBERS / CHAIN text labels. Art in Shapes. No ember section icon: the held and carried row icons act as the header. [ASSUMPTION — default, review] |
| Text outline | See Typography. [ASSUMPTION — default, review] |
| HP pip | 4 squares of `{spacing.pip-size}` at `{spacing.pip-pitch}`, vertical. Full = filled in the HP colour. Empty = 1 px outline in the empty colour. No alert recolour. |
| Ember counter | Two rows. Held: a flickering amber icon and `+N` in amber. Carried: a solid icon (no flicker) and the count in the HP colour. No alert recolour. Deposited embers never show here. |
| Chain number | Large amber digits centred in the right gutter; the empty colour at 0. No alert recolour. Sizes and pop in Typography. |
| Chain meter | 20 vertical segments of 12 × 6 at 9 px pitch, filling bottom to top to the cap. Filled = amber; empty = 1 px outline in the empty colour. Links stay lit during cling. |
| Cling grace bar | A 2 px vertical bar left of the meter, shown only while clinging. It drains top-down while the cling lasts. It uses the HP colour so it reads apart from the amber links. [ASSUMPTION — default, review] |
| Flare notch | 3 × 6 mark in the label colour, 2 px right of segment 2. |
| Flare cost hatch | Diagonal hatch on the lit segments a toss would take (the top half of the lit stack, rounding per GDD Flare Toss). Shown only while a lurker is stirring or hunting and the chain is ≥ 2 (log 2026-11-11). The hatch is 1 px lines from top-left to bottom-right every `{spacing.hatch-pitch}`, in the zone gutter colour over the amber fill. [ASSUMPTION — default, review] for colour and pitch. |
| Cling cue | A `{spacing.cling-cue-width}` × `{spacing.cling-cue-height}` vertical bar beside the player, on the side away from the wall, in the HP colour with the text outline. It drains top-down in step with the grace bar. [ASSUMPTION — default, review] |
| Alert frame | A 1 px predator-red border on both gutters that pulses at 2 Hz or slower. Paired with the alert eye, it uses shape, motion and colour. Under reduce flashing it stays solid with no pulse (log 2026-11-11). |
| Alert eye | The open eye (Shapes), `{spacing.eye-width}` × `{spacing.eye-height}`, predator red, in the right gutter, shown with the frame. [ASSUMPTION — default, review] for the art. |
| Off-screen edge cue | A small half-open predator-red eye at the play-area edge, level with the lurker, that opens wider as it stirs. It uses the alert eye's art (log 2026-11-11) and sits on the play-area side of the gutter rule. A red glow that meets the glow floor (Colors) goes with it. Position in Layout & Spacing. |
| Glyph prompt | A keycap: a `{spacing.glyph-size}` square with a 1 px outline and an 8 px label in the HP colour, filled with the zone surface colour as a backing, so it needs no text outline. Long keys (Esc, Enter, Space) widen to fit the label plus 4 px, up to `{spacing.glyph-max-width}`. Arrows are 5 × 5 arrow icons. Gamepad face buttons use the same box with the corner pixels removed and a generic letter (A, B, X, Y); sticks and d-pad use 5 × 5 direction icons. No brand colours. [ASSUMPTION — default, review] |
| Bank popup | Amber text `x{links} +{embers}` (e.g. "x12 +24") above the player as a chain banks, with the text outline. 8 px, or 10 px at 10+ links. Kept from M1. It starts `{spacing.popup-lift}` above the player [ASSUMPTION — default, review]. Motion in EXPERIENCE Game Feel & Juice. |
| Speech box | Bottom of the 360 px play area, name tag, one line at a time, no portraits, body-line type. [OPEN] Frame, height and name-tag style. |
| Shop list | Menu items and the ember cursor, with the deposited total and prices. [OPEN] Layout. |
| Menu item | `{typography.menu-item}`, rows at `{spacing.menu-row-pitch}`, text x `{spacing.menu-text-x}`. Selected = HP colour, idle = label colour. No glow. |
| Ember cursor | 5 × 5 amber ember, `{spacing.cursor-gap}` left of the selected item's text, flickering by 1 px. |
| Tab | Labels at `{spacing.tab-pitch}` pitch. Active = HP colour with a 1 px underline; idle = label colour. A full-width 1 px rule sits below as a divider. Tabs that have not landed are hidden, in Pause as in Options (log 2026-11-11). [Mock](mockups/key-pause-options.html). |
| Bank summary | Label left in the label colour, value right in the HP colour, held value in amber, rows at `{spacing.summary-row-pitch}`, with a 1 px divider between bank and stats. No heading. Positions in Menu positions. |
| Controls reference | Two columns: the action in the label colour and the binding glyph in the HP colour, body-line type, rows at `{spacing.controls-row-pitch}` (log 2026-11-11). Glyph art as Glyph prompt. |
| Pause note | The save-failure explanation: body-line text in the HP colour under the Pause tab items, no icon. [ASSUMPTION — default, review] |
| Options control | Menu items with the value right-aligned at x `{spacing.value-right}`. Toggle: a `{spacing.toggle-box}` box plus "On" / "Off"; On = filled in the HP colour, Off = 1 px outline in the empty colour. Slider: 10 segments of `{spacing.slider-segment-width}` × `{spacing.slider-segment-height}` at `{spacing.slider-pitch}` (49 px), filled = HP colour, empty = outlines, with the value number to the right. Choice list: value text between 3 × 5 arrows in the label colour; an arrow hides at the end of the list. On/Off and choice text use the label colour, and the HP colour on the selected row. [ASSUMPTION — default, review] [Mock](mockups/key-pause-options.html). |
| Confirm step | Replaces the current menu's items in place, with no box and no stacking: one body-line question in the HP colour, then No / Yes as menu items, No selected by default. Used by Quit, slot overwrite and slot delete. [ASSUMPTION — default, review] |
| Menu screen | Surface fill of the current zone. Outside play (title, Options from the title, slot picker, credits, click-to-play gate) it uses Dusk, the game's opening zone. [ASSUMPTION — default, review] |
| Title screen | Logo over a dark, slowly scrolling live shaft; menu items with the ember cursor; no gutters [ASSUMPTION — default, review]. [OPEN] Logo art. [Mock](mockups/key-title-slots.html). |
| Click-to-play gate | One line of body text in the HP colour on the menu surface, centred, no gutters. When the window is below ×2 it adds a fullscreen suggestion as a second body line in the label colour. [ASSUMPTION — default, review] for placement and the suggestion colour. [Mock](mockups/key-web-gate.html). |
| Difficulty step | Three menu items plus one body-line text block on death cost. |
| Death card | The play area dims to the zone surface at 70%. The death line (cause and tip) is centred in the 360 px play area, `{spacing.death-text-width}` wide, in body-line type with the text outline: cause in the HP colour, tip in the label colour. The tier line is a third body line under the tip, in the label colour (log 2026-11-11); copy per tier is in EXPERIENCE State Patterns. On Normal, the "cache gone" line follows the tier line. Ember losses show in the left gutter (log 2026-11-11): the held and carried rows count to their new values over 500 ms, and a row that lost everything shows its icon as an outline. A held row at zero shows `+0`; on Easy its icon stays solid and still. [ASSUMPTION — default, review] for the dim, colours, width, the `+0` row and the tier-line colour. [Mock](mockups/key-death-card.html). |
| Station menu | Replaces the play area only. The gutters stay, so the healed HP shows. Surface fill; the deposited total from the bank summary at the top, then Descend / Fast travel / Leave with the ember cursor. The Fast travel list replaces the items in place. Text sits at x `{spacing.station-text-x}` so the cursor stays out of the gutter. [ASSUMPTION — default, review] [Mock](mockups/key-station-menu.html). |
| Map tab | Room boxes with doors. Unvisited rooms that the Cartographer reveals are dotted outlines. Icons for stations, anchors, Ember Cache, chain gates. [OPEN] Room colours and icon art. |
| Journal tab | Entries in body-line type; new entries carry a "new" mark. [OPEN] Entry layout and mark art. |
| Guild records board | [OPEN] In-world board or menu panel. |
| Slot picker | 3 rows at `{spacing.slot-row-pitch}`. Line 1 is "Slot N" as a menu item. Line 2, in body-line type and the label colour, gives depth · best chain · play time · difficulty, e.g. "Depth S3 · Best chain 17 · 2:14 · Normal" (play time h:mm). An empty slot shows line 1 only, in the label colour (copy in EXPERIENCE Component Patterns). [ASSUMPTION — default, review] for colours and the details format. [Mock](mockups/key-title-slots.html). |
| Credits screen | Body-line text on the menu surface, including the AI disclosure line. |
| Autosave icon | A 7 × 7 lantern (Shapes) in the HP colour at the bottom of the left gutter (Layout & Spacing). On a failed save it becomes the crossed lantern, and the field note "Not saved" shows at the bottom-left of the play area (log 2026-11-11). The cross and the note use the HP colour. [ASSUMPTION — default, review] for art, position and colour. [Mock](mockups/key-hud.html). |
| Large HUD | The large HUD layout in Layout & Spacing. |

## Do's and Don'ts

- Do keep amber for the player's light and red for predators. Nothing else uses them.
- Do take every other UI colour from the active zone's role tokens.
- Do meet 4.5:1 for text and 3:1 for UI shapes against the gutter and the play area. Add a UI-only override when a zone misses.
- Do keep every HUD element inside the gutters. Only these cover the play area: in-world UI (glyph prompts, the cling cue, the off-screen edge cue, the bank popup, the "Not saved" note), the speech box, the death card and the station menu.
- Do draw empty states as outlines.
- Do snap everything to whole pixels and scale by whole numbers only.
- Don't add gradients, rounded corners or shadows to the UI. The only glow is the off-screen edge cue, which the GDD requires.
- Don't recolour HUD values for alerts. The alert is the gutter frame and eye.
- Don't flash the HUD. The alert frame pulses at 2 Hz or slower, pips blink at 2.5 Hz, and nothing exceeds 3 flashes per second. Reduce flashing makes both steady (EXPERIENCE.md Game Feel & Juice).
- Don't use colour as the only signal. Alert, empty, held, cost (hatch) and save-failed (cross) states also change shape or motion.
- Don't put text in the gutters, except numbers.
- Don't show a completion percentage anywhere (GDD Exploration Rewards).
- Don't bake text into sprites.

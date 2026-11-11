# HUD Legibility Review: The Unbroken Chain UX spines

- Date: 2026-11-10
- Reviewer stance: adversarial, legibility only
- Reviewed: `DESIGN.md`, `EXPERIENCE.md`, `.decision-log.md` (canonical), and the chosen mocks: `.working/hud-chain-placement-2026-11-10.html` (C), `.working/ui-color-themes-2026-11-10.html` (C), `.working/menu-directions-2026-11-10.html` (B)
- The spines were not edited. The fixes below are options, not decisions.

## Method and measured facts

- I read the geometry from the mocks' canvas code (`drawC`, theme `draw`, menu `base`/`drawB`).
- I measured text with the actual Silkscreen TTF (Google Fonts OFL), using PIL `getlength`/`getbbox`. Silkscreen is a placeholder, but any 8 px-grid pixel font will be close.
- **"8 px text" has 5 px of ink.** At 8 px, Silkscreen caps are 5 px tall, about 4–5 px wide, with 1 px tracking. That is roughly 5–6 px advance per glyph. The em box has about 4 px of empty space above the caps, and accents (É) rise to row 1. At 24 px the chain number has 15 px of ink; at 32 px it has 20 px.
- Measured widths at 8 px: `HP` 12, `CHAIN` 28, `EMBERS` 35, `+24` 19, `1240` 23, `+1240` 30, `Accessibility` 67, `Barrierefreiheit` 81, `SPACE` 29. At 32 px, `20` is 48 and `12` is 44. At 16 px (HUD ×2), `EMBERS` is 70, `CHAIN` 56 and `+1240` 60.
- Usable gutter width is **59 px**: the left gutter is x 0–58 with its rule at 59, and the right gutter is x 421–479 with its rule at 420.
- Legibility yardstick: a character height of about **16 arcmin minimum and 20–22 arcmin preferred** (the usual human-factors guidance for text).
- Contrast is WCAG relative luminance. The colour-vision-deficiency (CVD) figures use Machado 2009 matrices at severity 1.0.

### Physical size and visual angle per display

The visual angle is for the ink height: 5 px for 8 px text, and 15 or 20 px for the chain number.

| Display / scale | 1 game px | 8 px text (5 px caps) | HP pip 7 px | Meter seg 12×6 | Ember 5×5 | Chain # 24 / 32 |
|---|---|---|---|---|---|---|
| Steam Deck 7" 1280×800, ×2, 30 cm | 0.236 mm | 1.18 mm / **13.5′** | 1.65 mm / 18.9′ | 2.8×1.4 mm | 1.18 mm / 13.5′ | 40′ / 54′ |
| Steam Deck ×2, 40 cm | 0.236 mm | **10.1′** | 14.2′ | — | 10.1′ | 30′ / 40′ |
| 14" 1080p laptop @150%, 960×540 iframe, HiDPI on → ×3, 55 cm | 0.484 mm | 2.42 mm / 15.1′ | 21.2′ | 5.8×2.9 mm | 15.1′ | 45′ / 61′ |
| Same laptop, 640×360 iframe, HiDPI on → ×2 | 0.323 mm | **10.1′** | 14.1′ | — | 10.1′ | 30′ / 40′ |
| Same laptop, 640×360 iframe, HiDPI off → ×1 (then browser stretch ×1.5) | 0.242 mm | 1.21 mm / **7.6′** | 10.6′ | 2.9×1.5 mm | **7.6′** | 23′ / 30′ |
| 15.6" 1366×768 @100%, 960×540 iframe → ×2, 55 cm | 0.506 mm | 2.53 mm / 15.8′ | 22.1′ | 6.1×3.0 mm | 15.8′ | 47′ / 63′ |
| 15.6" 1366×768 @100%, 640–959 px iframe → ×1 | 0.253 mm | 1.26 mm / **7.9′** | 11.1′ | 3.0×1.5 mm | **7.9′** | 24′ / 32′ |
| 24" 1080p desktop, ×3 window (M1 default), 65 cm | 0.830 mm | 4.15 mm / 22.0′ | 30.7′ | 10×5 mm | 22.0′ | 66′ / 88′ |
| 24" 1080p fullscreen ×4, 65 cm | 1.107 mm | 5.53 mm / 29.3′ | 41′ | 13×7 mm | 29.3′ | 88′ / 117′ |

**Takeaway:** 8 px text is comfortable only on desktop at ×3 or ×4. It is borderline at a web ×2 or ×3 and below the minimum on Deck ×2. At ×1 it is about half the minimum. The chain number and the meter read everywhere. Pips and the ember icon become marginal at ×1 and on Deck at arm's length.

### Contrast checks the spines do not show

| Pair | Dusk | Umber | Cold violet |
|---|---|---|---|
| **Alert: red full pip/segment vs empty (zone-1)** | **1.86:1** (protan 1.49) | **2.53:1** (protan 1.95) | 3.46:1 (protan 2.56) |
| Normal: full pip (zone-3) vs empty (zone-1) | 4.62:1 | 3.95:1 | 7.01:1 |
| Red text on gutter (normal / protan) | 4.4 / 3.3 | 4.5 / 3.4 | 4.7 / 3.5 |
| Held ember icon (amber) vs carried icon (zone-3) | **1.21:1** | 1.92:1 | 1.48:1 |
| Amber vs red (chain number normal→alert), deutan | 3.0 / 2.67 | same | same |

## Findings

Severity counts: **critical 2, high 4, medium 9, low 5** (20 total).

### C1 — Critical: whole-number scaling drops to ×1 in common web cases, and nothing in the spines covers ×1

- **Where:** EXPERIENCE Responsive & Platform (web row); DESIGN Layout ("×2, ×3, ×4").
- **Problem:** The spines list ×2/×3/×4, but integer scaling falls to **×1** whenever the device-pixel viewport is below 960×540.
  - This happens with any itch iframe smaller than 960×540 on a DPR-1 screen, and with any iframe smaller than 640×360 CSS on a DPR-1.5 screen.
  - itch's default embed size is, as far as I know, 640×360 (verify in the itch dashboard). On a DPR-1 laptop that default gives ×1.
  - At ×1, 8 px HUD text has 5 px caps, which is 7.6–7.9′, about half the 16′ minimum. The 5×5 ember icon is the same size, and "held vs carried" is effectively unreadable.
- **Below 480×270:** Godot's integer stretch clamps the factor to a minimum of 1 (verify on 4.7). The view does not shrink; it is cropped or overflows.
- **Laptop viewports:** A 1080p laptop at 150% has a CSS viewport of about 1280×600 after browser chrome. A 960×540 iframe plus the itch header does not fit vertically, so the page scrolls, and arrow keys are blocked from scrolling it.
- **Options:**
  - (a) Set the itch viewport to 960×540 and enable the fullscreen button. Make the click-to-play gate also offer "Play fullscreen".
  - (b) Declare ×1 unsupported. Show a "Window too small — go fullscreen" overlay when the computed integer scale is below 2.
  - (c) Below ×2, allow one fractional "fit" mode with nearest filtering. This breaks the whole-number rule, so it would be an explicit exception.
  - (d) Add a ×1 layout profile that hides labels, leaving pips, icons, meter and number only, with bigger digits.
  - (e) Document ×2 as the minimum supported scale in the spines and in the GDD Platform section.

### C2 — Critical: the HUD ×2 text-scale assist cannot fit 60 px gutters, which makes a promised accessibility feature infeasible as specified

- **Where:** decision log [ASSUMPTION] HUD ×2; EXPERIENCE Accessibility Floor; DESIGN Layout.
- **Measured at 16 px:**
  - `EMBERS` is 70 px against 59 usable.
  - `CHAIN` is 56 of 59, with no margin.
  - Held embers `+1240` is 60 px of text, plus a 10 px icon and a gap, about 76 px.
  - The chain number at ×2 (48/64 px) puts `20` at 72–96 px wide.
  - A ×2 meter (24×12 segments at 18 px pitch) is **360 px tall**, but the screen is 270.
- This is not a "layout check". At native resolution the assist cannot be built inside 60 px gutters.
- **Options:**
  - (a) Scale only text and pips at ×2. Keep the meter at ×1 but thicker, for example 20×6 segments. Replace labels with icons (a heart, an ember, a chain link).
  - (b) Use the empty lower left gutter (y 120–270, about 150 px) to stack the ember rows vertically: icon above number, numbers right-aligned, no "+".
  - (c) Render the HUD on a separate higher-resolution canvas layer (window resolution) so a text "×1.5/×2" is possible at ×3/×4 window scale. This costs pixel consistency.
  - (d) Under the assist, widen the gutters (for example to 80 px, leaving a 320 play area). This conflicts with rooms framed for 360 px, so the camera would need horizontal follow.
  - (e) Use extra screen space where the scale leaves it: Deck letterbox, ultrawide, or the stretch aspect `expand` feeding only the gutters.
  - (f) Rename the assist to "large text in menus, journal and speech", and give the HUD a separate "high-visibility HUD" mode instead of a scaled one.

### H1 — High: the alert red recolour collapses the full vs empty contrast on pips and meter just when HP matters most

- **Where:** EXPERIENCE State Patterns (Alert); DESIGN hp-pip and chain-meter `alert`.
- **Problem:** During a telegraph, full pips and filled segments turn `#d9473f`, while empty ones stay zone-1.
  - Full vs empty drops from 4.62:1 to **1.86:1 in Dusk** (1.49:1 for protanopes) and 2.53:1 in Umber. Counting HP in the 0.9 s before a bite is the worst moment to lose that.
  - Red text on the gutter falls from 7–11:1 to 4.4–4.7:1 (about 3.3:1 for protanopes).
  - Amber to red on the chain number is mostly a **brightness drop** (3.0:1; 2.67:1 deutan). For red-green colour-deficient players the alert reads as "the HUD dimmed", not "danger".
  - Recolouring four elements at once also removes the amber vs zone separation that tells chain from HP.
- **Options:**
  - (a) Keep the pips and meter in their normal colours. Signal the alert with a red frame or rule on the gutter edge, or a red chain-number outline.
  - (b) Turn only the *empty* pips and segments red-tinted and keep full ones bright, which preserves luminance order.
  - (c) Recolour only the chain number and held embers, the values at risk. Leave HP alone.
  - (d) Add a shape change (an eye icon in the gutter, or chain-number brackets) so the alert does not rely on hue.
  - (e) Use a lighter alert tint for text, for example `#ff7a6e`. This conflicts with the reserved hex, so the GDD would need a "predator-red light" token.

### H2 — High: on Steam Deck at ×2, 8 px HUD text is below the legibility minimum, and the check is scheduled for E7 after E1 locks the 8 px token

- **Where:** EXPERIENCE Responsive & Platform (Deck row); Epic Rollout E7.
- **Problem:**
  - 1280×800 fits only ×2 (960×540). That uses 51% of the screen area, with 160 px pillars and 130 px bars.
  - 8 px text has 1.18 mm caps: 13.5′ at 30 cm and 10.1′ at 40 cm, below 16′.
  - The device-pixel cap height is 10 px. As I recall, that just clears Valve's guidance of about 9 px minimum glyph height, so it may pass a Verified check while still being uncomfortable.
  - The font face and the 8 px token are chosen in E1, but the Deck check is in E7.
- **Options:**
  - (a) Move a Deck-equivalent check (960×540 on a 7" panel or a simulated equivalent) into E1 HUD v2 acceptance.
  - (b) On Deck, use `expand` aspect at ×2: a 640×400 logical canvas. Give the extra 160 px of width to the gutters (130 px each, which also solves C2), and either letterbox the extra height or let it reveal more shaft. Revealing more shaft is a GDD fairness question.
  - (c) Pick an E1 font whose 8 px cut has 6–7 px caps instead of 5. That is still on the 8 px grid but about 30% bigger.
  - (d) Make "large HUD" the Deck default.

### H3 — High: HiDPI, fractional DPR and browser zoom behaviour is unspecified, so web pixels may be blurry or uneven

- **Where:** EXPERIENCE web row ("keeping whole-number scaling and letterboxing").
- **Problem:** The scale the player actually gets depends on device pixels, not the iframe's CSS size.
  - **If Godot ignores DPR:** a 960×540 canvas on a DPR-1.25 or 1.5 screen, or at 110%/125% browser zoom, is stretched by the browser. Each game pixel becomes 2.5 or 3 device pixels, and 5 px glyph stems and 1 px rules alternate between 2 and 3 px wide. Text shimmers, and the "whole-number" promise fails silently.
  - **If DPR is honoured:** the same iframe gives ×3 at DPR 1.5, which is better.
- **Options:**
  - (a) Specify `display/window/dpi/allow_hidpi = true` for web, and compute integer scale from device pixels.
  - (b) Add a web QA matrix: DPR 1/1.25/1.5/2 × iframe sizes 640×360 and 960×540 × browser zoom 90–125%.
  - (c) Show the current scale (×N) in Options > Video, so players and testers can see what they get.
  - (d) Re-run the scale calculation on window resize and DPR change events.

### H4 — High: the body-line token (8 px font, 8 px line height) has no leading, and it is used for every multi-line surface

- **Where:** DESIGN `typography.body-line` (and `menu-item`, `hud-value`: lineHeight 8px).
- **Problem:**
  - With 5 px caps placed at em rows 4–8, descenders reach row 10.
  - At 8 px pitch, the next line's caps start 1–2 px below the previous line's descenders. Accented capitals (É, rows 1–3) **overlap** them.
  - The speech box, death line card, journal entries and slot details will all be dense or colliding.
- **Options:**
  - (a) Set body-line line height to 12 px (1.5×). The 8 px grid still holds at the box level using 24 px pairs.
  - (b) Set it to 10 px, the minimum that clears descenders and accents.
  - (c) Keep 8 px only for single-line HUD values, and split the tokens into `hud-*` and `text-*`.

### M1 — Medium: the chain-number size tiers do not fit what is crisp and fits the gutter

- **Where:** DESIGN Typography [OPEN] 3/6 step sizes; EXPERIENCE Chain number.
- **Problem:**
  - There are four states (0–2, 3, 6, 10), but a bitmap 8 px-grid font is crisp only at 8/16/24/32/40.
  - At 40 px, `20` is 60 px, wider than the 59 px gutter. That leaves three usable sizes: 16, 24 and 32.
  - The spine's base token is 24, but the mock draws 16 below 3 links. The mock and the spine already disagree.
  - The pop is "1 px per link", but a bitmap glyph cannot grow by 1 px. It can only be offset.
- **Fit:** 32 px `20` has about 5 px margins, and the vertical space is fine (the number ends around y 57; the meter top is y 87).
- **Options:**
  - (a) Use 16 / 24 / 24 + outline / 32. The 6-link step changes treatment, not size.
  - (b) Use 16 / 24 / 32 with the 6-link step carried by colour weight or a 1 px amber underline.
  - (c) Define the pop as a 1 px upward offset for 2 frames, not a scale.

### M2 — Medium: held and carried embers rely on icon colour, and in Dusk the two colours are nearly identical (1.21:1)

- **Where:** DESIGN ember-counter; Do's and Don'ts ("colour as the only signal").
- **Problem:** Amber `#ffd27a` and dusk-3 `#d8c3a0` are both pale warm tones. The "+" prefix and row position help, but the icons themselves break the stated rule.
- **Options:**
  - (a) Give the carried icon a different shape, such as a pouch or a hollow ember outline.
  - (b) Use a hollow ember for carried and a solid one for held.
  - (c) Drop the carried icon and keep only the number under a small divider.

### M3 — Medium: no contrast floor, and cold-violet labels are 3.0:1 at 5 px ink height

- **Where:** DESIGN Measured contrast [OPEN].
- **Problem:** The text is tiny, so a 3:1 floor is too low for it. The 1 px drop shadow in the mocks is `#05040a` on a `#07060b` gutter, so it adds nothing.
- **Options:**
  - (a) A floor of 4.5:1 for 8 px text and 3:1 for shapes. Labels would use zone-3 at reduced weight instead of zone-2 in cold violet.
  - (b) A per-zone override table for label colour.
  - (c) Use a 1 px *lighter* gutter (zone-0 instead of zone-0 at 55%) behind label rows.

### M4 — Medium: speech box and death line density at 360 px is unspecified, and ×2 text makes the box take over the play area

- **Where:** DESIGN speech-box [OPEN]; EXPERIENCE Speech box, Death line card.
- **Problem:**
  - The example death line (83 characters) measures **425 px** at 8 px, wider than the whole 360 px play area. It wraps to 2 lines in a box about 340 px wide.
  - With +30% localisation it is about 553 px, still 2 lines.
  - At ×2 text it is about 1106 px, so 4 lines. With a name tag, padding and H4 leading, the box is about 80 px, which is 30% of play height.
  - "One line at a time" is ambiguous: one sentence, or one wrapped row?
  - The journal at 8 px in a roughly 280 px text column next to a sketch is about 50 characters per line and fine, but at ×2 it drops to about 25.
- **Options:**
  - (a) Define a "line" as at most 2 wrapped rows and cap strings at about 110 English characters.
  - (b) Let the speech box grow upward to 2 rows (4 at ×2) and allow it to cover the play area only in the hub, which has no threats.
  - (c) Show the death card full-width over the gutters (480 px), since nothing is live during it.
  - (d) Give the journal a scrolling text pane, with the sketch moving above the text at ×2.

### M5 — Medium: glyph prompts in the 360 px play area have no size, outline, clamping or long-key rule

- **Where:** DESIGN glyph-prompt [OPEN]; EXPERIENCE Glyph prompt.
- **Problem:**
  - Prompts sit over the world: amber light pools, zone rock, dark. Neither an amber nor a zone colour is guaranteed to read there.
  - Keyboard caps for `SPACE` (29 px) and `ENTER` (28 px) are about 6 times wider than `Z` (5 px).
  - Gamepad face-button glyphs need about 9–11 px to read the letter or symbol inside the circle, which is 8.5–10′ at ×1.
  - An object within about 15 px of the play edge pushes the prompt into the gutter, which the rule says is HUD-only.
  - With the camera leading downward, prompts near the top of the view clip.
- **Options:**
  - (a) Use an 11×11 keycap with a 1 px dark outline plus a 1 px zone-0 backing (no shadow), clamped inside the play area.
  - (b) Long keys use an abbreviated cap (`SPC`, `ENT`) or an icon.
  - (c) Pick a colour that is neither amber nor red: zone-3 on zone-0.
  - (d) Flip the prompt below the object when it would clip the top.

### M6 — Medium: alert on/off timing and stacking are undefined, risking flicker and red-on-red

- **Where:** EXPERIENCE Alert ("lasts the telegraph"); DESIGN off-screen edge glow [OPEN].
- **Problem:**
  - Overlapping or staggered lurker telegraphs can toggle the whole HUD red and back several times a second. A 4-element recolour is effectively a flash, so this risks breaching the ≤3 flashes/s cap.
  - If the red edge glow draws over the gutter, a red HUD sits on a red glow and both lose contrast.
- **Options:**
  - (a) Alert is the union of all active telegraphs, with a minimum hold of 400 ms and no re-trigger within 300 ms.
  - (b) Draw the edge glow on the play-area side of the gutter rule only.
  - (c) Fade the alert in and out over 80–120 ms instead of a hard swap, with no fade under reduce flashing.

### M7 — Medium: zone-matched recolour while falling fast can read as a HUD event

- **Where:** decision log, theme C; DESIGN zone-roles.
- **Problem:** Diving from Dusk into Umber or Cold violet changes the gutter tint and every label, pip and empty segment colour at once, in peripheral vision, mid-combat. That can be mistaken for the alert or for damage. Nothing defines when the swap happens (room load, or a camera band) or how.
- **Options:**
  - (a) Crossfade the UI roles over 300–500 ms at the zone boundary.
  - (b) Swap only at room transitions, or while the camera is between rooms.
  - (c) Keep the HP and value roles constant across Layer 1 and tint only the gutter fill and labels.

### M8 — Medium: at-a-glance reading in fast descent; the flare-ready info is about 210 px from the player and split from the number

- **Where:** DESIGN gutter coordinates; EXPERIENCE J2 step 5.
- **Problem:**
  - The player is near x 240. The gutter content sits around x 30 and x 450, about 16° away at ×3 on a desktop, so reading it means moving your eyes.
  - The chain number is at the top of the right gutter (y about 24–57), but the flare notch and cost tint are at the bottom (y about 249–264). Checking "can I toss?" during J2's cling needs two glances 200 px apart.
  - The cling cue sits near the player, but flare readiness has no near-player cue. Peripheral reading works for size and brightness, not for numbers or notches.
- **Options:**
  - (a) Repeat readiness at the number: the chain number gains a small flare pip when ≥2.
  - (b) Show flare readiness on the player (a lantern spark) as a semi-diegetic cue, like the cling cue.
  - (c) Make the cost tint appear only while Light is pressed, so it is noticed at the moment of decision.
  - (d) Move the meter's origin to the top, under the number, so segment 2 sits beside the number. This flips the fill direction.

### M9 — Medium: localisation headroom is checked by character count, not by glyph height or width

- **Where:** decision log Localisation; DESIGN Typography ("wide glyph coverage").
- **What fits:** `EMBERS` +30% is about 46 px and fits. `BRAISES`, `KETTE` and `CHAÎNE` fit. A 5-digit `+12400` (36 px) ends at x 58, touching the rule.
- **What does not:**
  - (1) Accented capitals need 3 px of headroom above the caps, which collides under H4.
  - (2) CJK is not legible on an 8 px grid. CJK pixel fonts start at 10–12 px, so the "8 px grid, wide coverage" rule contradicts itself for CJK.
  - (3) Options tabs at 70 px pitch: `Accessibility` is 67 px and `Barrierefreiheit` is 81 px, overrunning the 360 column by 1 px as the last tab. All five tabs at ×2 are impossible.
- **Options:**
  - (a) Limit "later localisation" to Latin and Cyrillic, and state CJK as needing a 12 px fallback layout.
  - (b) Lay out tabs by measured width rather than a fixed pitch, with scrolling tabs at ×2.
  - (c) Cap displayed embers (`9999+`) or switch to `12.4k` above 4 digits.

### L1 — Low: the mock's 1 px text shadow is invisible on the gutters

- **Problem:** The shadow `#05040a` sits on a gutter of `#07060b` to `#18100b`. It only matters for text drawn over the world (prompts, popups).
- **Options:**
  - (a) Drop shadows in the gutters.
  - (b) Use an outline only for in-world text.

### L2 — Low: pip "crack and shake" and 1 px pop details are lost at ×1 and ×2

- **Problem:** A 1 px crack inside a 7 px pip is 0.24 mm at ×1.
- **Options:**
  - (a) Make the lost pip collapse into an outline. This is a shape change, readable at any scale.
  - (b) Briefly enlarge the cracked pip to 9 px before it empties.

### L3 — Low: near-black gutters merge with the letterbox at small scales

- **Problem:** Cold-violet gutter `#07060b` against a black letterbox makes the game frame look 360 px wide and shifts the HUD visually.
- **Options:**
  - (a) Add a 1 px zone-1 rule on the gutter's outer edge too.
  - (b) Use a letterbox colour slightly darker or lighter than the gutter.

### L4 — Low: mock and spine drift that will mislead implementers

- **Problem:**
  - Mock C draws labels in the HP colour, while theme C uses the label role.
  - Mock C uses 16 px for chains below 3; the spine's base is 24.
  - The theme-C mock draws held text as `+24` but ties nothing to the chain value.
  - The menu mock footer keys are undecided.
- **Options:**
  - (a) Annotate the promoted mocks with "spine wins" callouts on each divergent element.
  - (b) Regenerate the mock C canvas with spine tokens before promotion.

### L5 — Low: no scale-down behaviour defined for windows smaller than 480×270

- **Problem:** Godot integer stretch clamps to ×1 and crops (verify on 4.7). This is rare on desktop but possible in a resized browser window or a narrow itch embed.
- **Options:**
  - (a) Show a minimum-size message.
  - (b) Use a fractional downscale fallback, with the exception documented.

## Things that hold up

- Chain number at 32 px: `20` is 48 px wide in 59 usable, with about 5 px side margins. Vertically it ends around y 57, well clear of the meter top at y 87.
- Meter: 20 segments of 12×6 at 9 px pitch span y 87–264. They read at every scale, including ×1 at about 18′ wide, and there is no need to count segments.
- At ×1, 4-digit held and carried counts fit: `+1240` runs from x 22 to x 52. Bank summary and menu text in the 360 px column fit with +30% growth: `Meilleure chaîne` (84 px) plus its value fits in the 140 px bank column.
- The static gutters are the right call for fast vertical motion. Nothing moves with the camera, and the HUD never covers the shaft.

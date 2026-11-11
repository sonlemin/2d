# Accessibility Review — UX spines (DESIGN.md, EXPERIENCE.md)

Reviewer lens: adversarial accessibility. Date: 2026-11-10. Spines not edited.
Inputs: `DESIGN.md`, `EXPERIENCE.md`, `.decision-log.md` (canonical), `.working/source-extract.md` (GDD facts).
References: WCAG 2.2 (1.4.3, 1.4.11, 2.2.1, 2.3.1, 2.3.3), Game Accessibility Guidelines (GAG) basic/intermediate, Xbox Accessibility Guidelines (XAG 101 Text display, 102 Contrast, 103 Additional channels for visual and audio cues, 105 Audio accessibility, 107 Input, 116 Visual distractions and motion, 118 Photosensitivity).

Every fix below is an **option for the developer**, not a decision. Line numbers are as of this review.

## Summary

| Severity | Count |
|---|---|
| Critical | 1 |
| High | 5 |
| Medium | 10 |
| Low | 8 |
| **Total** | **24** |

Strengths worth keeping: flash cap is stated and checked per effect; colour-never-only rule exists; difficulty never touches telegraphs; timing assists separated from difficulty; auto-pause on focus loss; hold↔toggle and full rebinding are planned; pause tab shows live bindings; amber/red hues are not "saturated red" under the WCAG definition (red share 0.62 for `#d9473f`, 0.61 for M1 `#ff594d`; threshold is 0.8), so the red alert is not an automatic WCAG 2.3.1 red-flash failure.

## Method

- WCAG relative-luminance contrast computed for every zone role on `gutter-{zone}` (HUD) and `zone-{zone}-0` (menu surface). DESIGN.md's measured table (DESIGN l.242–250) was reproduced and is correct.
- Colour-vision deficiency simulated with Machado et al. (2009) matrices at severity 1.0 (protanopia, deuteranopia, tritanopia), compared by CIE76 ΔE and by simulated luminance ratio.
- Text size: 8 px native glyphs render at 8 / 16 / 24 / 32 physical px at ×1 / ×2 / ×3 / ×4. Pixel fonts have 1-native-px strokes and small x-height, so this review treats all 8 px text as **small text (4.5:1 target)** even at ×3 where 24 px technically meets the WCAG "large" size.

### Contrast results

| Zone | Surface | idx3 HP/value/selected | idx2 label/idle | idx1 empty/rule | Amber | Red |
|---|---|---|---|---|---|---|
| Dusk | gutter `#18100b` | 10.94 | 5.93 | **2.37** | 13.20 | **4.40** |
| Umber | gutter `#110d0b` | 7.08 | **3.76** | **1.79** | 13.58 | 4.53 |
| Cold violet | gutter `#07060b` | 9.61 | **3.03** | **1.37** | 14.19 | 4.73 |
| Dusk | menu `#2b1d14` | 9.49 | 5.14 | 2.05 | 11.45 | 3.82 |
| Umber | menu `#1e1714` | 6.47 | **3.44** | 1.64 | 12.42 | 4.14 |
| Cold violet | menu `#0d0b14` | 9.30 | **2.93** | 1.33 | 13.72 | 4.58 |

Bold = below 4.5:1 for 8 px text, or below 3:1 for non-text UI (WCAG 1.4.11).

State-change contrast (same element, two states):

| Pair | Dusk | Umber | Violet |
|---|---|---|---|
| Full pip (idx3) vs empty pip (idx1) | 4.62 | 3.95 | 7.01 |
| Full pip (idx3) vs **alert** pip (red) | 2.48 | **1.56** | 2.03 |
| Chain number amber vs **alert** red | 3.00 | 3.00 | 3.00 |
| Held ember text (amber) vs carried (idx3) | **1.21** | 1.92 | 1.48 |
| Flare notch (idx2) vs empty segment (idx1) | 2.51 | 2.10 | 2.21 |

Colour-vision simulation (key pairs):

| Pair | Normal ΔE | Protan ΔE / lum. ratio | Deutan ΔE / lum. ratio | Read |
|---|---|---|---|---|
| Amber `#ffd27a` vs red `#d9473f` | 63 | 48 / 3.75 (`#e6d172` vs `#70663d`) | 33 / 2.68 (`#f1dd7d` vs `#94863a`) | Both become yellow-olive. Alert reads as "amber got darker", not as a hue change. |
| Umber idx3 pip vs red pip | 61 | 26 / 2.06 | 33 / **1.37** | Alert pips in Umber are near-identical in luminance for deutans. |
| Umber idx2 label vs red | 58 | 15 / **1.08** | 32 / 1.37 | Under protanopia red becomes the same grey-olive as Umber labels. |
| Dusk idx2 vs red | 49 | 16 / 1.69 | **12** / 1.20 | Same issue in Dusk for deutans. |
| Red edge glow vs gutter (full strength) | — | 3.27–3.52 | 5.1–5.5 | Protans see red as dark olive; a "faint" glow at partial alpha falls well under 3:1. |

Tritanopia keeps amber/red separable (ΔE 67); no tritan-specific blocker found.

---

## Findings

### Critical

**A11Y-01 — Death line card is too short and is skipped by any input** (EXPERIENCE l.193, l.209, J3 step 2 l.319; decision-log l.25)
The card auto-advances after about 1.5 s, and any input skips it. The example line is 16 words; at a typical 200–250 wpm that is about 4–5 s of reading, longer for players with dyslexia or cognitive or low-vision needs. Players are usually mashing attack or holding a direction at the moment of death, so "any input" will often dismiss the card on its first frame. This card carries Pillar 2 ("every death teaches") and the GDD success metric (testers name the killer in ≥80% of deaths). It conflicts with WCAG 2.2.1 (timing adjustable) and GAG basic "allow players to progress through text at their own pace". The full death log only arrives in E7 (EXPERIENCE l.58), so before then nothing recovers a missed line.
Options:
- (a) Ignore inputs already held at death; require a fresh press after a short lockout (for example 0.4 s) before skip is accepted.
- (b) Make the card wait for confirm (no auto-advance), with a quick-respawn option for players who want speed.
- (c) Keep auto-advance but scale the duration by word count (for example 1 s + 0.25 s/word), with an Accessibility toggle "Wait for input on death".
- (d) Pull a minimal "last death" line into the Pause tab in E1 so a skipped card is recoverable.

### High

**A11Y-02 — HUD alert is colour-only, contradicting the spines' own rule** (EXPERIENCE l.183, l.244; DESIGN l.218, l.306–309, l.336)
DESIGN l.336 says alert "also change[s] shape, position or motion", but every alert spec is a colour swap only (pips, held text, chain number, meter → red). EXPERIENCE l.244 justifies it by the telegraph sound and the eye motion, but those are world cues, not HUD cues; the sound only arrives in E3 and is lost for deaf or muted players. Measured: amber→red on the chain number is 3.00:1 in every zone, and under deuteranopia it collapses to a dark-yellow vs light-yellow shift (ΔE 33). In Umber, alert pips vs normal pips are 1.56:1 (deutan-simulated 1.37:1). XAG 103 and GAG basic both ask for a non-colour channel.
Options:
- (a) Add a shape change: alert pips swap to a hollow or "eye"-shaped glyph; the chain number gains a 1 px bracket or underline.
- (b) Add motion: a single 1 px HUD jolt at alert onset (respects the shake toggle; no repeating blink).
- (c) Add an alert icon (pixel eye) at a fixed gutter spot, which reads under any colour vision.
- (d) Remove the l.336 claim and document alert as supplementary HUD colour only (weakest option; still leaves deaf + colour-blind players with eyes-in-world only).

**A11Y-03 — No contrast floor; labels, idle items and empty states fail common targets** (DESIGN l.242–250 [OPEN], l.236–240; EXPERIENCE Open 4)
8 px labels are 3.76:1 (Umber) and 3.03:1 (Violet) on the gutter; idle menu items are 3.44:1 and 2.93:1. Empty pips/segments (non-text UI) are 2.37 / 1.79 / 1.37:1, below the WCAG 1.4.11 3:1 for UI state. In Violet an empty pip is nearly invisible, which matters because "how many HP do I have left" is read from the empty pips. Held red ember text in Dusk is 4.40:1, just under 4.5. The palette darkens as you descend, so the hardest-to-read HUD appears in the hardest content. XAG 101/102 recommend 4.5:1 for text.
Options:
- (a) Set floors: 4.5:1 for 8 px text, 3:1 for non-text state; allow per-zone overrides of the role tokens when an index misses the floor (for example a lifted `label-violet`).
- (b) Map label/idle to a mid-blend of idx2 and idx3 instead of raw idx2.
- (c) Draw empty pips and segments as 1 px outlines in idx2 or idx3 (shape, not fill) so they pass 3:1 without competing with full pips.
- (d) Add a "High-contrast HUD" toggle that switches all zone roles to fixed high-contrast values (keeps the zone-matched look as default).

**A11Y-04 — Off-screen "stirring" telegraph is a faint red glow, alone until E3/E7** (DESIGN l.313; EXPERIENCE l.95, l.184, l.243)
In E1 the only stirring cue is a "faint" red edge glow; panned sound lands in E3 and the edge marker in E7 (and only with visual sound cues on). Under protanopia, red becomes dark olive with about 3.3–3.5:1 against the gutter even at full strength; at "faint" alpha it will drop well under 3:1 and may disappear entirely against dark zones. This telegraph is the Pillar 2 protection against off-screen ambush (anti-pattern l.277). The death line itself tells players to "watch for the red glow", so the fix loop depends on a cue some players cannot see.
Options:
- (a) Give the glow a shape or motion signature (for example slow 1 Hz chevrons, or a pixel "eye" at the edge) in E1, not E7.
- (b) Define a minimum contrast for the glow peak (for example ≥3:1 against the zone's darkest colour) and specify its size.
- (c) Make the E7 edge marker on by default, or a sub-option of a colour-blind setting.
- (d) Rephrase the death line away from the colour word (see A11Y-21).

**A11Y-05 — Light tap/hold window is fixed and gear makes it tighter** (EXPERIENCE l.117, l.135, l.211; source-extract l.61, l.65)
Tap = Flare Toss only if Light is released before 0.12 s; otherwise it is Snuff, which breaks and banks the chain. Quick Wick lowers the threshold to 0.08 s, so buying gear makes Flare Toss **harder** for players with tremor, slow release or switch hardware. A misfire is high-cost (loses the chain at the climax of J2). The hold↔toggle option is E7 and does not address the tap window. GAG basic: "avoid or provide alternatives to holding buttons"; intermediate: "allow timing windows to be adjusted"; XAG 107.
Options:
- (a) Add an adjustable Light threshold (for example 0.08–0.30 s) in Accessibility; Quick Wick then lowers it relative to the player's setting.
- (b) Allow binding Flare Toss and Snuff to separate buttons as an optional layout (keeps the one-button default and Pillar 4).
- (c) Make Quick Wick opt-out, or have it shorten the Snuff animation instead of the input threshold.
- (d) Bring the threshold setting forward to E1, since misfires were already an M1 finding (V next to C).

**A11Y-06 — Text/HUD scale cannot fit the 60 px gutters as specified** (DESIGN l.258, l.267–285; EXPERIENCE l.78, l.241, Open Assumption 1)
"EMBERS" in a Silkscreen-like font is about 36 px wide at 8 px; at HUD ×2 it is about 72 px, wider than the 60 px gutter before the 30% localisation allowance (DESIGN l.268). A 4-pip column at 10 px pitch doubles to 80 px, and the 20-segment meter at 9 px pitch (about 180 px) cannot double within 270 px. So "Text / HUD scale" is promised (E7) but has no feasible layout, and the spines only flag it as an assumption. XAG 101 and GAG intermediate ask for scalable text.
Options:
- (a) Replace gutter labels with icons at larger scale (heart, ember, chain), keeping text only in menus.
- (b) Offer HUD ×1.5 via an alternate hand-drawn 12 px font and a compact meter (10 segments of 2 links each).
- (c) Scale menus and speech box text only, and state that the gutter HUD scales with the window scale.
- (d) Do the ×2 gutter layout check now (before E1 locks coordinates) rather than in E7.

### Medium

**A11Y-07 — Web build can render 8 px text at ×1** (EXPERIENCE l.253, l.25; DESIGN l.266)
Whole-number scaling with letterboxing means any itch embed or browser viewport narrower than 960 px renders at ×1: 8 physical px text and 7 px pips. itch embeds are often 960×540 or smaller, and browser chrome reduces the space further. XAG 101.
Options: (a) set the itch embed to at least 960×540 and show a "fullscreen recommended" hint on the click-to-play gate; (b) allow a non-integer fallback scale (with nearest filtering and a sharpness trade-off) only when ×2 does not fit; (c) state ×2 as the minimum supported web scale in GDD Performance.

**A11Y-08 — "Reduce flashing" has no defined scope** (EXPERIENCE l.229, l.236, Open 23)
The toggle ships in E1 but nothing says what it changes. Candidates in the spines and GDD: 2.5 Hz pip blink, 2 Hz lurker eye pulse with red wall light, HDR bloom, hit sparks, flare ignition, chain-gate glow, bank popup, Re-Weave silk glow. Saying "the blink still runs because it is under the cap" (l.229) misreads the purpose: players who turn this on often react below 3 Hz too. GAG intermediate; XAG 118.
Options: (a) list every effect the toggle softens; (b) under reduce flashing, replace the pip blink with a steady dim or outline for 0.6 s and the eye pulse with a steady glow; (c) cap bloom intensity and spark brightness when on; (d) turn it on by default for first launch with a one-screen photosensitivity notice.

**A11Y-09 — "Reduced motion" is referenced but no setting exists** (EXPERIENCE l.168, l.212, l.245 vs l.71–78)
The cursor "jumps under reduced motion", but the Options tabs list only reduce flashing and screen shake. Other motion that the setting should cover: the slowly scrolling title shaft behind text (l.51), 1 px ember cursor flicker, chain number pop, ember fly-to-gutter, meter segments falling away, popup rise. WCAG 2.3.3; XAG 116.
Options: (a) add a Reduced motion toggle in E1 Accessibility with a listed scope; (b) fold reduced motion into the screen-shake toggle and rename it "Motion"; (c) follow the OS/browser `prefers-reduced-motion` on web as the default.

**A11Y-10 — Alert colour can toggle faster than the cap during overlapping telegraphs** (EXPERIENCE l.183, l.185; source-extract l.103)
Alert "lasts the telegraph" (0.9 s, minimum 0.75 s). With two or more lurkers telegraphing back to back, or alert overlapping the 2.5 Hz invulnerability blink, the four HUD elements plus the 2 Hz red wall light can switch state more than 3 times in a second. The flash cap is "checked for every effect", but combined effects are not covered. WCAG 2.3.1 counts all flashes in any 1 s window.
Options: (a) debounce the HUD alert (stay red for at least 0.5 s after the last telegraph ends); (b) define the cap as screen-wide, not per-effect, and add it to the test plan; (c) suppress the pip blink while alert is active.

**A11Y-11 — Held vs carried embers are told apart by colour and a "+" only** (DESIGN l.307; EXPERIENCE l.87–88)
Held text is amber and carried text is zone idx3; in Dusk these are 1.21:1 in luminance and both pale warm tones. The only non-colour cue is the `+` prefix on held. Held is what you lose on death, carried is what drops as cache, and deposited is a third state not shown. This is a cognitive load as well as a colour issue.
Options: (a) add tiny row labels ("HELD"/"PACK") or distinct icons (lit vs unlit ember); (b) draw the carried icon hollow and the held icon filled; (c) explain the three ember states once in the Pause tab bank summary.

**A11Y-12 — Brightness arrives in E7 for a deliberately dark game** (EXPERIENCE l.76, l.238; Assumption 2)
The M1 F1 hotkey is removed and brightness moves to E7, so E1–E6 web builds (likely public on itch) have no brightness control. Low-vision players and players on dim laptop panels need it most in the darkest zones. GAG basic.
Options: (a) land a 4-level brightness in E1 Accessibility (it existed in M1); (b) keep F1 on PC only until E7; (c) add a "base light radius" floor option alongside brightness.

**A11Y-13 — All motor accommodations land in E7** (EXPERIENCE l.77, l.130–131, l.239–242)
Rebinding, hold↔toggle, game speed and timing assists are all E7. Cling requires holding Jump at a wall for up to the grace time (1 s per link, so up to about 20 s at cap); Snuff is a hold; swing is a hold. Defaults use arrows (right hand) plus ZXCV (left hand), so one-handed play is impossible before E7. If web builds go public before E7, motor-impaired players are locked out. GAG basic (remapping); XAG 107.
Options: (a) ship keyboard rebinding (even a simple list) in E1, gamepad in E7; (b) ship cling toggle in E1, since it is the longest hold; (c) offer a second preset layout (for example WASD + JKL;) in E1 as a cheap stand-in.

**A11Y-14 — Hearing support is thin and partly sound-only** (EXPERIENCE l.75, l.95, l.184, l.243; source-extract l.104–106)
Visual sound cues are E7 and scoped only to "predator sounds". Other sound-carried information: lurker hunt hiss that "follows position", Weaver twang/hiss telegraph, cling creak, Snuff "blown out" confirm, chain-gate rising tone, death muffled tail. There is no mono-audio option, although the stirring cue relies on panning (players with single-sided hearing lose direction). Volume sliders are unspecified (GAG basic: separate music / SFX / voice). XAG 103, 105.
Options: (a) widen visual sound cues to every gameplay-relevant sound and list them; (b) add a mono toggle and separate Music / SFX / Predator cue sliders in E3; (c) give the edge marker a direction arrow so side is never sound-only.

**A11Y-15 — Menu input rules are undefined** (EXPERIENCE l.118, l.124, l.168–169, l.208, Open 9, 18)
Confirm, back, tab switch, wrap and key-repeat are all open. Without hold-to-repeat timing, long lists (journal, map pins, shop) are tiring; Esc both pauses and exits browser fullscreen on web (l.118). GAG basic: "ensure all menus are navigable with the same inputs as gameplay"; XAG 107 and 112-style UI navigation.
Options: (a) define initial repeat delay (about 400 ms) and repeat rate (about 80–100 ms), and include menu actions in rebinding; (b) accept both Z/Enter/Space for confirm and X/Backspace/Esc for back; (c) bind pause to Esc and P, and on web prefer P, with Esc as fallback; (d) wrap lists so a single direction always reaches every item.

**A11Y-16 — No accessibility persona or test plan** (EXPERIENCE l.289)
The only persona is the developer playtesting on a laptop keyboard. Nothing checks the HUD at ×2 on the Deck, with a colour-blind filter, with sound off or one-handed. The success metric (naming the killer ≥80%) is not tested under these conditions.
Options: (a) add a second persona (for example low vision + deuteranopia, plays muted); (b) add a per-epic check: CVD-simulated screenshots of each zone, sound-off run, ×1 web check; (c) recruit at least one disabled tester before the planned release.

### Low

**A11Y-17 — Glyph swap may flip on stick drift** (EXPERIENCE l.132). "Switches on the first input from the other device" — a drifting stick or a resting finger will flicker glyphs. Options: (a) require a press or a stick move past a deadzone; (b) let players lock the glyph set in Controls.

**A11Y-18 — Interact needs "↓ while standing still"** (EXPERIENCE l.113, l.207). On a stick, ↓ often registers a small diagonal, and "standing still" may fail for players with tremor. Options: (a) use a generous stick deadzone for interact; (b) accept ↓ at low horizontal speed; (c) allow binding a dedicated interact key.

**A11Y-19 — Flare cost tint should not rely on hue** (DESIGN l.143–144, l.311; EXPERIENCE l.163). Still open. The lower half of the meter is already amber-filled; a hue tint will be weak under deutan (amber variants all read as yellow). Options: (a) a 1 px dither or hollowed pattern over the segments that would be spent; (b) a brightness drop of at least 3:1 against filled; (c) a bracket mark beside the cost range. Avoid red (reserved).

**A11Y-20 — Chain number at 0 is near-invisible in Violet** (DESIGN l.308; EXPERIENCE l.191). idx1 on the Violet gutter is 1.37:1. Probably intentional de-emphasis, but "0" then reads as missing UI. Options: (a) use idx2 for 0; (b) keep idx1 but outline the digits.

**A11Y-21 — Copy relies on a colour word and an ambiguous idiom** (EXPERIENCE l.144–145). The death line says "Watch for the red glow at the screen edge" (colour-reliant for protans); "The cache went dark." does not say embers were lost or how many, and the "Not" column rejects the explicit form. GAG basic: simple, clear language. Options: (a) "Watch for the glow at the screen edge."; (b) "The cache went dark. 40 embers gone."; (c) keep terse copy but always pair it with a number line on the card.

**A11Y-22 — Destructive actions lack confirmation** (EXPERIENCE l.67, l.175, Open 15, 17). Quit when not at an anchor, slot overwrite and slot delete are open. Accidental activation is likelier for motor-impaired players. Options: (a) confirm with the default on "No"; (b) hold-to-confirm only as an option, never required.

**A11Y-23 — Gamepad disconnect behaviour is open** (EXPERIENCE l.201). XAG 107 and platform guidance expect auto-pause. Option: auto-pause with a "Reconnect controller" message that keyboard can also dismiss.

**A11Y-24 — Speech box reveal and pace unspecified** (EXPERIENCE l.166, Open 10). Options: (a) instant text by default or a "text speed: instant" setting; (b) never auto-advance; (c) a backlog of the last few lines.

---

## Not issues (checked)

- 2.5 Hz invulnerability blink and 2 Hz eye pulse are each under 3 flashes/s, and the pips are a small area, well under the 25% of 10° field threshold. Combined effects are the risk (A11Y-10).
- Predator red is not "saturated red" under the WCAG definition, so the red alert is judged by luminance flashing only.
- Chain number (24–32 px native) is large text; amber on all gutters is 13.2–14.2:1.
- Tritanopia keeps amber vs red separable.
- Pause on web focus loss, the controls reference in Pause, and difficulty not changing telegraphs all meet GAG basic.

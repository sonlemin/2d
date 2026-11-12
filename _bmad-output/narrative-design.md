---
title: 'Narrative Design Document'
project: 'The Unbroken Chain'
date: '2026-11-12'
author: 'sonlm'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
status: 'complete'
narrativeComplexity: 'moderate'
scope: 'full 7-layer arc sketched; Layer 1 + hub written in detail (M2)'
gdd: '_bmad-output/planning-artifacts/gdds/gdd-pixel_art_game-2026-11-10/gdd.md'
---

# Narrative Design Document

## The Unbroken Chain

### Document Status

Created through the GDS Narrative Workflow, with an elicitation and a party-mode review on every section (2026-11-12). Design source of truth for all story text, alongside the GDD, UX and architecture.

**Narrative Complexity:** Moderate (full arc sketched, Layer 1 + hub detailed for M2)
**Steps Completed:** 11 of 11 (complete, 2026-11-12)

**Constraints carried in:** at most three reveals (origin, theft, cycle); Layer 1 holds only 2–3 deniable clues; story told mostly through environment, journal and Memorial Wall plus brief hub NPC talk; NPC dialogue is linear, flag-gated lines (architecture); all text in `game/text/strings.csv`; world, creatures and story are original.


---

## Story Foundation

### Narrative Premise

*Player-facing pitch (no spoilers):* The island's youngest diver chases a lost
legend's depth record into a living abyss — where the deeper your light burns,
the more the dark seems to know you.

*Internal premise:* You are Abyss Island's youngest diver — by the island's
telling, a shipwreck orphan raised by the Last Explorer, who went back down and
never returned. You dive to beat her depth record and learn what happened to
her. The truth: you are a living spark of the abyss's light, stolen as a child
and carried to the surface as the greatest relic ever found. Every link of your
chain burns brighter because you are going home. The abyss has made and lost
children like you for ages, and only you can end the cycle — or become its next
Last Explorer. Chasing the record *is* the lure: every dive walks the Last
Explorer's path, so the goal the island hands you is the cycle's first step.

### Core Themes

**Spine theme — Home and belonging.** The descent is a homecoming to a place you
never knew; the island is the home that raised you. Which one is yours?
(#100, #101) Every other theme serves this question.

- **Love and greed.** The Last Explorer stole you out of greed and loved you
  anyway; tragic, not evil. Your own ember greed echoes theirs. (#104, #107, #114)
- **Restraint vs burning bright.** The core mechanic as a question: when is it
  worth shining? The Weaver teaches restraint, the Hollow Furnace commitment,
  the Final Chain answers with full light.
- **Taking and the cycle.** The island lives on what it takes from the abyss —
  relics, embers, children. The Guild record board is the cycle's lure: beating
  the record means becoming the one who held it. What does it cost to stop
  taking? (#102, #106, #108)

### Tone and Atmosphere

**Tone:** melancholic wonder. Awe first, sadness underneath; danger is the price
of looking. Never grim. The hub may be warm and gently funny; never jokey.

**Atmosphere:** the hub is warm daylight and people; the abyss is beautiful and
strange, each layer its own sky. Darkness is tension, not confusion (Pillar 2).
Your amber light is the one constant colour — the visual "you".

**Emotional Register:** wonder at each new layer; quiet ache at the traces of the
lost (the Memorial Wall, *The Last Entry*); the thrill of a long chain; and a
growing, unspoken sense of belonging down here. Creatures are hungry, not
hateful (#109).

---

## Story Structure

### Structure Type

**Three acts, one per reveal** — origin → theft → cycle (brief: three reveals
max). Clues are deniable early and undeniable deep (#103, #112): the player
suspects before the character knows. Because players will suspect, each reveal
pays off *meaning* (why, and what it costs), not surprise.

### Act Breakdown

**Act 1 — Origin (Layers 1–3).**
Island life and the record chase. Layer 1 (Edge of the Abyss, the Weaver) and
Layer 2 (Bright Moon) plant 2–3 deniable clues each. Layer 1's are fixed by the
M2 Clue Budget (Dialogue Framework); from Layer 2, gentle creatures that don't
flee you and the Naturalist's observations join them. The origin
becomes undeniable at the Rootmother (Layer 3): you are of the abyss.

*M2 hook (Layer 1 must stand alone):* the slice ends on a question, not a
reveal — Oda's record on the Guild board, her name on the
Memorial Wall, *The Last Entry*'s "going deeper", and **The Watching Departure**
(creatures gather at the edge of your light as the lift carries you up) as the
deniable sign that something down here recognises you.
*M2 clue channels are existing systems only:* journal text, flag-gated NPC
lines, the Memorial Wall, environment props and The Watching Departure. No new
creature behaviour for story (party review, 2026-11-12).

*Turn:* from "I'm chasing a record" to "I belong down here."

**Act 2 — Theft (Layers 4–5).** *Sketch: revisable at each layer's milestone.*
Following Oda's trail: her camps, journal pages and gear. Love and greed both
show in her own words. By the Eye of the Storm (Layer 5) the theft is
undeniable — and the payoff is *why*: she took you up as a relic, and raised
you anyway.
*Turn:* from "who am I" to "what was done to me — and do I forgive it?"

**Act 3 — Cycle (Layers 6–7).** *Sketch: revisable at each layer's milestone.*
Freezing Magma flips the rules: light is warmth, going dark costs you —
commitment over restraint. At The Bottom, Oda, the Last Explorer, changed by greed
(#107), is fought as a mirror of your own verbs — the record-holder you have
been chasing all game. The cycle is revealed: the abyss has made and lost
children for ages ("bosses were children" stays an unconfirmed hint, #116).
Ending: *The Final Chain*, one unbroken descent at full light (#115).
*Turn:* from "what was done to me" to "what I choose to end."

*Resolved later in this document:* breaking the cycle = the island stops
taking; why predators stop hunting in The Final Chain = their hunger was
homesickness; the island after = Quiet Change (Story Beats 12–14). Oda's house
in the hub = yes, small (Characters).

---

## Story Beats

### Major Story Beats

1. **First Dive** *(inciting incident)* — the Guild registers you; the Last
   Explorer's all-time depth record is the target. (#89, #108)
2. **The Memorial Wall** — the Last Explorer's name among the lost. (#93)
3. **The Watching Departure** *(recurring)* — creatures gather at the edge of
   your light as the lift carries you up. Deniable: they might just want your
   light. Bookends beat 13: here they watch you leave; there they follow you
   home. (#120)
4. **The Last Entry** — S4 Explorers' Grave: a lost explorer's camp and
   half-written journal, "going deeper." (#56)
5. **The Weaver / The Fall** — the restraint lesson; at half health the fight
   plummets into Layer 2. (#71, #77)
6. **Origin** *(plot point 1)* — at the Rootmother, the origin becomes
   undeniable: you are a spark of the abyss. (#80, #101)
7. **The Speck** *(midpoint, awe)* — on the Great Mountain the camera pulls back
   until you are a dot. (#54, #81)
8. **The Trail** — Oda's camps and journal pages: love and greed in her own
   words. (#113, #114)
9. **Theft** *(plot point 2)* — by the Eye of the Storm: they took you up as a
   relic, and raised you anyway. (#82, #104)
10. **The Hollow Furnace** — light is warmth; commitment over restraint. (#83)
11. **The Last Explorer** *(climax)* — a mirror fight against the record-holder,
    changed by greed. (#84, #107)
12. **Cycle** — the island has taken the abyss's light as relics for ages, and
    you were the first *living* spark ever carried up. Below, the abyss has made
    and lost children of its own ("bosses were children" stays a hint, #116).
    Every taken light left the abyss darker and its creatures hungrier; your own
    embers were part of the taking — the love-and-greed echo, by design.
    Breaking the cycle: **the island stops taking.** You choose the abyss as
    home without abandoning the island. (#102, #106)
13. **The Final Chain** *(resolution)* — one unbroken descent at full light. The
    predators' hunger was homesickness for the light that was taken; with you
    home, they follow your light instead of hunting it. Every earlier hunt is
    reframed, not retconned. Staged to rhyme with The Watching Departure (beat
    3). The challenge is the descent itself (terrain, no landing), not
    predators; exact design belongs to Layer 7. (#109, #115)
14. **Epilogue: Quiet Change** — the Guild board's record line reads your name;
    the Memorial Wall gains no new names; each hub NPC adapts in a line. The
    island economy after the ending is out of scope until post-M2.

*Optional, per-layer moments (outside the main sequence):* Riding the Giant
(#55), Felling the Canopy (#57), The Curious Companion (#58).

### Beat Placement by Act

**Act 1 — Origin (Layers 1–3):** 1, 2, 3, 4, 5, 6. *M2 ships 1–5*, closing on:
**M2 closing beat** — Weaver defeated, the landing-arena station repaired, the
first ride up from the landing arena plays the full Watching Departure
through Layer 1 (its hoverers,
crawlers, and lurker eyes opening to watch, not hunt), and the Guild board logs
your new depth: still short of the Last Explorer's record. The slice ends on
that gap.

**Act 2 — Theft (Layers 4–5):** 7, 8, 9. *Sketch.*

**Act 3 — Cycle (Layers 6–7):** 10, 11, 12, 13, 14. *Sketch.*

---

## Pacing and Flow

### Narrative Tempo

Waves. Layers are near-silent exploration: the journal, props and the odd
memorial carry the story while the player plays. Story lands loudly at bosses
and on hub returns. Discovery is the reward for daring (brief), never a
cutscene in the way of a chain.

### Tension Curve

Escalating waves. Each layer rises from a quiet arrival to its boss; each hub
return is a breathing beat (warm palette, people, Watching Departure). Peaks
rise act by act: Weaver → Rootmother (origin) → Eye of the Storm (theft) →
Last Explorer (cycle).

### Story Density

- **In layers:** light. Journal entries, props, *one* set-piece moment per layer
  at most (Layer 1: The Last Entry).
- **At bosses:** heavy. Story reveals land after victory, never mid-fight.
  Boss *introductions* (e.g. the Weaver heard and glimpsed in S5) may come
  before or during a fight; The Fall is a gameplay moment, not a reveal.
- **In the hub:** medium. NPC lines change with flags after each boss or
  discovery; the Memorial Wall and Guild board update.
- **The main path carries every reveal and every M2 pointed clue**; optional
  content carries texture and world history, so a player who skips side areas
  never misses story they need.
- **Set pieces** (The Speck's pull-back, The Fall's slow-mo, the Departure's
  eyes) go through `Fx` and honour `reduced_motion` / `reduce_flashing`
  (architecture accessibility rule; party review 2026-11-12).

### Key Moments

**Highest tension:** the Last Explorer mirror fight (beat 11).
**Emotional climax:** The Final Chain (beat 13), when the hunt becomes a
homecoming.
**Resolution beat:** the epilogue record line with your name on it (beat 14).

*Hub line cadence:* see Dialogue Framework → Repeat Visits (one idle line, then
the shop).

---

## Characters

### Protagonist

#### Glim

**Description:** Abyss Island's youngest diver. The island calls you "Glim" —
old slang for a small light — the name Oda gave the "shipwreck orphan". A cute
kid's name that, in hindsight, says exactly what you are (deniable clue).

**Background:** Raised by Oda Vell in a small house beside the Guild, after she
"found you in a wreck". Years ago, when you were still a child, she went back
down and never returned. You stayed in the house; Old Tessaly looked in on you.

**Voice:** silent. Never gendered in any player-facing line (docs use
they/them). **Translator note:** Glim takes gender-neutral forms in every
language. Glim's inner conflict is shown through play — carrying vs depositing,
riding up vs diving on — never stated.

**Motivation:** Beat Oda's all-time depth record on the Guild board and learn
what happened to her. (Later: decide which home is yours.)

**Strengths:** your light. The longer the chain, the brighter, stronger and
richer you are — and the abyss responds to you in ways it responds to no one.

**Flaws:** greed for depth and embers — Oda's flaw, inherited by example. The
record is the lure (Story Foundation).

**Conflicts:**
- Internal: belonging — the island that raised you vs the abyss that made you;
  love for Oda vs what she did.
- External: predators that crave your light; the record; Oda herself at the
  Bottom.

---

### Antagonists

There is no villain. Opposition comes from hunger and from greed.

#### The Hunger (the abyss's creatures)

**Description:** the predators and bosses of every layer. Hungry, not hateful
(#109).
**Background:** the island has taken the abyss's light for ages; every taken
light left the abyss darker and its creatures hungrier.
**Goals:** your light — a piece of what was taken.
**Methods:** sensing light, telegraphing, hunting (always fairly: Pillar 2).
**Relationship to protagonist:** kin who don't know it — or do. They watch you
leave (The Watching Departure) and, at the end, follow you home.
**Sympathetic elements:** their hunger is homesickness. "Bosses were children"
stays an unconfirmed hint (#116).

#### Oda Vell, the Last Explorer (she/her)

**Description:** the island's legend; holder of the all-time depth record; her
name is on the Memorial Wall. At The Bottom, changed by greed, she is fought as
a mirror of your own verbs.
**Background:** the greatest explorer the island had. With a dive partner (named
in E6), she found a living spark of the abyss — you — and carried it up as the greatest relic ever found. Then
she raised it as her child.
**Goals:** at first, glory and the greatest relic; then, to keep you; finally,
something pulled her back down — greed for the light and depth she gave up, or
guilt and a wish to return what she took. Her journals never settle which; the
mirror fight shows greed won.
**Methods:** the same as yours — pogo, chain, light. The mirror fight.
**Relationship to protagonist:** mother, thief, the record to beat, the person
you might become.
**Sympathetic elements:** she loved you anyway. Her journals show both love and
greed in her own words; tragic, not evil (#114).

---

### Supporting Characters

#### Old Tessaly (he/him) — Guild keeper

**Role:** stand-in family; mentor; informant.
**Personality:** gruff warmth; dry; "Old" is the island's affection.
**Function:** keeps the record board and the Memorial Wall; knew Oda best; the
one islander who never quite believed the orphan story (#110) and drops the
deniable clues in his lines. No shop, so his whole job is story.
**Key Moments:** registers your First Dive (beat 1); the Memorial Wall (beat 2);
logs your depth at the M2 closing beat; reads your name on the record line in
the epilogue (beat 14).

#### The Cartographer

**Role:** informant.
**Personality:** precise, fussy about lines.
**Function:** sells maps and hints. Half of the Layer 1 map is copied from
Oda's own surveys — her handwriting is a trace of her (#113).

#### The Naturalist

**Role:** informant; the eyes of the "creatures recognise you" clue.
**Personality:** curious, a little too fascinated by you.
**Function:** pays for journal entries; from Layer 2 on, notes that creatures
behave oddly around you (deniable, then less so).

#### The Smith

**Role:** supporting; a trace of Oda.
**Personality:** few words, all practical.
**Function:** sells rule-bending gear. Forged Oda's lantern; one line connects
your Wick gear to hers.

#### Oda's house (your shared home) — a place, not a character

A small interior beside the Guild: your bed, her empty chair, her gear wall.
Props and flag-gated lines only. Each page of Oda's journal you find is
**pinned to her gear wall** as a flag-gated prop: you read pages in the Journal
tab; the house shows them piling up while her chair stays empty (#113, *Their
Presence*). **Not** a save or rest point (architecture: save triggers are only
autosave points and Quit). **GDD change needed:** the hub gains one small
interior (E5 hub scope).

---

## Character Arcs

### Glim — transformation

**Starting State:** a record-chaser who believes the orphan story and wants to
be Oda.
**Transformation Moments:** The Watching Departure (something knows you); the
Origin reveal (you belong down here); the Theft reveal (she took you, and loved
you); the mirror fight (you could become her).
**Ending State:** the one who stops the taking. The choice is enacted, not
selected: diving into The Final Chain *is* choosing the abyss as home, without
abandoning the island (no branching ending; architecture: linear lines).
**The question Glim answers:** is home where you were raised, where you were
made, or what you refuse to take?

### Oda Vell — negative arc, told backwards

**Starting State (as the player meets her):** a legend and a lost mother.
**Transformation Moments (revealed through journals):** the find; choosing to
raise the relic as a child; the pull of the deep returning; going back down.
**Ending State:** consumed by greed at The Bottom — the record-holder as a
warning.
**The question Oda answers:** can love outweigh greed? (Not in the end — but
her journals make you wish it had.)

### Old Tessaly — flat arc

**Starting State:** keeps the board, mourns the names, doubts the story.
**Transformation Moments:** each of Glim's returns.
**Ending State:** his doubt held true — and the Memorial Wall gains no new
names.
**The question Tessaly answers:** is it worth keeping watch over people who
keep leaving? (Yes: this time one came back.)

*Tessaly's First Dive line:* clue 1 in the M2 Clue Budget (Dialogue Framework);
the line itself is written after the voice-anchor gate.

---

## World Building

### World Overview

**Setting:** Abyss Island, a small industrial island built around the mouth of a
vast pit, and the seven layers below it. Ships from an unseen mainland come for
relics and leave.

**World Type:** original low fantasy, early-industrial: steam winches, iron lift
cages, mine carts, rope and scaffold works, ember lanterns.

**World Rules:**
- **Light is the abyss's life.** Embers are scraps of its light: the island's
  coin and its fuel. They burn in the lanterns and heat the boilers of the lift
  winches. The Guild fuels the lifts; riding is free. Depositing embers on
  arrival is, in-world, feeding the island. The island literally runs on the
  taking.
- **Light draws the hungry.** The abyss's creatures sense and crave light.
- **The ground is a sanctuary.** Landing ends the chain and puts you out of
  reach of light-hunters. Each layer bends one rule (Freezing Magma flips this
  one).
- **The Anchor.** A lantern anchor binds a *spark* to the island; death snaps it
  back (#111). Only Glim has a spark, so only Glim comes back. To islanders,
  anchors are waymarker lanterns that guide divers home, and Glim's returns are
  called luck — a deniable clue the Memorial Wall quietly contradicts.
- **Each layer has its own sky.** Depth is not darkness.
- **Amber is yours** (GDD palette rule). Lit ember lanterns appear only in the
  hub and as lantern anchors; the island is lit in your colour (a quiet clue).
  Old industrial lamps in the layers are dead or a cold, non-amber tint, so
  amber still reads as *you* during play (party review, 2026-11-12).

**Atmosphere:** a working island of brick, brass, rope and warm lantern light
above; below, the beautiful-strange abyss. Melancholic wonder.

**Unique Elements:** an economy and an industry fuelled by the very light the
protagonist is made of.

**M2 production scope:** the industrial age reads through a few static props
(lift cage, one winch, some pipe), no animated machinery; one mainland trace —
a stack of relic crates by the lift, stamped for shipping.

---

### History and Backstory

**Timeline Overview:**
1. **Ages ago** — the abyss makes and loses children of its own (sparks; "bosses
   were children" stays a hint).
2. **Generations ago** — the island is settled; the first divers bring up light.
   The Explorers' Guild is founded; the Memorial Wall begins.
3. **The industrial age** — mainland ships create a relic market; winches, lift
   cages, scaffolds and mines push into Layer 1 (its scaffolds, Rope Works and
   Old Mine are the island's old industry, now dark).
4. **Oda's era** — Oda Vell sets the all-time depth record and brings up the
   greatest relic ever found: a living spark. She raises it as Glim.
5. **Years ago** — Oda goes back down and is added to the Memorial Wall.
6. **Now** — Glim registers for the first dive.

**Major Events:** the founding of the Guild; the relic boom; Oda's record and
her find; Oda's last dive.

**Legends and Myths:**
- Divers' saying: "The deep remembers every light." Deniable: islanders mean the
  dead.
- The orphan story: Glim washed up in a wreck, and Oda took them in (#110).
- Anchors guide divers home; Glim is lucky.

**Hidden Secrets:** Glim's origin; Oda's theft; taken light makes the abyss
hungrier; the cycle; the bosses' nature (unconfirmed).

---

### Factions and Organizations

#### The Explorers' Guild
**Purpose:** registers dives, keeps records and the Memorial Wall.
**Leadership:** Old Tessaly, the keeper.
**Goals:** depth, records, bringing divers home.
**Methods:** the record board, contracts, the lifts (fuels them with embers).
**Relationships:** sells the haul to the mainland buyers; proud of its dead.
**Story Role:** the lure (the record board) and the conscience (the Wall).

#### The mainland buyers *(unseen)*
**Purpose:** buy relics and light.
**Leadership:** never shown.
**Goals:** more.
**Methods:** ships, prices.
**Relationships:** the reason the island takes.
**Story Role:** what "the island stops taking" costs. In M2, present only as
the stamped relic crates by the lift; the Docks stay deferred (#94).

---

### Key Locations

#### Abyss Island (hub)
**Description:** a two-screen industrial village on flat ground around the pit's
mouth: the Lift with its ember-fired winch and the relic crates, the Guild with
the record board and Memorial Wall, Oda's house, the Smith's forge, the
Cartographer, the Naturalist.
**Narrative Significance:** home; where the story is read and the deposits are
made.
**Atmosphere:** warm daylight and lantern light, brick and brass, people.
**Key Events:** First Dive, Memorial, M2 closing beat, epilogue.
**Inhabitants:** Old Tessaly, the Smith, the Cartographer, the Naturalist.

#### Oda's house
**Description:** a small interior beside the Guild: bed, empty chair, a gear
wall that fills with her pinned journal pages.
**Narrative Significance:** *Their Presence* (#113).
**Atmosphere:** quiet, lamplit, lived-in, missing someone.
**Inhabitants:** no one now.

#### Layer 1 — Edge of the Abyss (M2)
**Description:** the island's old industrial frontier fading into the wild
abyss: S1 The Lip, S2 Scaffold Drop, [A] Rope Works, S3 The Lantern Door, S4
Explorers' Grave, [B] Old Mine, [C] Sky Ledge, S5 Weaver's Hollow. Its lamps
are dead.
**Narrative Significance:** the last daylight; the island's footprint thins
the deeper you go. Deniable clues only.
**Atmosphere:** scaffolds and rope against fading daylight, then the dark.
**Key Events:** The Last Entry (S4); The Weaver and The Fall (S5).
**Inhabitants:** crawlers, hoverers, lurkers, the Weaver and its spiderlings.

#### Layer 2 landing arena (M2)
**Description:** a broken Lift Station under the Bright Moon sky.
**Narrative Significance:** Weaver phase 2; the slice's last step; the station
is repaired on victory, and the first ride up closes M2.

#### Layers 2–7 *(sketch)*
Bright Moon, Inverted Trees, Great Mountain, Whirlstorm Hell, Freezing Magma,
The Bottom: each with its own sky and rule twist (GDD). Details come with each
layer's milestone.

---

## Dialogue Framework

### Dialogue Style

**Overall Voice:** island dialect — a working people's English shaped by rope,
iron, boilers and depth. Sayings, trade words and understatement; subtext over
exposition; nobody explains the lore.

**Dialect guardrail:** dialect is carried by word choice, idiom and rhythm,
never phonetic spelling or dropped letters ("goin'", "o' the"). Reason: 8 px
legibility and translation. Each line must still read clearly to a non-native
English player.

**Voice-anchor gate:** before any NPC lines are written (E5), sonlm approves
**3 anchor lines per speaker** (Tessaly, Smith, Cartographer, Naturalist, Oda's
journal hand, death card). All later lines match the anchors.

**Style Elements:**
- Formality: casual, working-class, respectful of the dead.
- Period: early-industrial island; no modern slang.
- Verbosity: concise — a speech line fits **≤ 2 rows** of the 360 px speech box,
  **measured** in the UI font (not counted); a new flag unlocks **≤ 3 lines**
  per NPC (proposal for UX O5).
- Humor: dry and understated, hub only; never in reveals or the Memorial.
- Profanity: none (mild trade oaths at most, e.g. "rust and ropes").

**Character Voice Distinctions:**
- **Old Tessaly:** gruff, short sentences, island sayings ("The deep remembers
  every light"); calls Glim "Glim". Says less than he knows.
- **The Smith:** fewest words of anyone; speaks in tools and materials.
- **The Cartographer:** precise, fussy; distances, bearings, corrections.
- **The Naturalist:** curious; asks questions instead of stating; a little too
  interested in Glim.
- **Oda Vell (journal pages only):** first person, warm and vivid early,
  clipped and hungry later; her love and greed in the same hand.
- **Glim:** silent; never gendered.

### Repeat Visits

Lines change only when a new slot flag is set. With nothing new, the NPC says
**one idle line** (from a small per-NPC set, rotated by a saved per-NPC talk
counter — no randomness, project rule; a new `SlotState` field in E5, no
migration needed) and then opens the shop list. Tessaly (no shop) opens the
record board. Old story lines are never replayed in the speech box.

### M2 Clue Budget (GDD: 2–3 deniable clues in Layer 1)

Pointed clues (exactly three):
1. Tessaly, First Dive — Oda never let Glim near the pit's edge.
2. The Watching Departure — the creatures watch you leave.
3. Tessaly, after the Weaver — Glim keeps coming back; "luck".

Ambient texture, never pointed at by any line: the name "Glim"; the hub lit in
amber; the anchor rule (only Glim comes back). Everything else in M2 is
character, not clue. The E6 Memorial clue (Oda's dive partner's tag) is an
Act 2 thread about the theft, not an origin clue, so it sits outside the
budget.

---

### Key Conversations (M2)

#### First Dive
**Participants:** Old Tessaly, Glim.
**When:** new game, at the Guild (sets `first_dive`).
**Topic:** registering the dive; Oda's record on the board.
**Purpose:** inciting incident; the lure; clue 1.
**Tone:** gruff warmth, worry under it.

#### The Memorial Wall
**Participants:** Old Tessaly (Glim reads the Wall).
**When:** first interaction with the Wall (sets `memorial_read`).
**Topic:** the lost; Oda's name.
**Purpose:** grief; sets up the Last Explorer.
**Tone:** quiet, no humour.

#### After the Weaver (M2 closing beat)
**Participants:** Old Tessaly, Glim.
**When:** first hub return after `weaver_defeated`.
**Topic:** logging the new depth — still short of Oda's record; Glim keeps
coming back.
**Purpose:** ends the slice on the gap; clue 3.
**Tone:** proud, uneasy.

#### Smith — Oda's lantern
**Participants:** the Smith, Glim.
**When:** first visit; a line on buying a Wick (`bought_wick`).
**Purpose:** a trace of Oda (he forged her lantern).
**Tone:** terse, fond.

#### Cartographer — Oda's handwriting
**Participants:** the Cartographer, Glim.
**When:** first visit; on buying the Layer 1 map (`bought_map`).
**Purpose:** a trace of Oda (half the map is her survey).
**Tone:** precise, wistful at the edges.

#### Naturalist — first journal payout
**Participants:** the Naturalist, Glim.
**When:** first journal entry sold (`first_entry_sold`).
**Purpose:** introduces the observer. Character only in M2, no clue (creature
clues start at Layer 2).
**Tone:** eager, questioning.

#### Death card lines
**Participants:** none (narration).
**When:** each death (UX: death line = cause + how to avoid; auto-advances
~3 s; kept for the Journal death log).
**Format:** about one row, readable in 3 s. Island idiom may colour the
*cause*; the *how to avoid* is always plain words (Pillar 2: every death
teaches; that beats voice).
**Tone:** matter-of-fact, kind, never mocking.

---

### Branching Dialogue System

**System:** linear dialogue, flag-gated.
**Notes:** architecture rule — per-NPC ordered `{key, requires_flag}` lists in
`rules/dialogue.gd`, strings in `game/text/strings.csv`. No choices, no trees;
Glim is silent. Player agency is expressed through play (Characters: Glim).

**Data rules (party review, 2026-11-12):**
- **Flag ids are save data:** never renamed once testers have saves (same rule
  as persistent object ids). M2 flags: `first_dive`, `memorial_read`,
  `weaver_defeated`, `bought_map`, `bought_wick`, `first_entry_sold`; set
  through rule methods on `Game.slot`.
- **String keys:** `NPC_<WHO>_<FLAG>_<n>`, `NPC_<WHO>_IDLE_<n>`,
  `DEATH_<CAUSE>_LINE` + `DEATH_<CAUSE>_TIP` (cause, then plain tip), `JOURNAL_<ID>_BODY` (architecture example).
- **Length validator:** a pure validator measures every speech string in the UI
  font against the 2-row limit and returns errors; `tools/export.sh` refuses to
  build on any error.

---

## Environmental Storytelling

### Visual Storytelling

**Set Dressing:** the island's footprint thinning with depth. Layer 1 starts
with working scaffolds and rope, passes the abandoned Rope Works and Old Mine
(dead lamps, snapped lines, rusted carts), and ends in wild abyss at Weaver's
Hollow. Camps of lost explorers mark how far the island reached.

**Environmental Details (M2):**
- **The Last Entry (S4):** Oda's camp on her last dive — bedroll, a cold
  lantern, a half-written journal: "going deeper." Unsigned. **Her cold lantern
  is a lantern anchor:** lighting it is the moment, and from then on Glim
  respawns at her camp (one of Layer 1's ~5 anchors; party review 2026-11-12).
  Glim pins the page on Oda's gear wall at home: Glim recognises the hand
  without a word; the player infers (character, not an origin clue — outside
  the clue budget).
- **Dead lamps:** the island's old lamps below are dark or cold-tinted; only
  your light is amber down here.
- **The hub:** amber lanterns, the lift cage and ember winch, stamped relic
  crates, the record board, the Memorial Wall, Oda's house with its empty chair.

**Visual Symbolism** (each with one job):
- **The lantern — you.** Amber light, the Anchor, Oda's lantern from the
  Smith, dead lamps below, her cold camp lantern relit. Who still burns.
- **The open eye — recognition.** Lurker eyes (fear) → The Watching Departure
  (recognition) → following you home in The Final Chain. The one symbol whose
  meaning changes across the game.
- **The rope — the line home.** Lifts, scaffolds, the Rope Works. At The Fall
  the Weaver cuts its own strand anchors and the fight drops into Layer 2,
  where the station is broken: the first descent with no way back up until you
  win.
- **The empty chair — absence.** Oda's chair at home; echoed by abandoned camps
  below, The Last Entry first.

**Color and Lighting:** amber is yours (GDD palette rule): lit only in the hub
and on lantern anchors, which makes the hub lit in your colour (ambient
texture). Each layer has its own sky; depth is not darkness.

---

### Audio Storytelling

**Ambient Design:** organic world, synthetic light (GDD). Layer 1 sounds like
creaking rope, wind, dripping, iron settling; the hub adds boiler hiss, the
winch and voices. Silence after a Snuff.

**Music Integration:** chain-reactive music (GDD). **Shared motif:** the hub
theme's melody is, quietly, an abyss melody. Fragments return inside layer
themes; it plays in full, at last, in The Final Chain. *Production note (E3):*
compose the hub theme first; layer themes quote it.

**Voice Elements:** no voice acting.

**Sound Design Narrative:** your light is synth, the world is organic — you
sound like you don't belong to the world you're in, until The Final Chain. The
lurker growl is a fair warning (Pillar 2) and is always mixed above the music.

---

### Found Documents

**Document Types:** journal objects in the world (read with ↓ while standing
still); Oda's journal pages (from Act 2 on; The Last Entry in M2); creature
entries in the Journal tab.

**Quantity (M2):** 4 found documents — 3 written by the island's lost
(Rope Works ×2, Old Mine ×1) and The Last Entry (S4).

**Content Focus:**
- **The island's lost** (Rope Works, Old Mine): industrial-age workers and
  divers whose names match the Memorial Wall; the yard and the mine going dark;
  "the taking". World history only — no origin clues (budget spent).
- **Oda's pages:** love and greed in her own hand (Act 2's Trail); in M2 only
  The Last Entry.

**Discovery:**
- Required: The Last Entry (main path, S4).
- Optional: the 3 side-area documents.
- **Reading a document opens a screen and pauses gameplay** (ScreenRouter,
  like every screen); covered by a test.

**Rewards:** entries are never lost (world progress). The Naturalist *copies*
each new entry and pays 10 embers for the copy (GDD: "reads journal entries");
originals stay with Glim. Reading The Last Entry sets `last_entry_read`, and the
page appears pinned to Oda's gear wall at home.

### Playtest Check (M2)

Ask testers after the slice: **"Where do you think Glim comes from?"** Target:
some suspect the abyss, none are certain. All certain → clues too loud; none
suspect → too quiet. The playtest tunes clue volume (party review 2026-11-12).

---

## Narrative Delivery

### Cutscenes

**Approach:** no cutscene mode. Scripted moments are in-engine and play around
the player inside the room, with input kept live wherever it is safe. No
letterbox, no pre-rendered video, nothing to skip.

**M2 scripted moments:**
- **Weaver introduction** (S5): heard and glimpsed before the arena; you keep
  moving.
- **The Fall:** at half health the Weaver cuts its strand anchors; slow-mo via
  `Game.clock`; the one allowed mid-chain room cut (architecture).
- **Boss-defeat slow-mo:** a short `clock.request`, then control.
- **The Watching Departure:** plays during the lift ride up (see below).
- **The Last Entry:** no cutscene — you read it (a document screen, gameplay
  paused) and light Oda's lantern (an anchor).

**Length:** each moment fits inside the gameplay beat it decorates (a ride, a
phase change, a defeat), adding no time.
**Accessibility:** every moment goes through `Fx` / `Game.clock` and honours
`reduced_motion` / `reduce_flashing`.

### The Lift Ride and The Watching Departure

- **The ride up has a fixed duration** that covers the full Departure: a short
  scripted transition through `World` (room swaps go through `World`). Fast
  travel down or sideways plays no Departure. Ride timing is mocked with the
  speech box at E5 start (UX).
- **Full gathering** plays on the first ride up from a station's layer **after
  the player has met a lurker** (`lurker_met`: set when a lurker telegraph
  starts with the lurker inside `World.play_rect()`, not the viewport). Before
  that, rides are plain — the eyes always carry fear first.
- Keyed by the station's layer (`departure_l1_seen`, `departure_l2_seen`); the
  cast is the creatures of the layers the ride passes (M2: Layer 1's cast, also
  for the ride from the landing arena).
- **Later rides** show a few eyes at the edge of the light within the same ride
  time. Nothing to skip; the recurring feeling stays.

---

### In-Game Storytelling

**Opening (new game)** *(target from E5; until the hub exists, New Game starts
in S1)*: fade in **in Oda's house** — Glim wakes in bed beside the empty chair.
↓ interact is taught on the door. Outside, Old Tessaly at the Guild registers
the First Dive (clue 1) and points at Oda's record on the board — the **only
required talk**. The Memorial Wall is on the way to the lift, optional. The map
and Journal tabs are introduced on the first station rest. Story and hub within
the first two minutes (GDD: hub, map and journal within 5).

**Methods:**
- **NPC conversations:** hub only, linear, flag-gated, ≤ 3 lines per new flag.
- **Environmental cues:** dead lamps, camps, relic crates, the empty chair,
  the pinned pages.
- **Player actions:** relighting Oda's lantern; carrying vs depositing; the
  descent itself; The Final Chain as the ending choice.
- **UI:** the Journal (documents, creature entries, the death log), the Guild
  record board, the Memorial Wall.

**Show vs Tell:** show. Nobody explains the lore; reveals are confirmed, not
lectured.
**Interruption tolerance:** story never stops a chain. Only documents and NPC
speech open story screens, and only when you choose to (↓ while standing
still).
**Player control:** speech advances one line per confirm; documents close at
will; nothing forced except The Fall (a gameplay moment) and the First Dive
registration.

---

### Optional Content

- **Optional:** the Memorial Wall visit, the side-area documents (Rope Works
  ×2, Old Mine ×1), idle lines, Oda's pages off the main path (Act 2+),
  creature entries.
- **Main path carries every reveal** and every M2 pointed clue; skipping side
  areas never costs story comprehension.
- **Deferred:** the Gallery (#99), the Docks (#94).

### Endings

**Single ending** for every difficulty and completion level: The Final Chain,
then the Quiet Change epilogue. No secret or completion-gated endings; no
"best" ending. The epilogue's record line is story, not stats: every finished
run gets it, while the Guild's record statistics still exclude assisted runs
(UX).

**M2 flags added here:** `lurker_met`, `departure_l1_seen`, `departure_l2_seen`.

---

## Gameplay Integration

### Narrative-Gameplay Connection

**Integration Approach:** the mechanics *are* the story. The chain is your
light, the light is what you are, and the abyss responds to it. Story is
delivered around play (hub, documents, environment) and enacted through play
(the descent, The Final Chain); it never interrupts a chain.

**Mechanic-Theme Alignment:**

| Mechanic | Theme it carries |
|---|---|
| Chain-Light (brighter with each link) | burning bright vs restraint; you are light |
| Pogo hits pay embers | **you take too**: each hit knocks light out of a crawler, hoverer or spiderling; embers are that light — the love-and-greed echo of Oda and the island. Lurkers can't be hit (architecture: Slash/Pogo mask) |
| Held → carried → deposited | greed: how much will you risk before you bank? |
| Snuff | restraint: going dark to survive |
| Flare Toss | giving up part of your light to save yourself |
| Lantern anchor / respawn | the Anchor: only a spark comes back (only Glim) |
| Ember Cache drawing lurkers | the abyss wants back what you took |
| Deposit on arrival | feeding the island |
| Weaver Silk → Swing | your first new ability is something taken from the abyss |
| Weaver (light-shy) / Hollow Furnace (light is warmth) | restraint vs commitment |
| The Final Chain | creatures **rise to meet you**: every bounce offered, not taken |

**Story-Gameplay Balance:** play first. Story moments are short and mostly
optional; the main path carries the reveals.

**Ludonarrative Considerations:**
- **Killing kin → "you take too."** The story does not excuse the pogo: Glim
  takes light like everyone on the island. Creatures reform when you rest (GDD
  enemy respawn), so nothing is wiped out. The Final Chain inverts it: the
  creatures offer themselves as footholds, and taking becomes receiving.
- **Spark rule:** a hit creature bursts into sparks, never blood or corpses.
  The sparks leave in the creature's own tint and **turn amber as they fade** —
  its light becomes yours. Small and in place (no travel to the HUD); not a
  flash; through `Fx` with `reduce_flashing`; `CPUParticles2D` with a cached
  material, warmed at room load (architecture performance rules).
- **Boss defeats read as a win first** (Pillar 2 readability): slow-mo, a
  burst of light, the station repairing. Then, as a coda, the boss dims and
  withdraws downward into the dark in sparks. Bosses are never shown dying —
  keeping "bosses were children" an open hint and hinting the abyss takes its
  children back.

---

### Story Gating

**Gating Approach:** soft. Story never locks progress; skill gates (chain
gates ≥ 4 / ≥ 8 links) and the Weaver gate the world.

**Story-Locked Elements:** none in M2 beyond the First Dive registration
(required once, at new game). Swing comes from Weaver Silk (a boss reward, not
a story gate).

**Cutscene Triggers:** Weaver introduction (entering S5); The Fall (Weaver at
half health); boss-defeat slow-mo; The Watching Departure (lift ride up, after
`lurker_met`).

**Mandatory Story Beats (M2):** First Dive; The Last Entry (main path, S4);
The Weaver / The Fall; the M2 closing beat (Tessaly, after the Weaver — the
end of the slice, not a gate).

**Optional Narrative:** Memorial Wall visit, side-area documents, idle lines,
NPC trace lines (Smith, Cartographer, Naturalist), Oda's house.

---

### Player Agency

**Agency Level:** witness the story, **enact** the choices. No dialogue
choices; Glim is silent.

**Player Influence:** how bright to burn, what to risk, what to carry home,
which optional places to explore — all play, never menu choices. The ending
choice is diving into The Final Chain.

**Choice System:** none (linear, flag-gated; architecture).

**Role-Playing Freedom:** expressed through play style — a cautious banker or
a greedy chain-runner. The story frames both as Glim's inheritance from Oda.

---

## Production Planning

### Writing Scope

**Estimated Word Count:** M2 ≈ 2,000–2,500 words; full game ≈ 15,000–20,000
(the low end of Moderate; 7 layers + hub growth).

**Content Breakdown (M2):**
- NPC lines: ~40 lines (4 NPCs × story flags ≤ 3 lines + 3 idle lines each)
  ≈ 700 words.
- Found documents: 4 (3 by the island's lost, The Last Entry) ≈ 500 words.
- Creature entries: 5 (walker, hoverer, spiderling, lurker, Weaver) ≈ 300 words.
- Death card lines: ~8 causes (cause + how to avoid) ≈ 120 words.
- Memorial Wall: ~20 names + Oda + the partner (E6); Guild board labels.
- UI/system text: owned by UX, not counted here.

**Scene Count (M2):** 6 hub conversations, 4 documents, 5 scripted moments
(Weaver intro, The Fall, defeat slow-mo, Watching Departure, the opening in
Oda's house).

**Dialogue Lines:** ~40 (M2); linear, so no branching multiplier.

**Branching Complexity:** none (architecture: linear, flag-gated).

### Content by Epic (M2)

| Epic | Narrative content |
|---|---|
| **E1** Kit v2 | **Death card lines** (the death card and `death_log` ship in E1) — so the death-card voice anchors are approved at E1, not E5 |
| E2 Weaver prototype | Weaver introduction staging (placeholder) |
| E3 Audio | hub theme composed first, carrying the shared motif |
| **E4** Layer 1 world | 3 documents + The Last Entry; **the Memorial Wall name list** (written with the documents so names match; displayed in E5); Oda's cold lantern as anchor `anchor_s4_oda` in S4; dead lamps; `last_entry_read`, `lurker_met` set from E4 builds on (saves carry them until the hub shows their payoff) |
| **E5** Hub *(M → L)* | Oda's house (new interior) + the new-game opening; NPC lines and idles with a per-NPC `{seen, idle}` record in `SlotState`; Memorial Wall (displays the E4 list); Guild board; relic crates; The Watching Departure with a fixed ride; creature entries; the flag registry and its validator |
| **E6** Weaver final | The Fall / defeat staging (win first, withdraw coda); M2 closing beat (Tessaly); **Memorial clue = Oda's dive partner's tag** in a Swing secret, adding the partner's name to the Wall (name approved by sonlm with the E6 lines) |
| E7 Slice polish | full Field Journal; text-length validator pass; playtest question on clue volume |

### Writing Workflow

1. sonlm approves **3 voice-anchor lines per speaker** (death card at E1;
   NPCs, documents and Oda's hand at E4/E5).
2. Claude drafts each story's strings against the anchors and this document.
3. sonlm edits and approves before commit; strings go into `strings.csv` with
   the key scheme; the length validator and flag validator must pass.
4. The brief's AI-assisted pipeline disclosure covers this.

### Data Validation

- **Flag registry:** every flag id lives in one list in `rules/`. A pure
  validator checks that every `requires_flag` in `dialogue.gd` and every flag a
  rule method sets exists in the registry (typos fail the build, not the
  player). Run by `tools/export.sh` and the test suite.
- **Length validator:** every speech string measured in the UI font against
  the 2-row limit.

---

### Localization

**Approach:** English only in M2 (UX). Room is left: all text is in
`strings.csv` via `tr()`; gutter labels are icons.
**Future considerations:** dialect lives in word choice, not spelling (easier
to translate); Glim takes gender-neutral forms in every language; text growth
is checked by the length validator per language; CJK glyph size is open (UX
O18); Vietnamese needs a font with stacked marks (UX).

---

### Voice Acting

**Approach:** text only.
**Rationale:** solo dev, 8 px text-first presentation, localisation room;
creature sounds carry the abyss's voice (GDD audio).

---

### GDD, Epics and Other Changes Required

Applied in **one pass right after this workflow**, logged in the GDD
decision log:
1. **Hub:** add Oda's house (a small interior beside the Guild; not a save
   point); new-game opening starts there (E5).
2. **Memorial clue (E6):** now Oda's dive partner's Guild tag (adds the
   partner's name), not "the first name tied to the Last Explorer".
3. **The Last Entry:** Oda's unsigned camp; her cold lantern is a lantern
   anchor (E4).
4. **Naturalist:** copies entries and pays for the copy.
5. **Lift ride up:** fixed duration hosting The Watching Departure; full
   gathering after `lurker_met`, once per station layer.
6. **Boss defeat:** win first, then dim-and-withdraw coda; sparks shift from
   the creature's tint to amber.
7. **World lore:** embers fuel the island (lanterns, winch boilers); amber lit
   only in the hub and on anchors; layer lamps dead or cold.
8. **Narrative and Tone section:** replace the designer note with a pointer to
   this document; names (Glim, Oda Vell, Old Tessaly).
9. **M2 flags and ids:** flags `first_dive`, `memorial_read`,
   `weaver_defeated`, `bought_map`, `bought_wick`, `first_entry_sold`,
   `last_entry_read`, `lurker_met`, `departure_l1_seen`, `departure_l2_seen`
   (+ the partner-tag flag in E6); persistent ids `anchor_s4_oda`,
   `prop_house_page_last_entry`. All are save data: never renamed once
   testers have saves.
10. **Success metrics:** add the clue-volume playtest question.
11. **project-context.md:** add `narrative-design.md` to the design sources of
    truth, so story-writing agents load it.
12. **UX update at E5 start (gds-ux):** Oda's house and the opening, the lift
    ride timing, the speech box (closes O5 with the length validator).
13. **Epic sizes:** E5 Hub M → L. Epics E1, E4, E5, E6 gain the narrative
    items in Content by Epic.

---

## Appendix: Character Relationships

### Relationship Map

```
                 THE HUNGER (the abyss's creatures)
              hunt your light ↑      ↓ watch you leave / follow you home
                              |      |
  OLD TESSALY ──(stand-in family, doubts the story)──► GLIM ◄──(raised, stole)── ODA VELL
       │                                              │  ▲                          │
       │ keeps her name on the Wall                   │  └──(mirror fight, record)──┘
       └──────────────────(knew her best)──────────────────────────────────────────►┘
                                                      │
        SMITH (forged her lantern) · CARTOGRAPHER (copied her surveys)
        NATURALIST (watches Glim; copies entries) ──── traces of Oda / observers
                                                      │
                       THE ISLAND + MAINLAND BUYERS ── take the abyss's light
```

### Relationship Key

- Oda Vell → Glim: mother and thief; carried a living spark up as a relic and
  raised it; the record to beat; the mirror at The Bottom.
- Glim → Oda: love, then the question of forgiveness; risk of becoming her.
- Old Tessaly → Glim: stand-in family; looked in on Glim after Oda left; never
  believed the orphan story.
- Old Tessaly → Oda: knew her best; keeps her name on the Memorial Wall.
- The Smith → Oda: forged her lantern (trace).
- The Cartographer → Oda: half the Layer 1 map is her survey (trace).
- The Naturalist → Glim: curious observer; from Layer 2, notices creatures
  behave oddly around Glim.
- The Hunger → Glim: crave the light that was taken; watch Glim leave; at the
  end, rise to meet Glim's feet.
- The island and the mainland buyers → the abyss: take its light; the cause of
  its hunger and of the cycle.
- Oda's dive partner (E6, name TBD) → Oda: went down with her on the dive she
  found Glim; a name on the Wall (Act 2 thread).

---

## Appendix: Story Timeline

### Chronological Events

```
[BACKSTORY]
├── Ages ago: the abyss makes and loses children (sparks)
├── Generations ago: the island settles; the Guild and the Memorial Wall begin
├── Industrial age: mainland relic market; winches, lifts, scaffolds, mines
├── Oda's era: her record; she and her partner find a living spark (Glim)
└── Years ago: Oda goes back down; her name joins the Wall
        |
        v
[ACT 1: ORIGIN — Layers 1–3]          ← M2 ships Layer 1 + Weaver
├── Wake in Oda's house; First Dive (inciting incident, clue 1)
├── The Memorial Wall
├── The Watching Departure (after lurker_met; clue 2; recurring)
├── The Last Entry — Oda's camp; relight her lantern
├── The Weaver / The Fall
├── M2 closing beat — Tessaly logs your depth, "luck" (clue 3)
└── Rootmother — ORIGIN undeniable (plot point 1)
        |
        v
[ACT 2: THEFT — Layers 4–5]  (sketch)
├── The Speck (midpoint)
├── The Trail — Oda's camps and pages
└── Eye of the Storm — THEFT undeniable: why (plot point 2)
        |
        v
[ACT 3: CYCLE — Layers 6–7]  (sketch)
├── The Hollow Furnace — light is warmth
├── The Last Explorer — mirror fight (climax)
├── CYCLE — the island stops taking
├── The Final Chain — creatures rise to meet you (resolution)
└── Epilogue: Quiet Change — your name on the record line
```

### Timeline Notes

- Exact ages and years stay vague so the reveals don't box in later layers.
- Acts 2–3 are sketches, revisable at each layer's milestone.

---

## Appendix: References

Recorded from the brief; **mood and feel only — borrow nothing.** The world,
creatures, names and story are original (GDD, project rule).

- **Mood:** layered-abyss adventure fiction — the wonder and dread of
  descending into a living world.
- **Feel (gameplay, not story):** *Downwell* (the chain until you land),
  *Hollow Knight* (a hand-built world, dropping and recovering currency),
  *Spelunky* (deaths that tell a story), *Celeste* (fair, instant failure;
  assists).

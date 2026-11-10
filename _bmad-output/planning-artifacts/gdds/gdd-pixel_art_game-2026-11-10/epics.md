# The Unbroken Chain — Milestone 2 Epics

Source: `gdd.md` (2026-11-10). Order is risk-first. Every epic ends with something playable and a playtest question; a "no" answer is fixed before the next epic starts. **After each epic, post a short devlog or private build** (the brief's burnout mitigation). The stories below are high-level and are broken down later by `gds-create-epics-and-stories`.

---

## E1 — Kit v2

**Goal:** the full M2 move set and survival rules, in the existing M1 shaft.

**In:**
- **Health:** 4 HP, the damage table, 0.6 s invulnerability, crawler contact deals 1, a hunting lurker deals 2, +1 HP for banking a chain of 10 or more. **Any hit** breaks the chain and moves held embers to carried.
- **Default gamepad mapping.**
- **Lurker off-screen stirring:** a faint edge glow now, with the sound added in E3.
- **Flare Toss:** tap Light; needs ≥ 2 links; costs half the chain, with a matching share of embers moved to carried; 4 s; predators treat it as the player.
- **↓ interact** on the ground.
- **Lantern anchors:** lit by touch; respawn point.
- **Three ember stages:** held → carried → deposited. The Ember Cache drops on death and can be recovered once. Easy, Normal and Hard differ only in death cost.
- **Lift Station rest** (a placeholder station): full heal, deposit, enemies respawn.
- **Saving:** autosave on rest.
- **HUD:** HP, held and carried embers.
- **Flash safety from day one:** the ≤ 3 flashes/s cap is checked for every effect, and the "reduce flashing" toggle ships in E1.
- **Field Journal death line:** one line on death naming what killed you and how to avoid it (Pillar 2; deferred from M1).

**Out:** the Weaver; audio; new art; Swing.

**Depends on:** M1 (done).

**Playable:** the M1 shaft with a placeholder station at the top, two anchors and the full kit.

**Playtest question:** do HP, Flare Toss and lantern anchors keep deaths fair and retries short?

**Stories (high level):**
1. Player health and damage table
2. Flare Toss (throw, cost, lure)
3. Interact key
4. Lantern anchor respawn
5. Three-stage embers and the Ember Cache
6. Difficulty death-cost tiers
7. Placeholder Lift Station rest
8. Save and load
9. HUD v2
10. Flash-safety cap and the reduce-flashing toggle
10b. Default gamepad mapping
10c. Lurker off-screen stirring and edge glow
11. Field Journal death line
12. Tests for all chain, ember and damage rules

---

## E2 — Weaver prototype

**Goal:** prove the restraint fight is fun before content is built around it.

**In:**
- A rough placeholder arena (30×34 tiles) with 4 pogo-able strands and anchors that can be weakened.
- Weaver behaviour: bright → retreat and drop spiderlings; dark → descend and bite (0.9 s telegraph).
- The light-burst stun (chain 3 within 96 px); the flare herds it; dropping a strand deals 2 damage and stuns.
- HP 12. One Re-Weave at 9 HP. **The Fall is stubbed:** the fight ends at 6 HP.

**Out:** final art; phase 2; the Layer 2 landing arena; Swing.

**Depends on:** E1 (Flare Toss, HP).

**Playable:** a debug entry straight into the Weaver test arena.

**Playtest question:** is "go dark → herd → strike" fun and readable, and do testers feel it is *about restraint*?

**Stories:**
1. Strand and anchor system
2. Weaver movement and light-shy states
3. Bite telegraph
4. Stun by light burst
5. Flare herding
6. Strand drop
7. Spiderlings
8. Re-Weave
9. Boss HP and phase stub
10. Behaviour tests

---

## E3 — Audio

**Goal:** the biggest remaining lever on feel (M1 findings), plus the Pillar 2 sound telegraph.

**In:**
- **SFX script pipeline:** text parameter files → Python → WAV, kept in git.
- **The SFX list:** pogo with pitch +1 semitone per link up to +12, bank chime, lurker growl (panned) and hunting hiss, Snuff, cling, flare, Weaver strands, chain gate.
- **Chain-reactive music system:** stems fade in at 3, 6 and 10 links, resolve on a bank, cut on death.
- **Mix:** predator cues duck the music by 6 dB.
- **Settings:** volume sliders.

**Out:** final composed music (placeholder stems are fine); hub and boss themes.

**Depends on:** E1. E2 for the Weaver sounds.

**Playable:** the M1 shaft and the Weaver test arena, with sound.

**Playtest question:** does sound make the pogo feel great, and are lurkers heard before they are seen?

**Stories:**
1. SFX generator pipeline
2. Core SFX set
3. Pogo pitch crescendo
4. Positional lurker cues
5. Music stem system
6. Ducking and mix
7. Volume settings

---

## E4 — Layer 1 world

**Goal:** Edge of the Abyss, from the Lip to the Weaver's door.

**In:**
- Rooms and screen transitions; the camera leads downward.
- The spine **S1–S5** (about 23 screens) and side areas **A Rope Works, B Old Mine, C Sky Ledge**.
- **Chain gate 1 (≥ 4)** and **gate 2 (≥ 8)**, which opens the shortcut to the hub.
- **Lift Stations:** Lip and Hollow (real ones). About 5 lantern anchors.
- **Palette shift:** dusk → umber → violet. Ledge rims.
- **Map:** fills as you explore.
- **Journal objects:** 3 entries (A ×2, B), plus *The Last Entry* set-piece in S4. The Memorial clue arrives with the Swing secrets in E6.
- **Ember Hoards** in A, B and C.
- **Layer 1 tileset and enemy art.** A third regular enemy if the walk-through shows a need (NOTE in the GDD).
- **Reachability bot** extended to every shaft and gate.

**Out:** the hub (a placeholder room is fine); the Weaver arena art; Swing secrets (they need E6).

**Depends on:** E1. E3 is optional.

**Playable:** start at the Lip and descend to the Hollow Station.

**Playtest question:** does each move get taught before it is tested, and do players go for the gates and side areas?

**Stories:**
1. Room and transition system
2. Level authoring for multi-screen layouts
3. S1 to S5, one story each
4. Areas A, B and C
5. Chain gate object
6. Lift Station (final)
7. Palette zones
8. Map screen
9. Journal objects
10. Bot validation per room

---

## E5 — Hub

**Goal:** close the session loop: dive → home → spend.

**In:**
- **Abyss Island village:** 2 screens, flat ground; arriving deposits embers and heals.
- **Cartographer:** map (60), 3 hints (25 each).
- **Smith:** Quick Wick (200), Long Wick (250), Steady Grip (300).
- **Naturalist:** 10 embers per journal entry; 2 palettes (75, 150).
- **Guild records and Memorial Wall.**
- **Fast travel** between the hub and repaired stations.
- **The Watching Departure** on the lift ride up.
- **Hub art:** 4 NPCs and the village tileset.

**Out:** Docks, Gallery, Mentors, station repairs.

**Depends on:** E1 and E4 (the stations and the gate-2 shortcut).

**Playable:** dive into Layer 1, come home and spend.

**Playtest question:** do the three ember stages and the shops make "get home with it" feel worth it? Are the prices right?

**Stories:**
1. Hub scene and walking
2. NPC dialogue and shop framework
3. Cartographer
4. Smith and gear effects
5. Naturalist and journal payout
6. Guild records and Memorial
7. Fast travel
8. Watching Departure
9. Price tuning pass

---

## E6 — Weaver final

**Goal:** the complete slice climax and its reward.

**In:**
- The final arena in S5 with art (a segmented Weaver).
- Both Re-Weaves.
- **The Fall:** about 6 s of free fall with debris to pogo.
- The **Layer 2 landing arena** (Bright Moon palette) and **phase 2**: 2 strands, 0.75 s telegraph.
- The phase checkpoint.
- The **Silk → Swing** unlock: hold Dash near a silk anchor; rope 32–96 px; release ×1.1.
- The **3 Swing secrets** in A, S2 and C: Silk Grip, the Memorial clue and a cache.
- The landing station is repaired free and returns you to the hub.

**Out:** the rest of Layer 2.

**Depends on:** E2 (proven design), E4 and E5.

**Playable:** the full slice, from the hub through the Weaver and back for the secrets.

**Playtest question:** does the fight teach restraint within 3–8 attempts, and does Swing make the return trip rewarding?

**Stories:**
1. Weaver art and animation
2. Final arena
3. The Fall sequence
4. Landing arena and phase 2
5. Phase checkpoint
6. Swing ability
7. Silk anchors and secrets
8. Post-boss flow back to the hub

---

## E7 — Slice polish and ship

**Goal:** the first build to share with outside testers.

**In:**
- **Settings:** rebinding, screen shake on/off, 4 brightness levels, volume. (Reduce flashing already shipped in E1.)
- **Full Field Journal:** lore entries plus the death-line history (the death line itself ships in E1).
- **HUD polish.**
- **Art pass:** player animations (about 10), plus the hub and Layer 2 landing palettes.
- **Composed music stems** for Layer 1, the hub and the Weaver.
- **Performance:** check 60 FPS (see Tech Specs).
- **Steam Deck test pass:** ×2 scaling, HUD readability, battery.
- **Builds:** web and desktop (Windows and Linux).
- **Playtest round** with about 5 testers against the Success Metrics.
- **The Steam vs itch.io decision.**

**Out:** Layers 2–7. (Gamepad ships in E1.)

**Depends on:** E1–E6.

**Playable:** the shared M2 build.

**Playtest question:** the Success Metrics table in the GDD.

**Stories:**
1. Settings menu
2. Field Journal
3. HUD polish
4. Player animation set
5. Palettes
6. Music stems
7. Performance pass
8. Build and export
9. Playtest round and report
10. Distribution decision

---

## Coverage check (every GDD mechanic lands in an epic)

| Mechanic | Epic |
|---|---|
| Movement, pogo, chain (M1) | done |
| HP, Flare Toss, anchors, three ember stages, rest, saving | E1 |
| Weaver behaviour | E2 → E6 |
| Spiderlings | E2 |
| Audio and music | E3 → E7 |
| Layer 1, gates, map, journal, palettes | E4 |
| Hub, NPCs, gear, fast travel | E5 |
| Swing, Swing secrets, The Fall, phase 2 | E6 |
| Settings, Field Journal, accessibility | E7 |

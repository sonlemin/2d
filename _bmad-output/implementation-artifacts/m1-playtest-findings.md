# M1 Playtest Findings — The Unbroken Chain

**Date:** 2026-11-10 · **Branch:** `feat/m1-prototype` · **Build:** one shaft, Edge of the Abyss palette

## Verdict

M1 asked: *does a long chain feel both tempting and dangerous?* **Yes, after three fixes.**

| Check | Result |
|---|---|
| Tempting | Yes, **once chains paid embers**. Before that: "I want to keep the chain going, but does it make any difference?" |
| Dangerous | Yes. Lurkers read once the eyes were bigger and glowed |
| Fair deaths | Yes, after the escape bug fix and respawning on the last ledge |
| Pogo feel | "Feels a bit better now" after the impact-effects pass. Not yet great; revisit with audio |
| No ledge in reach | Solved by wall cling ("cling works") |

## What the playtest changed (design deltas the brief does not have yet)

1. **Embers (new: the chain's reward).** Each pogo hit adds `ember_value(link)` (linear: chain *n* pays n(n+1)/2) to a **held** pile. Any safe break (landing, Snuff, cling timeout, crawler knock) **banks** it; death **loses** it. Banked embers survive death.
   - *Why:* without a payoff the chain was all cost. Losing embers only "felt annoying" when the escape was broken or the trek back was long, not because of the loss itself.
   - *Open:* what embers buy (the hub economy in the brief: "return to the hub to spend your haul").
2. **Wall cling hides the light.** Cling keeps the count and held embers, but the light drops to base radius, so lurkers lose you. Grace is 1 s per chain, refilled by a pogo, then the chain breaks and banks. Release Jump = kick off; Down = drop. Slides only; climbing becomes a later earned upgrade.
   - *Brief said:* "pauses the chain ~1 s". It didn't say what happens to the light. Hiding it is what makes cling an escape.
3. **Attack in the air always pogoes.** Down+Attack was "clunky". This changes the brief's control table (Down + Attack = pogo).
4. **Snuff needs a 0.12 s hold.** Taps were misfiring (V sits next to C). Tap Light stays free for Flare Toss.
5. **A lurker that loses your scent is harmless at once.** Rule: a Snuff, landing or cling in time *always* saves you (Pillar 2).
6. **Respawn on the last ledge stood on**, not at the top. M2's Lift Stations should replace this with intentional checkpoints.
7. **Readability:** the camera leads downward while falling, ledge rims glow faintly, lurker eyes are big, open with an animation and cast red light, and the HUD turns red on alert.

## Tuning snapshot (starting values for M2)

| Constant | Value |
|---|---|
| Jump / pogo velocity | -330 / -300 (apex ~60 / ~50 px) |
| Max fall, fall gravity | 210 px/s, ×0.6 |
| Pogo armed window, hitbox | 0.22 s, 26×24 |
| Hitstop | 75 ms |
| Lurker notice | radius ≥ 80 px, distance ≤ radius × 1.6, on screen; telegraph 0.9 s; hunt 95 px/s |
| Cling | 1.0 s grace per chain, slide 18 px/s, kick (150, -260) |

## Still deferred from M1

- Field Journal death line; HUD polish plus the "reduce flashing" toggle (see `deferred-work.md`).
- **Audio:** none yet. It is the biggest remaining lever on pogo feel and on telegraph readability.

## Mechanic ideas logged for later

Lurker parry (top M2 candidate), phase dash, cashing in chain, chain-bending upgrades, more pogo directions, wall-jump climbing as an upgrade. See `deferred-work.md`.

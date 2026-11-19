# Performance Measurement (CP1)

**Purpose:** AR5, NFR1 ("60 FPS, no frame over 20 ms") and NFR5 (desktop browsers). Story 1.12 built the kit; Story 1.15 runs this procedure on the laptop and in the browsers and decides:

- **engine glow, go or no-go** (glow on must hold 60 FPS and pass the look check);
- whether **≤ 6 `PointLight2D` on screen** holds 60 FPS on every target (confirm the budget, or tighten it and re-run);
- **Compatibility glow parity on web** (it renders the same in Chrome and Firefox as on desktop);
- a **flare-cap recommendation** for Story 1.23.

The agent records no numbers. sonlm takes the measurements in Story 1.15 (a human gate: the server is headless).

## The scene and the run

`rooms/dev/perf_worst.txt` is the Old Mine at its worst, never a level: 30 × 68 cells (480 px wide, four screens tall), 10 lurkers in wall stubs inside the play rect (4 on the first screen, then 2 per screen), 44 hoverers in rows of 4, 4 walkers on side ledges. Columns 13–16 stay open from top to bottom for the run's path. Being 480 px wide, lit tiles fill the whole view, gutters included.

`--perf[=<s>]` (default 60 s) takes the player on every spawn:

- input locked, `Hurtbox` masked off (nothing can kill or knock it), chain held at `--chain`'s n, or 20 without it;
- moved every physics tick down the room's centre and back at 100 px/s, from a tick counter, so every run sees the same states in the same order (one pass of `perf_worst` is 992 px, about 9.9 s; a 60 s run makes about six passes);
- **two stand-in lights ride along on purpose:** a flare (ALWAYS, at the player's light radius, 138.4 px at chain 20) 112 px to the left and an Ember Cache (CACHE, 80 px) 112 px to the right. A real flare sticks and a real cache lies still; riding along keeps both on screen for the whole run, which is the worst case the budget must hold. They are lights only and wake no lurker.

Each pass wakes the lurkers as their screen comes into reach. Hunting lurkers (95 px/s) trail the 100 px/s path and fall away rather than pile up. Screen 1's four push the lights past the budget whenever the path passes the top (player + flare + cache + 4 glows = 7), so the sprite fallback is exercised on every pass.

**The light budget** (`BudgetLight`, `World`'s `LightBudget` node, every physics tick): at most 6 lights keep their `PointLight2D` in the whole 480 × 270 view; lurker glows beyond that show an additive sprite glow instead. The player's light and flares are never demoted. Overlay 4 shows `lights n/6, sprites m`.

**Known first-second hitch:** the first demotion is the additive material's first use, which can compile a shader. A worst frame within the first second may be that warm-up (Story 1.16's job), not steady-state cost. Always record `worst … at … s` with the number.

## How to run

**Desktop (laptop):** the window opens at ×3 (1440 × 810).

```bash
godot --path game -- --room=perf_worst --perf
godot --path game -- --room=perf_worst --perf --glow=on
```

In the editor: Debug → Customize Run Instances, with the args after `--` per instance. Never set Project Settings `editor/run/main_run_args` (it writes `project.godot`).

**Web** (once Stories 1.13 and 1.14 have landed): the debug web build at the ×2 embed (960 × 540), in Chrome and Firefox with hardware acceleration on:

```
…/index.html?room=perf_worst&perf
…/index.html?room=perf_worst&perf&glow=on
```

**HD 620-class machine:** the same two runs, if one is available. If none is, write "not available" in the results and say so in the 1.15 verdict.

**Conditions:**

- vsync on (the default); note the display's refresh rate (the target is 60 FPS, so a 120 Hz display shows about 120);
- on mains power, other heavy apps closed;
- overlays off during the run (they cost a little);
- read the summary from the terminal or the browser console (`[room] dev: perf …`), or press backquote until overlay 4 after the run (the autopilot keeps going, so the load stays).

## What to record

One row per run. The summary line gives most of it:

```
perf 60 s: <frames> frames, avg <x> fps, min <n> fps, worst <y> ms at <t> s, <k> over 20 ms; lights max <l>/6, sprites max <s>, over <o>; chain 20, breaks 0, deaths 0; glow off; window 1440x810; Linux, <adapter>
```

- **avg / min fps:** average over the run; min is the fewest frames in any whole second.
- **worst … at … s:** the longest frame and when it started. In the first second, suspect the shader warm-up.
- **over 20 ms:** NFR1's count; the target is 0.
- **lights max / sprites max / over:** the most lights lit in the view (never above 6), the most sprite glows, and how far the always-lights alone went past 6 (expected 0 here).
- **breaks / deaths:** both expected 0. Anything else means the run was disturbed; re-run.

## The look check (glow on vs off)

At each brightness (`--set=brightness:0` … `3`, added to the run's args), compare glow off and on:

- **the darkness:** a 2026-11-19 probe on a software renderer saw glow *darken* the dark ambient (0.039 → 0.016). Check on the laptop's GPU whether the darkness stays readable with glow on (Pillar 2: tension, never confusion);
- **the halo:** the player's light, the lurker glows and the flare stand-in;
- **sprite beside lit:** a sprite glow next to a lit lurker glow must not read as a different thing.

## Decision guide for 1.15

A guide, not a rule; sonlm decides.

- Glow off fails anywhere (avg under 60, or slow frames past the first-second hitch) → tighten the budget (`BudgetLight.MAX_ON_SCREEN` and `Spec.LIGHTS_ON_SCREEN_MAX`, GDD first) and re-run at 5.
- Glow on holds 60 FPS with no slow frames on every target and passes the look check → go: a follow-up story moves glow into game code.
- Otherwise no-go: bloom is faked with unshaded additive sprites (architecture → Lighting).
- **Flare cap:** the slots left after the player (1), the cache (1) and a minimum of lurker glows; flares are ALWAYS, so each one past that pushes `over` up.

## Results (Story 1.15)

No numbers are recorded by the agent; sonlm fills this in Story 1.15.

| Date | Build / commit | Machine and adapter | Window and scale | Refresh | Glow | Avg FPS | Min FPS | Worst ms (at s) | Over 20 ms | Lights / sprites / over max | Breaks / deaths | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | |

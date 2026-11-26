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
- **two lights ride along on purpose:** a flare stand-in (ALWAYS, at the player's light radius, 138.4 px at chain 20) 112 px to the left and an Ember Cache 112 px to the right. A real flare sticks and a real cache lies still; riding along keeps both on screen for the whole run, which is the worst case the budget must hold. The flare stand-in is a light only and wakes no lurker (1.23 makes it the real flare). Since Story 1.22 the cache is the real one (`objects/ember_cache.tscn`: rank CACHE, `Tuning` `cache_radius`, 80 px to start): a `LightSource`, so it wakes lurkers in `perf_worst`, who hunt it harmlessly. Runs before 1.22 had a plain 80 px CACHE stand-in that woke nothing.

Each pass wakes the lurkers as their screen comes into reach. Hunting lurkers (95 px/s) trail the 100 px/s path and fall away rather than pile up. Screen 1's four push the lights past the budget whenever the path passes the top (player + flare + cache + 4 glows = 7), so the sprite fallback is exercised on every pass.

**The light budget** (`BudgetLight`, `World`'s `LightBudget` node, every physics tick): at most 6 lights keep their `PointLight2D` in the whole 480 × 270 view; lurker glows beyond that show an additive sprite glow instead. The player's light and flares are never demoted. Overlay 4 shows `lights n/6, sprites m`.

**Known first-second hitch:** the first demotion is the additive material's first use, which can compile a shader. A worst frame within the first second may be that compile, not steady-state cost. Since Story 1.16, `Fx.warm_up()` draws the shared materials (sparks, a label, an additive light sprite) once at every room load, at an alpha no one sees, so a material's first draw is paid at the load. It does not remove the 1.15 hitch. The first 1.16 run below measured 548 ms against 562 ms, but the code review found its warm-up items were freed on a 0.05 s timer and could go undrawn after a slow frame. The patched warm-up counts frames (two drawn frames, probed on 4.7.2), and the re-run on it measured 634 ms at 0.0 s: with a warm-up that is drawn, the stall is still there (one run each, so the three figures are not ranked). The stall at 0.0 s is the load itself and is Story 7.13's (ledgered), as is the re-run's higher count of frames over 20 ms (30, against 5 and 2), which one run can't explain. Always record `worst … at … s` with the number.

## How to run

**Desktop (laptop):** the window opens at ×3 (1440 × 810).

```bash
godot --path game -- --room=perf_worst --perf
godot --path game -- --room=perf_worst --perf --glow=on
```

In the editor: Debug → Customize Run Instances, with the args after `--` per instance. Never set Project Settings `editor/run/main_run_args` (it writes `project.godot`).

**Web:** the debug web build at the ×2 embed (960 × 540), in Chrome and Firefox with hardware acceleration on. Build it on the server with `tools/export.sh`, serve `builds/<version>/` with `serve.js` and open it on the laptop through an SSH tunnel ([build.md → Playing builds on the laptop](./build.md#playing-builds-on-the-laptop)):

```
http://localhost:8060/web_debug/index.html?room=perf_worst&perf
http://localhost:8060/web_debug/index.html?room=perf_worst&perf&glow=on
```

The server's web smoke runs on SwiftShader, so it says nothing about performance: only these laptop runs count.

**HD 620-class machine:** the same two runs, if one is available. If none is, write "not available" in the results and say so in the 1.15 verdict.

**Conditions:**

- vsync on (the default); note the display's refresh rate (the target is 60 FPS, so a 120 Hz display shows about 120);
- on mains power, other heavy apps closed;
- overlays off during the run (they cost a little);
- keep the window in front and the browser tab visible for the whole run: a minimised window or a hidden tab stops frames (there is no focus-loss pause before its own story), and the first frame back spans the whole gap, so `worst` and `min` are void and the run may end early. If that happens, run it again;
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

No numbers are recorded by the agent: each row is copied from a summary line sonlm ran and pasted (Story 1.15, D3). The lines are kept verbatim in the playtest record (`_bmad-output/implementation-artifacts/playtests/1-15-cp1-gate-feel-check-and-performance-verdict.md`).

| Date | Build / commit | Machine and adapter | Window and scale | Refresh | Glow | Avg FPS | Min FPS | Worst ms (at s) | Over 20 ms | Lights / sprites / over max | Breaks / deaths | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-11-21 | `feat/m2-e1` clone (1.15) | sonlm's laptop, Windows, NVIDIA GeForce RTX 3050 Laptop GPU | 3456x1984 | 60 Hz | off | 115.4 | 56 | 116.1 (0.4 s) | 16 | 6/6 / 7 / 0 | 0 / 0 | debug (editor exe), D1; worst frame is the first-second hitch (1.16) |
| 2026-11-21 | 20261121-e304d31 `web_debug` | sonlm's laptop, Firefox, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0) | 3330x1087 | 60 Hz | off | 59.5 | 28 | 562.0 (0.0 s) | 5 | 6/6 / 7 / 0 | 0 / 0 | the weakest target run (browser on the Intel iGPU); min 28 is the first second (hitch, 1.16) |

## Results (Story 1.16: warm-up)

Copied from the summary lines sonlm ran and pasted (2026-11-21). The Firefox line is verbatim in the 1.16 story's Dev Agent Record; the record shortens the Chrome line with "…", so that row's lights, sprites, breaks and deaths are here only (the row is void either way). The first two rows predate the code review's warm-up patch; the last two are on the patched build (see the hitch paragraph above).

| Date | Build / commit | Machine and adapter | Window and scale | Refresh | Glow | Avg FPS | Min FPS | Worst ms (at s) | Over 20 ms | Lights / sprites / over max | Breaks / deaths | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2026-11-21 | 20261121-22fa2af `web_debug` | sonlm's laptop, Firefox, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0) | 3330x1870 | 60 Hz | off | 59.5 | 29 | 548.0 (0.0 s) | 2 | 6/6 / 7 / 0 | 0 / 0 | with `Fx.warm_up()`: no change from 1.15's 562 ms. The stall is the first frame itself (load time, before any input), which a warm-up in that same frame can't take out. Not chased further (→ 7.13) |
| 2026-11-21 | 20261121-22fa2af `web_debug` | sonlm's laptop, Chrome, WebKit WebGL | 4358x6762 | — | off | (4.1) | (0) | (159886.3 at 46.8 s) | (160) | 6/6 / 5 / 0 | 0 / 0 | **void:** a 160 s frame is a hidden tab (see below), not the GPU |
| 2026-11-21 | 20261121-af07203 `web_debug` | sonlm's laptop, Firefox, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0) | 3330x1087 | — | off | (2.5) | (0) | (95438.0 at 48.3 s) | (15) | 6/6 / 5 / 0 | 0 / 0 | **void:** the re-run on the patched warm-up (code review); a 95 s frame is a hidden or covered tab, so the first-frame figure can't be read from it. Run again below |
| 2026-11-21 | 20261121-af07203 `web_debug` | sonlm's laptop, Firefox, ANGLE (Intel, Intel(R) HD Graphics Direct3D11 vs_5_0 ps_5_0) | 3330x1087 | 60 Hz | off | 59.4 | 24 | 634.0 (0.0 s) | 30 | 6/6 / 7 / 0 | 0 / 0 | the patched warm-up (frees after three frames, so it is drawn): the first-frame stall is still there. 30 frames over 20 ms against 5 (1.15) and 2 (first 1.16 run): nothing in the patch runs after the third frame, so not explained by it; one run (→ 7.13) |

## Results (Story 1.22: the real Ember Cache)

The cache stand-in became the real cache, which now wakes lurkers. One headless run on the server (2026-11-26, `godot --headless --path game -- --room=perf_worst --perf=20`): **lights max 6/6, sprites max 7, over 0**, breaks 0, deaths 0, the same light counts as 1.15's laptop run. A headless run draws nothing, so its frame times say nothing about the GPU; the laptop run is the story's Task 11 (sonlm), and its row goes in the table below.

| Date | Build / commit | Machine and adapter | Window and scale | Refresh | Glow | Avg FPS | Min FPS | Worst ms (at s) | Over 20 ms | Lights / sprites / over max | Breaks / deaths | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

**Runs not made at CP1 (sonlm's choice, 2026-11-21):** glow on everywhere (glow was a no-go, so its cost no longer decides anything), the laptop desktop on the Intel iGPU, and Chrome. No separate HD 620 machine was available; the laptop's Intel iGPU, through Firefox, stood in for the low-end target. The full pass is Story 7.13.

**Hidden tabs ruin a web run.** A browser stops drawing a hidden tab, and the run measures wall time, so the whole hidden stretch counts as one frame (two discarded 1.15 runs had a single 132 s and 146 s frame). Keep the game tab in front for the whole run, with DevTools docked in the same window and opened from the browser menu (the web key guard swallows F12 and Ctrl+Shift+J).

# The Unbroken Chain: M1 prototype

Open this folder in Godot 4.7 and press F5.

A debug build (an editor run, or the `Web debug` export that `tools/export.sh` makes on the server; [docs/build.md](../docs/build.md)) can start in any room and state, e.g. from the repo root: `godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0` (the args and overlays are in [the development guide](../docs/development-guide.md#devtools-debug-builds-only)). For a performance run, `godot --path game -- --room=perf_worst --perf` plays the worst-case scene on autopilot for 60 s and prints one summary line (add `--glow=on` to compare engine glow; the procedure is [docs/perf.md](../docs/perf.md)).

## Controls

| Key | Action |
|---|---|
| ← → | Move |
| Z or ↑ | Jump (hold for a higher jump) |
| Hold Z/↑ at a wall (falling) | **Wall cling**: the chain pauses and your light drops to normal, so lurkers lose you. You get 1 s per chain (refilled by a pogo), then the chain ends and your embers bank. **Release** to kick off the wall; **↓** to drop |
| X on the ground | Slash sideways |
| X in the air | **Pogo**: strike down, bounce off an enemy and add 1 to the chain |
| C | Air dash (refilled by each pogo) |
| Hold V | **Snuff** (hold past the tap window, 0.12 s by default; a quick tap does nothing yet, Flare Toss comes later): go dark. Breaks the chain, and lurkers lose you |
| ↓ standing still on the ground | Interact: does nothing yet (stations come later) |
| `` ` `` (debug builds) | Cycle the dev overlays: play rect and gutters, light and notice rings, exits and ids, FPS / lights / Clock, then off |

## The loop

- Pogo off crawlers without landing to build the **chain**. Each link makes your slash bigger and your light brighter.
- **Landing** ends the chain.
- **Embers:** each pogo hit adds embers to a **held** pile, and later hits pay more (hit 5 pays 5). Landing or Snuff **banks** them. Dying **loses** whatever you're holding. There is no HUD for now (the gutter HUD comes later); the popups over each hit show the chain and its embers.
- You have **4 HP**. A big light wakes the **lurkers**: red eyes pulse in the dark for about a second, then they hunt you. A hunting lurker's touch costs 2 HP.
- To shake a lurker off, **land or Snuff**. Both break the chain.
- Touching a crawler costs 1 HP and knocks you back. Any hit breaks the chain but banks what you held; you flash and blink, and can't be hit again for 0.6 s.
- Spikes (`^` in a room file) cost 1 HP and put you back on the last floor you stood on safely.
- Banking a chain of 10 or more safely (landing, Snuff, a cling running out) heals 1 HP.
- At 0 HP you die. Dying respawns you, with full HP, at the **top of the shaft** after a short pause, without reloading: banked embers are kept, and the shaft is rebuilt with every crawler back except the ones you killed. To restart from scratch, relaunch. Until the Options screen, brightness changes only with `--set=brightness:<0-3>` in a debug build, for that session (nothing is saved).
- The hole in the floor (bottom left) loops you back to the top, still falling. A chain you carry through it is banked first, as on a landing.
- A lurker that loses your scent (you land or Snuff) is harmless at once.

## Tests

Run `./run_tests.sh` from this folder. If `godot` isn't on your PATH, use `GODOT=/path/to/godot ./run_tests.sh`.

- **Chain rules** (`tests/test_chain_state.gd`): chain hits, landing, Snuff, the cap and the growth curves; a hit banks the held embers too, and the chain says whether it ended safely or by a hit.
- **Health** (`tests/test_health.gd`): 4 HP; a crawler and a spike take 1, a hunting lurker 2; a hit can't land again while you blink; a chain of 10 or more banked safely heals 1 HP.
- **Log** (`tests/test_log.gd`): the `[category] message` format and the debug-category switches.
- **Clock** (`tests/test_clock.gd`): time-scale requests multiply, refresh, run on real time, pause with the game and clear on death; a pogo hit freezes for 75 ms.
- **Tuning** (`tests/test_tuning.gd`): gear modifiers apply in a fixed order, and every M1 tuning value still holds after the move to `scripts/rules/tuning.gd`.
- **State** (`tests/test_state.gd`): settings, slot and dive state, their save shapes and `settings.json` (a missing or broken file falls back to the defaults).
- **Rooms** (`tests/test_room_loader.gd`): room files are checked before they build (every error names its file, line and column), and the shaft (`rooms/l1/m1_shaft.txt`) has the right enemies, ledges and exits.
- **Room sweeps** (`tests/test_room_sweep.gd`): the fairness rules every room is held to, each proven on small made-up grids.
- **Deferred-work owners** (`tests/test_deferred_owners.gd`): fails while any item in `_bmad-output/implementation-artifacts/deferred-work.md` has no owner, so a ledger edit alone can turn the run red.
- **Every room** (`tests/smoke_rooms.gd`): every file in `rooms/` is checked: exits lead to real rooms, a spine shaft has a ledge (or a narrow cling stretch) within every 1.5 s of fall, no enemy waits beside where you arrive from below, every lurker only notices a big light on screen and always telegraphs for at least 0.75 s, and the first lurker in each room does no damage after a Snuff, a landing or a cling made in time, down to a landing one tick before its touch. A lurker already touching you on the tick you escape still costs 2 HP, and at point-blank range it only has to turn harmless at once and stay so.
- **Bot** (`tests/smoke_bot.gd`): a simple bot plays every spine shaft from top to bottom without dashing and must chain 5 or more. Its two closest pogo hits must be at least a third of a second apart, so the sparks, light swell and popup of each hit stay under 3 flashes per second.
- **Moves** (`tests/smoke_moves.gd`): plays the shaft with simulated key presses: pogo, landing, jump height (held vs tapped), wall cling, and releasing Light ending a Snuff.
- **World smoke test** (`tests/smoke_world.gd`): the game scene with its gutters and framing; banked embers, the best chain, deaths and brightness live in `Game`; a death respawns a fresh player at the top without a reload; the floor hole loops you to the top; a lurker hidden behind a gutter never notices you.
- **Room swap smoke test** (`tests/smoke_room_swap.gd`): two small test rooms; going through an exit banks the chain, you arrive still falling from above or standing beside the hole from below, and killed crawlers stay gone across swaps and deaths.
- **Health smoke test** (`tests/smoke_health.gd`): in a small spike room, a crawler knocks you back for 1 HP and a hunting lurker hits for 2, but a lurker that has lost you never does, even on the very tick it lost you; spikes cost 1 HP and put you back on the last safe floor (even arriving from above); a long chain banked heals; at 0 HP you die and come back with full HP; the hit flash shows (or dims, with reduce flashing), and the pogo squash shows through the freeze.
- **DevTools args** (`tests/test_dev_args.gd`): the debug launch options read the same from the command line and a web address, and every bad value is caught with a warning that names the valid ones.
- **DevTools smoke test** (`tests/smoke_dev_tools.gd`): with no options the debug tools change nothing; a real debug run prints `[room] SMOKE boot ok` once when its first room is in (the web smoke waits for it), a test or a respawn never; each option starts the right room, chain, log or setting (a session-only setting is never saved); the backquote key cycles the four overlays, even while paused; the light count shows what the light budget counts; no function key is bound.
- **Export presets** (`tests/test_export_presets.gd`): the four presets `tools/export.sh` builds from are all there, single-threaded on the web, and their filters put every room in every build, the dev rooms and DevTools only in the web debug build, and no test file anywhere.
- **Effects** (`tests/test_fx.gd`): the hit effects share one material each instead of building a new one per effect, and they clean themselves up. Every effect is declared in one table: the blink runs at 2.5 Hz and the lurker's eye pulse at no more than 2 Hz, and each has its reduced version or a written reason for having none.
- **Accessibility smoke test** (`tests/smoke_a11y.gd`): with screen shake off the camera never shakes while the pogo still freezes and sparks; with reduce flashing on, the blink after a hit becomes steady transparency; the camera's look-ahead eases on a pogo hit.
- **Light budget** (`tests/test_light_budget.gd`): at most 6 lights stay lit on screen; lurker glows past that become sprite glows, the player's light and flares never do, and nothing flickers between the two; every light in the scenes is part of the budget.
- **Text** (`tests/test_strings.gd`): every word the player reads comes from `text/strings.csv`; each key the code uses exists, none is unused, the committed translation matches the table, it still reads in English on a non-English machine, and the copy never names a colour, says "roguelike" or shows a percentage. The build runs it too.
- **Colours** (`tests/test_palettes.gd`): every UI colour is the design's, and each one is bright enough against its background (the contrast floors), with the dimmer colours lifted by the smallest step that passes.
- **Zone colours smoke test** (`tests/smoke_palettes.gd`): the side gutters take each room's zone colours when you enter it, die or respawn, and a popup is outlined in that zone's background colour.
- **Font and theme** (`tests/test_theme.gd`): the pixel font imports crisp (no smoothing or hinting), covers Latin-1 and Latin Extended-A, measures what the design says, and every popup draws at 8 px with a 1 px outline on four sides.
- **Perf smoke test** (`tests/smoke_perf.gd`): a 3-second perf run in the worst-case scene holds chain 20 and the light budget on every tick and reports one summary; engine glow and bad options; the shaft never needs the budget.

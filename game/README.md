# The Unbroken Chain: M1 prototype

Open this folder in Godot 4.7 and press F5.

A debug build (an editor run or a debug export) can start in any room and state, e.g. from the repo root: `godot --path game -- --room=m1_shaft --chain=8 --set=brightness:0` (the args and overlays are in [the development guide](../docs/development-guide.md#devtools-debug-builds-only)).

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
- A big light wakes the **lurkers**: red eyes pulse in the dark for about a second, then they hunt you. Contact with a hunting lurker kills you.
- To shake a lurker off, **land or Snuff**. Both break the chain.
- Touching a crawler knocks you back and breaks the chain, but doesn't kill you.
- Dying respawns you at the **top of the shaft** after a short pause, without reloading: banked embers are kept, and the shaft is rebuilt with every crawler back except the ones you killed. To restart from scratch, relaunch. Until the Options screen, brightness changes only with `--set=brightness:<0-3>` in a debug build, for that session (nothing is saved).
- The hole in the floor (bottom left) loops you back to the top, still falling. A chain you carry through it is banked first, as on a landing.
- A lurker that loses your scent (you land or Snuff) is harmless at once, even point-blank.

## Tests

Run `./run_tests.sh` from this folder. If `godot` isn't on your PATH, use `GODOT=/path/to/godot ./run_tests.sh`.

- **Chain rules** (`tests/test_chain_state.gd`): chain hits, landing, Snuff, the cap and the growth curves.
- **Log** (`tests/test_log.gd`): the `[category] message` format and the debug-category switches.
- **Clock** (`tests/test_clock.gd`): time-scale requests multiply, refresh, run on real time, pause with the game and clear on death; a pogo hit freezes for 75 ms.
- **Tuning** (`tests/test_tuning.gd`): gear modifiers apply in a fixed order, and every M1 tuning value still holds after the move to `scripts/rules/tuning.gd`.
- **State** (`tests/test_state.gd`): settings, slot and dive state, their save shapes and `settings.json` (a missing or broken file falls back to the defaults).
- **Rooms** (`tests/test_room_loader.gd`): room files are checked before they build (every error names its file, line and column), and the shaft (`rooms/l1/m1_shaft.txt`) has the right enemies, ledges and exits.
- **Room sweeps** (`tests/test_room_sweep.gd`): the fairness rules every room is held to, each proven on small made-up grids.
- **Deferred-work owners** (`tests/test_deferred_owners.gd`): fails while any item in `_bmad-output/implementation-artifacts/deferred-work.md` has no owner, so a ledger edit alone can turn the run red.
- **Every room** (`tests/smoke_rooms.gd`): every file in `rooms/` is checked: exits lead to real rooms, a spine shaft has a ledge (or a narrow cling stretch) within every 1.5 s of fall, no enemy waits beside where you arrive from below, every lurker only notices a big light on screen and always telegraphs for at least 0.75 s, and the first lurker in each room lets a Snuff (even point-blank), a landing or a cling save you.
- **Bot** (`tests/smoke_bot.gd`): a simple bot plays every spine shaft from top to bottom without dashing and must chain 5 or more.
- **Moves** (`tests/smoke_moves.gd`): plays the shaft with simulated key presses: pogo, landing, jump height (held vs tapped), wall cling, and releasing Light ending a Snuff.
- **World smoke test** (`tests/smoke_world.gd`): the game scene with its gutters and framing; banked embers, the best chain, deaths and brightness live in `Game`; a death respawns a fresh player at the top without a reload; the floor hole loops you to the top; a lurker hidden behind a gutter never notices you.
- **Room swap smoke test** (`tests/smoke_room_swap.gd`): two small test rooms; going through an exit banks the chain, you arrive still falling from above or standing beside the hole from below, and killed crawlers stay gone across swaps and deaths.
- **DevTools args** (`tests/test_dev_args.gd`): the debug launch options read the same from the command line and a web address, and every bad value is caught with a warning that names the valid ones.
- **DevTools smoke test** (`tests/smoke_dev_tools.gd`): with no options the debug tools change nothing; each option starts the right room, chain, log or setting (a session-only setting is never saved); the backquote key cycles the four overlays, even while paused; no function key is bound.

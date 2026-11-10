# The Unbroken Chain: M1 prototype

Open this folder in Godot 4.7 and press F5.

## Controls

| Key | Action |
|---|---|
| ← → | Move |
| Z or ↑ | Jump (hold for a higher jump) |
| Hold Z/↑ at a wall (falling) | **Wall cling**: the chain pauses and your light drops to normal, so lurkers lose you. You get 1 s per chain (refilled by a pogo), then the chain ends and your embers bank. **Release** to kick off the wall; **↓** to drop |
| X on the ground | Slash sideways |
| X in the air | **Pogo**: strike down, bounce off an enemy and add 1 to the chain |
| C | Air dash (refilled by each pogo) |
| Hold V | **Snuff** (hold about 0.12 s; a quick tap does nothing): go dark. Breaks the chain, and lurkers lose you |
| F1 | Cycle brightness (4 levels) |
| F2 | Show or hide the on-screen controls |

## The loop

- Pogo off crawlers without landing to build the **chain**. Each link makes your slash bigger and your light brighter.
- **Landing** ends the chain.
- **Embers:** each pogo hit adds embers to a **held** pile, and later hits pay more (hit 5 pays 5). Landing or Snuff **banks** them. Dying **loses** whatever you're holding. The top bar shows `embers` (banked) and `held`.
- A big light wakes the **lurkers**: red eyes pulse in the dark for about a second, then they hunt you. Contact with a hunting lurker kills you.
- To shake a lurker off, **land or Snuff**. Both break the chain.
- Touching a crawler knocks you back and breaks the chain, but doesn't kill you.
- Dying respawns you on the **last ledge you stood on**. Press **F3** to restart from the top.
- A lurker that loses your scent (you land or Snuff) is harmless at once, even point-blank.

## Tests

Run `./run_tests.sh` from this folder. If `godot` isn't on your PATH, use `GODOT=/path/to/godot ./run_tests.sh`.

- **Chain rules** (`tests/run_tests.gd`): chain hits, landing, Snuff, the cap and the growth curves.
- **Shaft smoke test** (`tests/smoke_shaft.gd`): plays the real level with simulated key presses. It covers the pogo, landing, jump height (held vs tapped), a bot chaining the long run, and the lurker's telegraph, hunt and kill rules.

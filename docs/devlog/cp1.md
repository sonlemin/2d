# Devlog: CP1, Foundations (2026-11-21)

*The Unbroken Chain, M2 Epic 1, Stories 1.1–1.15.*

## What CP1 built

M1 proved the idea: fall down a dark shaft, keep the chain alive by pogoing off what lives in it. CP1 rebuilt that prototype on foundations meant to last the whole game, without changing how it plays:

- **State in plain objects.** The chain, the dive and the save slot live in pure rule objects held by one `Game` autoload, with no scene reloads: a death rebuilds the room and spawns a fresh player.
- **Rooms as text.** Levels are text grids loaded by `RoomLoader`; the M1 shaft is now `rooms/l1/m1_shaft.txt`, and every room file is checked for fair falls, safe arrivals and lurker guarantees. A bot plays the shaft top to bottom on every test run (best chain 8).
- **Input as intents.** The player reads `PlayerInput` intents, never raw keys, so presses during hitstop are kept and the Light tap/hold is one tested machine.
- **One clock, one light budget.** Only `Clock` touches time scale. Every light goes through a budget of 6 on screen, and lights over it fall back to glowing sprites.
- **Builds from one script.** `tools/export.sh` checks the content, exports Windows, Linux and web, and boots the web build in a real browser before it says `BUILD OK`.
- **Pixel-perfect on any screen.** Whole-number scaling on PC (×3 on the laptop) and in the browser.

1397 automated checks pass, and the M1 chain tests run unchanged.

## What the CP1 gate decided

I played the migrated shaft on my laptop and in the browser (build `20261121-e304d31`):

- **Feel: yes.** It plays like normal gameplay, the way it did before the rebuild.
- **Physics interpolation stays on.** At 60 Hz I couldn't see a difference; it's already built and tested. A high-refresh check waits for the Steam Deck pass.
- **No engine glow.** Bloom stays as soft additive sprites.
- **6 lights on screen is the budget.** The worst-case scene (10 lurkers, 44 hoverers, a flare) held it on the laptop, and in Firefox on the laptop's integrated Intel GPU (59.5 fps average).
- **No flare cap for now.** Story 1.23 revisits it with real flares.
- **The air dash keeps its length** (≈ 39 px, a little longer than the design doc said; the doc now matches the game).

## Next

CP2: the full move set and fair deaths, starting with the effects accessibility gate and a shader warm-up for the first-second hitch (Story 1.16).

# The Unbroken Chain: M1 prototype

Open this folder in Godot 4.7 and press F5.

## Controls

| Key | Action |
|---|---|
| ← → | Move |
| Z or ↑ | Jump (hold for a higher jump) |
| X on the ground | Slash sideways |
| X in the air | **Pogo**: strike down, bounce off an enemy and add 1 to the chain |
| C | Air dash (refilled by each pogo) |
| Hold V | **Snuff**: go dark. Breaks the chain, and lurkers lose you |
| F1 | Cycle brightness (4 levels) |
| F2 | Show or hide the on-screen controls |

## The loop

- Pogo off crawlers without landing to build the **chain**. Each link makes your slash bigger and your light brighter.
- **Landing** ends the chain.
- A big light wakes the **lurkers**: red eyes pulse in the dark for about a second, then they hunt you. Contact with a hunting lurker kills you.
- To shake a lurker off, **land or Snuff**. Both break the chain.
- Touching a crawler knocks you back and breaks the chain, but doesn't kill you.
- Dying restarts you at the top of the shaft.

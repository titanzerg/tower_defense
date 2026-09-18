# Tower Defense (Roblox + Rojo)

Playable multiplayer-friendly prototype with a generated map, five mixed waves,
ground and flying enemies, four tower classes, cash rewards, and base health.

## Getting started

```bash
rojo serve
```

In Roblox Studio, open the Rojo plugin, connect to `localhost:34872`, and sync.
Press **Play** (not Run) so the client UI starts. Select a tower from the bottom
bar, then click on grass away from the path. Press Escape to cancel placement.

Tower roles:

- **Machine Gun** targets ground enemies quickly.
- **Anti-Air** has long range and targets flying enemies.
- **Cannon** deals splash damage to groups on the ground.
- **Frost** targets both types and temporarily slows them.

To build a standalone place:

```bash
rojo build -o "tower-defense.rbxlx"
```

Gameplay values and waves are in `src/shared/GameConfig.luau`.

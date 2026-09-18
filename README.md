# Tower Defense (Roblox + Rojo)

Playable multiplayer-friendly prototype with a generated map, five waves, tower
placement, targeting, cash rewards, and base health.

## Getting started

```bash
rojo serve
```

In Roblox Studio, open the Rojo plugin, connect to `localhost:34872`, and sync.
Press **Play** (not Run) so the client UI starts. Click **สร้างป้อม**, then click
on grass away from the path. Press Escape to cancel placement.

To build a standalone place:

```bash
rojo build -o "tower-defense.rbxlx"
```

Gameplay values and waves are in `src/shared/GameConfig.luau`.

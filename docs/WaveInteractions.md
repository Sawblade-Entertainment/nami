
# Wave Interaction

## surface:pointSplash()

Injects a displacement into a single simulation cell.

Useful for impacts, raindrops, explosions, or object interaction.

### Syntax

```lua
surface:pointSplash(z, x, height)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `z` | `number` | Grid Z coordinate. |
| `x` | `number` | Grid X coordinate. |
| `height` | `number` | Initial wave displacement. |

### Example

```lua
surface:pointSplash(50, 50, 5)
```

---

## surface:splash()

Creates a smooth Gaussian-shaped disturbance.

Prefer this over `pointSplash` for most interactions to avoid "spiky" water.

### Syntax

```lua
surface:splash(z, x, amplitude, radius)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `z` | `number` | Grid Z coordinate. |
| `x` | `number` | Grid X coordinate. |
| `amplitude` | `number` | Height of the bump. |
| `radius` | `number` | Radius of the disturbance in grid cells. |

### Example

```lua
surface:splash(50, 50, 2, 5)
```

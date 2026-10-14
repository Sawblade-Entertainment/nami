# Water Rings

`Nami.Ring` allows you to create a ring-shaped water mesh that surrounds a central area. This is typically used to expand the visible water area around a moving object (like a boat) without needing a massive single simulation grid.

## Nami.Ring.create()

Creates a new water ring instance.

### Syntax

```lua
local ring = Nami.Ring.create(config, parent, sampler)
```

### Parameters

| Parameter | Type | Description |
|------------|------|-------------|
| `config` | `RingConfig` | Configuration table (see below). |
| `parent` | `Instance` | Parent instance for the generated MeshPart. |
| `sampler` | `function` | A function `(x, z, cellSize) -> number` that provides the height. |

#### RingConfig

| Parameter | Type | Description |
|------------|------|-------------|
| `CellSize` | `number` | Distance between vertices. |
| `InnerHalf` | `number` | Half-width of the inner hole (the area where the main surface sits). |
| `OuterHalf` | `number` | Half-width of the entire ring mesh. |
| `YOffset` | `number` | (Optional) Vertical offset to prevent Z-fighting with other meshes. |
| `UpdateInterval` | `number` | (Optional) Update frequency in frames. `1` for every frame. |
| `Color` | `Color3` | (Optional) Mesh color. |
| `Material` | `Enum.Material` | (Optional) Mesh material. |

### Example

```lua
local Ambient = Nami.getAmbientWaves()

local ring = Nami.Ring.create({
    CellSize = 2,
    InnerHalf = 50,
    OuterHalf = 100,
}, workspace, function(x, z, cellSize)
    return Ambient.sample(x, z, cellSize)
end)
```

---

## ring:update()

Positions the ring and updates its vertex heights.

### Syntax

```lua
ring:update(center, y)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `center` | `Vector3` | The world position the ring should center around. |
| `y` | `number` | The vertical position of the water. |

### Example

```lua
RunService.Heartbeat:Connect(function()
    ring:update(boat.Position, 0)
end)
```

---

## ring:destroy()

Cleans up the mesh and associated resources.

### Syntax

```lua
ring:destroy()
```

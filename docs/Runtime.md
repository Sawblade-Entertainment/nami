# Runtime

# Runtime

## surface:step()

Advances the simulation.
This should typically be called every frame from `RunService`.

### Syntax

```lua
local didStep = surface:step(deltaTime)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `deltaTime` | `number` | Frame delta time. |

### Returns

```lua
(boolean) -- Returns true if the simulation stepped and the mesh was updated.
```

> **Note:** `step()` implements a fixed-timestep simulation. It accumulates `deltaTime` and only performs simulation steps when the accumulated time exceeds the `TimeStep` defined during creation. It may perform multiple substeps per frame to catch up after a hitch, up to the `MaxSubsteps` limit.

### Example

```lua
RunService.Heartbeat:Connect(function(dt)
    surface:step(dt)
end)
```

# Advanced Movement

## surface:shiftField()

Moves the simulation field in world space to keep the water stationary while the `MeshPart` moves. This is essential for moving water surfaces (e.g., a floating platform of water).

It uses bilinear sampling to ensure smooth motion even when movement is smaller than a grid cell.

### Syntax

```lua
surface:shiftField(dx, dz, rotationDelta)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `dx` | `number` | World-space X movement delta. |
| `dz` | `number` | World-space Z movement delta. |
| `rotationDelta` | `number` | Rotation delta in radians about the Y axis. |

### Example

```lua
-- If your MeshPart moved by some offset and rotation this frame:
surface:shiftField(moveX, moveZ, rotY)
```

# Cleanup

## surface:destroy()

Destroys the generated mesh and marks the simulation as unusable.

After calling this method, any further operations on the surface will throw an error.

### Syntax

```lua
surface:destroy()
```

### Example

```lua
surface:step(0.016)

surface:destroy()

surface:step(0.016) -- Throws an error: "Nami instance is already destroyed"
```

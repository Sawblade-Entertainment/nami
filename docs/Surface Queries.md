# Surface Queries

# Surface Queries

## surface:worldPositionToMesh()

Converts a world-space position into mesh grid coordinates. All mesh related functions (`pointSplash`, `splash`, `normalAt`, `heightAt`, etc) take mesh grid coordinates. Use this function to convert world to mesh grid.

### Syntax

```lua
local z, x = surface:worldPositionToMesh(worldPosition)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `worldPosition` | `Vector3` | The world-space position to convert. |

### Returns

```lua
(number, number) -- (z, x) grid coordinates.
```

### Example

```lua
local z, x = surface:worldPositionToMesh(
    hitPosition
)

surface:pointSplash(z, x, 4)
```

---

## surface:normalAt()

Returns the surface normal at a grid coordinate.

Useful for buoyancy and object orientation.

### Syntax

```lua
local z, x = surface:worldPositionToMesh(boat.Position)
local normal = surface:normalAt(z, x)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `meshZ` | `number` | Grid Z coordinate. |
| `meshX` | `number` | Grid X coordinate. |

### Returns

```lua
Vector3
```

### Example

```lua
local normal = surface:normalAt(50, 50)
```

---

## surface:heightAt()

Returns the rendered height of the water surface at a grid coordinate.

### Syntax

```lua
local height = surface:heightAt(meshZ, meshX)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `meshZ` | `number` | Grid Z coordinate. |
| `meshX` | `number` | Grid X coordinate. |

### Returns

```lua
number
```

### Example

```lua
local z, x = surface:worldPositionToMesh(boat.Position)
local height = surface:heightAt(z, x)
```

---

## surface:setHeightOffset()

Sets a function that adds additional height to the water during rendering. This is useful for adding ambient waves or background motion that doesn't need to be simulated by the physics engine.

### Syntax

```lua
surface:setHeightOffset(fn)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `fn` | `function` | A function `(worldX, worldZ) -> number`. |

### Example

```lua
surface:setHeightOffset(function(x, z)
    return math.sin(x * 0.1) * 2
end)
```

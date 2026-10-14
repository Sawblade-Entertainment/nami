# Ambient Waves

Ambient waves are formula-based background waves that can be applied to any Nami surface or ring. Because they are calculated based on world coordinates, they line up perfectly across different mesh seams.

## Nami.getAmbientWaves()

Returns the `AmbientWaves` singleton.

### Setting Waves

To define the background motion, use `setWaves()`. This accepts a list of wave configurations.

```luau
local Ambient = Nami.getAmbientWaves()

Ambient.setWaves({
    {
        amplitude = 1.5,
        frequency = 0.1,
        speed = 2,
        direction = Vector2.new(1, 0),
    },
    {
        amplitude = 0.8,
        frequency = 0.2,
        speed = 1.5,
        direction = Vector2.new(0.7, 0.7).Unit,
    },
})
```

### Updating Time

The waves are time-dependent. You must update the internal clock every frame for the waves to move.

```luau
RunService.Heartbeat:Connect(function()
    Ambient.setTime(tick())
end)
```

### Integration with Nami Surface

The easiest way to apply ambient waves to a `WaterSurface` is via `setHeightOffset()`.

```luau
local Ambient = Nami.getAmbientWaves()
local surface = Nami.create({ ... })

surface:setHeightOffset(function(worldX, worldZ)
    -- We pass the surface's spacing as the cellSize so the 
    -- system can fade out waves that are too small for the resolution.
    return Ambient.sample(worldX, worldZ, surface.spacingX)
end)
```

### Parameters: Wave Configuration

| Parameter | Type | Description |
|------------|------|-------------|
| `amplitude` | `number` | Height of the wave. |
| `frequency` | `number` | Radians per stud. Higher values create shorter waves. |
| `speed` | `number` | Speed of propagation. |
| `direction` | `Vector2` | The direction the wave travels. |

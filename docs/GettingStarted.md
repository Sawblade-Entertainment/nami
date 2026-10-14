# Installation

Place the `Nami` ModuleScript somewhere accessible and require it:
```luau
local Nami = require(path.To.Nami)
```
It is recommended that Nami is ran on the client.

# Creating a Surface

## Nami.create()

Creates a new water surface instance.

### Syntax

```luau
local surface = Nami.create({
    LengthX = 100,
    LengthZ = 100,
    VertsPerStud = 0.5,
    WaveSpeed = 20,
    TimeStep = 1 / 50,
    Damping = 0.995,
    Sigma = 1.1,
    -- Optional:
    MaxSubsteps = 4,
    EdgeFadeCells = 6,
})
```

### Parameters

| Parameter | Type | Units | Description |
|------------|--------|--------|-------------|
| `LengthX` | `number` | Studs| Width of the water surface. |
| `LengthZ` | `number` | Studs| Length of the water surface. |
| `VertsPerStud` | `number` |Vertex per Stud | Vertex density used for rendering. |
| `WaveSpeed` | `number` |Studs per Second | Speed at which waves propagate. |
| `TimeStep` | `number` | Seconds| Fixed simulation timestep. |
| `Damping` | `number` |Dimensionless | Energy loss applied each simulation step. Values slightly below `1` are recommended. |
| `Sigma` | `number` |Dimensionless| Gaussian blur strength used for postprocessing. |
| `MaxSubsteps` | `number` |Count (Optional) | Caps catch-up iterations after a frame hitch (default: `4`). |
| `EdgeFadeCells` | `number` |Cells (Optional) | Width of the edge band that fades the wake and absorbs waves (default: `6`). |

### Returns

```luau
WaterSurface
```

### Example

```luau
local surface = Nami.create({
    LengthX = 100,
    LengthZ = 100,
    VertsPerStud = 0.5,
    WaveSpeed = 20,
    TimeStep = 1 / 50,
    Damping = 0.995,
    Sigma = 1.1,
})
```
> **Note:** The timestep is expressed as `1 / physics FPS` for easy interpretation. This is the recommended approach.
> Try to keep at or below 60.

> **Note:** If the water looks spiky, the blur is too low. If the water lacks detail, the blur is too high.
>
---

> **Note:** The timestep is expressed as `1 / physics FPS` for easy interpretation. This is the recommended approach.
> Try to keep at or below 60.

> **Note:** If the water looks spiky, the blur is too low. If the water lacks detail, the blur is too high.
>
---

# The CFL Condition **(important)**
For stability, Nami will refuse to initialise if the given parameters do not satisfy the CFL condition:
$$
\frac{wavespeed \times timestep}{vertspacing} \le \frac{1}{\sqrt{2}}
$$
For most use cases you probably wont have to worry about vertex spacing, just balancing time step to the wave speed you want. Faster waves require smaller step sizes.

# Initialisation

## surface:initialise()

Creates the EditableMesh, MeshPart, and simulation buffers.

**MUST** be called before any other surface method.

### Syntax

```luau
surface:initialise(parent)
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `parent` | `Instance` | Parent instance for the generated MeshPart. |

### Example

```luau
surface:initialise(workspace)
```

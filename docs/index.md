# About
**See installation tab for setting things up**

Nami is a real-time 2D wave simulation module for Roblox built on EditableMesh. It simulates wave propagation using the discrete wave equation and renders the result as a deformable water surface.

# The Math

The 2D wave equation is given by:

$$
\frac{\partial^2 u}{\partial t^2}
=
c^2 \left(
\frac{\partial^2 u}{\partial x^2}
+
\frac{\partial^2 u}{\partial z^2}
\right)
$$

Where u(x,z,t) is a function of water height at point (x,z) during time t.

The terms to the right resemble the curvature of the surface and are approximated with central finite differences. The second time derivative is then solved using Verlet integration:

$$
u_{t+\Delta t} = 2u_t - u_{t-\Delta t} + a_t \Delta t^2
$$

# About
**See installation tab for setting things up**

Nami is a real-time 2D wave simulation module for Roblox built on EditableMesh. It simulates wave propagation using the discrete wave equation and renders the result as a deformable water surface.

# The Math

The 2D wave equation is given by:

$$
\frac{\partial^2 u}{\partial t^2}
=
c^2 \left(
\frac{\partial^2 u}{\partial x^2}
+
\frac{\partial^2 u}{\partial z^2}
\right)
$$

Where u(x,z,t) is a function of water height at point (x,z) during time t.

The terms to the right resemble the curvature of the surface and are approximated with central finite differences. The second time derivative is then solved using Verlet integration:

$$
u_{t+\Delta t} = 2u_t - u_{t-\Delta t} + a_t \Delta t^2
$$

# Complete Example

```lua
local Nami = require(path.To.Nami)

-- 1. Create the surface with a config table
local ocean = Nami.create({
    LengthX = 100,
    LengthZ = 100,
    VertsPerStud = 0.5,
    WaveSpeed = 30,
    TimeStep = 1/50,
    Damping = 0.98,
    Sigma = 1,
})

-- 2. Initialise and place it in the world
ocean:initialise(workspace)
ocean.meshPart.Material = Enum.Material.Glass

-- 3. Run the simulation
game:GetService("RunService").Heartbeat:Connect(function(dt)
	local t = os.clock()
	if ocean:step(dt) then
		-- Use Vector3 for worldPositionToMesh
		local pos = Vector3.new(math.sin(t) * 10, 0, math.cos(t) * 10)
		local z, x = ocean:worldPositionToMesh(pos)
		ocean:pointSplash(z, x, 5)
	end
end)
```

---

# WaterSurface API

| Method | Description |
|----------|-------------|
| `initialise(parent)` | Sets up the EditableMesh and MeshPart. |
| `step(deltaTime)` | Advances simulation and updates mesh. |
| `pointSplash(z, x, height)` | Injects height into a single cell. |
| `splash(z, x, amp, rad)` | Injects a smooth Gaussian bump. |
| `normalAt(z, x)` | Returns the surface normal at a cell. |
| `heightAt(z, x)` | Returns the rendered height at a cell. |
| `worldPositionToMesh(pos)` | Converts world Vector3 to grid coordinates. |
| `setHeightOffset(fn)` | Adds an offset function to the render pass. |
| `shiftField(dx, dz, rot)` | Moves the simulation to stay world-stationary. |
| `destroy()` | Cleans up all resources. |

--!strict
--!native
--!optimize 2

local AssetService = game:GetService("AssetService")

local Nami = {}
Nami.__index = Nami

type NumberGrid = { number }
type BlurKernel = { number } -- 5-tap, normalised

export type Config = {
    LengthX: number,
    LengthZ: number,
    VertsPerStud: number,
    WaveSpeed: number,
    TimeStep: number,
    Damping: number,
    Sigma: number,
    MaxSubsteps: number?, -- default 4; caps catch-up after a frame hitch
	EdgeFadeCells: number?, -- default 6; edge band that fades the wake and absorbs waves
}

export type WaterSurface = typeof(setmetatable({} :: {
    LengthX: number,
    LengthZ: number,
    VertsPerStud: number,
    WaveSpeed: number,
    TimeStep: number,
    Damping: number,
    Sigma: number,
    MaxSubsteps: number,

    accumulatedDt: number,
    initialised: boolean,
    destroyed: boolean,

    meshPart: MeshPart?,
    editableMesh: EditableMesh?,

    -- grid layout: index = (x - 1) * sizeZ + z
    sizeX: number,
    sizeZ: number,
    spacingX: number,
    spacingZ: number,

    vertexIds: { number },
    baseX: { number }, -- cached vertex X positions
    baseZ: { number }, -- cached vertex Z positions

    -- physics buffers (rotated, never reallocated)
    curr: NumberGrid,
    prev: NumberGrid,
    next: NumberGrid,

    -- derived buffers
    blurTemp: NumberGrid,
    height: NumberGrid, -- blurred, what the mesh shows
    dhdx: NumberGrid,
    dhdz: NumberGrid,

    blurKernel: BlurKernel?,
    fieldDirty: boolean,

	EdgeFadeCells: number,
    displayFade: NumberGrid, -- 0 at edges → 1 inside
    sponge: NumberGrid, -- extra damping near edges
    heightOffset: ((worldX: number, worldZ: number) -> number)?,
}, Nami))

local SQRT_HALF = 1 / math.sqrt(2)
local MAX_TRIANGLES = 20000
local MAX_VERTICES = 60000

Nami.Ring = require(script.Ring) -- so callers can use Nami.Ring

local function filled(n: number, value: number): NumberGrid
    local t = table.create(n, value)
    return t
end

function Nami.getAmbientWaves(): any
	return require(script.AmbientWaves)
end

function Nami.create(config: Config): WaterSurface
    local self = setmetatable({
        LengthX = config.LengthX,
        LengthZ = config.LengthZ,
        VertsPerStud = config.VertsPerStud,
        WaveSpeed = config.WaveSpeed,
        TimeStep = config.TimeStep,
        Damping = config.Damping,
        Sigma = config.Sigma,
        MaxSubsteps = config.MaxSubsteps or 4,

        accumulatedDt = 0,
        initialised = false,
        destroyed = false,

        sizeX = 0,
        sizeZ = 0,
        spacingX = 0,
        spacingZ = 0,

        vertexIds = {},
        baseX = {},
        baseZ = {},
        curr = {},
        prev = {},
        next = {},
        blurTemp = {},
        height = {},
        dhdx = {},
        dhdz = {},
        fieldDirty = false,

		EdgeFadeCells = config.EdgeFadeCells or 6,
        displayFade = {},
        sponge = {},
        heightOffset = nil,
    }, Nami)

    return self
end

-- 5-tap Gaussian. Returns nil if sigma <= 0 (blur disabled).
function Nami.computeBlurKernel(sigma: number): BlurKernel?
    if sigma <= 0 then
        return nil
    end

    local kernel = table.create(5)
    local sum = 0
    local denom = 2 * sigma * sigma

    for i = -2, 2 do
        local v = math.exp(-(i * i) / denom)
        kernel[i + 3] = v
        sum += v
    end

    for i = 1, 5 do
        kernel[i] /= sum
    end

    return kernel
end

function Nami.initialise(self: WaterSurface, parent: Instance)
    self:assertAlive()
    assert(not self.initialised, "Nami instance already initialised")

    local sizeX = math.floor(self.LengthX * self.VertsPerStud) + 1
    local sizeZ = math.floor(self.LengthZ * self.VertsPerStud) + 1
    local count = sizeX * sizeZ

    local spacingX = self.LengthX / (sizeX - 1)
    local spacingZ = self.LengthZ / (sizeZ - 1)
	
	local triCount = 2 * (sizeX - 1) * (sizeZ - 1)
    
	if count > MAX_VERTICES or triCount > MAX_TRIANGLES then
        error(string.format(
            "Simulation mesh over budget: %d tris / %d verts (max %d / %d). Lower VertsPerStud or the lengths.",
            triCount, count, MAX_TRIANGLES, MAX_VERTICES
        ))
    end

    self.sizeX, self.sizeZ = sizeX, sizeZ
    self.spacingX, self.spacingZ = spacingX, spacingZ

    -- Fail before allocating anything if the config is unstable.
    if not self:verifyCFL() then
        error(
            string.format(
                "CFL condition unsatisfied: WaveSpeed * TimeStep / spacing = %.3f (must be < %.3f). "
                    .. "Lower WaveSpeed or TimeStep, or lower VertsPerStud.",
                self.WaveSpeed * self.TimeStep / math.min(spacingX, spacingZ),
                SQRT_HALF
            )
        )
    end

    local editableMesh = AssetService:CreateEditableMesh()

    local vertexIds = table.create(count)
    local baseX = table.create(count)
    local baseZ = table.create(count)

    local halfX, halfZ = self.LengthX / 2, self.LengthZ / 2

    for x = 1, sizeX do
        local worldX = (x - 1) * spacingX - halfX
        local column = (x - 1) * sizeZ
        for z = 1, sizeZ do
            local worldZ = (z - 1) * spacingZ - halfZ
            local index = column + z

            vertexIds[index] = editableMesh:AddVertex(Vector3.new(worldX, 0, worldZ))
            baseX[index] = worldX
            baseZ[index] = worldZ
        end
    end

    for x = 1, sizeX - 1 do
        for z = 1, sizeZ - 1 do
            local i = (x - 1) * sizeZ + z
            local v1 = vertexIds[i]
            local v2 = vertexIds[i + sizeZ]
            local v3 = vertexIds[i + sizeZ + 1]
            local v4 = vertexIds[i + 1]

            editableMesh:AddTriangle(v1, v3, v2)
            editableMesh:AddTriangle(v1, v4, v3)
        end
    end

    local meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
    meshPart.Anchored = true
    meshPart.BrickColor = BrickColor.Blue()
    meshPart.Material = Enum.Material.Glass
    meshPart.Parent = parent

    self.meshPart = meshPart
    self.editableMesh = editableMesh
    self.vertexIds = vertexIds
    self.baseX = baseX
    self.baseZ = baseZ

    -- Separate tables (the original aliased curr and prev).
    self.curr = filled(count, 0)
    self.prev = filled(count, 0)
    self.next = filled(count, 0)
    self.blurTemp = filled(count, 0)
    self.height = filled(count, 0)
    self.dhdx = filled(count, 0)
    self.dhdz = filled(count, 0)

    self.blurKernel = Nami.computeBlurKernel(self.Sigma)

	local displayFade = table.create(count)
    local sponge = table.create(count)
    local fadeCells = self.EdgeFadeCells

    for x = 1, sizeX do
        local dX = math.min(x - 1, sizeX - x)
        local column = (x - 1) * sizeZ
		
        for z = 1, sizeZ do
            local d = math.min(dX, z - 1, sizeZ - z)
            local t = if fadeCells > 0 then math.clamp(d / fadeCells, 0, 1) else 1

            displayFade[column + z] = t * t * (3 - 2 * t) -- smoothstep
            sponge[column + z] = 1 - 0.15 * (1 - t) ^ 2 -- absorb instead of reflect
        end
    end

    self.displayFade = displayFade
    self.sponge = sponge

    self.initialised = true
end

-- Call from RunService. Returns true if the mesh was updated this frame.
function Nami.step(self: WaterSurface, deltaTime: number): boolean
    self:assertAlive()
    self:assertInitialised()

    self.accumulatedDt += deltaTime
    if self.accumulatedDt < self.TimeStep then
        return false
    end

    -- Fixed-timestep with catch-up, capped so a hitch doesn't spiral.
    local substeps = 0
    while self.accumulatedDt >= self.TimeStep and substeps < self.MaxSubsteps do
        self:stepField(self.TimeStep)
        self.accumulatedDt -= self.TimeStep
        substeps += 1
    end
    if substeps >= self.MaxSubsteps then
        self.accumulatedDt = 0 -- drop the backlog rather than lagging forever
    end

    self:computeHeightField()
    self:computeGradients()
    self:applyToMesh()

    return true
end

-- Fused Laplacian + Verlet integration in one pass, writing into a reused buffer.
function Nami.stepField(self: WaterSurface, dt: number)
    local curr, prev, nextField = self.curr, self.prev, self.next
    local sizeX, sizeZ = self.sizeX, self.sizeZ
    local lastColumnStart = (sizeX - 1) * sizeZ

    local c2dt2 = self.WaveSpeed * self.WaveSpeed * dt * dt
    local invDx2 = c2dt2 / (self.spacingX * self.spacingX)
    local invDz2 = c2dt2 / (self.spacingZ * self.spacingZ)
    local damping = self.Damping
	local sponge = self.sponge

    for index = 1, sizeX * sizeZ do
        local z = (index - 1) % sizeZ + 1
        local center = curr[index]

        -- Neumann (reflective) boundary via clamped neighbours
        local xm = if index > sizeZ then curr[index - sizeZ] else center
        local xp = if index <= lastColumnStart then curr[index + sizeZ] else center
        local zm = if z > 1 then curr[index - 1] else center
        local zp = if z < sizeZ then curr[index + 1] else center

        local lap = (xp + xm - 2 * center) * invDx2 + (zp + zm - 2 * center) * invDz2

        nextField[index] = (2 * center - prev[index] + lap) * damping * sponge[index]
    end

    -- Rotate buffers instead of allocating.
    self.prev, self.curr, self.next = curr, nextField, prev
end

-- Separable 5-tap Gaussian blur of curr into height. If blur is disabled, copies.
function Nami.computeHeightField(self: WaterSurface)
    local field = self.curr
    local kernel = self.blurKernel
    local height = self.height
    local sizeX, sizeZ = self.sizeX, self.sizeZ

    if not kernel then
        table.move(field, 1, sizeX * sizeZ, 1, height)
        return
    end

    local k1, k2, k3, k4, k5 = kernel[1], kernel[2], kernel[3], kernel[4], kernel[5]
    local temp = self.blurTemp

    -- pass along X (stride sizeZ)
    for x = 1, sizeX do
        local c0 = (x - 1) * sizeZ
        local cm2 = (math.clamp(x - 2, 1, sizeX) - 1) * sizeZ
        local cm1 = (math.clamp(x - 1, 1, sizeX) - 1) * sizeZ
        local cp1 = (math.clamp(x + 1, 1, sizeX) - 1) * sizeZ
        local cp2 = (math.clamp(x + 2, 1, sizeX) - 1) * sizeZ

        for z = 1, sizeZ do
            temp[c0 + z] = k1 * field[cm2 + z]
                + k2 * field[cm1 + z]
                + k3 * field[c0 + z]
                + k4 * field[cp1 + z]
                + k5 * field[cp2 + z]
        end
    end

    -- pass along Z (stride 1)
    for x = 1, sizeX do
        local c0 = (x - 1) * sizeZ
        for z = 1, sizeZ do
            local zm2 = math.clamp(z - 2, 1, sizeZ)
            local zm1 = math.clamp(z - 1, 1, sizeZ)
            local zp1 = math.clamp(z + 1, 1, sizeZ)
            local zp2 = math.clamp(z + 2, 1, sizeZ)

            height[c0 + z] = k1 * temp[c0 + zm2]
                + k2 * temp[c0 + zm1]
                + k3 * temp[c0 + z]
                + k4 * temp[c0 + zp1]
                + k5 * temp[c0 + zp2]
        end
    end
end

function Nami.computeGradients(self: WaterSurface)
    local h = self.height
    local dhdx, dhdz = self.dhdx, self.dhdz
    local sizeX, sizeZ = self.sizeX, self.sizeZ
    local lastColumnStart = (sizeX - 1) * sizeZ

    local inv2dx = 1 / (2 * self.spacingX)
    local inv2dz = 1 / (2 * self.spacingZ)

    for index = 1, sizeX * sizeZ do
        local z = (index - 1) % sizeZ + 1
        local center = h[index]

        local xm = if index > sizeZ then h[index - sizeZ] else center
        local xp = if index <= lastColumnStart then h[index + sizeZ] else center
        local zm = if z > 1 then h[index - 1] else center
        local zp = if z < sizeZ then h[index + 1] else center

        dhdx[index] = (xp - xm) * inv2dx
        dhdz[index] = (zp - zm) * inv2dz
    end
end

function Nami.applyToMesh(self: WaterSurface)
    local editableMesh = self.editableMesh :: EditableMesh
    local meshPart = self.meshPart :: MeshPart
    local vertexIds, baseX, baseZ = self.vertexIds, self.baseX, self.baseZ
    local height, fade = self.height, self.displayFade
    local offsetFn = self.heightOffset

    local cf = meshPart.CFrame
    local px, pz = cf.X, cf.Z
    local xv, zv = cf.XVector, cf.ZVector

    for index = 1, self.sizeX * self.sizeZ do
        local bx, bz = baseX[index], baseZ[index]
        local h = height[index] * fade[index]
        if offsetFn then
            h += offsetFn(px + xv.X * bx + zv.X * bz, pz + xv.Z * bx + zv.Z * bz)
        end
        editableMesh:SetPosition(vertexIds[index], Vector3.new(bx, h, bz))
    end
end

-- Extra height added on top of the simulation when drawing (e.g. background waves).
function Nami.setHeightOffset(self: WaterSurface, fn: ((worldX: number, worldZ: number) -> number)?)
    self.heightOffset = fn
end

function Nami.isInside(self: WaterSurface, z: number, x: number): boolean
    return z >= 1 and x >= 1 and z <= self.sizeZ and x <= self.sizeX
end

function Nami.heightAt(self: WaterSurface, z: number, x: number): number?
    if not self:isInside(z, x) then
        return nil
    end

	local ind = (x - 1) * self.sizeZ + z
    return self.height[ind] * self.displayFade[ind]
end

-- Surface normal in object space of the MeshPart.
function Nami.normalAt(self: WaterSurface, z: number, x: number): Vector3?
    if not self:isInside(z, x) then
        return nil
    end

    local ind = (x - 1) * self.sizeZ + z
    return Vector3.new(-self.dhdx[ind], 1, -self.dhdz[ind]).Unit
end

-- World position -> nearest grid cell (z, x). Uses the real grid spacing.
function Nami.worldPositionToMesh(self: WaterSurface, worldPosition: Vector3): (number, number)
    local meshPart = self.meshPart :: MeshPart
    local rel = meshPart.CFrame:PointToObjectSpace(worldPosition)

    local z = math.round((rel.Z + self.LengthZ / 2) / self.spacingZ) + 1
    local x = math.round((rel.X + self.LengthX / 2) / self.spacingX) + 1
    return z, x
end

-- Sets a single cell. Produces sharp, choppy ripples; prefer splash().
function Nami.pointSplash(self: WaterSurface, z: number, x: number, y: number)
    if not self:isInside(z, x) then
        return
    end
    self.curr[(x - 1) * self.sizeZ + z] = y
end

-- Adds a smooth Gaussian bump. radius is in grid cells.
function Nami.splash(self: WaterSurface, z: number, x: number, amplitude: number, radius: number)
    local sizeX, sizeZ = self.sizeX, self.sizeZ
    local curr = self.curr
    local r = math.ceil(radius * 3)
    local invR2 = 1 / (2 * radius * radius)

    for gx = math.max(1, x - r), math.min(sizeX, x + r) do
        local dx = gx - x
        local column = (gx - 1) * sizeZ
        for gz = math.max(1, z - r), math.min(sizeZ, z + r) do
            local dz = gz - z
            curr[column + gz] += amplitude * math.exp(-(dx * dx + dz * dz) * invR2)
        end
    end
end

-- Call when the MeshPart has moved by (dx, dz) in world space and rotated by
-- rotationDelta radians about Y, so the water stays put in the world.
-- Uses bilinear sampling so sub-cell movement doesn't stair-step.
function Nami.shiftField(self: WaterSurface, dx: number, dz: number, rotationDelta: number)
    self:assertInitialised()

    local meshPart = self.meshPart :: MeshPart
    local rel = meshPart.CFrame:VectorToObjectSpace(Vector3.new(dx, 0, dz))
    local vx = rel.X / self.spacingX
    local vz = rel.Z / self.spacingZ

    local doRotate = math.abs(rotationDelta) > 1e-3
    if math.abs(vx) < 1e-6 and math.abs(vz) < 1e-6 and not doRotate then
        return
    end

    local sizeX, sizeZ = self.sizeX, self.sizeZ
    local cosR, sinR = math.cos(rotationDelta), math.sin(rotationDelta)
    local midX, midZ = (sizeX + 1) / 2, (sizeZ + 1) / 2

    local function sample(field: NumberGrid, fx: number, fz: number): number
        if fx < 1 or fz < 1 or fx > sizeX or fz > sizeZ then
            return 0
        end
        local x0 = math.floor(fx)
        local z0 = math.floor(fz)
        local x1 = math.min(x0 + 1, sizeX)
        local z1 = math.min(z0 + 1, sizeZ)
        local tx, tz = fx - x0, fz - z0

        local c0, c1 = (x0 - 1) * sizeZ, (x1 - 1) * sizeZ
        local a = field[c0 + z0] + (field[c0 + z1] - field[c0 + z0]) * tz
        local b = field[c1 + z0] + (field[c1 + z1] - field[c1 + z0]) * tz
        return a + (b - a) * tx
    end

    local function transform(src: NumberGrid, dst: NumberGrid)
        for x = 1, sizeX do
            local cx = x - midX
            local column = (x - 1) * sizeZ
            for z = 1, sizeZ do
                local cz = z - midZ
                local rotX = cx * cosR + cz * sinR
                local rotZ = -cx * sinR + cz * cosR
                dst[column + z] = sample(src, rotX + midX + vx, rotZ + midZ + vz)
            end
        end
    end

    -- Use the spare buffers as scratch so we don't allocate.
    transform(self.curr, self.next)
    self.curr, self.next = self.next, self.curr

    transform(self.prev, self.blurTemp)
    self.prev, self.blurTemp = self.blurTemp, self.prev
end

function Nami.verifyCFL(self: WaterSurface): boolean
    local minSpacing = math.min(self.spacingX, self.spacingZ)
    return (self.WaveSpeed * self.TimeStep) / minSpacing < SQRT_HALF
end

function Nami.assertAlive(self: WaterSurface)
    assert(not self.destroyed, "Nami instance is already destroyed")
end

function Nami.assertInitialised(self: WaterSurface)
    assert(self.initialised, "Please initialise Nami first")
end

function Nami.destroy(self: WaterSurface)
    self:assertAlive()
    self.destroyed = true

    if self.meshPart then
        self.meshPart:Destroy()
        self.meshPart = nil
    end
    if self.editableMesh then
        self.editableMesh:Destroy()
        self.editableMesh = nil
    end

    -- Release the large buffers so they can be collected immediately.
    self.curr, self.prev, self.next = {}, {}, {}
    self.blurTemp, self.height, self.dhdx, self.dhdz = {}, {}, {}, {}
    self.vertexIds, self.baseX, self.baseZ = {}, {}, {}
end

return Nami
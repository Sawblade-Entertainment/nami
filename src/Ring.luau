--!strict
--!native
--!optimize 2

local AssetService = game:GetService("AssetService")

-- Per-mesh caps. Check the current Roblox docs; triangles are what you hit first.
local MAX_TRIANGLES = 20000
local MAX_VERTICES = 60000

local Ring = {}
Ring.__index = Ring

export type RingConfig = {
	CellSize: number,
	InnerHalf: number, -- half-width of the mesh inside this ring
	OuterHalf: number,
	YOffset: number?, -- sit slightly lower to avoid flicker where meshes overlap
	UpdateInterval: number?, -- frames between updates (1 = every frame)
	Color: Color3?,
	Material: Enum.Material?,
}

export type Sampler = (x: number, z: number, cellSize: number) -> number

export type WaterRing = typeof(setmetatable(
	{} :: {
		cellSize: number,
		yOffset: number,
		interval: number,
		frame: number,
		sampler: Sampler,
		meshPart: MeshPart?,
		editableMesh: EditableMesh?,
		vertexIds: { number },
		localX: { number },
		localZ: { number },
	},
	Ring
))

function Ring.create(config: RingConfig, parent: Instance, sampler: Sampler): WaterRing
	local s = config.CellSize
	local n = math.ceil(2 * config.OuterHalf / s) -- cells per side
	local half = n * s / 2

	-- Make the hole 2 cells smaller than the inner mesh. Both meshes snap to
	-- their own grids, so their centres can be up to ~1 cell apart; the
	-- overlap hides any gap.
	local hole = config.InnerHalf - 2 * s

	local function cellIsHole(ix: number, iz: number): boolean
		local x0, z0 = -half + ix * s, -half + iz * s
		return x0 >= -hole and x0 + s <= hole and z0 >= -hole and z0 + s <= hole
	end

	-- Check the budget before building anything.
	local tris = 0
	local usedVert: { [number]: boolean } = {}
	local verts = 0
	local function key(ix: number, iz: number): number
		return ix * (n + 1) + iz + 1
	end
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			if not cellIsHole(ix, iz) then
				tris += 2
				for _, k in { key(ix, iz), key(ix + 1, iz), key(ix, iz + 1), key(ix + 1, iz + 1) } do
					if not usedVert[k] then
						usedVert[k] = true
						verts += 1
					end
				end
			end
		end
	end
	if tris > MAX_TRIANGLES or verts > MAX_VERTICES then
		error(
			string.format(
				"Ring over mesh budget: %d tris / %d verts (max %d / %d). Increase CellSize or reduce OuterHalf.",
				tris,
				verts,
				MAX_TRIANGLES,
				MAX_VERTICES
			)
		)
	end

	local mesh = AssetService:CreateEditableMesh()
	local idByKey: { [number]: number } = {}
	local vertexIds: { number }, localX, localZ = table.create(verts), table.create(verts), table.create(verts)

	local function vert(ix: number, iz: number): number
		local k = key(ix, iz)
		local id: number? = idByKey[k]

		if id then
			return id
		end

		local x, z = -half + ix * s, -half + iz * s

		idByKey[k] = mesh:AddVertex(Vector3.new(x, 0, z))

		table.insert(vertexIds, idByKey[k])
		table.insert(localX, x)
		table.insert(localZ, z)

		return idByKey[k]
	end

	-- Same winding order as Nami's patch.
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			if not cellIsHole(ix, iz) then
				local v1 = vert(ix, iz)
				local v2 = vert(ix + 1, iz)
				local v3 = vert(ix + 1, iz + 1)
				local v4 = vert(ix, iz + 1)
				mesh:AddTriangle(v1, v3, v2)
				mesh:AddTriangle(v1, v4, v3)
			end
		end
	end

	local meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	meshPart.Anchored = true
	meshPart.CanCollide = false
	meshPart.CanQuery = false
	meshPart.CanTouch = false
	meshPart.CastShadow = false
	meshPart.Color = config.Color or BrickColor.Blue().Color
	meshPart.Material = config.Material or Enum.Material.Glass
	meshPart.Parent = parent

	return setmetatable({
		cellSize = s,
		yOffset = config.YOffset or 0,
		interval = math.max(1, config.UpdateInterval or 1),
		frame = 0,
		sampler = sampler,
		meshPart = meshPart,
		editableMesh = mesh,
		vertexIds = vertexIds,
		localX = localX,
		localZ = localZ,
	}, Ring)
end

function Ring.update(self: WaterRing, center: Vector3, y: number)
	local meshPart, mesh = self.meshPart, self.editableMesh
	if not (meshPart and mesh) then
		return
	end

	self.frame += 1
	if self.frame % self.interval ~= 0 then
		return
	end

	-- Snap to 2 cells so vertices land on the same world positions every
	-- frame instead of sliding.
	local s = self.cellSize
	local snap = 2 * s
	local cx = math.round(center.X / snap) * snap
	local cz = math.round(center.Z / snap) * snap
	meshPart.CFrame = CFrame.new(cx, y + self.yOffset, cz)

	local sampler, ids, lx, lz = self.sampler, self.vertexIds, self.localX, self.localZ
	for i = 1, #ids do
		local x, z = lx[i], lz[i]
		mesh:SetPosition(ids[i], Vector3.new(x, sampler(cx + x, cz + z, s), z))
	end
end

function Ring.destroy(self: WaterRing)
	if self.meshPart then
		self.meshPart:Destroy()
		self.meshPart = nil
	end
	if self.editableMesh then
		self.editableMesh:Destroy()
		self.editableMesh = nil
	end
end

return Ring

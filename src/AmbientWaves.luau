--!strict
--!native
--!optimize 2

-- Formula-based background waves. Every mesh (simulation patch and rings)
-- uses this same function, so the waves line up across seams.
local AmbientWaves = {}

export type Wave = {
	amplitude: number,
	frequency: number, -- radians per stud
	speed: number,
	direction: Vector2,
}

local TWO_PI = 2 * math.pi

-- Split into flat arrays for the hot loop.
local amp: { number } = {}
local freq: { number } = {}
local speed: { number } = {}
local dirX: { number } = {}
local dirZ: { number } = {}
local wavelength: { number } = {}
local count = 0

local time = 0

function AmbientWaves.setWaves(waves: { Wave })
	table.clear(amp)
	table.clear(freq)
	table.clear(speed)

	table.clear(dirX)
	table.clear(dirZ)
	table.clear(wavelength)

	for i, w in waves do
		local d = w.direction.Unit
		amp[i], freq[i], speed[i] = w.amplitude, w.frequency, w.speed
		dirX[i], dirZ[i] = d.X, d.Y
		wavelength[i] = TWO_PI / w.frequency
	end

	count = #waves
end

function AmbientWaves.setTime(t: number)
	time = t
end

-- cellSize: the grid spacing of the mesh asking. Waves shorter than ~4 cells
-- would just flicker at that resolution, so they fade out (8+ cells = full strength).
function AmbientWaves.sample(x: number, z: number, cellSize: number?): number
	local h = 0
	for i = 1, count do
		local weight = 1
		if cellSize then
			weight = math.clamp((wavelength[i] / cellSize - 2) / 2, 0, 1)
		end
		if weight > 0 then
			h += math.sin((x * dirX[i] + z * dirZ[i]) * freq[i] + time * speed[i]) * amp[i] * weight
		end
	end
	return h
end

return AmbientWaves

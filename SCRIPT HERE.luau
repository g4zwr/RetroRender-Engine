local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local floor = math.floor
local ceil = math.ceil
local clamp = math.clamp
local sin = math.sin
local max = math.max
local min = math.min
local clock = os.clock
local tcreate = table.create
local v3new = Vector3.new
local v2new = Vector2.new
local c3new = Color3.new
local c3rgb = Color3.fromRGB
local udOffset = UDim2.fromOffset
local udScale = UDim2.fromScale
local newInst = Instance.new
local raycast = Workspace.Raycast

local PIXEL_SIZE = 7
local MAX_DISTANCE = 500
local SHADOW_DISTANCE = 150
local MAX_REFLECTION_DEPTH = 1
local DEFAULT_REFLECTIVITY = 0.3
local SUN_DIR = v3new(0.4, 0.6, 0.3).Unit
local SUN_ANGULAR_SIZE = 0.06
local SUN_GLOW_SIZE = 0.35
local CLOUD_HEIGHT = 400
local CLOUD_SCALE = 0.006
local CLOUD_SPEED = 0.5
local CLOUD_COVERAGE = 0.55
local TILE_SIZE = 6
local NUM_PHASES = 6

local FrameEditableImage = {}
FrameEditableImage.__index = FrameEditableImage

local function buildGrid(self)
	self._container = newInst("Frame")
	self._container.Name = "FrameEditableImage"
	self._container.BackgroundTransparency = 1
	self._container.Size = udOffset(self.Width * self.PixelSize, self.Height * self.PixelSize)
	self._container.ClipsDescendants = true
	self._container.Parent = self._parent

	self._pixels = tcreate(self.Width * self.Height)

	for y = 0, self.Height - 1 do
		for x = 0, self.Width - 1 do
			local px = newInst("Frame")
			px.Name = string.format("Pixel_%d_%d", x, y)
			px.BorderSizePixel = 0
			px.Size = udOffset(self.PixelSize, self.PixelSize)
			px.Position = udOffset(x * self.PixelSize, y * self.PixelSize)
			px.BackgroundColor3 = c3new(0, 0, 0)
			px.BackgroundTransparency = 1
			px.Parent = self._container

			self._pixels[y * self.Width + x + 1] = px
		end
	end
end

function FrameEditableImage.new(parent, width, height, pixelSize)
	assert(parent, "parent is required")
	assert(width and height and width > 0 and height > 0, "width/height must be positive")

	local self = setmetatable({}, FrameEditableImage)
	self._parent = parent
	self.Width = width
	self.Height = height
	self.PixelSize = pixelSize or 4

	buildGrid(self)

	return self
end

local function inBounds(self, x, y)
	return x >= 0 and x < self.Width and y >= 0 and y < self.Height
end

local function index(self, x, y)
	return y * self.Width + x + 1
end

function FrameEditableImage:DrawPixel(x, y, color3, alpha)
	if not inBounds(self, x, y) then
		return false
	end
	local px = self._pixels[index(self, x, y)]
	px.BackgroundColor3 = color3
	px.BackgroundTransparency = 1 - ((alpha or 255) / 255)
	return true
end

function FrameEditableImage:WritePixels(startPos, size, pixelBuffer)
	local sx, sy = startPos[1], startPos[2]
	local w, h = size[1], size[2]

	local i = 1
	for row = 0, h - 1 do
		for col = 0, w - 1 do
			local px = pixelBuffer[i]
			if px then
				self:DrawPixel(sx + col, sy + row, c3rgb(px[1], px[2], px[3]), px[4])
			end
			i += 1
		end
	end
end

function FrameEditableImage:Resize(newWidth, newHeight)
	for _, px in ipairs(self._pixels) do
		px:Destroy()
	end
	self.Width = newWidth
	self.Height = newHeight
	buildGrid(self)
end

function FrameEditableImage:Destroy()
	if self._container then
		self._container:Destroy()
	end
end

local function hash21(x, y)
	local n = sin(x * 12.9898 + y * 78.233) * 43758.5453
	return n - floor(n)
end

local function fade(t)
	return t * t * (3 - 2 * t)
end

local function valueNoise(x, y)
	local xi, yi = floor(x), floor(y)
	local xf, yf = x - xi, y - yi
	local u, v = fade(xf), fade(yf)

	local a = hash21(xi, yi)
	local b = hash21(xi + 1, yi)
	local c = hash21(xi, yi + 1)
	local d = hash21(xi + 1, yi + 1)

	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
end

local function fbm(x, y)
	local total, amp, freq = 0, 0.5, 1
	for _ = 1, 4 do
		total += valueNoise(x * freq, y * freq) * amp
		amp *= 0.5
		freq *= 2
	end
	return total
end

local function materialTextureFactor(material, point)
	if material == Enum.Material.Grass or material == Enum.Material.LeafyGrass then
		local n = fbm(point.X * 1.5, point.Z * 1.5)
		return 0.7 + n * 0.6

	elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		local grain = sin((point.X + point.Z) * 3 + fbm(point.X * 0.15, point.Z * 0.15) * 8)
		return 0.82 + grain * 0.18

	elseif material == Enum.Material.Concrete
		or material == Enum.Material.Slate
		or material == Enum.Material.Rock
		or material == Enum.Material.Basalt then
		local n = fbm(point.X * 0.6, point.Z * 0.6)
		return 0.75 + n * 0.5

	elseif material == Enum.Material.Sand then
		local n = fbm(point.X * 2, point.Z * 2)
		return 0.85 + n * 0.3

	elseif material == Enum.Material.Brick then
		local bx = floor(point.X * 1.2) % 2
		local bz = floor(point.Z * 0.6) % 2
		local mortar = (bx == 0 and bz == 0) and 0.85 or 1.0
		local n = fbm(point.X * 2, point.Z * 2)
		return mortar * (0.9 + n * 0.2)

	elseif material == Enum.Material.Plastic or material == Enum.Material.SmoothPlastic then
		return 1.0

	elseif material == Enum.Material.Metal or material == Enum.Material.DiamondPlate
		or material == Enum.Material.CorrodedMetal then
		local n = fbm(point.X * 3, point.Z * 3)
		return 0.9 + n * 0.2

	else
		local n = fbm(point.X * 0.5, point.Z * 0.5)
		return 0.9 + n * 0.2
	end
end

local function specularBoost(material, normal, toLight, viewDir)
	if material ~= Enum.Material.Plastic and material ~= Enum.Material.SmoothPlastic then
		return 0
	end
	local halfVec = (toLight + viewDir).Unit
	local spec = max(normal:Dot(halfVec), 0) ^ 40
	return spec * 180
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local screenGui = newInst("ScreenGui")
screenGui.Name = "CameraRaycastDemo"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = -100
screenGui.Parent = playerGui

local backdrop = newInst("Frame")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = c3new(0, 0, 0)
backdrop.BorderSizePixel = 0
backdrop.Size = udScale(1, 1)
backdrop.Position = udScale(0, 0)
backdrop.Parent = screenGui

local function gridSizeFromViewport()
	local viewport = camera.ViewportSize
	local shortSide = min(viewport.X, viewport.Y)
	local size = max(1, floor(shortSide / PIXEL_SIZE))
	return size, size
end

local SIZE = gridSizeFromViewport()

local canvas = FrameEditableImage.new(screenGui, SIZE, SIZE, PIXEL_SIZE)
canvas._container.AnchorPoint = v2new(0.5, 0.5)
canvas._container.Position = udScale(0.5, 0.5)

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	local newSize = gridSizeFromViewport()
	if newSize ~= canvas.Width then
		canvas:Resize(newSize, newSize)
	end
end)

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function updateFilter()
	local character = player.Character
	raycastParams.FilterDescendantsInstances = character and { character } or {}
end
updateFilter()
player.CharacterAdded:Connect(updateFilter)

local function skyBase(rayDir)
	local up = clamp(rayDir.Y * 0.5 + 0.5, 0, 1)
	return {
		20 + up * 90,
		20 + up * 130,
		40 + up * 170,
	}
end

local function applySun(color, rayDir)
	local cosAngle = rayDir:Dot(SUN_DIR)

	if cosAngle > 1 - SUN_ANGULAR_SIZE then
		return { 255, 250, 230 }
	end

	if cosAngle > 1 - SUN_ANGULAR_SIZE - SUN_GLOW_SIZE then
		local t = (cosAngle - (1 - SUN_ANGULAR_SIZE - SUN_GLOW_SIZE)) / SUN_GLOW_SIZE
		t = fade(clamp(t, 0, 1))
		return {
			color[1] + (255 - color[1]) * t,
			color[2] + (245 - color[2]) * t,
			color[3] + (210 - color[3]) * t,
		}
	end

	return color
end

local function applyClouds(color, rayDir, origin, t)
	if rayDir.Y <= 0.02 then
		return color
	end

	local travel = (CLOUD_HEIGHT - origin.Y) / rayDir.Y
	local point = origin + rayDir * travel

	local nx = point.X * CLOUD_SCALE + t * CLOUD_SPEED
	local nz = point.Z * CLOUD_SCALE

	local density = fbm(nx, nz)
	density = clamp((density - (1 - CLOUD_COVERAGE)) / CLOUD_COVERAGE, 0, 1)
	density = density * density * (3 - 2 * density)

	local horizonFade = clamp(rayDir.Y * 4, 0, 1)
	density *= horizonFade

	local cloudColor = { 235, 235, 240 }
	return {
		color[1] + (cloudColor[1] - color[1]) * density,
		color[2] + (cloudColor[2] - color[2]) * density,
		color[3] + (cloudColor[3] - color[3]) * density,
	}
end

local function shadeSky(rayDir, origin, t)
	local color = skyBase(rayDir)
	color = applyClouds(color, rayDir, origin, t)
	color = applySun(color, rayDir)
	return color
end

local function isInShadow(point, normal)
	local shadowOrigin = point + normal * 0.05
	local result = raycast(Workspace, shadowOrigin, SUN_DIR * SHADOW_DISTANCE, raycastParams)
	return result ~= nil
end

local function reflect(dir, normal)
	return (dir - 2 * dir:Dot(normal) * normal).Unit
end

local traceRay

local function shadeHit(result, origin, direction, depth, t)
	local instance = result.Instance
	local baseColor = instance.Color
	local material = instance.Material
	local normal = result.Normal
	local point = result.Position

	local diffuse = max(normal:Dot(SUN_DIR), 0)
	if diffuse > 0 and isInShadow(point, normal) then
		diffuse = 0
	end

	local ambient = 0.22
	local intensity = ambient + diffuse * 0.78

	local texFactor = materialTextureFactor(material, point)

	local viewDir = (-direction).Unit
	local spec = specularBoost(material, normal, SUN_DIR, viewDir)

	local r = baseColor.R * 255 * intensity * texFactor + spec
	local g = baseColor.G * 255 * intensity * texFactor + spec
	local b = baseColor.B * 255 * intensity * texFactor + spec

	local toPoint = point - origin
	local dist = toPoint.Magnitude
	local fog = clamp(dist / MAX_DISTANCE, 0, 1) ^ 1.5
	local sky = shadeSky(toPoint.Unit, origin, t)

	r = r * (1 - fog) + sky[1] * fog
	g = g * (1 - fog) + sky[2] * fog
	b = b * (1 - fog) + sky[3] * fog

	local reflectance = max(instance.Reflectance or 0, DEFAULT_REFLECTIVITY)
	if reflectance > 0.01 and depth < MAX_REFLECTION_DEPTH then
		local reflectDir = reflect(direction.Unit, normal)
		local reflectOrigin = point + normal * 0.05
		local reflectColor = traceRay(reflectOrigin, reflectDir * MAX_DISTANCE, depth + 1, t)

		r = r + (reflectColor[1] - r) * reflectance
		g = g + (reflectColor[2] - g) * reflectance
		b = b + (reflectColor[3] - b) * reflectance
	end

	return {
		clamp(r, 0, 255),
		clamp(g, 0, 255),
		clamp(b, 0, 255),
	}
end

traceRay = function(origin, direction, depth, t)
	local result = raycast(Workspace, origin, direction, raycastParams)
	if result then
		return shadeHit(result, origin, direction, depth, t)
	else
		return shadeSky(direction.Unit, origin, t)
	end
end

local frameCounter = 0

local renderConnection
renderConnection = RunService.RenderStepped:Connect(function()
	local t = clock()
	local size = canvas.Width
	local viewport = camera.ViewportSize

	local shortSide = min(viewport.X, viewport.Y)
	local offsetX = (viewport.X - shortSide) / 2
	local offsetY = (viewport.Y - shortSide) / 2

	local phase = frameCounter % NUM_PHASES
	local phaseX = phase % 2
	local phaseY = floor(phase / 2)
	frameCounter += 1

	local tilesPerRow = ceil(size / TILE_SIZE)
	local tileBuffer = tcreate(TILE_SIZE * TILE_SIZE)

	for tileY = 0, tilesPerRow - 1 do
		if tileY % 2 == phaseY then
			for tileX = 0, tilesPerRow - 1 do
				if tileX % 2 == phaseX then
					local startX = tileX * TILE_SIZE
					local startY = tileY * TILE_SIZE
					local w = min(TILE_SIZE, size - startX)
					local h = min(TILE_SIZE, size - startY)

					local bi = 1
					for ly = 0, h - 1 do
						local gy = startY + ly
						local screenY = offsetY + (gy + 0.5) / size * shortSide
						for lx = 0, w - 1 do
							local gx = startX + lx
							local screenX = offsetX + (gx + 0.5) / size * shortSide

							local unitRay = camera:ViewportPointToRay(screenX, screenY)
							local color = traceRay(unitRay.Origin, unitRay.Direction * MAX_DISTANCE, 0, t)

							tileBuffer[bi] = { color[1], color[2], color[3], 255 }
							bi += 1
						end
					end

					canvas:WritePixels({ startX, startY }, { w, h }, tileBuffer)
				end
			end
		end
	end
end)

screenGui.AncestryChanged:Connect(function(_, parent)
	if not parent then
		renderConnection:Disconnect()
	end
end)

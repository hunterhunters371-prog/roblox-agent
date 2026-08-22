-- Ejecutores de operaciones del protocolo RBX Bridge v0.1.
-- Cada handler recibe la operación (y opcionalmente el id del comando, v1.2) y devuelve:
--   (action: "created" | "updated" | "skipped" | nil, detail?, data?)
-- En error lanza error({ code = ..., message = ... }) (o un string plano).
-- v1.2: todo lo que el plugin CREA queda etiquetado con el atributo _RBX_Bridge = <id del
-- comando>, así la inspección puede reconocer qué fue hecho por el agente.
-- v1.9: capture_spec (plano rejugable de un subárbol) y replicate_instance (reconstruye
-- planos u objetos en vivo, 1-50 copias con offset/step); decodeValue acepta ahora
-- UDim2, UDim, Vector2 y NumberRange (necesario para replicar GUI y partículas), y los
-- MeshPart conservan su malla vía AssetService:CreateMeshPartAsync.
-- v1.9.2: replicate_instance devuelve data.copias (nombre, path, nº de nodos y
-- scripts de cada copia) para que el registro señale qué objeto/script se agregó.

local ServerStorage = game:GetService("ServerStorage")
local AssetService = game:GetService("AssetService")

local Config = require(script.Parent.Config)
local Resolver = require(script.Parent.PathResolver)
local Validator = require(script.Parent.Validator)

local Ops = {}

-- ---------- utilidades ----------

local function fail(code, message)
	error({ code = code, message = message }, 0)
end

-- v1.2: marca de autoría del bridge (best-effort; algunos objetos no aceptan atributos).
local function marcar(instance, cmdId)
	pcall(function()
		instance:SetAttribute("_RBX_Bridge", cmdId or "agent-bridge")
	end)
end

local function toVector3(value)
	assert(type(value) == "table" and #value == 3, "se esperaba [x, y, z]")
	return Vector3.new(value[1], value[2], value[3])
end

local function toColor3(value)
	assert(type(value) == "table" and #value == 3, "se esperaba [r, g, b]")
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function toCFrame(value)
	local position = value.position or { 0, 0, 0 }
	local rotation = value.rotation or { 0, 0, 0 }
	return CFrame.new(position[1], position[2], position[3])
		* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
end

-- Decodifica un valor JSON según el tipo de la propiedad destino.
local function decodeValue(target, property, value)
	local ok, current = pcall(function()
		return target[property]
	end)
	if not ok then
		fail("PROPERTY_NOT_WRITABLE", ("la propiedad '%s' no existe en %s"):format(property, target.ClassName))
	end
	local currentType = typeof(current)
	if currentType == "Vector3" and type(value) == "table" then
		return toVector3(value)
	elseif currentType == "Color3" and type(value) == "table" then
		return toColor3(value)
	elseif currentType == "BrickColor" and type(value) == "string" then
		return BrickColor.new(value)
	elseif currentType == "CFrame" and type(value) == "table" then
		return toCFrame(value)
	elseif currentType == "UDim2" and type(value) == "table" then
		-- v1.9: { scaleX, offsetX, scaleY, offsetY } (mismo formato que valorPlano)
		return UDim2.new(value.scaleX or 0, value.offsetX or 0, value.scaleY or 0, value.offsetY or 0)
	elseif currentType == "UDim" and type(value) == "table" then
		return UDim.new(value.scale or 0, value.offset or 0)
	elseif currentType == "Vector2" and type(value) == "table" then
		return Vector2.new(value[1] or value.x or 0, value[2] or value.y or 0)
	elseif currentType == "NumberRange" and type(value) == "table" then
		return NumberRange.new(value[1] or 0, value[2] or value[1] or 0)
	elseif currentType == "EnumItem" and type(value) == "string" then
		local enumType = current.EnumType
		local okEnum, enumItem = pcall(function()
			return enumType[value]
		end)
		if not okEnum then
			fail("OP_FAILED", ("enum inválido '%s' para %s"):format(value, property))
		end
		return enumItem
	end
	return value
end

local function applyProperties(instance, properties)
	for property, value in pairs(properties) do
		local decoded = decodeValue(instance, property, value)
		local ok = pcall(function()
			instance[property] = decoded
		end)
		if not ok then
			fail("PROPERTY_NOT_WRITABLE", property)
		end
	end
end

local function mustResolve(path)
	local instance, code = Resolver.Resolve(path)
	if not instance then
		fail(code or "PATH_NOT_FOUND", path)
	end
	return instance
end

local function safeIsA(instance, className)
	local ok, result = pcall(function()
		return instance:IsA(className)
	end)
	return ok and result
end

-- ---------- lectura ----------

local function buildTree(instance, depth, maxDepth, classFilter)
	local node = { name = instance.Name, class = instance.ClassName }
	if depth < maxDepth then
		for _, child in ipairs(instance:GetChildren()) do
			if not classFilter or table.find(classFilter, child.ClassName) then
				node.children = node.children or {}
				table.insert(node.children, buildTree(child, depth + 1, maxDepth, classFilter))
			end
		end
	end
	return node
end

function Ops.inspect_tree(op)
	local root = mustResolve(op.path)
	return nil, nil, buildTree(root, 1, op.max_depth, op.class_filter)
end

function Ops.inspect_instance(op)
	local instance = mustResolve(op.path)
	local data = {
		name = instance.Name,
		class = instance.ClassName,
		path = Resolver.PathOf(instance),
	}
	if op.include_attributes ~= false then
		data.attributes = instance:GetAttributes()
	end
	if op.include_children ~= false then
		data.children = {}
		for _, child in ipairs(instance:GetChildren()) do
			table.insert(data.children, { name = child.Name, class = child.ClassName })
		end
	end
	if instance:IsA("BasePart") then
		data.size = { instance.Size.X, instance.Size.Y, instance.Size.Z }
		data.position = { instance.Position.X, instance.Position.Y, instance.Position.Z }
		data.material = instance.Material.Name
	end
	return nil, nil, data
end

function Ops.find_instances(op)
	local root = mustResolve(op.path)
	local matches = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		local include = true
		if op.class and not safeIsA(descendant, op.class) then
			include = false
		end
		if include and op.name_pattern and not descendant.Name:find(op.name_pattern, 1, true) then
			include = false
		end
		if include and op.attribute then
			local value = descendant:GetAttribute(op.attribute.name)
			if op.attribute.value ~= nil and value ~= op.attribute.value then
				include = false
			elseif op.attribute.value == nil and value == nil then
				include = false
			end
		end
		if include then
			table.insert(matches, { name = descendant.Name, class = descendant.ClassName, path = Resolver.PathOf(descendant) })
		end
		if #matches >= 200 then
			break
		end
	end
	return nil, ("%d coincidencias"):format(#matches), matches
end

-- ---------- escritura ----------

function Ops.ensure_instance(op, cmdId)
	local existing = Resolver.Resolve(op.path)
	if existing then
		if existing.ClassName ~= op.class then
			fail("OP_FAILED", ("%s ya existe pero es %s, no %s"):format(op.path, existing.ClassName, op.class))
		end
		if op.properties then
			applyProperties(existing, op.properties)
			return "updated", "ya existía; propiedades verificadas"
		end
		return "skipped", "ya existía"
	end

	local parent, name = Resolver.ResolveParent(op.path)
	if not parent then
		if not op.create_parents then
			fail("PATH_NOT_FOUND", op.path)
		end
		-- crea la cadena de Folders hasta el padre
		local segments = Resolver.Split(op.path)
		local current = Resolver.GetRoot(segments[1])
		for i = 2, #segments - 1 do
			local next_ = current:FindFirstChild(segments[i])
			if not next_ then
				next_ = Instance.new("Folder")
				next_.Name = segments[i]
				next_.Parent = current
			end
			current = next_
		end
		parent = current
		name = segments[#segments]
	end

	local instance = Instance.new(op.class)
	instance.Name = name
	if op.properties then
		applyProperties(instance, op.properties)
	end
	instance.Parent = parent
	marcar(instance, cmdId)
	return "created"
end

function Ops.create_instance(op, cmdId)
	if Resolver.Resolve(op.path) then
		fail("PATH_EXISTS", op.path)
	end
	return Ops.ensure_instance(op, cmdId)
end

function Ops.set_property(op)
	local target = mustResolve(op.path)
	local decoded = decodeValue(target, op.property, op.value)
	local ok = pcall(function()
		target[op.property] = decoded
	end)
	if not ok then
		fail("PROPERTY_NOT_WRITABLE", op.property)
	end
	return "updated"
end

function Ops.set_attribute(op)
	local target = mustResolve(op.path)
	local valueType = type(op.value)
	if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
		fail("VALIDATION_FAILED", "atributos: solo string/number/boolean en v0.1")
	end
	target:SetAttribute(op.name, op.value)
	return "updated"
end

function Ops.set_transform(op)
	local target = mustResolve(op.path)
	if op.size then
		if not target:IsA("BasePart") then
			fail("OP_FAILED", "size solo aplica a BasePart")
		end
		target.Size = toVector3(op.size)
	end
	if op.position or op.rotation then
		local isModel = target:IsA("Model")
		if not isModel and not target:IsA("BasePart") then
			fail("OP_FAILED", "position/rotation solo aplica a BasePart o Model")
		end
		local current = isModel and target:GetPivot() or target.CFrame
		local pos = op.position and toVector3(op.position) or current.Position
		local newCf
		if op.rotation then
			newCf = CFrame.new(pos)
				* CFrame.Angles(math.rad(op.rotation[1]), math.rad(op.rotation[2]), math.rad(op.rotation[3]))
		else
			-- conserva la rotación actual
			newCf = CFrame.new(pos) * (current - current.Position)
		end
		if isModel then
			target:PivotTo(newCf)
		else
			target.CFrame = newCf
		end
	end
	return "updated"
end

function Ops.apply_material(op)
	local target = mustResolve(op.path)
	if not target:IsA("BasePart") then
		fail("OP_FAILED", "apply_material solo aplica a BasePart")
	end
	local okEnum, material = pcall(function()
		return Enum.Material[op.material]
	end)
	if not okEnum or not material then
		fail("OP_FAILED", "material desconocido: " .. tostring(op.material))
	end
	target.Material = material
	if op.color then
		target.Color = toColor3(op.color)
	end
	return "updated"
end

function Ops.move_instance(op)
	local target = mustResolve(op.path)
	local parent = mustResolve(op.new_parent)
	target.Parent = parent
	return "updated", "movido a " .. op.new_parent
end

function Ops.rename_instance(op)
	local target = mustResolve(op.path)
	target.Name = op.new_name
	return "updated"
end

function Ops.clone_instance(op, cmdId)
	local source = mustResolve(op.path)
	local parent = mustResolve(op.new_parent)
	local finalName = op.new_name or source.Name
	if parent:FindFirstChild(finalName) then
		return "skipped", "ya existe en el destino"
	end
	local clone = source:Clone()
	clone.Name = finalName
	clone.Parent = parent
	marcar(clone, cmdId)
	return "created"
end

function Ops.delete_instance(op)
	local target = mustResolve(op.path)
	-- borrado suave: papelera en ServerStorage (protocolo v0.1, sección 8)
	local trash = ServerStorage:FindFirstChild("_RBX_Trash")
	if not trash then
		trash = Instance.new("Folder")
		trash.Name = "_RBX_Trash"
		trash.Parent = ServerStorage
	end
	target.Name = ("%s__%d"):format(target.Name, os.time())
	target.Parent = trash
	return "updated", "movido a ServerStorage._RBX_Trash"
end

function Ops.set_script_source(op)
	local target = mustResolve(op.path)
	if not (target:IsA("Script") or target:IsA("ModuleScript") or target:IsA("LocalScript")) then
		fail("OP_FAILED", "set_script_source solo aplica a Script/ModuleScript/LocalScript")
	end
	target.Source = op.source
	local lines = 1 + select(2, op.source:gsub("\n", "\n"))
	return "updated", nil, { source_lines = lines }
end

function Ops.group_instances(op, cmdId)
	local parent = mustResolve(op.parent)
	local model = parent:FindFirstChild(op.model_name)
	local created = false
	if not model then
		model = Instance.new("Model")
		model.Name = op.model_name
		model.Parent = parent
		created = true
	elseif not model:IsA("Model") then
		fail("OP_FAILED", op.parent .. "." .. op.model_name .. " ya existe y no es un Model")
	end
	for _, path in ipairs(op.paths) do
		local instance = mustResolve(path)
		if instance.Parent ~= model then
			instance.Parent = model
		end
	end
	-- intenta centrar el pivot en el bounding box (best-effort)
	pcall(function()
		model.WorldPivot = model:GetBoundingBox()
	end)
	if created then
		marcar(model, cmdId)
	end
	return created and "created" or "updated"
end

-- ---------- construcción de alto nivel ----------

local function makeNativePart(class, name, parent, sizeVec3, position, rotation, material, color)
	local part = Instance.new(class)
	part.Name = name
	if part:IsA("BasePart") then
		part.Size = sizeVec3 or Vector3.new(4, 1, 4)
		part.CFrame = toCFrame({ position = position or { 0, 0, 0 }, rotation = rotation })
		if material then
			pcall(function()
				part.Material = Enum.Material[material]
			end)
		end
		if color then
			part.Color = toColor3(color)
		end
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
	end
	part.Parent = parent
	return part
end

local function singlePartStructure(defaultName)
	return function(params)
		local parent = mustResolve(params.parent or "Workspace")
		local model = Instance.new("Model")
		model.Name = params.name or defaultName
		local part = makeNativePart(
			"Part",
			defaultName,
			model,
			params.size and toVector3(params.size) or nil,
			params.position,
			params.rotation,
			params.material,
			params.color
		)
		model.PrimaryPart = part
		model.Parent = parent
		return model
	end
end

local STRUCTURES = {
	platform = singlePartStructure("Platform"),
	arena_floor = singlePartStructure("ArenaFloor"),
	wall = singlePartStructure("Wall"),
	gate = singlePartStructure("Gate"),
	road = singlePartStructure("Road"),
	room = singlePartStructure("Room"),
}

STRUCTURES.staircase = function(params)
	local parent = mustResolve(params.parent or "Workspace")
	local model = Instance.new("Model")
	model.Name = params.name or "Staircase"
	local steps = params.steps or 6
	local stepSize = params.step_size or { 6, 1, 2 }
	local origin = params.position or { 0, 0, 0 }
	for i = 1, steps do
		makeNativePart(
			"Part",
			("Step_%02d"):format(i),
			model,
			Vector3.new(stepSize[1], stepSize[2], stepSize[3]),
			{ origin[1], origin[2] + (i - 0.5) * stepSize[2], origin[3] - (i - 1) * stepSize[3] },
			nil,
			params.material,
			params.color
		)
	end
	model.Parent = parent
	return model
end

STRUCTURES.tower = function(params)
	local parent = mustResolve(params.parent or "Workspace")
	local model = Instance.new("Model")
	model.Name = params.name or "Tower"
	local height = params.height or 30
	local base = params.base_size or { 8, 8 }
	local origin = params.position or { 0, 0, 0 }
	makeNativePart(
		"Part",
		"Body",
		model,
		Vector3.new(base[1], height, base[2]),
		{ origin[1], origin[2] + height / 2, origin[3] },
		nil,
		params.material,
		params.color
	)
	makeNativePart(
		"Part",
		"Top",
		model,
		Vector3.new(base[1] + 2, 2, base[2] + 2),
		{ origin[1], origin[2] + height + 1, origin[3] },
		nil,
		params.material,
		params.color
	)
	model.Parent = parent
	return model
end

function Ops.build_structure(op, cmdId)
	local builder = STRUCTURES[op.structure]
	if not builder then
		fail("OP_FAILED", "estructura no implementada en el MVP: " .. tostring(op.structure))
	end
	local model = builder(op.params or {})
	marcar(model, cmdId)
	return "created", model:GetFullName()
end

function Ops.build_from_spec(op, cmdId)
	local created, skipped = 0, 0
	for index, partSpec in ipairs(op.parts) do
		if not Validator.IsClassAllowed(partSpec.class) then
			fail("CLASS_NOT_ALLOWED", tostring(partSpec.class))
		end
		local parentPath = partSpec.parent or "Workspace"
		local parent = mustResolve(parentPath)
		local finalName = partSpec.name or (partSpec.class .. "_" .. index)
		if parent:FindFirstChild(finalName) then
			skipped += 1
		else
			local instance = Instance.new(partSpec.class)
			instance.Name = finalName
			if partSpec.properties then
				applyProperties(instance, partSpec.properties)
			end
			if instance:IsA("BasePart") then
				if partSpec.size then
					instance.Size = toVector3(partSpec.size)
				end
				if partSpec.position or partSpec.rotation then
					instance.CFrame = toCFrame({ position = partSpec.position or { 0, 0, 0 }, rotation = partSpec.rotation })
				end
				instance.Anchored = partSpec.anchored ~= false
			end
			instance.Parent = parent
			marcar(instance, cmdId)
			created += 1
		end
	end
	return "created", ("%d creadas, %d omitidas"):format(created, skipped)
end

-- ---------- captura de planos y réplica (v1.9) ----------
-- Un "plano" es la serialización rejugable de un subárbol: clase, nombre,
-- propiedades clave, transformación, atributos, hijos, scripts y soldaduras
-- internas. capture_spec lo produce; replicate_instance lo reconstruye.

local MAX_REPLICAS = 50
local PLANO_MAX_DEPTH = 10

local function vec3(v)
	return { v.X, v.Y, v.Z }
end

local function col3(c)
	return {
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5),
	}
end

local function udim2(u)
	return { scaleX = u.X.Scale, offsetX = u.X.Offset, scaleY = u.Y.Scale, offsetY = u.Y.Offset }
end

local function udim(u)
	return { scale = u.Scale, offset = u.Offset }
end

-- Convierte valores de Roblox a JSON (atributos y propiedades capturadas).
local function valorPlano(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	elseif t == "Vector3" then
		return vec3(v)
	elseif t == "Vector2" then
		return { v.X, v.Y }
	elseif t == "Color3" then
		return col3(v)
	elseif t == "BrickColor" then
		return v.Name
	elseif t == "UDim2" then
		return udim2(v)
	elseif t == "UDim" then
		return udim(v)
	elseif t == "NumberRange" then
		return { v.Min, v.Max }
	elseif t == "EnumItem" then
		return v.Name
	end
	return tostring(v)
end

local function esScript(instance)
	return instance:IsA("Script") or instance:IsA("ModuleScript") or instance:IsA("LocalScript")
end

-- Propiedades capturadas por clase (solo tipos que decodeValue sabe reconstruir).
-- Se evalúan con IsA: una instancia puede coincidir con varias entradas.
local PROPS_PLANO = {
	{ isA = "BasePart", props = { "Transparency", "Reflectance", "Anchored", "CanCollide", "CastShadow" } },
	{ isA = "Part", props = { "Shape" } },
	{ isA = "SpawnLocation", props = { "Neutral", "AllowTeamChangeOnTouch", "Duration" } },
	{ isA = "Seat", props = { "Disabled" } },
	{ isA = "GuiObject", props = { "Visible", "Size", "Position", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel", "ZIndex", "LayoutOrder" } },
	{ isA = "TextLabel", props = { "Text", "TextSize", "Font", "TextColor3", "TextWrapped", "TextScaled", "RichText" } },
	{ isA = "TextButton", props = { "Text", "TextSize", "Font", "TextColor3", "TextWrapped", "TextScaled", "RichText" } },
	{ isA = "TextBox", props = { "Text", "TextSize", "Font", "TextColor3", "TextWrapped", "RichText", "PlaceholderText", "ClearTextOnFocus" } },
	{ isA = "ImageLabel", props = { "Image", "ImageColor3", "ScaleType" } },
	{ isA = "ImageButton", props = { "Image", "ImageColor3", "ScaleType" } },
	{ isA = "ScrollingFrame", props = { "CanvasSize", "ScrollBarThickness", "AutomaticCanvasSize" } },
	{ isA = "ScreenGui", props = { "Enabled", "DisplayOrder", "ResetOnSpawn", "IgnoreGuiInset" } },
	{ isA = "BillboardGui", props = { "Size", "StudsOffset", "AlwaysOnTop", "Enabled" } },
	{ isA = "SurfaceGui", props = { "CanvasSize", "AlwaysOnTop", "Enabled" } },
	{ isA = "PointLight", props = { "Color", "Brightness", "Range", "Enabled", "Shadows" } },
	{ isA = "SpotLight", props = { "Color", "Brightness", "Range", "Angle", "Face", "Enabled", "Shadows" } },
	{ isA = "SurfaceLight", props = { "Color", "Brightness", "Range", "Angle", "Face", "Enabled", "Shadows" } },
	{ isA = "Sound", props = { "SoundId", "Volume", "Looped", "PlaybackSpeed" } },
	{ isA = "Decal", props = { "Texture", "Transparency", "Color3" } },
	{ isA = "Texture", props = { "Texture", "Transparency", "Color3" } },
	{ isA = "ParticleEmitter", props = { "Enabled", "Rate", "Speed", "Lifetime", "SpreadAngle" } },
	{ isA = "Fire", props = { "Color", "SecondaryColor", "Size", "Heat", "Enabled" } },
	{ isA = "Smoke", props = { "Color", "Opacity", "RiseVelocity", "Enabled" } },
	{ isA = "Sparkles", props = { "SparkleColor", "Enabled" } },
	{ isA = "Trail", props = { "Enabled", "Brightness" } },
	{ isA = "Beam", props = { "Enabled", "Brightness", "Width0", "Width1" } },
	{ isA = "UICorner", props = { "CornerRadius" } },
	{ isA = "UIStroke", props = { "Color", "Thickness", "ApplyStrokeMode", "Transparency" } },
	{ isA = "UIGradient", props = { "Enabled", "Rotation" } },
	{ isA = "UIPadding", props = { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } },
	{ isA = "UIListLayout", props = { "Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder" } },
	{ isA = "UIGridLayout", props = { "CellSize", "CellPadding", "FillDirection", "SortOrder" } },
	{ isA = "UIAspectRatioConstraint", props = { "AspectRatio", "AspectType" } },
	{ isA = "ProximityPrompt", props = { "ActionText", "ObjectText", "HoldDuration", "MaxActivationDistance", "RequiresLineOfSight" } },
	{ isA = "ValueBase", props = { "Value" } },
}

-- Serializa el subárbol en pre-orden. state: { counter, nidOf, joints }.
-- nid: id de recorrido que permite reconstruir las soldaduras internas.
local function capturarNodo(instance, depth, maxDepth, includeScripts, state)
	state.counter += 1
	local nid = state.counter
	state.nidOf[instance] = nid

	local node = {
		class = instance.ClassName,
		name = instance.Name,
		nid = nid,
	}

	local attrs = {}
	for key, value in pairs(instance:GetAttributes()) do
		if key ~= "_RBX_Bridge" then -- la etiqueta de autoría se pone nueva al replicar
			attrs[key] = valorPlano(value)
		end
	end
	if next(attrs) ~= nil then
		node.attributes = attrs
	end

	if instance:IsA("BasePart") then
		node.size = vec3(instance.Size)
		local rx, ry, rz = instance.CFrame:ToEulerAnglesXYZ()
		node.position = vec3(instance.CFrame.Position)
		node.rotation = { math.deg(rx), math.deg(ry), math.deg(rz) }
		node.props = { Color = col3(instance.Color), Material = instance.Material.Name }
		if instance:IsA("MeshPart") then
			node.props.MeshId = instance.MeshId -- se re-aplica al crear (AssetService)
		end
	end
	if instance:IsA("Model") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok then
			local rx, ry, rz = pivot:ToEulerAnglesXYZ()
			node.pivot = {
				position = vec3(pivot.Position),
				rotation = { math.deg(rx), math.deg(ry), math.deg(rz) },
			}
		end
		if instance.PrimaryPart then
			node.primary_part = instance.PrimaryPart.Name
		end
	end

	for _, entry in ipairs(PROPS_PLANO) do
		if safeIsA(instance, entry.isA) then
			for _, prop in ipairs(entry.props) do
				local ok, value = pcall(function()
					return instance[prop]
				end)
				if ok and value ~= nil then
					node.props = node.props or {}
					node.props[prop] = valorPlano(value)
				end
			end
		end
	end

	if esScript(instance) and includeScripts then
		node.source = instance.Source
	end

	-- soldaduras internas: se resuelven a nid al final de la captura
	if instance:IsA("JointInstance") or instance:IsA("WeldConstraint") then
		local ok0, p0 = pcall(function()
			return instance.Part0
		end)
		local ok1, p1 = pcall(function()
			return instance.Part1
		end)
		if ok0 and p0 and ok1 and p1 then
			table.insert(state.joints, { node = node, p0 = p0, p1 = p1 })
		end
	end

	if depth < maxDepth then
		for _, child in ipairs(instance:GetChildren()) do
			if not esScript(child) or includeScripts then
				node.children = node.children or {}
				table.insert(node.children, capturarNodo(child, depth + 1, maxDepth, includeScripts, state))
			end
		end
	end
	return node
end

-- API pública: plano rejugable de una instancia. Lo usa capture_spec y también
-- el botón 🧬 Replicar del panel (init.server.lua).
function Ops.CaptureBlueprint(instance, maxDepth, includeScripts)
	local state = { counter = 0, nidOf = {}, joints = {} }
	local root = capturarNodo(instance, 1, maxDepth or PLANO_MAX_DEPTH, includeScripts ~= false, state)
	for _, joint in ipairs(state.joints) do
		local n0 = state.nidOf[joint.p0]
		local n1 = state.nidOf[joint.p1]
		if n0 and n1 then -- solo soldaduras internas al subárbol
			joint.node.joint = { part0 = n0, part1 = n1 }
		end
	end
	return root
end

function Ops.capture_spec(op)
	local instance = mustResolve(op.path)
	local plano = Ops.CaptureBlueprint(instance, op.max_depth, op.include_scripts)
	return nil, "plano capturado", plano
end

-- Aplica propiedades sin tumbar la réplica: las que fallen se cuentan.
local function applyPropsSoft(instance, props, state)
	for property, value in pairs(props) do
		-- MeshId solo se aplica al crear la instancia (AssetService); reasignarla falla
		if property ~= "MeshId" then
			local okDecode, decoded = pcall(decodeValue, instance, property, value)
			local ok = okDecode and pcall(function()
				instance[property] = decoded
			end)
			if not ok then
				state.warnings += 1
			end
		end
	end
end

local function construirNodo(node, parent, state, nameOverride)
	if type(node.class) ~= "string" then
		state.warnings += 1
		return nil
	end
	if not Validator.IsClassAllowed(node.class) then
		-- la lista blanca sigue mandando: la clase no permitida se omite y se reporta
		state.skippedClasses[node.class] = true
		state.warnings += 1
		return nil
	end
	local instance
	if node.class == "MeshPart" and type(node.props) == "table" and type(node.props.MeshId) == "string" and node.props.MeshId ~= "" then
		-- Instance.new("MeshPart") no conserva la malla; AssetService sí (v1.9)
		local okMesh, meshPart = pcall(function()
			return AssetService:CreateMeshPartAsync(node.props.MeshId)
		end)
		if okMesh then
			instance = meshPart
		end
	end
	if not instance then
		local okNew, created = pcall(Instance.new, node.class)
		if not okNew then
			state.warnings += 1
			return nil
		end
		instance = created
	end
	-- v1.9.2: contar lo agregado para el reporte (nodos y scripts)
	state.nodes += 1
	if esScript(instance) then
		table.insert(state.scripts, node.name or node.class)
	end
	instance.Name = nameOverride or node.name or node.class
	if node.nid then
		state.instOf[node.nid] = instance
	end
	if node.props then
		applyPropsSoft(instance, node.props, state)
	end
	if node.attributes then
		for key, value in pairs(node.attributes) do
			pcall(function()
				instance:SetAttribute(key, value)
			end)
		end
	end
	if instance:IsA("BasePart") then
		if node.size then
			pcall(function()
				instance.Size = toVector3(node.size)
			end)
		end
		if node.position or node.rotation then
			local position = node.position and toVector3(node.position) or Vector3.new(0, 0, 0)
			local rotation = node.rotation or { 0, 0, 0 }
			pcall(function()
				instance.CFrame = CFrame.new(position)
					* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
			end)
		end
	end
	if node.source ~= nil and esScript(instance) then
		pcall(function()
			instance.Source = node.source
		end)
	end
	if node.joint then
		table.insert(state.joints, { instance = instance, part0 = node.joint.part0, part1 = node.joint.part1 })
	end
	instance.Parent = parent
	if node.children then
		for _, childNode in ipairs(node.children) do
			construirNodo(childNode, instance, state)
		end
	end
	return instance
end

-- Reconstruye un plano (spec) o copia un objeto en vivo (path), 1-50 veces.
-- Idempotente: si el nombre final ya existe en el destino, esa copia se omite.
function Ops.replicate_instance(op, cmdId)
	local spec = op.spec
	if type(spec) ~= "table" then
		if type(op.path) ~= "string" then
			fail("VALIDATION_FAILED", "replicate_instance requiere 'path' (objeto en vivo) o 'spec' (plano)")
		end
		spec = Ops.CaptureBlueprint(mustResolve(op.path), PLANO_MAX_DEPTH, true)
	end
	if type(spec.class) ~= "string" then
		fail("VALIDATION_FAILED", "spec sin 'class'")
	end
	local parent = mustResolve(op.new_parent)
	local count = op.count or 1
	if type(count) ~= "number" or count < 1 or count > MAX_REPLICAS or count % 1 ~= 0 then
		fail("VALIDATION_FAILED", ("count debe ser entero entre 1 y %d"):format(MAX_REPLICAS))
	end
	local offset = op.offset and toVector3(op.offset) or Vector3.new(0, 0, 0)
	local step = op.step and toVector3(op.step) or nil

	local created, skipped = 0, 0
	local warnings = 0
	local skippedClasses = {}
	local copias = {} -- v1.9.2: qué se agregó en cada copia
	for i = 1, count do
		local baseName = op.new_name or spec.name or spec.class
		local finalName = count == 1 and baseName or (baseName .. "_" .. i)
		if parent:FindFirstChild(finalName) then
			skipped += 1
		else
			local shift = offset
			if step then
				shift = offset + step * (i - 1)
			end
			local state = { instOf = {}, joints = {}, warnings = 0, skippedClasses = {}, nodes = 0, scripts = {} }
			local root = construirNodo(spec, parent, state, finalName)
			if root then
				-- PrimaryPart del Model raíz (lo usa PivotTo como referencia)
				if root:IsA("Model") and spec.primary_part then
					local pp = root:FindFirstChild(spec.primary_part, true)
					if pp and pp:IsA("BasePart") then
						root.PrimaryPart = pp
					end
				end
				-- soldaduras internas: segunda pasada, ya existen todas las partes
				for _, joint in ipairs(state.joints) do
					local p0 = state.instOf[joint.part0]
					local p1 = state.instOf[joint.part1]
					if p0 and p1 then
						pcall(function()
							joint.instance.Part0 = p0
							joint.instance.Part1 = p1
						end)
					end
				end
				-- posición final del subárbol: transformación del plano + desplazamiento
				if root:IsA("PVInstance") then
					pcall(function()
						if root:IsA("Model") and spec.pivot then
							local pos = toVector3(spec.pivot.position) + shift
							local rot = spec.pivot.rotation or { 0, 0, 0 }
							root:PivotTo(
								CFrame.new(pos) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
							)
						elseif shift.Magnitude > 0 then
							root:PivotTo(root:GetPivot() + shift)
						end
					end)
				end
				marcar(root, cmdId)
				created += 1
				table.insert(copias, {
					nombre = finalName,
					path = root:GetFullName(),
					nodos = state.nodes,
					scripts = state.scripts,
				})
			else
				skipped += 1
			end
			warnings += state.warnings
			for class in pairs(state.skippedClasses) do
				skippedClasses[class] = true
			end
		end
	end

	local detail = ("%d creada(s), %d omitida(s)"):format(created, skipped)
	if warnings > 0 then
		detail ..= (", %d propiedad(es) no aplicada(s)"):format(warnings)
	end
	local lista = {}
	for class in pairs(skippedClasses) do
		table.insert(lista, class)
	end
	if #lista > 0 then
		table.sort(lista)
		detail ..= "; clases fuera de la lista blanca omitidas: " .. table.concat(lista, ", ")
	end
	-- v1.9.2: el resultado detalla qué objeto o script se agregó por copia
	if #copias > 0 then
		local data = { copias = copias, advertencias = warnings }
		if #lista > 0 then
			data.clases_omitidas = lista
		end
		return created > 0 and "created" or "skipped", detail, data
	end
	return created > 0 and "created" or "skipped", detail
end

return Ops

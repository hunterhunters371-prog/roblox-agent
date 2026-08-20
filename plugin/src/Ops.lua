-- Ejecutores de operaciones del protocolo RBX Bridge v0.1.
-- Cada handler recibe la operación y devuelve:
--   (action: "created" | "updated" | "skipped" | nil, detail?, data?)
-- En error lanza error({ code = ..., message = ... }) (o un string plano).

local ServerStorage = game:GetService("ServerStorage")

local Config = require(script.Parent.Config)
local Resolver = require(script.Parent.PathResolver)
local Validator = require(script.Parent.Validator)

local Ops = {}

-- ---------- utilidades ----------

local function fail(code, message)
	error({ code = code, message = message }, 0)
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

function Ops.ensure_instance(op)
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
	return "created"
end

function Ops.create_instance(op)
	if Resolver.Resolve(op.path) then
		fail("PATH_EXISTS", op.path)
	end
	return Ops.ensure_instance(op)
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

function Ops.clone_instance(op)
	local source = mustResolve(op.path)
	local parent = mustResolve(op.new_parent)
	local finalName = op.new_name or source.Name
	if parent:FindFirstChild(finalName) then
		return "skipped", "ya existe en el destino"
	end
	local clone = source:Clone()
	clone.Name = finalName
	clone.Parent = parent
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

function Ops.group_instances(op)
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

function Ops.build_structure(op)
	local builder = STRUCTURES[op.structure]
	if not builder then
		fail("OP_FAILED", "estructura no implementada en el MVP: " .. tostring(op.structure))
	end
	local model = builder(op.params or {})
	return "created", model:GetFullName()
end

function Ops.build_from_spec(op)
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
			created += 1
		end
	end
	return "created", ("%d creadas, %d omitidas"):format(created, skipped)
end

return Ops

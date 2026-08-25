-- Validación del lado del plugin: envelope + listas blancas.
-- Espejo de schemas/allowed_roots.json y schemas/allowed_classes.json (v0.1).
-- v2.0: insert_asset (Toolbox vía LoadAsset); allow_scripts=true fuerza aprobación.
-- v3.0: lint_scripts y mirror_place (solo lectura, sin campos obligatorios).

local Config = require(script.Parent.Config)

local ROOTS = {
	Workspace = true,
	ReplicatedStorage = true,
	ServerStorage = true,
	ServerScriptService = true,
	StarterGui = true,
	StarterPack = true,
	StarterPlayer = true,
	Lighting = true,
	SoundService = true,
	Teams = true,
}

local CLASSES = {
	Part = true, WedgePart = true, CornerWedgePart = true, MeshPart = true, UnionOperation = true,
	Model = true, Folder = true, Configuration = true,
	Script = true, ModuleScript = true, LocalScript = true,
	ScreenGui = true, BillboardGui = true, SurfaceGui = true,
	Frame = true, ScrollingFrame = true, TextLabel = true, TextButton = true, TextBox = true,
	ImageLabel = true, ImageButton = true, ViewportFrame = true,
	UIListLayout = true, UIGridLayout = true, UIPageLayout = true, UIPadding = true,
	UICorner = true, UIStroke = true, UIGradient = true, UIAspectRatioConstraint = true,
	SpawnLocation = true, Seat = true,
	Attachment = true, Weld = true, WeldConstraint = true, Motor6D = true,
	PointLight = true, SpotLight = true, SurfaceLight = true,
	ParticleEmitter = true, Trail = true, Beam = true, Fire = true, Smoke = true, Sparkles = true,
	Sound = true, SoundGroup = true, Decal = true, Texture = true, SurfaceAppearance = true,
	Highlight = true, SelectionBox = true, SelectionSphere = true,
	BoolValue = true, IntValue = true, NumberValue = true, StringValue = true,
	Color3Value = true, BrickColorValue = true, ObjectValue = true, Vector3Value = true, CFrameValue = true,
	RemoteEvent = true, RemoteFunction = true, BindableEvent = true, BindableFunction = true,
	ColorCorrectionEffect = true, BloomEffect = true, BlurEffect = true,
	SunRaysEffect = true, DepthOfFieldEffect = true,
	Atmosphere = true, Sky = true, Clouds = true,
}

local REQUIRED = {
	inspect_tree = { "path", "max_depth" },
	inspect_instance = { "path" },
	find_instances = { "path" },
	ensure_instance = { "path", "class" },
	create_instance = { "path", "class" },
	set_property = { "path", "property", "value" },
	set_attribute = { "path", "name", "value" },
	set_transform = { "path" },
	apply_material = { "path", "material" },
	move_instance = { "path", "new_parent" },
	rename_instance = { "path", "new_name" },
	clone_instance = { "path", "new_parent" },
	delete_instance = { "path" },
	set_script_source = { "path", "source" },
	group_instances = { "paths", "model_name", "parent" },
	build_structure = { "structure", "params" },
	build_from_spec = { "parts" },
	insert_asset = { "asset_id" }, -- v2.0: Toolbox/Creator Store (path opcional, default Workspace)
	lint_scripts = {}, -- v3.0: todo opcional (path, max_findings)
	mirror_place = {}, -- v3.0: todo opcional (path, max_depth, max_instances)
}

local PATH_FIELDS = { "path", "new_parent", "parent" }

local Validator = {}

local function fail(code, message)
	return nil, code, message
end

local function checkPath(value)
	if type(value) ~= "string" then
		return nil, "VALIDATION_FAILED", "path debe ser string, recibido: " .. type(value)
	end
	local root = value:match("^([^.]+)")
	if not ROOTS[root] then
		return nil, "ROOT_NOT_ALLOWED", value
	end
	return true
end

-- Devuelve true, o nil + código + mensaje (códigos de la sección 7 del protocolo).
function Validator.ValidateCommand(cmd)
	if type(cmd) ~= "table" then
		return fail("VALIDATION_FAILED", "el comando no es un objeto JSON")
	end
	if cmd.version ~= Config.VERSION then
		return fail("UNSUPPORTED_VERSION", "version=" .. tostring(cmd.version) .. ", soportada: " .. Config.VERSION)
	end
	if type(cmd.id) ~= "string" or not cmd.id:match("^cmd_%d%d%d%d%d%d$") then
		return fail("VALIDATION_FAILED", "id con formato inválido (esperado cmd_NNNNNN)")
	end
	if type(cmd.title) ~= "string" or cmd.title == "" then
		return fail("VALIDATION_FAILED", "title vacío")
	end
	if type(cmd.operations) ~= "table" or #cmd.operations == 0 then
		return fail("VALIDATION_FAILED", "operations vacío")
	end
	if #cmd.operations > Config.MAX_OPS then
		return fail("OP_LIMIT_EXCEEDED", ("%d operaciones (máx. %d)"):format(#cmd.operations, Config.MAX_OPS))
	end

	for index, op in ipairs(cmd.operations) do
		if type(op) ~= "table" or type(op.op) ~= "string" or REQUIRED[op.op] == nil then
			return fail("VALIDATION_FAILED", ("operación #%d con op desconocido"):format(index))
		end
		if type(op.id) ~= "string" or not op.id:match("^op_%d+$") then
			return fail("VALIDATION_FAILED", ("operación #%d sin id op_NN"):format(index))
		end
		for _, field in ipairs(REQUIRED[op.op]) do
			if op[field] == nil then
				return fail("VALIDATION_FAILED", ("%s (%s) requiere '%s'"):format(op.op, op.id, field))
			end
		end
		for _, field in ipairs(PATH_FIELDS) do
			if op[field] ~= nil then
				local ok, code, message = checkPath(op[field])
				if not ok then
					return nil, code, ("%s (%s): %s"):format(op.op, op.id, message)
				end
			end
		end
		if op.op == "group_instances" then
			if type(op.paths) ~= "table" or #op.paths == 0 then
				return fail("VALIDATION_FAILED", "group_instances requiere paths no vacío")
			end
			for _, p in ipairs(op.paths) do
				local ok, code, message = checkPath(p)
				if not ok then
					return nil, code, message
				end
			end
		end
		if op.op == "insert_asset" then
			if type(op.asset_id) ~= "number" or op.asset_id <= 0 then
				return fail("VALIDATION_FAILED", ("insert_asset (%s): asset_id debe ser número positivo"):format(op.id))
			end
		end
		if op.op == "lint_scripts" or op.op == "mirror_place" then
			if op.max_depth ~= nil and type(op.max_depth) ~= "number" then
				return fail("VALIDATION_FAILED", ("%s (%s): max_depth debe ser número"):format(op.op, op.id))
			end
			if op.max_findings ~= nil and type(op.max_findings) ~= "number" then
				return fail("VALIDATION_FAILED", ("%s (%s): max_findings debe ser número"):format(op.op, op.id))
			end
			if op.max_instances ~= nil and type(op.max_instances) ~= "number" then
				return fail("VALIDATION_FAILED", ("%s (%s): max_instances debe ser número"):format(op.op, op.id))
			end
		end
		if (op.op == "ensure_instance" or op.op == "create_instance") and not CLASSES[op.class] then
			return fail("CLASS_NOT_ALLOWED", tostring(op.class))
		end
	end

	return true
end

-- delete_instance SIEMPRE exige aprobación humana (protocolo v0.1, sección 8).
-- insert_asset con allow_scripts=true también (v2.0: scripts de terceros solo con
-- aprobación; por defecto el plugin los elimina al insertar).
function Validator.NeedsApproval(cmd)
	local options = cmd.options or {}
	if options.require_approval ~= false then
		return true
	end
	for _, op in ipairs(cmd.operations) do
		if op.op == "delete_instance" then
			return true
		end
		if op.op == "insert_asset" and op.allow_scripts == true then
			return true
		end
	end
	return false
end

-- Lo usa Ops.build_from_spec para validar la clase de cada pieza.
function Validator.IsClassAllowed(class)
	return CLASSES[class] == true
end

return Validator

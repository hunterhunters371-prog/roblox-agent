-- Operaciones extra del protocolo (v2.0 / v3.0 / v3.1 / v3.2). Ops.lua llego al limite sano de
-- tamano de este repo (~16 KB por archivo escrito), asi que las ops nuevas viven aqui y
-- Executor las fusiona en el mismo registro al cargar. Mismas convenciones que Ops.lua:
-- handler(op, cmdId) -> (action, detail?, data?) y error({ code, message }) al fallar.
-- v3.0: lint_scripts y mirror_place (solo lectura).
-- v3.1: set_reference y weld_parts. Hasta ahora el bridge NO podia cablear referencias
-- entre instancias (Part0/Part1, Attachment0/Attachment1, PrimaryPart, SoundGroup...):
-- set_property lee el valor actual para decidir el tipo y, si es nil, asignaba el string
-- crudo -> PROPERTY_NOT_WRITABLE. Sin esto es imposible montar un vehiculo con
-- constraints como un modelo de verdad.
-- v3.2: export_model. mirror_place solo da nombre/clase/posicion/tamano, que no basta
-- para VER un modelo: falta rotacion, color, material, mesh y, sobre todo, que esta
-- soldado con que. export_model vuelca todo eso para poder reconstruirlo en 3D.

local InsertService = game:GetService("InsertService")

local Resolver = require(script.Parent.PathResolver)
local Lint = require(script.Parent.Lint)
local AutoSense = require(script.Parent.AutoSense)

local OpsExtra = {}

local function fail(code, message)
	error({ code = code, message = message }, 0)
end

local function mustResolve(path)
	local instance, code = Resolver.Resolve(path)
	if not instance then
		fail(code or "PATH_NOT_FOUND", path)
	end
	return instance
end

-- Marca de autoria del bridge (best-effort; algunos objetos no aceptan atributos).
local function marcar(instance, cmdId)
	pcall(function()
		instance:SetAttribute("_RBX_Bridge", cmdId or "agent-bridge")
	end)
end

-- Elimina TODOS los scripts de lo insertado. La Toolbox es el vector clasico de
-- malware en Roblox (modelos con scripts ocultos); por defecto no entra ni uno.
-- Solo se conservan si el comando trae allow_scripts = true (y eso fuerza aprobacion).
local function quitarScripts(root)
	local quitados = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			pcall(function()
				d:Destroy()
			end)
			quitados += 1
		end
	end
	return quitados
end

-- insert_asset { asset_id, path?, position?, name?, allow_scripts? }
-- Inserta un asset de la Toolbox/Creator Store con InsertService:LoadAsset bajo `path`
-- (default Workspace). El asset debe ser gratuito/publico o propiedad de esta cuenta.
-- La busqueda por nombre NO es posible desde un plugin (HttpService no puede llamar a
-- roblox.com); el agente trabaja con asset_id exactos.
function OpsExtra.insert_asset(op, cmdId)
	local assetId = op.asset_id
	if type(assetId) ~= "number" or assetId <= 0 or assetId % 1 ~= 0 then
		fail("VALIDATION_FAILED", "asset_id debe ser un numero entero positivo")
	end
	local parent = mustResolve(op.path or "Workspace")

	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		fail(
			"OP_FAILED",
			("LoadAsset(%d) fallo: %s - asset privado, retirado o de pago?"):format(assetId, tostring(container))
		)
	end
	if not container then
		fail("OP_FAILED", ("LoadAsset(%d) devolvio nil"):format(assetId))
	end

	-- LoadAsset suele devolver un Model contenedor con el item dentro; si hay un
	-- unico hijo, trabajamos con ese hijo directamente.
	local item = container
	local hijos = container:GetChildren()
	if container:IsA("Model") and #hijos == 1 then
		item = hijos[1]
	end

	if type(op.name) == "string" and op.name ~= "" then
		item.Name = op.name
	end

	local quitados = 0
	if op.allow_scripts ~= true then
		quitados = quitarScripts(item)
	end

	if op.position then
		assert(type(op.position) == "table" and #op.position == 3, "position se esperaba [x, y, z]")
		local destino = CFrame.new(op.position[1], op.position[2], op.position[3])
		if item:IsA("Model") then
			item:PivotTo(destino)
		elseif item:IsA("BasePart") then
			item.CFrame = destino
		end
	end

	item.Parent = parent
	marcar(item, cmdId)
	if container ~= item then
		container:Destroy()
	end

	local detail = ("%s (%s) -> %s"):format(item.Name, item.ClassName, Resolver.PathOf(item))
	if quitados > 0 then
		detail ..= (" - %d script(s) eliminados por seguridad"):format(quitados)
	end
	return "created", detail
end

-- set_reference { path, property, target_path? } (v3.1)
-- Asigna una REFERENCIA a otra instancia: Part0/Part1 de un Weld, Attachment0/
-- Attachment1 de un constraint, PrimaryPart de un Model, SoundGroup de un Sound...
-- target_path ausente o null limpia la propiedad (nil).
-- Sin esta op no se puede ensamblar un vehiculo con constraints desde el bridge.
function OpsExtra.set_reference(op, _cmdId)
	if type(op.property) ~= "string" or op.property == "" then
		fail("VALIDATION_FAILED", "set_reference requiere 'property'")
	end
	local target = mustResolve(op.path)

	-- La propiedad debe existir en la clase destino (leerla no debe fallar).
	local okRead = pcall(function()
		return target[op.property]
	end)
	if not okRead then
		fail(
			"PROPERTY_NOT_WRITABLE",
			("la propiedad '%s' no existe en %s"):format(op.property, target.ClassName)
		)
	end

	local valor = nil
	local detalle
	if op.target_path ~= nil and op.target_path ~= "" then
		valor = mustResolve(op.target_path)
		detalle = ("%s.%s -> %s"):format(target.Name, op.property, valor.Name)
	else
		detalle = ("%s.%s -> nil (limpiada)"):format(target.Name, op.property)
	end

	local okWrite, err = pcall(function()
		target[op.property] = valor
	end)
	if not okWrite then
		fail(
			"PROPERTY_NOT_WRITABLE",
			("%s.%s no acepta %s: %s"):format(
				target.ClassName,
				op.property,
				valor and valor.ClassName or "nil",
				tostring(err)
			)
		)
	end
	return "updated", detalle
end

-- weld_parts { path_a, path_b, name? } (v3.1)
-- Atajo para soldar dos BaseParts con un WeldConstraint (Part0 = A, Part1 = B),
-- creado como hijo de A. Es idempotente: si ya existe un WeldConstraint entre esas
-- dos partes, no crea otro. Evita 3 ops (create + 2 set_reference) por soldadura.
function OpsExtra.weld_parts(op, cmdId)
	local a = mustResolve(op.path_a)
	local b = mustResolve(op.path_b)
	if not a:IsA("BasePart") or not b:IsA("BasePart") then
		fail("OP_FAILED", "weld_parts solo aplica entre dos BasePart")
	end
	for _, hijo in ipairs(a:GetChildren()) do
		if hijo:IsA("WeldConstraint") then
			local p0, p1 = hijo.Part0, hijo.Part1
			if (p0 == a and p1 == b) or (p0 == b and p1 == a) then
				return "skipped", "ya estaban soldadas"
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = op.name or "Weld"
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = a
	marcar(weld, cmdId)
	return "created", ("%s <-> %s"):format(a.Name, b.Name)
end

-- lint_scripts { path?, max_findings? } (v3.0, solo lectura)
-- Analiza estaticamente TODOS los scripts bajo `path` (o el place entero) con
-- Lint.lua: bloques sin cerrar, pares sin cerrar, globals no declarados y APIs
-- deprecadas. Los hallazgos viajan en `data` del result.json.
function OpsExtra.lint_scripts(op, _cmdId)
	local root = game
	if op.path then
		root = mustResolve(op.path)
	end
	local findings = Lint.Place(root)
	local maxFindings = op.max_findings or 200
	local errores, avisos, infos = 0, 0, 0
	for _, f in ipairs(findings) do
		if f.severity == Lint.SEVERITY.ERROR then
			errores += 1
		elseif f.severity == Lint.SEVERITY.WARN then
			avisos += 1
		else
			infos += 1
		end
	end
	local truncated = #findings > maxFindings
	if truncated then
		local recorte = {}
		for i = 1, maxFindings do
			recorte[i] = findings[i]
		end
		findings = recorte
	end
	return nil, ("lint en %s: %d error(es), %d aviso(s), %d info"):format(
		op.path or "todo el place",
		errores,
		avisos,
		infos
	), {
		errores = errores,
		avisos = avisos,
		infos = infos,
		total = errores + avisos + infos,
		truncated = truncated,
		findings = findings,
	}
end

-- mirror_place { path?, max_depth?, max_instances? } (v3.0, solo lectura)
-- Espejo compacto del estado actual del place: nombres, clases, posicion/tamano
-- de BaseParts, pivot de Models y numero de lineas de los scripts.
function OpsExtra.mirror_place(op, _cmdId)
	local raiz = op.path or "Workspace"
	local root = workspace
	if op.path then
		root = mustResolve(op.path)
	end
	local depth = math.clamp(op.max_depth or 4, 1, 10)
	local maxNodes = math.clamp(op.max_instances or 4000, 100, 10000)
	local presupuesto = { n = maxNodes }
	local tree = AutoSense.MirrorTree(root, depth, presupuesto)
	local usados = maxNodes - presupuesto.n
	return nil, ("espejo de %s: %d nodo(s), profundidad %d%s"):format(
		raiz,
		usados,
		depth,
		presupuesto.n <= 0 and " (truncado por max_instances)" or ""
	), {
		root = raiz,
		depth = depth,
		nodes = usados,
		truncated = presupuesto.n <= 0,
		tree = tree,
	}
end

local function redondear(n, escala)
	local e = escala or 1000
	return math.floor(n * e + 0.5) / e
end

local function canal(v)
	return math.floor(v * 255 + 0.5)
end

-- Propiedades de referencia que definen COMO esta ensamblado un modelo. Sin esto
-- un volcado de piezas no dice nada: no se sabe que esta soldado con que.
local REFS = { "Part0", "Part1", "Attachment0", "Attachment1" }

local function nodo3d(inst, profundidad, presupuesto, opciones)
	if presupuesto.n <= 0 then
		return nil
	end
	presupuesto.n -= 1
	local nodo = { n = inst.Name, c = inst.ClassName }

	if inst:IsA("BasePart") then
		local cf = inst.CFrame
		local rx, ry, rz = cf:ToOrientation()
		nodo.pos = { redondear(cf.X), redondear(cf.Y), redondear(cf.Z) }
		nodo.size = { redondear(inst.Size.X), redondear(inst.Size.Y), redondear(inst.Size.Z) }
		-- rotacion en GRADOS, mucho mas legible que una matriz de 12 numeros
		local rot = { redondear(math.deg(rx), 100), redondear(math.deg(ry), 100), redondear(math.deg(rz), 100) }
		if rot[1] ~= 0 or rot[2] ~= 0 or rot[3] ~= 0 then
			nodo.rot = rot
		end
		nodo.color = { canal(inst.Color.R), canal(inst.Color.G), canal(inst.Color.B) }
		nodo.mat = inst.Material.Name
		if inst.Transparency > 0 then
			nodo.transp = redondear(inst.Transparency, 100)
		end
		if not inst.Anchored then
			nodo.anchored = false
		end
		if not inst.CanCollide then
			nodo.canCollide = false
		end
		if inst.Massless then
			nodo.massless = true
		end
		pcall(function()
			if inst.MeshId and inst.MeshId ~= "" then
				nodo.mesh = inst.MeshId
			end
		end)
		pcall(function()
			nodo.shape = inst.Shape.Name
		end)
	elseif inst:IsA("Model") then
		pcall(function()
			local cf = inst:GetPivot()
			nodo.pos = { redondear(cf.X), redondear(cf.Y), redondear(cf.Z) }
		end)
		pcall(function()
			local ext = inst:GetExtentsSize()
			nodo.extents = { redondear(ext.X), redondear(ext.Y), redondear(ext.Z) }
		end)
	elseif inst:IsA("LuaSourceContainer") then
		nodo.lines = 1 + select(2, inst.Source:gsub("\n", "\n"))
		if opciones.include_source then
			nodo.src = inst.Source
		end
	elseif inst:IsA("Attachment") then
		local cf = inst.CFrame
		nodo.pos = { redondear(cf.X), redondear(cf.Y), redondear(cf.Z) }
	end

	-- Referencias: aqui esta el esqueleto del ensamblaje.
	for _, prop in ipairs(REFS) do
		pcall(function()
			local v = inst[prop]
			if typeof(v) == "Instance" then
				nodo[prop] = v.Name
			end
		end)
	end

	if opciones.include_attributes then
		local attrs, hay = {}, false
		pcall(function()
			for k, v in pairs(inst:GetAttributes()) do
				local t = typeof(v)
				if t == "number" or t == "string" or t == "boolean" then
					attrs[k] = v
				else
					attrs[k] = tostring(v)
				end
				hay = true
			end
		end)
		if hay then
			nodo.attrs = attrs
		end
	end

	if profundidad > 1 then
		local hijos = inst:GetChildren()
		if #hijos > 0 then
			nodo.children = {}
			for _, hijo in ipairs(hijos) do
				local sub = nodo3d(hijo, profundidad - 1, presupuesto, opciones)
				if sub then
					table.insert(nodo.children, sub)
				else
					table.insert(nodo.children, { n = "...", c = "presupuesto agotado" })
					break
				end
			end
		end
	end
	return nodo
end

-- export_model { path, max_depth?, max_nodes?, include_attributes?, include_source? }
-- (v3.2, solo lectura) Volcado COMPLETO de un modelo para poder verlo y
-- reconstruirlo en 3D: por cada pieza posicion, rotacion en grados, tamano, color
-- RGB, material, transparencia, forma, mesh y banderas de fisica (anchored,
-- canCollide, massless); de cada constraint/soldadura, con que piezas conecta; y
-- los atributos de cada nodo. Es lo que mirror_place no da y sin lo cual es
-- imposible auditar por que un vehiculo se comporta mal.
-- Los datos viajan en `data` del result.json.
function OpsExtra.export_model(op, _cmdId)
	local root = mustResolve(op.path)
	local depth = math.clamp(op.max_depth or 12, 1, 24)
	local maxNodes = math.clamp(op.max_nodes or 600, 10, 4000)
	local presupuesto = { n = maxNodes }
	local opciones = {
		include_attributes = op.include_attributes ~= false,
		include_source = op.include_source == true,
	}
	local arbol = nodo3d(root, depth, presupuesto, opciones)
	local usados = maxNodes - presupuesto.n
	local truncado = presupuesto.n <= 0
	return nil, ("modelo %s exportado: %d nodo(s)%s"):format(
		op.path,
		usados,
		truncado and " (TRUNCADO, sube max_nodes)" or ""
	), {
		tipo = "modelo-3d",
		formato = "rbx-model-json/1",
		path = op.path,
		nodes = usados,
		truncated = truncado,
		unidades = "studs; rot en grados XYZ; color RGB 0-255",
		model = arbol,
	}
end

return OpsExtra

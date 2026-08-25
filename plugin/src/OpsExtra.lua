-- Operaciones extra del protocolo (v2.0/v3.0). Ops.lua llegó al límite sano de tamaño de
-- este repo (~16 KB por archivo escrito), así que las ops nuevas viven aquí y
-- Executor las fusiona en el mismo registro al cargar. Mismas convenciones que Ops.lua:
-- handler(op, cmdId) → (action, detail?, data?) y error({ code, message }) al fallar.
-- v3.0: lint_scripts y mirror_place (solo lectura; sus resultados viajan en el
-- result.json del comando y el agente los convierte en issues / estado del place).

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

-- Marca de autoría del bridge (best-effort; algunos objetos no aceptan atributos).
local function marcar(instance, cmdId)
	pcall(function()
		instance:SetAttribute("_RBX_Bridge", cmdId or "agent-bridge")
	end)
end

-- Elimina TODOS los scripts de lo insertado. La Toolbox es el vector clásico de
-- malware en Roblox (modelos con scripts ocultos); por defecto no entra ni uno.
-- Solo se conservan si el comando trae allow_scripts = true (y eso fuerza aprobación).
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
-- (default Workspace). El asset debe ser gratuito/público o propiedad de esta cuenta;
-- si no, LoadAsset falla y la op reporta OP_FAILED.
-- Nota: la búsqueda por nombre NO es posible desde un plugin (HttpService no puede
-- llamar a roblox.com); el agente trabaja con asset_id exactos.
function OpsExtra.insert_asset(op, cmdId)
	local assetId = op.asset_id
	if type(assetId) ~= "number" or assetId <= 0 or assetId % 1 ~= 0 then
		fail("VALIDATION_FAILED", "asset_id debe ser un número entero positivo")
	end
	local parent = mustResolve(op.path or "Workspace")

	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		fail(
			"OP_FAILED",
			("LoadAsset(%d) falló: %s — ¿asset privado, retirado o de pago?"):format(assetId, tostring(container))
		)
	end
	if not container then
		fail("OP_FAILED", ("LoadAsset(%d) devolvió nil"):format(assetId))
	end

	-- LoadAsset suele devolver un Model contenedor con el item dentro; si hay un
	-- único hijo, trabajamos con ese hijo directamente.
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

	local detail = ("%s (%s) → %s"):format(item.Name, item.ClassName, Resolver.PathOf(item))
	if quitados > 0 then
		detail ..= (" · %d script(s) eliminados por seguridad"):format(quitados)
	end
	return "created", detail
end

-- lint_scripts { path?, max_findings? } (v3.0, solo lectura)
-- Analiza estáticamente TODOS los scripts bajo `path` (o el place entero) con
-- Lint.lua: bloques sin cerrar, pares sin cerrar, globals no declarados y APIs
-- deprecadas. Devuelve los hallazgos en `data` (viajan en el result.json del
-- comando; el agente los convierte en issues con el arreglo sugerido).
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
-- Espejo compacto del estado actual del place: nombres, clases, posición/tamaño
-- de BaseParts, pivot de Models y nº de líneas de los scripts. El agente lo usa
-- para reconocer el estado actual de Studio sin adivinar coordenadas.
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

return OpsExtra

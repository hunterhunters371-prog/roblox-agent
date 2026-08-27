-- OpsScan.lua (v3.3) — ops de ESCANEO de solo lectura:
--
--   scan_workspace { path?, max_depth?, max_nodes?, include_source?, inline? }
--     Escanea el place ABIERTO AHORA en Studio: árbol de instancias con
--     posición/tamaño de parts, nº de líneas de cada script y, si include_source,
--     su código fuente completo. Publica snapshots/escaneo_<UTC>.json.
--
--   scan_repo { repo_path?, read_files?, max_files?, inline? }
--     Escanea el REPO del bridge en GitHub: árbol completo (git trees recursivo)
--     con tamaños; read_files (máx. 10) incluye el contenido de archivos puntuales.
--     Publica snapshots/repo_<UTC>.json.
--
-- Ambas devuelven un resumen en `data` del result.json (o el escaneo COMPLETO si
-- inline = true). Main fija el entorno con OpsScan.set_env(env) al arrancar y
-- Executor fusiona estas ops en el registro de Ops como hace con OpsExtra.
-- Convención: handler(op, cmdId) -> (action, detail?, data?) y
-- error({ code, message }) al fallar.

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Resolver = require(script.Parent.PathResolver)

local OpsScan = {}

local EnvCompartido = nil

-- NO es una op: Main la llama una vez al arrancar para compartir ui/github.
function OpsScan.set_env(env)
	EnvCompartido = env
end

local function fail(code, message)
	error({ code = code, message = message }, 0)
end

local function redondear(n)
	return math.floor(n * 100 + 0.5) / 100
end

local function githubActual()
	if EnvCompartido and EnvCompartido.getGithub then
		return EnvCompartido.getGithub()
	end
	return nil
end

-- ---------- scan_workspace ----------

local SERVICIOS_ESCANEO = {
	"Workspace", "ServerScriptService", "ServerStorage", "ReplicatedStorage",
	"StarterGui", "StarterPlayer", "StarterPack", "Lighting", "Teams", "SoundService",
}

local MAX_HIJOS = 60

local function nodoEscaneo(inst, profundidad, presupuesto, incluirFuente)
	if presupuesto.n <= 0 then
		return nil
	end
	presupuesto.n -= 1
	local nodo = { name = inst.Name, class = inst.ClassName }

	if inst:IsA("BasePart") then
		local p, s = inst.Position, inst.Size
		nodo.pos = { redondear(p.X), redondear(p.Y), redondear(p.Z) }
		nodo.size = { redondear(s.X), redondear(s.Y), redondear(s.Z) }
		if not inst.Anchored then
			nodo.anchored = false
		end
	elseif inst:IsA("Model") then
		local ok, cf = pcall(function()
			return inst:GetPivot()
		end)
		if ok then
			nodo.pos = { redondear(cf.X), redondear(cf.Y), redondear(cf.Z) }
		end
	elseif inst:IsA("LuaSourceContainer") then
		nodo.lines = 1 + select(2, inst.Source:gsub("\n", "\n"))
		if incluirFuente then
			nodo.src = inst.Source
		end
	end

	if profundidad > 1 then
		local hijos = inst:GetChildren()
		if #hijos > 0 then
			nodo.children = {}
			for i, hijo in ipairs(hijos) do
				if i > MAX_HIJOS then
					table.insert(nodo.children, { name = ("y %d mas"):format(#hijos - MAX_HIJOS), class = "..." })
					break
				end
				local sub = nodoEscaneo(hijo, profundidad - 1, presupuesto, incluirFuente)
				if sub then
					table.insert(nodo.children, sub)
				else
					table.insert(nodo.children, { name = "...", class = "presupuesto agotado" })
					break
				end
			end
		end
	end
	return nodo
end

function OpsScan.scan_workspace(op, _cmdId)
	local profundidad = math.clamp(op.max_depth or 6, 1, 10)
	local presupuesto = { n = math.clamp(op.max_nodes or 3000, 100, 10000) }
	local incluirFuente = op.include_source == true

	local raices = {}
	if op.path then
		local inst = Resolver.Resolve(op.path)
		if not inst then
			fail("PATH_NOT_FOUND", op.path)
		end
		table.insert(raices, { nombre = op.path, inst = inst })
	else
		for _, nombre in ipairs(SERVICIOS_ESCANEO) do
			local ok, servicio = pcall(function()
				return game:GetService(nombre)
			end)
			if ok and servicio then
				table.insert(raices, { nombre = nombre, inst = servicio })
			end
		end
	end

	local trees, counts, total = {}, {}, 0
	for _, raiz in ipairs(raices) do
		local antes = presupuesto.n
		local arbol = nodoEscaneo(raiz.inst, profundidad, presupuesto, incluirFuente)
		if arbol then
			trees[raiz.nombre] = arbol
			counts[raiz.nombre] = antes - presupuesto.n
			total += counts[raiz.nombre]
		end
	end

	local escaneo = {
		tipo = "escaneo-place",
		place = game.Name,
		place_id = game.PlaceId,
		capturado_at = DateTime.now():ToIsoDate(),
		play_mode = RunService:IsRunning(),
		include_source = incluirFuente,
		truncated = presupuesto.n <= 0,
		counts = counts,
		total_nodes = total,
		trees = trees,
	}

	local snapshotPath = ("snapshots/escaneo_%s.json"):format(os.date("!%Y%m%d_%H%M%S"))
	local publicado = false
	local github = githubActual()
	if github then
		local okUp = pcall(function()
			github:WriteJson(snapshotPath, escaneo, ("escaneo del place (%d nodos)"):format(total))
		end)
		publicado = okUp
	end

	return nil, ("escaneo del place: %d nodo(s)%s%s"):format(
		total,
		presupuesto.n <= 0 and " (truncado)" or "",
		publicado and (" -> " .. snapshotPath) or " (no se publicó: ¿falta token?)"
	), {
		snapshot = publicado and snapshotPath or nil,
		total_nodes = total,
		truncated = presupuesto.n <= 0,
		counts = counts,
		inline = if op.inline == true then escaneo else nil,
	}
end

-- ---------- scan_repo ----------

function OpsScan.scan_repo(op, _cmdId)
	local github = githubActual()
	if not github then
		fail("OP_FAILED", "scan_repo necesita el token de GitHub guardado en el plugin")
	end

	local prefijo = op.repo_path or ""
	local respuesta = github:_request("GET", ("/git/trees/%s?recursive=1"):format(Config.BRANCH))

	local archivos = {}
	for _, nodo in ipairs(respuesta.tree or {}) do
		if nodo.type == "blob" and (prefijo == "" or nodo.path:sub(1, #prefijo) == prefijo) then
			table.insert(archivos, { path = nodo.path, size = nodo.size })
		end
	end
	table.sort(archivos, function(a, b)
		return a.path < b.path
	end)

	local maxFiles = math.clamp(op.max_files or 500, 1, 2000)
	local truncado = #archivos > maxFiles
	if truncado then
		local recorte = {}
		for i = 1, maxFiles do
			recorte[i] = archivos[i]
		end
		archivos = recorte
	end

	-- contenido opcional de archivos puntuales (máx. 10, 200 KB por archivo)
	local contenidos = nil
	if type(op.read_files) == "table" then
		contenidos = {}
		for i, ruta in ipairs(op.read_files) do
			if i > 10 then
				break
			end
			local okL, texto = pcall(function()
				return github:ReadFile(ruta)
			end)
			if okL and type(texto) == "string" then
				contenidos[ruta] = texto:sub(1, 204800)
			end
		end
	end

	local escaneo = {
		tipo = "escaneo-repo",
		repo = Config.REPO_OWNER .. "/" .. Config.REPO_NAME,
		branch = Config.BRANCH,
		capturado_at = DateTime.now():ToIsoDate(),
		prefijo = prefijo,
		total_files = #archivos,
		truncated = truncado,
		files = archivos,
		contents = contenidos,
	}

	local snapshotPath = ("snapshots/repo_%s.json"):format(os.date("!%Y%m%d_%H%M%S"))
	local publicado = false
	local okUp = pcall(function()
		github:WriteJson(snapshotPath, escaneo, ("escaneo del repo (%d archivos)"):format(#archivos))
	end)
	publicado = okUp

	return nil, ("escaneo del repo: %d archivo(s)%s%s"):format(
		#archivos,
		truncado and " (truncado)" or "",
		publicado and (" -> " .. snapshotPath) or " (falló la subida)"
	), {
		snapshot = publicado and snapshotPath or nil,
		total_files = #archivos,
		truncated = truncado,
		inline = if op.inline == true then escaneo else nil,
	}
end

return OpsScan

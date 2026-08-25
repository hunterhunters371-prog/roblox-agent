-- AutoSense.lua (v3.0) - sondeo continuo del place: lint automatico de scripts y
-- espejo del estado actual de Studio publicado en el repo (place/mirror.json).
-- Studio no expone acceso entrante; la unica via es este plugin publicando el
-- estado para que el agente lo lea del repo. Solo escribe cuando algo CAMBIA
-- (firma FNV-1a del contenido), para no inundar el historial de commits.
--
-- init(env) arranca el sondeo y devuelve { detener }. Ademas expone
-- AutoSense.MirrorTree, que reutiliza OpsExtra.mirror_place.

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Lint = require(script.Parent.Lint)

local AutoSense = {}

local function firma(texto)
	local h = 2166136261
	for i = 1, #texto do
		h = bit32.bxor(h, texto:byte(i))
		h = (h * 16777619) % 4294967296
	end
	return string.format("%08x", h)
end

local function redondear(n)
	return math.floor(n * 100 + 0.5) / 100
end

-- Arbol compacto: nombre, clase, posicion/tamano de BasePart, pivot de Model y
-- lineas de los scripts (sin fuente; la fuente viaja en los snapshots de codigo).
function AutoSense.MirrorTree(inst, profundidad, presupuesto)
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
	end
	if profundidad > 1 then
		local hijos = inst:GetChildren()
		if #hijos > 0 then
			nodo.children = {}
			for i, hijo in ipairs(hijos) do
				if i > 40 then
					table.insert(nodo.children, { name = ("y %d mas"):format(#hijos - 40), class = "..." })
					break
				end
				local sub = AutoSense.MirrorTree(hijo, profundidad - 1, presupuesto)
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

local SERVICIOS_ESPEJO = {
	"Workspace", "ServerScriptService", "ServerStorage", "ReplicatedStorage",
	"StarterGui", "StarterPlayer", "StarterPack", "Lighting", "Teams", "SoundService",
}

-- Espejo del place entero (lo que el agente lee para conocer el estado de Studio).
function AutoSense.BuildMirror(maxDepth, maxNodes)
	local presupuesto = { n = maxNodes or Config.MIRROR_MAX_NODES or 2500 }
	local trees, counts = {}, {}
	local total = 0
	for _, nombre in ipairs(SERVICIOS_ESPEJO) do
		local ok, servicio = pcall(function()
			return game:GetService(nombre)
		end)
		if ok and servicio then
			local antes = presupuesto.n
			local arbol = AutoSense.MirrorTree(servicio, maxDepth or 3, presupuesto)
			if arbol then
				trees[nombre] = arbol
				local usados = antes - presupuesto.n
				counts[nombre] = usados
				total += usados
			end
		end
	end
	return {
		tipo = "espejo-place",
		place = game.Name,
		place_id = game.PlaceId,
		capturado_at = DateTime.now():ToIsoDate(),
		play_mode = RunService:IsRunning(),
		truncated = presupuesto.n <= 0,
		counts = counts,
		total_nodes = total,
		trees = trees,
	}
end

function AutoSense.init(env)
	if Config.AUTO_LINT == false and Config.AUTO_MIRROR == false then
		return { detener = function() end }
	end
	local plugin = env.plugin
	local activo = true
	local ultimoLint, ultimoMirror = 0, 0

	local function upsertJson(path, payload, msg)
		local gh = env.getGithub()
		if not gh then
			return false
		end
		local sha
		pcall(function()
			local _, s = gh:ReadJson(path)
			sha = s
		end)
		local ok, err = pcall(function()
			gh:WriteJson(path, payload, msg, sha)
		end)
		if not ok then
			env.reportError("autosense", err)
			return false
		end
		return true
	end

	local function firmaDe(tabla)
		local ok, texto = pcall(function()
			return HttpService:JSONEncode(tabla)
		end)
		if not ok then
			return nil
		end
		return firma(texto)
	end

	local function pasadaLint()
		local findings = Lint.Place()
		local sig = firmaDe(findings)
		if not sig or sig == plugin:GetSetting("autosense_lint_sig") then
			return
		end
		local enviados = findings
		if #findings > 300 then
			enviados = {}
			for i = 1, 300 do
				enviados[i] = findings[i]
			end
		end
		local ok = upsertJson(Config.PATHS.lint .. "/findings.json", {
			tipo = "lint",
			capturado_at = env.nowIso(),
			play_mode = RunService:IsRunning(),
			total = #findings,
			truncated = #findings > 300,
			findings = enviados,
		}, ("lint: %d hallazgo(s)"):format(#findings))
		if ok then
			plugin:SetSetting("autosense_lint_sig", sig)
			pcall(function()
				env.getUi():Log(("Auto-lint: %d hallazgo(s) -> lint/findings.json"):format(#findings))
			end)
		end
	end

	local function pasadaMirror()
		local mirror = AutoSense.BuildMirror()
		local sig = firmaDe(mirror.trees)
		if not sig or sig == plugin:GetSetting("autosense_mirror_sig") then
			return
		end
		if upsertJson(Config.PATHS.place .. "/mirror.json", mirror,
			("espejo del place (%d nodos)"):format(mirror.total_nodes)) then
			plugin:SetSetting("autosense_mirror_sig", sig)
			pcall(function()
				env.getUi():Log("Espejo del place actualizado -> place/mirror.json")
			end)
		end
	end

	task.spawn(function()
		task.wait(15) -- deja arrancar el runtime con calma
		while activo do
			if env.getGithub() then
				local ahora = os.clock()
				if Config.AUTO_LINT ~= false and ahora - ultimoLint >= (Config.AUTO_LINT_SECONDS or 600) then
					ultimoLint = ahora
					pcall(pasadaLint)
				end
				if Config.AUTO_MIRROR ~= false and ahora - ultimoMirror >= (Config.AUTO_MIRROR_SECONDS or 300) then
					ultimoMirror = ahora
					pcall(pasadaMirror)
				end
			end
			task.wait(30)
		end
	end)

	return {
		detener = function()
			activo = false
		end,
	}
end

return AutoSense

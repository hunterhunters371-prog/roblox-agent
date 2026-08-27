-- Runtime principal del Roblox Agent Bridge (v2.0/v3.0).
-- NO se instala a mano: lo descarga y arranca el loader (init.server.lua), que puede
-- sustituirlo en caliente al pulsar "⟳ Actualizar". start(ctx) monta la UI y devuelve
-- stop() para esa actualización en caliente. (Historia v1.1–v1.8: ver README y git.)
-- v3.0: AutoSense — lint automático de scripts (lint/findings.json) y espejo del
-- estado del place (place/mirror.json), publicados solo cuando algo cambia.
-- v3.3: SIN aprobación humana — los comandos válidos de pending/ y approved/ se
-- AUTO-EJECUTAN al sincronizar. Se aceptan archivos .cmd además de .json (mismo
-- envelope JSON). Nuevas ops de escaneo (OpsScan): scan_workspace y scan_repo.
-- v3.3.1: require tolerante de OpsScan (la carrera de caché del CDN podía servir
-- Main nuevo + manifiesto viejo sin OpsScan.lua y tumbar la carga completa),
-- filtro de comandos estricto (los .state.json huérfanos ya no se leen como
-- comandos) y sync inicial automático al cargar el token.
-- v3.3.2: los comandos en processing/ también se REANUDAN solos al sincronizar
-- (una vez por sesión por comando, para no entrar en bucle si uno falla).
--
-- ctx = { plugin, widget, version, loader }

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local GitHub = require(script.Parent.GitHub)
local Validator = require(script.Parent.Validator)
local Executor = require(script.Parent.Executor)
local UI = require(script.Parent.UI)
local Inspect = require(script.Parent.Inspect)
local Chat = require(script.Parent.Chat)
local AutoSense = require(script.Parent.AutoSense)

-- v3.3.1: require tolerante — si el CDN sirvió una versión a medias (manifiesto
-- viejo sin OpsScan.lua en la lista), el runtime arranca igual y solo faltarán
-- las ops de escaneo, en vez de fallar la carga completa del Main.
local OpsScan = nil
do
	local okOpsScan, opsScanMod = pcall(function()
		return require(script.Parent.OpsScan)
	end)
	if okOpsScan then
		OpsScan = opsScanMod
	end
end

local Main = {}

function Main.start(ctx)
	local plugin = ctx.plugin
	local widget = ctx.widget

	local ui
	local github
	local doSync
	local ultimoConteoComandos = nil
	local activo = true
	local autoEjecutando = false -- v3.3: guarda contra re-entrada de la auto-ejecución
	local autoReanudados = {} -- v3.3.2: ids de processing/ ya reanudados automáticamente en esta sesión
	local conexiones = {}

	local function nowIso()
		return DateTime.now():ToIsoDate()
	end

	local function setStatusReady()
		if github then
			ui:SetStatus("conectado · " .. Config.REPO_OWNER .. "/" .. Config.REPO_NAME, "ok")
		else
			ui:SetStatus("sin token de GitHub", "warn")
		end
	end

	local function reportError(context, err)
		local message = (type(err) == "table" and err.message) or tostring(err)
		if message:lower():find("http") and message:lower():find("enabled") then
			message ..= " — activa 'Allow HTTP Requests' en Game Settings → Security."
		end
		ui:Log("ERROR · " .. context .. ": " .. message)
		warn("[RBX Bridge] " .. context .. ": " .. message)
		setStatusReady()
	end

	local function guardGithub()
		if not github then
			ui:Log("Guarda primero el token de GitHub.")
			ui:ShowTokenRow(true)
			return false
		end
		return true
	end

	-- Entorno compartido con Inspect, Chat y AutoSense. ui/github se asignan después
	-- del init, así que se pasan getters en vez del valor.
	local env = {
		plugin = plugin,
		nowIso = nowIso,
		getUi = function()
			return ui
		end,
		getGithub = function()
			return github
		end,
		guardGithub = function()
			return guardGithub()
		end,
		reportError = reportError,
		setStatusReady = setStatusReady,
		sync = function(silencioso)
			if doSync then
				doSync(silencioso)
			end
		end,
	}
	local inspectApi = Inspect.init(env)
	local chatApi = Chat.init(env)
	local autoSenseApi = AutoSense.init(env) -- v3.0: lint + espejo automáticos
	if OpsScan then
		OpsScan.set_env(env) -- v3.3: las ops de escaneo publican snapshots desde aquí
	end

	-- ---------- acceso a comandos ----------

	-- v3.3.1: nombre EXACTO cmd_NNNNNN + extensión permitida (.json/.cmd).
	-- Así los auxiliares (cmd_000001.state.json, .result.json, .reason.json)
	-- jamás se interpretan como comandos.
	local function esArchivoComando(nombre)
		local base, ext = nombre:match("^(cmd_%d%d%d%d%d%d)(%.%a+)$")
		if not base then
			return false
		end
		for _, permitida in ipairs(Config.COMMAND_EXTENSIONS or { ".json" }) do
			if ext == permitida then
				return true
			end
		end
		return false
	end

	local function listCommands(folder)
		local files = github:ListFiles(folder)
		local commands = {}
		for _, file in ipairs(files) do
			if esArchivoComando(file.name) then
				table.insert(commands, file)
			end
		end
		table.sort(commands, function(a, b)
			return a.name < b.name
		end)
		return commands
	end

	local function readCommand(file)
		local raw = github:ReadFile(file.path)
		local ok, data = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not ok then
			return nil
		end
		return data
	end

	local function statePathOf(id)
		return Config.PATHS.processing .. "/" .. id .. ".state.json"
	end

	local function readState(id)
		local ok, data = pcall(function()
			local json, sha = github:ReadJson(statePathOf(id))
			json._sha = sha
			return json
		end)
		if ok then
			return data
		end
		return nil
	end

	local function reject(file, code, message)
		ui:Log(("%s rechazado: %s — %s"):format(file.name, code, message))
		github:MoveFile(file.path, Config.PATHS.rejected .. "/" .. file.name, "rechazar " .. file.name .. ": " .. code)
		local base = file.name:gsub("%.json$", ""):gsub("%.cmd$", "")
		github:WriteJson(Config.PATHS.rejected .. "/" .. base .. ".reason.json", {
			code = code,
			message = message,
			rejected_at = nowIso(),
		}, "motivo de rechazo " .. file.name)
	end

	-- ---------- ciclo de vida ----------

	local function finishCommand(cmd, processingPath, stateSha, startedAt, results, errors, done)
		local failed = #errors > 0
		local result = {
			id = cmd.id,
			status = failed and "failed" or "completed",
			started_at = startedAt,
			finished_at = nowIso(),
			progress = { done = done or 0, total = #cmd.operations },
			results = results,
			errors = errors,
			waypoint = cmd.id,
		}
		local destination = failed and Config.PATHS.failed or Config.PATHS.completed
		github:MoveFile(processingPath, destination .. "/" .. cmd.id .. ".json", "cerrar " .. cmd.id)
		github:WriteJson(destination .. "/" .. cmd.id .. ".result.json", result, "resultado " .. cmd.id)
		if stateSha then
			-- limpia el checkpoint: el comando ya terminó
			pcall(function()
				github:DeleteFile(statePathOf(cmd.id), stateSha, "limpiar checkpoint " .. cmd.id)
			end)
		end
		ui:SetProgress(nil)
		if failed then
			ui:Log(("%s terminó con %d error(es)."):format(cmd.id, #errors))
		else
			ui:Log("✓ " .. cmd.id .. " completado.")
		end
	end

	-- Ejecuta (o reanuda) un comando. resumeState es opcional.
	local function doExecute(file, cmd, resumeState)
		if not guardGithub() then
			return
		end
		ui:SetStatus("ejecutando " .. cmd.id .. "…", "busy")
		local startedAt = nowIso()

		local ok, err = pcall(function()
			-- mover a processing/ si aún no está (contenido intacto: regla de oro)
			local processingPath = Config.PATHS.processing .. "/" .. file.name
			if not resumeState then
				github:MoveFile(file.path, processingPath, "ejecutar " .. cmd.id)
			end

			local options = cmd.options or {}
			local stateSha = resumeState and resumeState._sha or nil
			local results, errors, done

			if options.dry_run then
				results, errors = Executor.DryRun(cmd)
				done = #cmd.operations
			else
				results, errors, done = Executor.Run(cmd, function(doneCount, total, opId)
					ui:SetStatus(("%s · %d/%d"):format(cmd.id, doneCount, total), "busy")
					ui:SetProgress(doneCount, total)
					stateSha = github:WriteJson(statePathOf(cmd.id), {
						id = cmd.id,
						status = "processing",
						last_completed = opId,
						done = doneCount,
						total = total,
						updated_at = nowIso(),
					}, ("checkpoint %s %d/%d"):format(cmd.id, doneCount, total), stateSha)
				end, resumeState and (resumeState.done + 1) or 1)
			end

			finishCommand(cmd, processingPath, stateSha, startedAt, results, errors, done)
		end)

		if not ok then
			ui:SetProgress(nil)
			reportError("ejecutar " .. cmd.id, err)
		end
		doSync()
	end

	local function doUndo()
		local ok, err = pcall(function()
			ChangeHistoryService:Undo()
		end)
		if ok then
			ui:Log("Deshacer ejecutado (último waypoint).")
		else
			ui:Log("Deshacer falló: " .. tostring(err))
		end
	end

	local function onSaveToken(token)
		plugin:SetSetting("github_token", token)
		github = GitHub.new(token)
		ui:ShowTokenRow(false)
		ui:Log("Token guardado. Sincronizando…")
		doSync()
	end

	-- ---------- sync ----------
	-- silencioso = true: no ensucia el registro si no cambió el número de comandos.
	doSync = function(silencioso)
		if not guardGithub() then
			return
		end
		if not silencioso then
			ui:SetStatus("sincronizando…", "busy")
		end
		local items = {}
		local colaAuto = {} -- v3.3: comandos válidos listos para auto-ejecutar

		local ok, err = pcall(function()
			for _, file in ipairs(listCommands(Config.PATHS.pending)) do
				local cmd = readCommand(file)
				if not cmd then
					reject(file, "VALIDATION_FAILED", "JSON inválido")
				else
					local valid, code, message = Validator.ValidateCommand(cmd)
					if not valid then
						reject(file, code, message)
					else
						-- v3.3: sin aprobación — todo comando válido va a la cola de ejecución
						table.insert(items, {
							id = cmd.id,
							title = cmd.title,
							state = "pending (auto)",
							actionLabel = "Ejecutar",
							onAction = function()
								doExecute(file, cmd)
							end,
						})
						table.insert(colaAuto, { file = file, cmd = cmd })
					end
				end
			end

			for _, file in ipairs(listCommands(Config.PATHS.approved)) do
				local cmd = readCommand(file)
				if cmd then
					table.insert(items, {
						id = cmd.id,
						title = cmd.title,
						state = "approved",
						actionLabel = "Ejecutar",
						onAction = function()
							doExecute(file, cmd)
						end,
					})
					table.insert(colaAuto, { file = file, cmd = cmd })
				end
			end

			for _, file in ipairs(listCommands(Config.PATHS.processing)) do
				local cmd = readCommand(file)
				if cmd then
					local state = readState(cmd.id)
					table.insert(items, {
						id = cmd.id,
						title = cmd.title,
						state = "processing",
						progress = state and { done = state.done, total = state.total } or nil,
						actionLabel = "Continuar",
						onAction = function()
							doExecute(file, cmd, state)
						end,
					})
					-- v3.3.2: reanudar solo al sincronizar (una vez por sesión por comando)
					if not autoReanudados[cmd.id] then
						autoReanudados[cmd.id] = true
						table.insert(colaAuto, { file = file, cmd = cmd, resumeState = state })
					end
				end
			end
		end)

		if not ok then
			if not silencioso then
				reportError("sync", err)
			end
		else
			if not silencioso or ultimoConteoComandos ~= #items then
				ui:Log(("Sync: %d comando(s) activos."):format(#items))
			end
			ultimoConteoComandos = #items
			setStatusReady()
		end
		ui:SetCommands(items)

		-- v3.3: AUTO-EJECUCIÓN sin aprobación humana. Se ejecuta el primer comando
		-- de la cola; al terminar, doExecute sincroniza y esta pasada recoge el
		-- siguiente. autoEjecutando evita re-entrada mientras hay uno en marcha.
		-- ("~= false": si el CDN sirvió un Config viejo sin la clave, se auto-ejecuta igual)
		if Config.AUTO_EXECUTE ~= false and not autoEjecutando and #colaAuto > 0 then
			local siguiente = colaAuto[1]
			ui:Log(("▶ Auto-ejecutando %s — %s"):format(siguiente.cmd.id, tostring(siguiente.cmd.title)))
			task.spawn(function()
				autoEjecutando = true
				pcall(doExecute, siguiente.file, siguiente.cmd, siguiente.resumeState)
				autoEjecutando = false
				doSync(true) -- recoge el siguiente comando en cola, si lo hay
			end)
		end
	end

	-- ---------- arranque ----------

	for _, child in ipairs(widget:GetChildren()) do
		-- limpia restos del runtime anterior o del fallback del loader
		child:Destroy()
	end

	ui = UI.new(widget, {
		onSync = function()
			doSync()
		end,
		onUndo = doUndo,
		onSaveToken = onSaveToken,
		onInspectSelection = inspectApi.seleccion,
		onUploadCode = inspectApi.codigo,
		onUploadEnvironment = inspectApi.entorno,
		onSendChat = chatApi.enviar,
	})

	-- highlight del cursor: activo solo mientras el panel esté abierto
	table.insert(
		conexiones,
		widget:GetPropertyChangedSignal("Enabled"):Connect(function()
			if widget.Enabled then
				inspectApi.iniciarHover()
			else
				inspectApi.detenerHover()
			end
		end)
	)

	-- sondeo periódico: chat cada 20 s + sync silencioso cada 60 s
	task.spawn(function()
		local tick = 0
		while activo do
			if widget.Enabled then
				pcall(chatApi.revisar)
				tick += 1
				if tick % 3 == 0 and doSync then
					pcall(doSync, true)
				end
			end
			task.wait(20)
		end
	end)

	ui:SetCommands({}) -- lista vacía ANTES del sync inicial, para no borrar lo que llene
	local savedToken = plugin:GetSetting("github_token")
	if type(savedToken) == "string" and #savedToken > 0 then
		github = GitHub.new(savedToken)
		ui:ShowTokenRow(false)
		ui:Log("Token cargado. Sincronizando…")
		doSync(true) -- v3.3.1: sync inicial inmediato — la cola pendiente arranca sola
	else
		ui:ShowTokenRow(true)
		ui:Log("Bienvenido. Pega tu token fine-grained de GitHub para empezar.")
	end
	setStatusReady()
	ui:Log(("Bridge runtime v%s (loader v%s) — ⟳ Actualizar trae versiones nuevas sin reinstalar."):format(
		tostring(ctx.version),
		tostring(ctx.loader)
	))
	ui:Log("v3.3.2: 100% automático — pending/, approved/ y processing/ se ejecutan solos al sincronizar. Formatos: .json y .cmd.")
	if Config.AUTO_LINT ~= false or Config.AUTO_MIRROR ~= false then
		ui:Log(("AutoSense activo: lint cada %ds y espejo cada %ds (solo escribe cuando algo cambia)."):format(
			Config.AUTO_LINT_SECONDS or 600,
			Config.AUTO_MIRROR_SECONDS or 300
		))
	end

	-- stop(): el loader lo llama al actualizar en caliente o al descargarse el plugin.
	local function stop()
		if not activo then
			return
		end
		activo = false
		for _, conexion in ipairs(conexiones) do
			pcall(function()
				conexion:Disconnect()
			end)
		end
		inspectApi.detenerHover()
		autoSenseApi.detener()
		for _, child in ipairs(widget:GetChildren()) do
			child:Destroy()
		end
	end
	return stop
end

return Main

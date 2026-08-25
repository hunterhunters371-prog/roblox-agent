-- Runtime principal del Roblox Agent Bridge (v2.0).
-- NO se instala a mano: lo descarga y arranca el loader (init.server.lua), que puede
-- sustituirlo en caliente al pulsar "⟳ Actualizar". start(ctx) monta la UI y devuelve
-- stop() para esa actualización en caliente. (Historia v1.1–v1.8: ver README y git.)
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

local Main = {}

function Main.start(ctx)
	local plugin = ctx.plugin
	local widget = ctx.widget

	local ui
	local github
	local doSync
	local ultimoConteoComandos = nil
	local activo = true
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

	-- Entorno compartido con Inspect y Chat. ui/github se asignan después del init,
	-- así que se pasan getters en vez del valor.
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

	-- ---------- acceso a comandos ----------

	local function listCommands(folder)
		local files = github:ListFiles(folder)
		local commands = {}
		for _, file in ipairs(files) do
			if file.name:match("^cmd_%d%d%d%d%d%d%.json$") then
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
		github:WriteJson(Config.PATHS.rejected .. "/" .. file.name:gsub("%.json$", "") .. ".reason.json", {
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

	local function doApprove(file, cmd)
		if not guardGithub() then
			return
		end
		local ok, err = pcall(function()
			github:MoveFile(file.path, Config.PATHS.approved .. "/" .. file.name, "aprobar " .. cmd.id)
		end)
		if ok then
			ui:Log(cmd.id .. " aprobado.")
			doSync()
		else
			reportError("aprobar " .. cmd.id, err)
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

		local ok, err = pcall(function()
			for _, file in ipairs(listCommands(Config.PATHS.pending)) do
				local cmd = readCommand(file)
				if not cmd then
					reject(file, "VALIDATION_FAILED", "JSON inválido")
				else
					local valid, code, message = Validator.ValidateCommand(cmd)
					if not valid then
						reject(file, code, message)
					elseif Validator.NeedsApproval(cmd) then
						table.insert(items, {
							id = cmd.id,
							title = cmd.title,
							state = "pending",
							actionLabel = "Aprobar",
							onAction = function()
								doApprove(file, cmd)
							end,
						})
					else
						table.insert(items, {
							id = cmd.id,
							title = cmd.title,
							state = "pending (auto)",
							actionLabel = "Ejecutar",
							onAction = function()
								doExecute(file, cmd)
							end,
						})
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

	local savedToken = plugin:GetSetting("github_token")
	if type(savedToken) == "string" and #savedToken > 0 then
		github = GitHub.new(savedToken)
		ui:ShowTokenRow(false)
		ui:Log("Token cargado. Pulsa Sync para buscar comandos.")
	else
		ui:ShowTokenRow(true)
		ui:Log("Bienvenido. Pega tu token fine-grained de GitHub para empezar.")
	end
	ui:SetCommands({})
	setStatusReady()
	ui:Log(("Bridge runtime v%s (loader v%s) — ⟳ Actualizar trae versiones nuevas sin reinstalar."):format(
		tostring(ctx.version),
		tostring(ctx.loader)
	))

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
		for _, child in ipairs(widget:GetChildren()) do
			child:Destroy()
		end
	end
	return stop
end

return Main

-- Roblox Agent Bridge — punto de entrada del plugin (protocolo v0.1).
-- Flujo: Sync → validar → aprobar → ejecutar → reportar. Todo el estado vive en GitHub.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")

local Config = require(script.Config)
local GitHub = require(script.GitHub)
local Validator = require(script.Validator)
local Executor = require(script.Executor)
local UI = require(script.UI)

-- ---------- toolbar + widget ----------

local toolbar = plugin:CreateToolbar("Roblox Agent Bridge")
local openButton = toolbar:CreateButton("Agent Bridge", "Abrir el panel de Roblox Agent Bridge", "")
openButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right, -- dock inicial
	false, -- habilitado al inicio
	false, -- no sobreescribir estado previo
	440, -- ancho default
	420, -- alto default
	340, -- ancho mínimo
	320 -- alto mínimo
)
local widget = plugin:CreateDockWidgetPluginGui("RobloxAgentBridge", widgetInfo)
widget.Title = "Roblox Agent Bridge"
openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- ---------- estado del controlador ----------

local ui
local github
local doSync

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
	if failed then
		ui:Log(("%s terminó con %d error(es)."):format(cmd.id, #errors))
	else
		ui:Log(cmd.id .. " completado.")
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

doSync = function()
	if not guardGithub() then
		return
	end
	ui:SetStatus("sincronizando…", "busy")
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
		reportError("sync", err)
	else
		ui:Log(("Sync: %d comando(s) activos."):format(#items))
		setStatusReady()
	end
	ui:SetCommands(items)
end

-- ---------- arranque ----------

ui = UI.new(widget, {
	onSync = function()
		doSync()
	end,
	onUndo = doUndo,
	onSaveToken = onSaveToken,
})

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

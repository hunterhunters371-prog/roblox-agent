-- Roblox Agent Bridge — punto de entrada del plugin (protocolo v0.1).
-- Flujo: Sync → validar → aprobar → ejecutar → reportar. Todo el estado vive en GitHub.
-- v1.1: botón "Selección" — sube a snapshots/ un informe de lo seleccionado con el mouse.
-- v1.2: highlight del objeto bajo el cursor + inspección de GUI, scripts contenidos,
--        etiqueta _RBX_Bridge y flag play_mode.
-- v1.3: los scripts suben SIEMPRE con su código completo; árboles de GUI sin límite
--        práctico (ScreenGui/BillboardGui/SurfaceGui/ImageLabel con imagen);
--        mesh_id/primary_part/shape; el log confirma cuántos scripts subieron.
-- v1.3.1: profundidad base 3 (alcanza scripts dentro de modelos, p. ej. NPC's → Sell).
-- v1.4: botón "⬆ Código" — sube TODOS los scripts del juego de una vez, un archivo por
--        servicio (snapshots/codigo_<Servicio>_<ts>.json), para análisis completo.
-- v1.6: barra de progreso durante la ejecución + clase del objeto en la fila hover.
-- v1.7: pestaña 💬 CHAT — mensajes a chat/inbox/ y sondeo de chat/outbox/ cada 20s.
-- v1.8: botón "🗺 Entorno" (mapa del place: servicios, árbol ligero del Workspace,
--        iluminación) + hover con tamaño/hijos + auto-sync silencioso cada 60s y tras
--        cada respuesta del agente (los comandos pedidos por chat aparecen solos).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

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
	560, -- alto default (v1.7+: más alto para el chat)
	340, -- ancho mínimo
	480 -- alto mínimo
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
local ultimoConteoComandos = nil -- v1.8: para el sync silencioso

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
	ui:SetProgress(nil) -- v1.6: ocultar la barra al terminar
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
				ui:SetProgress(doneCount, total) -- v1.6: barra de progreso
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

-- ---------- inspección de selección (v1.1–v1.3) ----------

local function colorATabla(color)
	return {
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5),
	}
end

-- JSONEncode no acepta tipos de Roblox (Vector3, Color3…): los convertimos a texto/tablas.
local function valorJson(v)
	local t = typeof(v)
	if t == "string" or t == "number" or t == "boolean" then
		return v
	end
	if t == "UDim2" then
		return { scaleX = v.X.Scale, offsetX = v.X.Offset, scaleY = v.Y.Scale, offsetY = v.Y.Offset }
	end
	if t == "UDim" then
		return { scale = v.Scale, offset = v.Offset }
	end
	if t == "Vector3" then
		return { v.X, v.Y, v.Z }
	end
	if t == "Color3" then
		return colorATabla(v)
	end
	if t == "table" then
		local limpio = {}
		for k2, v2 in v do
			limpio[tostring(k2)] = valorJson(v2)
		end
		return limpio
	end
	return tostring(v)
end

local function esScript(instance)
	return instance:IsA("Script") or instance:IsA("ModuleScript") or instance:IsA("LocalScript")
end

local function esGui(instance)
	return instance:IsA("GuiObject") or instance:IsA("LayerCollector")
end

-- Scripts contenidos dentro de la instancia (v1.2): reconoce modelos con lógica propia.
local function scriptsDentro(instance)
	local lista = {}
	for _, d in ipairs(instance:GetDescendants()) do
		if esScript(d) then
			table.insert(lista, d.ClassName .. ":" .. d.Name)
		end
	end
	return lista
end

-- contador de scripts del informe actual (v1.3: el log confirma cuántos subieron)
local contadorScripts = 0

-- Describe una instancia: identidad, atributos, geometría (BasePart/Model), GUI completa
-- (v1.3), scripts contenidos y etiqueta del bridge (v1.2), fuente completa si es script.
-- Reglas de profundidad (v1.3): los scripts suben SIEMPRE completos; los árboles de GUI
-- recorren hasta 6 niveles; el resto del mundo según la profundidad recibida.
local function describir(instance, profundidad)
	local data = {
		name = instance.Name,
		class = instance.ClassName,
		path = instance:GetFullName(),
	}
	local attrs = instance:GetAttributes()
	if next(attrs) ~= nil then
		data.attributes = valorJson(attrs)
	end
	local bridgeTag = instance:GetAttribute("_RBX_Bridge")
	if bridgeTag ~= nil then
		data.bridge = bridgeTag -- lo creó el agente en ese comando (v1.2)
	end
	if instance:IsA("BasePart") then
		data.size = { instance.Size.X, instance.Size.Y, instance.Size.Z }
		data.position = { instance.Position.X, instance.Position.Y, instance.Position.Z }
		data.material = instance.Material.Name
		data.color = colorATabla(instance.Color)
		data.anchored = instance.Anchored
		local okShape, shape = pcall(function()
			return instance.Shape.Name
		end)
		if okShape then
			data.shape = shape -- v1.3
		end
		if instance:IsA("MeshPart") then
			data.mesh_id = instance.MeshId -- v1.3 (clave para replicar el aspecto)
		end
	end
	if instance:IsA("Model") then
		local okPivot, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if okPivot then
			data.pivot = { pivot.Position.X, pivot.Position.Y, pivot.Position.Z }
		end
		if instance.PrimaryPart then
			data.primary_part = instance.PrimaryPart.Name -- v1.3
		end
		local dentro = scriptsDentro(instance)
		if #dentro > 0 then
			data.scripts_inside = dentro -- contiene lógica (v1.2)
		end
	end
	if instance:IsA("LayerCollector") then
		-- v1.3: contenedores de GUI (ScreenGui, BillboardGui, SurfaceGui…)
		local lc = {}
		local okEnabled, enabled = pcall(function()
			return instance.Enabled
		end)
		if okEnabled then
			lc.enabled = enabled
		end
		if instance:IsA("ScreenGui") then
			lc.display_order = instance.DisplayOrder
			lc.reset_on_spawn = instance.ResetOnSpawn
			lc.ignore_gui_inset = instance.IgnoreGuiInset
			lc.screen_insets = instance.ScreenInsets.Name
		elseif instance:IsA("BillboardGui") then
			lc.size = valorJson(instance.Size)
			lc.studs_offset = valorJson(instance.StudsOffset)
			lc.always_on_top = instance.AlwaysOnTop
		elseif instance:IsA("SurfaceGui") then
			lc.canvas_size = valorJson(instance.CanvasSize)
			lc.always_on_top = instance.AlwaysOnTop
		end
		data.layer = lc
	end
	if instance:IsA("GuiObject") then
		local g = {
			visible = instance.Visible,
			size = valorJson(instance.Size),
			position = valorJson(instance.Position),
			anchor_point = valorJson(instance.AnchorPoint),
			background_color = colorATabla(instance.BackgroundColor3),
			background_transparency = instance.BackgroundTransparency,
			z_index = instance.ZIndex,
			layout_order = instance.LayoutOrder,
		}
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			g.text = instance.Text
			g.text_size = instance.TextSize
			g.font = instance.Font.Name
			g.text_color = colorATabla(instance.TextColor3)
		end
		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			-- v1.3: la imagen es lo esencial para replicar una GUI
			g.image = instance.Image
			g.image_color = colorATabla(instance.ImageColor3)
			g.scale_type = instance.ScaleType.Name
		end
		data.gui = g
	end
	if esScript(instance) then
		contadorScripts += 1
		data.source_lines = 1 + select(2, instance.Source:gsub("\n", "\n"))
		data.source = instance.Source
	end
	local hijos = instance:GetChildren()
	if #hijos > 0 then
		data.children = {}
		for _, hijo in ipairs(hijos) do
			if esScript(hijo) then
				table.insert(data.children, describir(hijo, 2)) -- scripts siempre completos (v1.3)
			elseif esGui(hijo) then
				table.insert(data.children, describir(hijo, 6)) -- GUI completa (v1.3)
			elseif profundidad > 1 then
				table.insert(data.children, describir(hijo, profundidad - 1))
			else
				table.insert(data.children, { name = hijo.Name, class = hijo.ClassName })
			end
		end
	end
	return data
end

local function doInspeccionarSeleccion()
	if not guardGithub() then
		return
	end
	local seleccion = Selection:Get()
	if #seleccion == 0 then
		ui:Log("Selección vacía — selecciona algo con el mouse o en el Explorer primero.")
		return
	end
	contadorScripts = 0
	local items = {}
	for _, inst in ipairs(seleccion) do
		table.insert(items, describir(inst, 3)) -- v1.3.1: profundidad base 3 (alcanza scripts dentro de modelos)
	end
	ui:SetStatus("subiendo selección…", "busy")
	local ok, err = pcall(function()
		local nombre = "seleccion_" .. os.date("!%Y%m%d_%H%M%S") .. ".json"
		github:WriteJson(Config.PATHS.snapshots .. "/" .. nombre, {
			tipo = "seleccion",
			capturado_at = nowIso(),
			play_mode = RunService:IsRunning(), -- true si capturaste durante Play (v1.2)
			total = #items,
			scripts = contadorScripts, -- v1.3
			items = items,
		}, "snapshot: selección (" .. #items .. " instancia(s), " .. contadorScripts .. " script(s))")
		ui:Log(
			("✓ Subida: snapshots/%s — %d instancia(s), %d script(s) con código completo"):format(
				nombre,
				#items,
				contadorScripts
			)
		)
	end)
	if not ok then
		reportError("inspeccionar selección", err)
	end
	setStatusReady()
end

-- ---------- subir todo el código del juego (v1.4) ----------

local SERVICIOS_CODIGO = {
	"ServerScriptService",
	"ReplicatedStorage",
	"StarterPlayer",
	"StarterGui",
	"StarterPack",
	"Workspace",
}

-- Recorre los servicios habituales y sube todos los scripts encontrados, un archivo por
-- servicio: snapshots/codigo_<Servicio>_<timestamp>.json (para análisis completo del juego).
local function doSubirCodigo()
	if not guardGithub() then
		return
	end
	ui:SetStatus("recopilando código…", "busy")
	local totalScripts, subidas, fallos = 0, 0, 0
	for _, nombreServicio in ipairs(SERVICIOS_CODIGO) do
		local okServicio, servicio = pcall(function()
			return game:GetService(nombreServicio)
		end)
		if okServicio and servicio then
			local items = {}
			for _, d in ipairs(servicio:GetDescendants()) do
				if esScript(d) then
					table.insert(items, describir(d, 1))
				end
			end
			if #items > 0 then
				totalScripts += #items
				local ok, err = pcall(function()
					local nombre = ("codigo_%s_%s.json"):format(nombreServicio, os.date("!%Y%m%d_%H%M%S"))
					github:WriteJson(Config.PATHS.snapshots .. "/" .. nombre, {
						tipo = "codigo",
						servicio = nombreServicio,
						capturado_at = nowIso(),
						play_mode = RunService:IsRunning(),
						scripts = #items,
						items = items,
					}, ("snapshot: código de %s (%d scripts)"):format(nombreServicio, #items))
				end)
				if ok then
					subidas += 1
					ui:Log(("✓ Código de %s: %d script(s)"):format(nombreServicio, #items))
				else
					fallos += 1
					reportError("subir código de " .. nombreServicio, err)
				end
			end
		end
	end
	if totalScripts == 0 then
		ui:Log("No encontré scripts en los servicios habituales de este place.")
	elseif fallos == 0 then
		ui:Log(("✓ Todo el código subido: %d script(s) en %d archivo(s)"):format(totalScripts, subidas))
	end
	setStatusReady()
end

-- ---------- mapa del entorno (v1.8) ----------

local SERVICIOS_ENTORNO = {
	"Workspace",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPlayer",
	"StarterPack",
	"Lighting",
	"Teams",
}

-- Árbol ligero (sin código fuente ni detalle de GUI): para orientarse en el place.
local function arbolLigero(inst, profundidad)
	local nodo = { name = inst.Name, class = inst.ClassName }
	if profundidad > 1 then
		local hijos = inst:GetChildren()
		if #hijos > 0 then
			nodo.children = {}
			for i, hijo in ipairs(hijos) do
				if i > 40 then
					table.insert(nodo.children, { name = ("…y %d más"):format(#hijos - 40), class = "…" })
					break
				end
				table.insert(nodo.children, arbolLigero(hijo, profundidad - 1))
			end
		end
	end
	return nodo
end

local function doSubirEntorno()
	if not guardGithub() then
		return
	end
	ui:SetStatus("mapeando entorno…", "busy")
	local ok, err = pcall(function()
		local servicios = {}
		for _, nombre in ipairs(SERVICIOS_ENTORNO) do
			local okServicio, servicio = pcall(function()
				return game:GetService(nombre)
			end)
			if okServicio and servicio then
				local hijos = servicio:GetChildren()
				local primeros = {}
				for i, hijo in ipairs(hijos) do
					if i > 60 then
						break
					end
					table.insert(primeros, hijo.ClassName .. ":" .. hijo.Name)
				end
				servicios[nombre] = { total_hijos = #hijos, primeros = primeros }
			end
		end
		local lighting = {}
		pcall(function()
			local l = game:GetService("Lighting")
			lighting.ambient = valorJson(l.Ambient)
			lighting.outdoor_ambient = valorJson(l.OutdoorAmbient)
			lighting.brightness = l.Brightness
			lighting.clock_time = l.ClockTime
			lighting.atmosphere = l:FindFirstChildOfClass("Atmosphere") ~= nil
		end)
		local jugadores = 0
		pcall(function()
			jugadores = #game:GetService("Players"):GetPlayers()
		end)
		local nombre = "entorno_" .. os.date("!%Y%m%d_%H%M%S") .. ".json"
		github:WriteJson(Config.PATHS.snapshots .. "/" .. nombre, {
			tipo = "entorno",
			capturado_at = nowIso(),
			play_mode = RunService:IsRunning(),
			jugadores = jugadores,
			servicios = servicios,
			lighting = lighting,
			workspace = arbolLigero(workspace, 2),
		}, "snapshot: mapa del entorno")
		ui:Log("✓ Entorno subido: snapshots/" .. nombre)
	end)
	if not ok then
		reportError("mapear entorno", err)
	end
	setStatusReady()
end

-- ---------- chat con el agente (v1.7) ----------
-- Canal: chat/inbox/ (mensajes del usuario) ↔ chat/outbox/ (respuestas del agente).
-- El agente no está siempre activo: escribe aquí y avísale en Notion («lee el chat»);
-- él lee inbox/, deja su respuesta en outbox/ y el plugin la muestra solo (sondeo 20s).

local CHAT_IN = "chat/inbox"
local CHAT_OUT = "chat/outbox"
local chatVistos = {}
local chatPrimeraPasada = true

local function doEnviarChat(texto)
	texto = texto:gsub("^%s*(.-)%s*$", "%1")
	if texto == "" then
		return
	end
	if not guardGithub() then
		return
	end
	ui:AddChatBubble("usuario", texto)
	local ok, err = pcall(function()
		github:WriteJson(CHAT_IN .. "/msg_" .. os.date("!%Y%m%d_%H%M%S") .. ".json", {
			autor = "usuario",
			texto = texto,
			enviado_at = nowIso(),
		}, "chat: mensaje del usuario")
	end)
	if ok then
		ui:Log("✓ Mensaje enviado al agente (avísale en Notion: «lee el chat»).")
	else
		reportError("enviar mensaje de chat", err)
	end
end

local function revisarChat()
	if not github then
		return
	end
	local ok, archivos = pcall(function()
		return github:ListFiles(CHAT_OUT)
	end)
	if not ok or type(archivos) ~= "table" then
		return
	end
	local huboRespuesta = false
	for _, archivo in ipairs(archivos) do
		if archivo.name:match("^resp_%d%d%d%d%d%d%d%d_%d%d%d%d%d%d%.json$") and not chatVistos[archivo.name] then
			chatVistos[archivo.name] = true
			if not chatPrimeraPasada then
				local ok2, resp = pcall(function()
					return github:ReadJson(archivo.path)
				end)
				if ok2 and resp and resp.texto then
					ui:AddChatBubble("agente", resp.texto)
					ui:Log("💬 Respuesta del agente recibida en el chat.")
					huboRespuesta = true
				end
			end
		end
	end
	chatPrimeraPasada = false
	if huboRespuesta and doSync then
		-- las respuestas suelen venir con comandos nuevos: sincroniza en silencio (v1.8)
		pcall(doSync, true)
	end
end

-- ---------- highlight al pasar el cursor (v1.2/v1.8) ----------

local hoverHighlight = nil
local hoverConnection = nil
local ultimoHover = nil

local function obtenerHighlight()
	if not hoverHighlight then
		hoverHighlight = Instance.new("Highlight")
		hoverHighlight.Name = "_RBX_HoverHighlight"
		hoverHighlight.FillTransparency = 1
		hoverHighlight.OutlineColor = Color3.fromRGB(0, 220, 255)
		hoverHighlight.OutlineTransparency = 0
		hoverHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hoverHighlight.Parent = CoreGui
	end
	return hoverHighlight
end

-- detalle rápido del objeto bajo el cursor (v1.8): tamaño (BasePart) o nº de hijos (Model)
local function detalleHover(adorno)
	if adorno:IsA("BasePart") then
		local s = adorno.Size
		return ("%.0f×%.0f×%.0f studs"):format(s.X, s.Y, s.Z)
	end
	if adorno:IsA("Model") then
		return ("%d hijos"):format(#adorno:GetChildren())
	end
	return nil
end

local function iniciarHover()
	local mouse = plugin:GetMouse()
	hoverConnection = RunService.Heartbeat:Connect(function()
		local target = mouse.Target
		if target ~= ultimoHover then
			ultimoHover = target
			if target then
				-- adorneamos el modelo contenedor si existe (más legible que la part suelta)
				local adorno = target:FindFirstAncestorOfClass("Model") or target
				obtenerHighlight().Adornee = adorno
				ui:SetHover(adorno:GetFullName(), adorno.ClassName, detalleHover(adorno))
			else
				if hoverHighlight then
					hoverHighlight.Adornee = nil
				end
				ui:SetHover(nil)
			end
		end
	end)
end

local function detenerHover()
	if hoverConnection then
		hoverConnection:Disconnect()
		hoverConnection = nil
	end
	if hoverHighlight then
		hoverHighlight.Adornee = nil
	end
	ultimoHover = nil
end

-- ---------- sync ----------
-- silencioso = true: no ensucia el registro si no cambió el número de comandos (v1.8).
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

ui = UI.new(widget, {
	onSync = function()
		doSync()
	end,
	onUndo = doUndo,
	onSaveToken = onSaveToken,
	onInspectSelection = doInspeccionarSeleccion,
	onUploadCode = doSubirCodigo,
	onUploadEnvironment = doSubirEntorno,
	onSendChat = doEnviarChat,
})

-- highlight del cursor: activo solo mientras el panel esté abierto (v1.2)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled then
		iniciarHover()
	else
		detenerHover()
	end
end)
plugin.Unloading:Connect(detenerHover)

-- sondeo periódico (v1.7/v1.8): chat cada 20s + sync silencioso cada 60s,
-- solo mientras el panel esté abierto.
task.spawn(function()
	local tick = 0
	while true do
		if widget.Enabled then
			pcall(revisarChat)
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

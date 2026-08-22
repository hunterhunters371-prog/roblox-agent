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
-- v1.9: botón "🧬 Replicar" — la selección se captura como plano rejugable
--        (snapshots/plan_<ts>.json) para la nueva op replicate_instance; el plano
--        incluye geometría, propiedades, GUI, scripts y soldaduras internas.
-- v1.9.1: captura por cursor cuando la selección está vacía (reconoce objetos
--        creados por código en modo Play) + cola local de snapshots: en Play
--        Studio bloquea el HTTP del plugin ("can only be executed by game
--        server") y las capturas suben solas al detener la simulación.
-- v1.9.2: la réplica y la captura señalan QUÉ se agregó: el registro lista cada
--        copia con su path, nº de nodos y scripts, y el result.json del comando
--        trae data.copias con ese detalle.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local HttpService = game:GetService("HttpService")
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Config = require(script.Config)
local GitHub = require(script.GitHub)
local Validator = require(script.Validator)
local Executor = require(script.Executor)
local Ops = require(script.Ops)
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
-- v1.9.1: cursor para capturar sin selección + cola de snapshots en modo Play
local ultimoHover = nil
local pendientesSubida = {}

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
	local mensajeLower = message:lower()
	if mensajeLower:find("can only be executed by game server") then
		message ..= " — Studio bloquea el HTTP del plugin en modo Play; las capturas quedan en cola y suben al detener la simulación."
	elseif mensajeLower:find("http") and mensajeLower:find("enabled") then
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

-- ---------- captura por cursor y cola Play (v1.9.1) ----------

-- Objetivo para inspección/réplica: la selección de Studio si la hay; si está
-- vacía (en modo Play el click sobre el mundo no selecciona), el objeto bajo
-- el cursor — así también se reconocen objetos creados por código en ejecución.
local function objetivoActual()
	local seleccion = Selection:Get()
	if #seleccion > 0 then
		return seleccion, "selección"
	end
	local ok, adorno = pcall(function()
		if ultimoHover then
			return ultimoHover:FindFirstAncestorOfClass("Model") or ultimoHover
		end
		return nil
	end)
	if ok and adorno then
		return { adorno }, "cursor"
	end
	return nil, nil
end

-- En modo Play, Studio bloquea el HTTP del plugin con este error.
local function esErrorHttpDePlay(err)
	local mensaje = (type(err) == "table" and err.message) or tostring(err)
	return mensaje:lower():find("can only be executed by game server") ~= nil
end

-- Sube las capturas que quedaron en cola durante el modo Play.
local function flushPendientes()
	if not github or #pendientesSubida == 0 then
		return
	end
	local enCola = pendientesSubida
	pendientesSubida = {}
	local subidos = 0
	for _, item in ipairs(enCola) do
		local ok = pcall(function()
			github:WriteJson(Config.PATHS.snapshots .. "/" .. item.nombre, item.tabla, item.mensaje)
		end)
		if ok then
			subidos += 1
		else
			table.insert(pendientesSubida, item) -- sigue en cola para el próximo intento
		end
	end
	if subidos > 0 then
		ui:Log(("✓ Cola de Play subida: %d snapshot(s) a snapshots/"):format(subidos))
	end
end

-- Sube un snapshot; si HTTP está bloqueado (Play), lo deja en cola local.
-- Devuelve true si subió, false si quedó en cola; otros errores se relanzan.
local function subirSnapshot(nombre, tabla, mensaje)
	local ok, err = pcall(function()
		github:WriteJson(Config.PATHS.snapshots .. "/" .. nombre, tabla, mensaje)
	end)
	if ok then
		return true
	end
	if esErrorHttpDePlay(err) then
		table.insert(pendientesSubida, { nombre = nombre, tabla = tabla, mensaje = mensaje })
		ui:Log(
			("⏸ HTTP bloqueado en modo Play — %s queda en cola (%d); sube solo al detener la simulación."):format(
				nombre,
				#pendientesSubida
			)
		)
		return false
	end
	error(err, 0)
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
	-- v1.9.2: señalar qué objeto o script se agregó en cada copia
	for _, r in ipairs(results) do
		if type(r.data) == "table" and type(r.data.copias) == "table" then
			for _, copia in ipairs(r.data.copias) do
				local extra = ("%d nodos"):format(copia.nodos or 0)
				if type(copia.scripts) == "table" and #copia.scripts > 0 then
					extra ..= (" · scripts: %s"):format(table.concat(copia.scripts, ", "))
				end
				ui:Log(("✓ agregado %s → %s (%s)"):format(copia.nombre, copia.path, extra))
			end
		end
	end
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
	local objetivos, origen = objetivoActual()
	if not objetivos then
		ui:Log("Selección vacía y nada bajo el cursor — apunta al objeto con el mouse o selecciónalo en el Explorer.")
		return
	end
	if origen == "cursor" then
		ui:Log("Sin selección: uso el objeto bajo el cursor → " .. objetivos[1]:GetFullName())
	end
	contadorScripts = 0
	local items = {}
	for _, inst in ipairs(objetivos) do
		table.insert(items, describir(inst, 3)) -- v1.3.1: profundidad base 3 (alcanza scripts dentro de modelos)
	end
	ui:SetStatus("subiendo selección…", "busy")
	local ok, err = pcall(function()
		local nombre = "seleccion_" .. os.date("!%Y%m%d_%H%M%S") .. ".json"
		local subio = subirSnapshot(nombre, {
			tipo = "seleccion",
			capturado_at = nowIso(),
			play_mode = RunService:IsRunning(), -- true si capturaste durante Play (v1.2)
			total = #items,
			scripts = contadorScripts, -- v1.3
			items = items,
		}, "snapshot: selección (" .. #items .. " instancia(s), " .. contadorScripts .. " script(s))")
		if subio then
			ui:Log(
				("✓ Subida: snapshots/%s — %d instancia(s), %d script(s) con código completo"):format(
					nombre,
					#items,
					contadorScripts
				)
			)
		end
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
	local totalScripts, subidas, fallos, enCola = 0, 0, 0, 0 -- v1.9.1: enCola = snapshots esperando fin de Play
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
				local subio = false
				local ok, err = pcall(function()
					local nombre = ("codigo_%s_%s.json"):format(nombreServicio, os.date("!%Y%m%d_%H%M%S"))
					subio = subirSnapshot(nombre, {
						tipo = "codigo",
						servicio = nombreServicio,
						capturado_at = nowIso(),
						play_mode = RunService:IsRunning(),
						scripts = #items,
						items = items,
					}, ("snapshot: código de %s (%d scripts)"):format(nombreServicio, #items))
				end)
				if ok and subio then
					subidas += 1
					ui:Log(("✓ Código de %s: %d script(s)"):format(nombreServicio, #items))
				elseif ok then
					enCola += 1 -- v1.9.1: HTTP bloqueado en Play, queda en cola
				else
					fallos += 1
					reportError("subir código de " .. nombreServicio, err)
				end
			end
		end
	end
	if totalScripts == 0 then
		ui:Log("No encontré scripts en los servicios habituales de este place.")
	elseif fallos == 0 and enCola == 0 then
		ui:Log(("✓ Todo el código subido: %d script(s) en %d archivo(s)"):format(totalScripts, subidas))
	elseif fallos == 0 then
		ui:Log(("✓ Código: %d archivo(s) subidos, %d en cola (suben al detener Play)"):format(subidas, enCola))
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
		local subio = subirSnapshot(nombre, {
			tipo = "entorno",
			capturado_at = nowIso(),
			play_mode = RunService:IsRunning(),
			jugadores = jugadores,
			servicios = servicios,
			lighting = lighting,
			workspace = arbolLigero(workspace, 2),
		}, "snapshot: mapa del entorno")
		if subio then
			ui:Log("✓ Entorno subido: snapshots/" .. nombre)
		end
	end)
	if not ok then
		reportError("mapear entorno", err)
	end
	setStatusReady()
end

-- ---------- plano de réplica de la selección (v1.9) ----------

local function contarNodos(plano)
	local n = 1
	for _, hijo in ipairs(plano.children or {}) do
		n += contarNodos(hijo)
	end
	return n
end

-- v1.9.2: scripts del plano (para que el registro los señale)
local function contarScriptsPlano(plano)
	local n = plano.source ~= nil and 1 or 0
	for _, hijo in ipairs(plano.children or {}) do
		n += contarScriptsPlano(hijo)
	end
	return n
end

-- Captura la selección como plano rejugable (Ops.CaptureBlueprint) y lo sube a
-- snapshots/plan_<ts>.json. El agente lo rejuega con replicate_instance: pasa el
-- plano como 'spec', o usa 'path' con el objeto en vivo. Opciones: new_parent
-- (obligatorio), new_name, offset, count (1-50) y step.
local function doCapturarPlan()
	if not guardGithub() then
		return
	end
	local objetivos, origen = objetivoActual()
	if not objetivos then
		ui:Log("Selección vacía y nada bajo el cursor — apunta al objeto con el mouse o selecciónalo en el Explorer.")
		return
	end
	if origen == "cursor" then
		ui:Log("Sin selección: uso el objeto bajo el cursor → " .. objetivos[1]:GetFullName())
	end
	ui:SetStatus("capturando plano…", "busy")
	local ok, err = pcall(function()
		local planos = {}
		local nodos = 0
		local scripts = 0 -- v1.9.2
		for _, inst in ipairs(objetivos) do
			local plano = Ops.CaptureBlueprint(inst, 10, true)
			table.insert(planos, plano)
			nodos += contarNodos(plano)
			scripts += contarScriptsPlano(plano)
		end
		local nombre = "plan_" .. os.date("!%Y%m%d_%H%M%S") .. ".json"
		local subio = subirSnapshot(nombre, {
			tipo = "plan_replica",
			capturado_at = nowIso(),
			play_mode = RunService:IsRunning(),
			total = #planos,
			nodos = nodos,
			scripts = scripts, -- v1.9.2
			instrucciones = "Rejugable con la op replicate_instance: pasa cada plano como 'spec', o usa 'path' con el objeto en vivo. Opciones: new_parent (obligatorio), new_name, offset, count (1-50), step.",
			planos = planos,
		}, ("snapshot: plano de réplica (%d raíz/raíces, %d nodos)"):format(#planos, nodos))
		if subio then
			ui:Log(
				("✓ Plano subido: snapshots/%s — %d raíz/raíces, %d nodos, %d script(s)"):format(
					nombre,
					#planos,
					nodos,
					scripts
				)
			)
		end
	end)
	if not ok then
		reportError("capturar plano", err)
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
-- (ultimoHover vive arriba, en el estado del controlador — v1.9.1)

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
		pcall(flushPendientes) -- v1.9.1: si hubo capturas en cola (Play), suben aquí
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
	onCapturePlan = doCapturarPlan, -- v1.9
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

-- v1.9.1: al detener la simulación, las capturas en cola suben solas
RunService.RunStateChanged:Connect(function(state)
	if state == Enum.RunState.Stopped then
		task.defer(flushPendientes)
	end
end)

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

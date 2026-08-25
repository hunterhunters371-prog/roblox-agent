-- Inspección de selección (v1.1–v1.3), subida de todo el código (v1.4), mapa del
-- entorno (v1.8) y highlight del cursor (v1.2/v1.8). Submódulo del runtime: lo carga
-- Main.lua. Recibe `env` con getters porque ui/github se crean después del init.

local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Config = require(script.Parent.Config)

local Inspect = {}

function Inspect.init(env)
	local plugin = env.plugin

	local function ui()
		return env.getUi()
	end

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

	-- Scripts contenidos dentro de la instancia: reconoce modelos con lógica propia.
	local function scriptsDentro(instance)
		local lista = {}
		for _, d in ipairs(instance:GetDescendants()) do
			if esScript(d) then
				table.insert(lista, d.ClassName .. ":" .. d.Name)
			end
		end
		return lista
	end

	-- contador de scripts del informe actual (el log confirma cuántos subieron)
	local contadorScripts = 0

	-- Describe una instancia: identidad, atributos, geometría (BasePart/Model), GUI completa,
	-- scripts contenidos y etiqueta del bridge, fuente completa si es script.
	-- Reglas de profundidad: los scripts suben SIEMPRE completos; los árboles de GUI
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
			data.bridge = bridgeTag -- lo creó el agente en ese comando
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
				data.shape = shape
			end
			if instance:IsA("MeshPart") then
				data.mesh_id = instance.MeshId -- clave para replicar el aspecto
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
				data.primary_part = instance.PrimaryPart.Name
			end
			local dentro = scriptsDentro(instance)
			if #dentro > 0 then
				data.scripts_inside = dentro -- contiene lógica
			end
		end
		if instance:IsA("LayerCollector") then
			-- contenedores de GUI (ScreenGui, BillboardGui, SurfaceGui…)
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
				-- la imagen es lo esencial para replicar una GUI
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
					table.insert(data.children, describir(hijo, 2)) -- scripts siempre completos
				elseif esGui(hijo) then
					table.insert(data.children, describir(hijo, 6)) -- GUI completa
				elseif profundidad > 1 then
					table.insert(data.children, describir(hijo, profundidad - 1))
				else
					table.insert(data.children, { name = hijo.Name, class = hijo.ClassName })
				end
			end
		end
		return data
	end

	-- ---------- botón Selección ----------

	local function seleccion()
		if not env.guardGithub() then
			return
		end
		local sel = Selection:Get()
		if #sel == 0 then
			ui():Log("Selección vacía — selecciona algo con el mouse o en el Explorer primero.")
			return
		end
		contadorScripts = 0
		local items = {}
		for _, inst in ipairs(sel) do
			table.insert(items, describir(inst, 3)) -- profundidad base 3 (alcanza scripts dentro de modelos)
		end
		ui():SetStatus("subiendo selección…", "busy")
		local ok, err = pcall(function()
			local nombre = "seleccion_" .. os.date("!%Y%m%d_%H%M%S") .. ".json"
			env.getGithub():WriteJson(Config.PATHS.snapshots .. "/" .. nombre, {
				tipo = "seleccion",
				capturado_at = env.nowIso(),
				play_mode = RunService:IsRunning(), -- true si capturaste durante Play
				total = #items,
				scripts = contadorScripts,
				items = items,
			}, "snapshot: selección (" .. #items .. " instancia(s), " .. contadorScripts .. " script(s))")
			ui():Log(
				("✓ Subida: snapshots/%s — %d instancia(s), %d script(s) con código completo"):format(
					nombre,
					#items,
					contadorScripts
				)
			)
		end)
		if not ok then
			env.reportError("inspeccionar selección", err)
		end
		env.setStatusReady()
	end

	-- ---------- botón Código: sube TODOS los scripts del juego, un archivo por servicio ----------

	local SERVICIOS_CODIGO = {
		"ServerScriptService",
		"ReplicatedStorage",
		"StarterPlayer",
		"StarterGui",
		"StarterPack",
		"Workspace",
	}

	local function codigo()
		if not env.guardGithub() then
			return
		end
		ui():SetStatus("recopilando código…", "busy")
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
						env.getGithub():WriteJson(Config.PATHS.snapshots .. "/" .. nombre, {
							tipo = "codigo",
							servicio = nombreServicio,
							capturado_at = env.nowIso(),
							play_mode = RunService:IsRunning(),
							scripts = #items,
							items = items,
						}, ("snapshot: código de %s (%d scripts)"):format(nombreServicio, #items))
					end)
					if ok then
						subidas += 1
						ui():Log(("✓ Código de %s: %d script(s)"):format(nombreServicio, #items))
					else
						fallos += 1
						env.reportError("subir código de " .. nombreServicio, err)
					end
				end
			end
		end
		if totalScripts == 0 then
			ui():Log("No encontré scripts en los servicios habituales de este place.")
		elseif fallos == 0 then
			ui():Log(("✓ Todo el código subido: %d script(s) en %d archivo(s)"):format(totalScripts, subidas))
		end
		env.setStatusReady()
	end

	-- ---------- botón Entorno: mapa ligero del place ----------

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

	local function entorno()
		if not env.guardGithub() then
			return
		end
		ui():SetStatus("mapeando entorno…", "busy")
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
			env.getGithub():WriteJson(Config.PATHS.snapshots .. "/" .. nombre, {
				tipo = "entorno",
				capturado_at = env.nowIso(),
				play_mode = RunService:IsRunning(),
				jugadores = jugadores,
				servicios = servicios,
				lighting = lighting,
				workspace = arbolLigero(workspace, 2),
			}, "snapshot: mapa del entorno")
			ui():Log("✓ Entorno subido: snapshots/" .. nombre)
		end)
		if not ok then
			env.reportError("mapear entorno", err)
		end
		env.setStatusReady()
	end

	-- ---------- highlight al pasar el cursor ----------

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

	-- detalle rápido del objeto bajo el cursor: tamaño (BasePart) o nº de hijos (Model)
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
		if hoverConnection then
			return -- ya activo
		end
		local mouse = plugin:GetMouse()
		hoverConnection = RunService.Heartbeat:Connect(function()
			local target = mouse.Target
			if target ~= ultimoHover then
				ultimoHover = target
				if target then
					-- adorneamos el modelo contenedor si existe (más legible que la part suelta)
					local adorno = target:FindFirstAncestorOfClass("Model") or target
					obtenerHighlight().Adornee = adorno
					ui():SetHover(adorno:GetFullName(), adorno.ClassName, detalleHover(adorno))
				else
					if hoverHighlight then
						hoverHighlight.Adornee = nil
					end
					ui():SetHover(nil)
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

	return {
		seleccion = seleccion,
		codigo = codigo,
		entorno = entorno,
		iniciarHover = iniciarHover,
		detenerHover = detenerHover,
	}
end

return Inspect

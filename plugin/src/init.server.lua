-- Roblox Agent Bridge — LOADER (v2.1).
-- Este es el ÚNICO archivo que se instala a mano en Studio (una sola vez). Descarga
-- el runtime completo (Main, UI, Ops, …) desde GitHub y lo ejecuta. El botón
-- "⟳ Actualizar" (o abrir el panel tras 5 min) vuelve a descargarlo y lo reinicia
-- EN CALIENTE: las versiones nuevas ya NO requieren reinstalar el plugin.
-- Solo si cambia ESTE archivo hará falta reinstalar (raro; se avisa en el README).
--
-- OJO: instalar NO es conectar Rojo. «Connect» sincroniza el código DENTRO del place
-- (aparece un RobloxAgentBridge en el Explorador) y ahí no corre con permisos de plugin.
-- Los pasos correctos están en plugin/INSTALAR.md.
--
-- v2.1 (correcciones):
--   · el título del panel muestra SIEMPRE la versión en marcha (antes solo durante la
--     descarga), así se ve de un vistazo si la actualización entró.
--   · el chip de versión de la UI está escrito a mano en UI.lua; ahora se reescribe con
--     la versión real del runtime (antes mostraba una versión vieja para siempre).
--   · ⟳ Actualizar avisa «ya al día» cuando no hay versión nueva (antes: ninguna señal).
--   · comprobación periódica mientras el panel está abierto, no solo al abrirlo.
--   · cache-busting con os.time(): os.clock() reinicia en cada sesión de Studio y el CDN
--     de raw.githubusercontent podía devolver una copia cacheada (¡versión vieja!).
--   · si la descarga falla al arrancar Studio ya no se fuerza la apertura del panel.
--
-- Seguridad: el runtime se descarga del repo oficial por HTTPS (es público: lectura sin
-- token) y cada versión queda registrada en el historial git (auditable).

local HttpService = game:GetService("HttpService")

local OWNER = "hunterhunters371-prog"
local REPO = "roblox-agent"
local BRANCH = "main"
local RAW_BASE = ("https://raw.githubusercontent.com/%s/%s/%s/plugin/"):format(OWNER, REPO, BRANCH)
local LOADER_VERSION = "2.1"
local RECHECK_SECONDS = 300

-- ---------- toolbar + widget (permanentes) ----------

local toolbar = plugin:CreateToolbar("Roblox Agent Bridge")
local openButton = toolbar:CreateButton("Agent Bridge", "Abrir el panel de Roblox Agent Bridge", "")
openButton.ClickableWhenViewportHidden = true
local updateButton = toolbar:CreateButton(
	"⟳ Actualizar",
	"Descargar la última versión del plugin desde GitHub y reiniciarlo en caliente",
	""
)
updateButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right, -- dock inicial
	false, -- habilitado al inicio
	false, -- no sobreescribir estado previo
	440, -- ancho default
	560, -- alto default
	340, -- ancho mínimo
	480 -- alto mínimo
)
local widget = plugin:CreateDockWidgetPluginGui("RobloxAgentBridge", widgetInfo)
widget.Title = "Roblox Agent Bridge"
openButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local function setTitulo(extra)
	widget.Title = "Roblox Agent Bridge" .. (extra and (" — " .. extra) or "")
end

-- El chip de versión de la cabecera vive dentro de UI.lua con un valor fijo ("v1.8"…).
-- Tras arrancar el runtime lo reescribimos con la versión realmente en marcha: si no, el
-- panel muestra una versión antigua y parece que no se actualizó nada.
local function sincronizarChip(version)
	if not version then
		return
	end
	for _, descendant in ipairs(widget:GetDescendants()) do
		if descendant:IsA("TextLabel") and descendant.Text:match("^v%d") then
			descendant.Text = "v" .. version
		end
	end
end

-- ---------- estado del runtime vivo ----------

local runtimeFolder = nil -- Folder con los ModuleScripts descargados
local mainModule = nil -- tabla devuelta por require(Runtime.Main)
local stopActual = nil -- stop() del runtime en marcha
local versionActual = nil
local actualizando = false
local ultimaComprobacion = 0
local descargado = false -- true cuando Studio descarga el plugin (corta el bucle)

local actualizar -- declaración anticipada: la usa el botón de emergencia

-- ---------- descarga ----------

local function fetchText(relPath)
	-- el CDN de raw cachea unos minutos: el query lo evita. os.time() cambia entre
	-- sesiones de Studio (os.clock() no) y el random cubre dos intentos en el mismo segundo.
	local url = ("%s%s?t=%d_%d"):format(RAW_BASE, relPath, os.time(), math.random(0, 999999))
	local ok, body = pcall(function()
		return HttpService:GetAsync(url, true)
	end)
	if not ok then
		return nil, tostring(body)
	end
	return body
end

local function construirRuntime(files)
	local staging = Instance.new("Folder")
	staging.Name = "RuntimeStaging"
	staging.Parent = script
	for _, fileName in ipairs(files) do
		local source, err = fetchText("src/" .. tostring(fileName))
		if not source then
			staging:Destroy()
			return nil, ("no se pudo descargar %s: %s"):format(tostring(fileName), tostring(err))
		end
		local module = Instance.new("ModuleScript")
		module.Name = (tostring(fileName):gsub("%.lua$", ""))
		module.Source = source
		module.Parent = staging
	end
	return staging
end

-- ---------- interfaz mínima de emergencia (cuando no hay runtime) ----------

local function mostrarFallback(detalle, abrir)
	for _, child in ipairs(widget:GetChildren()) do
		child:Destroy()
	end
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = widget
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(230, 230, 235)
	label.TextWrapped = true
	label.TextSize = 13
	label.Font = Enum.Font.Gotham
	label.Position = UDim2.new(0, 12, 0, 12)
	label.Size = UDim2.new(1, -24, 0, 170)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "No se pudo descargar el runtime del Bridge.\n\n"
		.. tostring(detalle)
		.. "\n\nComprueba tu conexión y que el place tenga «Allow HTTP Requests» y «Enable Studio Access to API Services» (Game Settings → Security), y pulsa Reintentar o ⟳ Actualizar en la barra."
	label.Parent = frame
	local boton = Instance.new("TextButton")
	boton.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
	boton.TextColor3 = Color3.fromRGB(255, 255, 255)
	boton.Text = "Reintentar"
	boton.TextSize = 13
	boton.Font = Enum.Font.GothamBold
	boton.Position = UDim2.new(0, 12, 0, 190)
	boton.Size = UDim2.new(0, 110, 0, 30)
	boton.Parent = frame
	boton.MouseButton1Click:Connect(function()
		task.spawn(function()
			actualizar(true)
		end)
	end)
	if abrir then
		widget.Enabled = true
	end
end

-- ---------- actualización en caliente ----------

-- manual = true cuando lo pide el usuario (⟳ Actualizar / Reintentar): en ese caso sí
-- damos señales visibles aunque no haya nada nuevo.
actualizar = function(manual)
	if actualizando then
		return
	end
	actualizando = true
	ultimaComprobacion = os.time()
	local ok, err = pcall(function()
		setTitulo("comprobando versión…")
		local manifestRaw, fetchErr = fetchText("version.json")
		if not manifestRaw then
			error("version.json inaccesible: " .. tostring(fetchErr), 0)
		end
		local okJson, manifest = pcall(function()
			return HttpService:JSONDecode(manifestRaw)
		end)
		if not okJson or type(manifest) ~= "table" or type(manifest.files) ~= "table" or type(manifest.version) ~= "string" then
			error("version.json con formato inesperado", 0)
		end
		if runtimeFolder and manifest.version == versionActual then
			sincronizarChip(versionActual)
			if manual then
				setTitulo("v" .. versionActual .. " · ya al día")
				task.delay(4, function()
					if versionActual and not actualizando then
						setTitulo("v" .. versionActual)
					end
				end)
			else
				setTitulo("v" .. versionActual)
			end
			return
		end
		setTitulo("descargando v" .. manifest.version .. "…")
		local staging, buildErr = construirRuntime(manifest.files)
		if not staging then
			error(buildErr, 0)
		end
		-- prueba de carga ANTES de tocar el runtime que funciona
		local okReq, mainOrErr = pcall(function()
			return require(staging.Main)
		end)
		if not okReq or type(mainOrErr) ~= "table" or type(mainOrErr.start) ~= "function" then
			staging:Destroy()
			error("el Main.lua descargado no carga: " .. tostring(okReq and "falta start()" or mainOrErr), 0)
		end
		-- apaga el runtime viejo conservando sus módulos (para rollback)
		local oldFolder, oldMain, oldVersion = runtimeFolder, mainModule, versionActual
		if stopActual then
			pcall(stopActual)
			stopActual = nil
		end
		staging.Name = "Runtime"
		local ctx = { plugin = plugin, widget = widget, version = manifest.version, loader = LOADER_VERSION }
		local okStart, stopOrErr = pcall(function()
			return mainOrErr.start(ctx)
		end)
		if not okStart then
			-- rollback: intenta revivir el runtime anterior
			staging:Destroy()
			runtimeFolder, mainModule, versionActual = nil, nil, nil
			if oldFolder and oldMain then
				local okBack, stopBack = pcall(function()
					return oldMain.start({ plugin = plugin, widget = widget, version = oldVersion, loader = LOADER_VERSION })
				end)
				if okBack then
					stopActual = stopBack
					runtimeFolder, mainModule, versionActual = oldFolder, oldMain, oldVersion
					sincronizarChip(oldVersion)
				end
			end
			error("el runtime nuevo falló al arrancar (rollback aplicado): " .. tostring(stopOrErr), 0)
		end
		-- éxito: ahora sí, destruir el runtime viejo
		if oldFolder then
			pcall(function()
				oldFolder:Destroy()
			end)
		end
		stopActual = stopOrErr
		runtimeFolder = staging
		mainModule = mainOrErr
		versionActual = manifest.version
		setTitulo("v" .. manifest.version)
		sincronizarChip(manifest.version)
		print(("[RBX Bridge] runtime v%s en marcha (loader v%s)"):format(manifest.version, LOADER_VERSION))
	end)
	actualizando = false
	if not ok then
		setTitulo(versionActual and ("v" .. versionActual .. " · falló la actualización") or "actualización falló")
		warn("[RBX Bridge loader] " .. tostring(err))
		if runtimeFolder == nil then
			mostrarFallback(tostring(err), manual == true)
		end
	end
end

updateButton.Click:Connect(function()
	task.spawn(function()
		actualizar(true)
	end)
end)

-- Al abrir el panel, si han pasado > 5 min desde la última comprobación, mira si hay
-- versión nueva (el agente pudo publicarla mientras tanto). Si ya estás al día no pasa nada.
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled and os.time() - ultimaComprobacion > RECHECK_SECONDS then
		task.spawn(function()
			actualizar(false)
		end)
	end
end)

-- …y también cada 5 min con el panel abierto, sin tener que cerrarlo y abrirlo.
task.spawn(function()
	while not descargado do
		task.wait(60)
		if not descargado and widget.Enabled and not actualizando and os.time() - ultimaComprobacion > RECHECK_SECONDS then
			actualizar(false)
		end
	end
end)

plugin.Unloading:Connect(function()
	descargado = true
	if stopActual then
		pcall(stopActual)
	end
end)

task.spawn(function()
	actualizar(false)
end)

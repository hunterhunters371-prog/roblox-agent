-- UI del dock widget: estado, lista de comandos, acciones, chat y log.
-- v1.1: botón "🔍 Selección" (inspeccionar lo seleccionado con el mouse).
-- v1.2: fila "hover" que muestra el path del objeto bajo el cursor.
-- v1.4: botón "⬆ Código" (subir todos los scripts del juego, un archivo por servicio).
-- v1.5: rediseño visual — paleta oscura, hover en botones, franja de estado, secciones.
-- v1.6: barra de progreso (SetProgress), log con colores (✓/ERROR), presión en botones.
-- v1.7: pestañas COMANDOS / 💬 CHAT — burbujas de conversación con el agente.
-- v1.8: botón "🗺 Entorno", hover con tamaño/hijos del objeto, saludo de bienvenida
--        en el chat explicando cómo pedir cosas al agente.
-- v1.9: botón "🧬 Replicar" (captura el plano rejugable de la selección).
-- v1.9.1: chip de versión (el comportamiento de modo Play vive en init.server.lua).
-- v1.9.2: chip de versión (el detalle de qué se agregó vive en Ops/init).
-- v1.9.3: chip de versión (token robusto vive en init/GitHub).

local UI = {}
UI.__index = UI

local VERSION = "v1.9.3"

-- paleta (oscura, tipo Notion)
local COLOR_BG = Color3.fromRGB(25, 25, 25)
local COLOR_PANEL = Color3.fromRGB(32, 32, 32)
local COLOR_CARD = Color3.fromRGB(38, 38, 38)
local COLOR_BORDER = Color3.fromRGB(56, 56, 56)
local COLOR_TEXT = Color3.fromRGB(232, 232, 232)
local COLOR_MUTED = Color3.fromRGB(155, 155, 155)
local COLOR_ACCENT = Color3.fromRGB(35, 131, 226) -- azul Notion
local COLOR_OK = Color3.fromRGB(77, 163, 106) -- verde
local COLOR_WARN = Color3.fromRGB(203, 145, 47) -- ámbar
local COLOR_NEUTRAL = Color3.fromRGB(82, 82, 82)
local COLOR_HOVER = Color3.fromRGB(41, 196, 226) -- cian
local COLOR_CODE = Color3.fromRGB(144, 101, 196) -- violeta
local COLOR_MAP = Color3.fromRGB(62, 132, 128) -- verde azulado
local COLOR_REPLICA = Color3.fromRGB(171, 84, 150) -- magenta (v1.9)
local COLOR_LOG_BG = Color3.fromRGB(20, 20, 20)
local COLOR_LOG_TEXT = Color3.fromRGB(168, 215, 168)
local COLOR_BUBBLE_ME = Color3.fromRGB(43, 78, 120) -- mis mensajes
local COLOR_BUBBLE_ME_TEXT = Color3.fromRGB(150, 190, 235)

local STATE_COLORS = {
	pending = COLOR_WARN,
	["pending (auto)"] = COLOR_ACCENT,
	approved = COLOR_OK,
	processing = COLOR_CODE,
}

local SALUDO_CHAT =
	"¡Hola! 👋 Soy tu agente. Escríbeme aquí como si hablaras conmigo: «agrega una caja», «pon más decoración», «replica 3 veces lo que tengo seleccionado»… Tu mensaje viaja por GitHub; avísame en Notion con «lee el chat» y te respondo aquí mismo. Si pides construir algo, te dejo el comando listo en la pestaña COMANDOS para que pulses Ejecutar. Con el botón 🧬 Replicar me subes el plano del objeto que señales para copiarlo."

local function escaparRich(texto)
	return (texto:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function makeLabel(parent, text, size)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = COLOR_TEXT
	label.Font = Enum.Font.Gotham
	label.TextSize = size or 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

local function rounded(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 6)
	corner.Parent = instance
end

local function bordered(instance)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLOR_BORDER
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
end

-- Botón con efecto hover (aclara) y presión (oscurece al mantener pulsado).
local function makeButton(parent, text, color)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.Text = text
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Parent = parent
	rounded(button, 6)
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.16)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = color
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.2)
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.16)
	end)
	return button
end

-- Pestaña (sin efecto hover: su color lo controla SetTab).
local function makeTab(parent, text)
	local tab = Instance.new("TextButton")
	tab.BackgroundColor3 = COLOR_NEUTRAL
	tab.TextColor3 = Color3.new(1, 1, 1)
	tab.Font = Enum.Font.GothamBold
	tab.TextSize = 11
	tab.Text = text
	tab.AutoButtonColor = false
	tab.BorderSizePixel = 0
	tab.Parent = parent
	rounded(tab, 6)
	return tab
end

local function sectionLabel(parent, text, order)
	local label = makeLabel(parent, text, 10)
	label.TextColor3 = COLOR_MUTED
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.new(1, 0, 0, 16)
	label.LayoutOrder = order
	return label
end

-- handlers: { onSync, onUndo, onSaveToken, onInspectSelection, onUploadCode, onUploadEnvironment, onCapturePlan, onSendChat }
function UI.new(widget, handlers)
	local self = setmetatable({}, UI)

	local root = Instance.new("Frame")
	root.BackgroundColor3 = COLOR_BG
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = root

	-- cabecera: icono + título + chip de versión
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 22)
	header.LayoutOrder = 1
	header.Parent = root

	local title = makeLabel(header, "🔌 ROBLOX AGENT BRIDGE", 14)
	title.Font = Enum.Font.GothamBold
	title.Size = UDim2.new(1, -60, 1, 0)

	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = COLOR_CARD
	chip.Size = UDim2.new(0, 44, 0, 18)
	chip.Position = UDim2.new(1, -44, 0.5, -9)
	chip.Parent = header
	rounded(chip, 9)
	bordered(chip)
	local chipText = makeLabel(chip, VERSION, 10)
	chipText.TextColor3 = COLOR_MUTED
	chipText.Size = UDim2.fromScale(1, 1)
	chipText.TextXAlignment = Enum.TextXAlignment.Center

	-- estado (pastilla)
	local statusPill = Instance.new("Frame")
	statusPill.BackgroundColor3 = COLOR_PANEL
	statusPill.Size = UDim2.new(1, 0, 0, 24)
	statusPill.LayoutOrder = 2
	statusPill.Parent = root
	rounded(statusPill, 12)
	bordered(statusPill)
	local statusPad = Instance.new("UIPadding")
	statusPad.PaddingLeft = UDim.new(0, 10)
	statusPad.Parent = statusPill

	self._status = makeLabel(statusPill, "● sin token de GitHub", 12)
	self._status.Size = UDim2.fromScale(1, 1)
	self._status.TextColor3 = COLOR_WARN

	-- barra de progreso (v1.6): visible solo mientras un comando se ejecuta
	local progressTrack = Instance.new("Frame")
	progressTrack.BackgroundColor3 = COLOR_CARD
	progressTrack.BorderSizePixel = 0
	progressTrack.Size = UDim2.new(1, 0, 0, 6)
	progressTrack.LayoutOrder = 3
	progressTrack.Visible = false
	progressTrack.Parent = root
	rounded(progressTrack, 3)

	local progressFill = Instance.new("Frame")
	progressFill.BackgroundColor3 = COLOR_ACCENT
	progressFill.BorderSizePixel = 0
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.Parent = progressTrack
	rounded(progressFill, 3)
	self._progressTrack = progressTrack
	self._progressFill = progressFill

	-- fila de token
	local tokenRow = Instance.new("Frame")
	tokenRow.BackgroundTransparency = 1
	tokenRow.Size = UDim2.new(1, 0, 0, 28)
	tokenRow.LayoutOrder = 4
	tokenRow.Parent = root
	local tokenLayout = Instance.new("UIListLayout")
	tokenLayout.FillDirection = Enum.FillDirection.Horizontal
	tokenLayout.Padding = UDim.new(0, 6)
	tokenLayout.Parent = tokenRow

	local tokenBox = Instance.new("TextBox")
	tokenBox.PlaceholderText = "Token de GitHub (fine-grained, solo este repo)"
	tokenBox.PlaceholderColor3 = COLOR_MUTED
	tokenBox.Text = ""
	tokenBox.Size = UDim2.new(1, -90, 1, 0)
	tokenBox.BackgroundColor3 = COLOR_PANEL
	tokenBox.TextColor3 = COLOR_TEXT
	tokenBox.Font = Enum.Font.Gotham
	tokenBox.TextSize = 12
	tokenBox.ClearTextOnFocus = false
	tokenBox.TextXAlignment = Enum.TextXAlignment.Left
	tokenBox.BorderSizePixel = 0
	tokenBox.Parent = tokenRow
	rounded(tokenBox, 6)
	bordered(tokenBox)
	local tokenPad = Instance.new("UIPadding")
	tokenPad.PaddingLeft = UDim.new(0, 8)
	tokenPad.Parent = tokenBox

	local saveToken = makeButton(tokenRow, "Guardar", COLOR_ACCENT)
	saveToken.Size = UDim2.new(0, 84, 1, 0)
	saveToken.MouseButton1Click:Connect(function()
		local token = tokenBox.Text:gsub("^%s*(.-)%s*$", "%1")
		if #token > 0 then
			tokenBox.Text = ""
			handlers.onSaveToken(token)
		end
	end)
	self._tokenRow = tokenRow

	-- acciones principales (3 columnas)
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, 32)
	actions.LayoutOrder = 5
	actions.Parent = root
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.Padding = UDim.new(0, 6)
	actionsLayout.Parent = actions

	local syncButton = makeButton(actions, "⟳ Sync", COLOR_ACCENT)
	syncButton.Size = UDim2.new(0.333, -4, 1, 0)
	syncButton.MouseButton1Click:Connect(handlers.onSync)

	local inspectButton = makeButton(actions, "🔍 Selección", Color3.fromRGB(63, 122, 78))
	inspectButton.Size = UDim2.new(0.333, -4, 1, 0)
	inspectButton.MouseButton1Click:Connect(handlers.onInspectSelection)

	local codeButton = makeButton(actions, "⬆ Código", COLOR_CODE)
	codeButton.Size = UDim2.new(0.334, -4, 1, 0)
	codeButton.MouseButton1Click:Connect(handlers.onUploadCode)

	-- segunda fila de acciones (v1.8/v1.9): réplica + entorno + deshacer
	local actions2 = Instance.new("Frame")
	actions2.BackgroundTransparency = 1
	actions2.Size = UDim2.new(1, 0, 0, 24)
	actions2.LayoutOrder = 6
	actions2.Parent = root
	local actions2Layout = Instance.new("UIListLayout")
	actions2Layout.FillDirection = Enum.FillDirection.Horizontal
	actions2Layout.Padding = UDim.new(0, 6)
	actions2Layout.Parent = actions2

	local replicateButton = makeButton(actions2, "🧬 Replicar", COLOR_REPLICA)
	replicateButton.Size = UDim2.new(0.333, -4, 1, 0)
	replicateButton.TextSize = 11
	replicateButton.Font = Enum.Font.Gotham
	replicateButton.MouseButton1Click:Connect(handlers.onCapturePlan)

	local envButton = makeButton(actions2, "🗺 Entorno", COLOR_MAP)
	envButton.Size = UDim2.new(0.333, -4, 1, 0)
	envButton.TextSize = 11
	envButton.Font = Enum.Font.Gotham
	envButton.MouseButton1Click:Connect(handlers.onUploadEnvironment)

	local undoButton = makeButton(actions2, "↩ Deshacer", COLOR_NEUTRAL)
	undoButton.Size = UDim2.new(0.334, -4, 1, 0)
	undoButton.TextSize = 11
	undoButton.Font = Enum.Font.Gotham
	undoButton.MouseButton1Click:Connect(handlers.onUndo)

	-- fila hover (v1.2/v1.8): tarjeta con clase + detalle + path bajo el cursor
	local hoverCard = Instance.new("Frame")
	hoverCard.BackgroundColor3 = COLOR_PANEL
	hoverCard.Size = UDim2.new(1, 0, 0, 24)
	hoverCard.LayoutOrder = 7
	hoverCard.Parent = root
	rounded(hoverCard, 6)
	bordered(hoverCard)
	local hoverPad = Instance.new("UIPadding")
	hoverPad.PaddingLeft = UDim.new(0, 8)
	hoverPad.Parent = hoverCard

	self._hover = makeLabel(hoverCard, "🖱 (pasa el cursor sobre el mundo)", 11)
	self._hover.Size = UDim2.fromScale(1, 1)
	self._hover.TextColor3 = COLOR_HOVER

	-- pestañas (v1.7): COMANDOS / CHAT
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, 26)
	tabs.LayoutOrder = 8
	tabs.Parent = root
	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 6)
	tabsLayout.Parent = tabs

	self._tabComandos = makeTab(tabs, "COMANDOS")
	self._tabComandos.Size = UDim2.new(0.5, -3, 1, 0)
	self._tabChat = makeTab(tabs, "💬 CHAT CON EL AGENTE")
	self._tabChat.Size = UDim2.new(0.5, -3, 1, 0)

	-- contenedor de contenido (lista de comandos O chat)
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 1, -414)
	content.LayoutOrder = 9
	content.Parent = root

	-- · pestaña comandos: la lista de siempre
	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = COLOR_PANEL
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 1)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = COLOR_NEUTRAL
	list.Parent = content
	rounded(list, 6)
	bordered(list)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = list
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 8)
	listPad.PaddingBottom = UDim.new(0, 8)
	listPad.PaddingLeft = UDim.new(0, 8)
	listPad.PaddingRight = UDim.new(0, 8)
	listPad.Parent = list
	self._list = list

	-- · pestaña chat (v1.7): burbujas + caja de texto
	local chatFrame = Instance.new("Frame")
	chatFrame.BackgroundTransparency = 1
	chatFrame.Size = UDim2.fromScale(1, 1)
	chatFrame.Visible = false
	chatFrame.Parent = content
	local chatLayout = Instance.new("UIListLayout")
	chatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chatLayout.Padding = UDim.new(0, 6)
	chatLayout.Parent = chatFrame

	local chatScroll = Instance.new("ScrollingFrame")
	chatScroll.BackgroundColor3 = COLOR_PANEL
	chatScroll.BorderSizePixel = 0
	chatScroll.Size = UDim2.new(1, 0, 1, -34)
	chatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	chatScroll.ScrollBarThickness = 3
	chatScroll.ScrollBarImageColor3 = COLOR_NEUTRAL
	chatScroll.LayoutOrder = 1
	chatScroll.Parent = chatFrame
	rounded(chatScroll, 6)
	bordered(chatScroll)
	local bubblesLayout = Instance.new("UIListLayout")
	bubblesLayout.Padding = UDim.new(0, 6)
	bubblesLayout.Parent = chatScroll
	local bubblesPad = Instance.new("UIPadding")
	bubblesPad.PaddingTop = UDim.new(0, 8)
	bubblesPad.PaddingBottom = UDim.new(0, 8)
	bubblesPad.PaddingLeft = UDim.new(0, 8)
	bubblesPad.PaddingRight = UDim.new(0, 8)
	bubblesPad.Parent = chatScroll
	self._chatScroll = chatScroll

	local chatInputRow = Instance.new("Frame")
	chatInputRow.BackgroundTransparency = 1
	chatInputRow.Size = UDim2.new(1, 0, 0, 28)
	chatInputRow.LayoutOrder = 2
	chatInputRow.Parent = chatFrame
	local chatInputLayout = Instance.new("UIListLayout")
	chatInputLayout.FillDirection = Enum.FillDirection.Horizontal
	chatInputLayout.Padding = UDim.new(0, 6)
	chatInputLayout.Parent = chatInputRow

	local chatInput = Instance.new("TextBox")
	chatInput.PlaceholderText = "Pídeme algo: «agrega una caja»…"
	chatInput.PlaceholderColor3 = COLOR_MUTED
	chatInput.Text = ""
	chatInput.Size = UDim2.new(1, -76, 1, 0)
	chatInput.BackgroundColor3 = COLOR_PANEL
	chatInput.TextColor3 = COLOR_TEXT
	chatInput.Font = Enum.Font.Gotham
	chatInput.TextSize = 12
	chatInput.ClearTextOnFocus = false
	chatInput.TextXAlignment = Enum.TextXAlignment.Left
	chatInput.BorderSizePixel = 0
	chatInput.Parent = chatInputRow
	rounded(chatInput, 6)
	bordered(chatInput)
	local chatInputPad = Instance.new("UIPadding")
	chatInputPad.PaddingLeft = UDim.new(0, 8)
	chatInputPad.Parent = chatInput
	self._chatInput = chatInput

	local sendButton = makeButton(chatInputRow, "Enviar", COLOR_ACCENT)
	sendButton.Size = UDim2.new(0, 70, 1, 0)

	local function enviar()
		local texto = chatInput.Text
		if texto:gsub("%s", "") ~= "" then
			chatInput.Text = ""
			handlers.onSendChat(texto)
		end
	end
	sendButton.MouseButton1Click:Connect(enviar)
	chatInput.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			enviar()
		end
	end)

	self._chatFrame = chatFrame
	self._chatSaludado = false

	self._tabComandos.MouseButton1Click:Connect(function()
		self:SetTab("comandos")
	end)
	self._tabChat.MouseButton1Click:Connect(function()
		self:SetTab("chat")
	end)
	self:SetTab("comandos")

	-- sección: registro
	sectionLabel(root, "REGISTRO", 10)

	local log = Instance.new("TextBox")
	log.BackgroundColor3 = COLOR_LOG_BG
	log.TextColor3 = COLOR_LOG_TEXT
	log.Font = Enum.Font.Code
	log.TextSize = 11
	log.TextXAlignment = Enum.TextXAlignment.Left
	log.TextYAlignment = Enum.TextYAlignment.Top
	log.MultiLine = true
	log.ClearTextOnFocus = false
	log.TextEditable = false
	log.RichText = true -- v1.6: líneas coloreadas (✓ / ERROR)
	log.Text = ""
	log.BorderSizePixel = 0
	log.Size = UDim2.new(1, 0, 0, 128)
	log.LayoutOrder = 11
	log.Parent = root
	rounded(log, 6)
	bordered(log)
	local logPad = Instance.new("UIPadding")
	logPad.PaddingTop = UDim.new(0, 6)
	logPad.PaddingLeft = UDim.new(0, 8)
	logPad.PaddingRight = UDim.new(0, 8)
	logPad.Parent = log
	self._log = log

	return self
end

function UI:SetStatus(text, kind)
	self._status.Text = "● " .. text
	if kind == "ok" then
		self._status.TextColor3 = COLOR_OK
	elseif kind == "busy" then
		self._status.TextColor3 = COLOR_ACCENT
	else
		self._status.TextColor3 = COLOR_WARN
	end
end

-- v1.6: barra de progreso de la ejecución. Sin argumentos (o done>=total) = ocultar.
function UI:SetProgress(done, total)
	if not done or not total or total <= 0 or done >= total then
		self._progressTrack.Visible = false
		self._progressFill.Size = UDim2.new(0, 0, 1, 0)
		return
	end
	self._progressTrack.Visible = true
	self._progressFill.Size = UDim2.new(done / total, 0, 1, 0)
end

function UI:ShowTokenRow(visible)
	self._tokenRow.Visible = visible
end

-- v1.7/v1.8: cambia entre comandos y chat; la primera vez que abres el chat, saludo.
function UI:SetTab(nombre)
	local esComandos = nombre == "comandos"
	self._list.Visible = esComandos
	self._chatFrame.Visible = not esComandos
	self._tabComandos.BackgroundColor3 = esComandos and COLOR_ACCENT or COLOR_NEUTRAL
	self._tabChat.BackgroundColor3 = esComandos and COLOR_NEUTRAL or COLOR_ACCENT
	if not esComandos and not self._chatSaludado then
		self._chatSaludado = true
		self:AddChatBubble("agente", SALUDO_CHAT)
	end
end

-- v1.2–v1.8: objeto bajo el cursor: clase, detalle (tamaño/hijos) y path.
function UI:SetHover(path, className, detalle)
	if path then
		local texto = "🖱 " .. (className or "?")
		if detalle then
			texto ..= " · " .. detalle
		end
		texto ..= " — " .. path
		self._hover.Text = texto
	else
		self._hover.Text = "🖱 (pasa el cursor sobre el mundo)"
	end
end

function UI:Log(message)
	local timestamp = DateTime.now():FormatLocalTime("HH:mm:ss", "es-co")
	local linea = ("[%s] %s"):format(timestamp, escaparRich(message))
	if message:sub(1, 5) == "ERROR" then
		linea = ('<font color="rgb(224,108,117)">%s</font>'):format(linea) -- v1.6: errores en rojo
	elseif message:sub(1, 1) == "✓" then
		linea = ('<font color="rgb(120,220,140)">%s</font>'):format(linea) -- v1.6: éxitos en verde
	end
	self._log.Text ..= "\n" .. linea
	self._log.CursorPosition = #self._log.Text + 1
end

-- v1.7: burbuja de chat. autor: "usuario" (derecha, azul) | "agente" (izquierda, gris).
function UI:AddChatBubble(autor, texto)
	local esMio = autor == "usuario"

	-- contenedor de ancho completo para poder "alinear" la burbuja
	local fila = Instance.new("Frame")
	fila.BackgroundTransparency = 1
	fila.Size = UDim2.new(1, 0, 0, 0)
	fila.AutomaticSize = Enum.AutomaticSize.Y
	fila.Parent = self._chatScroll

	local burbuja = Instance.new("Frame")
	burbuja.BackgroundColor3 = esMio and COLOR_BUBBLE_ME or COLOR_CARD
	burbuja.BorderSizePixel = 0
	burbuja.Size = UDim2.new(0.85, 0, 0, 0)
	burbuja.Position = UDim2.new(esMio and 0.15 or 0, 0, 0, 0)
	burbuja.AutomaticSize = Enum.AutomaticSize.Y
	burbuja.Parent = fila
	rounded(burbuja, 8)
	bordered(burbuja)

	local burbujaLayout = Instance.new("UIListLayout")
	burbujaLayout.SortOrder = Enum.SortOrder.LayoutOrder
	burbujaLayout.Padding = UDim.new(0, 2)
	burbujaLayout.Parent = burbuja
	local burbujaPad = Instance.new("UIPadding")
	burbujaPad.PaddingTop = UDim.new(0, 6)
	burbujaPad.PaddingBottom = UDim.new(0, 8)
	burbujaPad.PaddingLeft = UDim.new(0, 10)
	burbujaPad.PaddingRight = UDim.new(0, 10)
	burbujaPad.Parent = burbuja

	local autorLabel = makeLabel(burbuja, esMio and "Tú" or "🤖 Agente", 10)
	autorLabel.TextColor3 = esMio and COLOR_BUBBLE_ME_TEXT or COLOR_MUTED
	autorLabel.Font = Enum.Font.GothamBold
	autorLabel.Size = UDim2.new(1, 0, 0, 12)
	autorLabel.LayoutOrder = 1

	local textoLabel = Instance.new("TextLabel")
	textoLabel.BackgroundTransparency = 1
	textoLabel.TextColor3 = COLOR_TEXT
	textoLabel.Font = Enum.Font.Gotham
	textoLabel.TextSize = 12
	textoLabel.TextXAlignment = Enum.TextXAlignment.Left
	textoLabel.TextYAlignment = Enum.TextYAlignment.Top
	textoLabel.TextWrapped = true
	textoLabel.RichText = true
	textoLabel.Text = escaparRich(texto)
	textoLabel.Size = UDim2.new(1, 0, 0, 0)
	textoLabel.AutomaticSize = Enum.AutomaticSize.Y
	textoLabel.LayoutOrder = 2
	textoLabel.Parent = burbuja

	-- bajar el scroll al final (tras dejar que se recalculen los tamaños)
	task.defer(function()
		self._chatScroll.CanvasPosition = Vector2.new(0, self._chatScroll.AbsoluteCanvasSize.Y)
	end)
end

-- items: { { id, title, state, progress?, actionLabel?, onAction? } }
function UI:SetCommands(items)
	for _, child in ipairs(self._list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #items == 0 then
		local empty = makeLabel(self._list, "📭 Sin comandos activos — pulsa ⟳ Sync", 11)
		empty.Size = UDim2.new(1, 0, 0, 20)
		empty.TextColor3 = COLOR_MUTED
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	for _, item in ipairs(items) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = COLOR_CARD
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 48)
		row.Parent = self._list
		rounded(row, 6)
		bordered(row)

		-- franja de color según el estado (v1.5)
		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = STATE_COLORS[item.state] or COLOR_MUTED
		stripe.BorderSizePixel = 0
		stripe.Size = UDim2.new(0, 4, 1, -12)
		stripe.Position = UDim2.new(0, 6, 0, 6)
		stripe.Parent = row
		rounded(stripe, 2)

		local stateText = item.state
		if item.progress then
			stateText ..= (" (%d/%d)"):format(item.progress.done, item.progress.total)
		end

		local idLabel = makeLabel(row, item.id, 11)
		idLabel.Font = Enum.Font.GothamBold
		idLabel.Size = UDim2.new(1, -116, 0, 16)
		idLabel.Position = UDim2.new(0, 18, 0, 6)

		local infoLabel = makeLabel(row, stateText .. "  ·  " .. item.title, 11)
		infoLabel.TextColor3 = COLOR_MUTED
		infoLabel.Size = UDim2.new(1, -116, 0, 14)
		infoLabel.Position = UDim2.new(0, 18, 0, 24)

		if item.actionLabel and item.onAction then
			local button = makeButton(row, item.actionLabel, COLOR_ACCENT)
			button.Size = UDim2.new(0, 86, 0, 30)
			button.Position = UDim2.new(1, -92, 0.5, -15)
			button.MouseButton1Click:Connect(item.onAction)
		end
	end
end

return UI

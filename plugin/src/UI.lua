-- UI del dock widget: estado, lista de comandos, acciones y log.
-- v1.1: botón "🔍 Selección" (inspeccionar lo seleccionado con el mouse).
-- v1.2: fila "hover" que muestra el path del objeto bajo el cursor.
-- v1.4: botón "⬆ Código" (subir todos los scripts del juego, un archivo por servicio).
-- v1.5: rediseño visual — paleta oscura refinada, botones con hover, filas con franja
--        de color por estado, secciones etiquetadas, log más amplio, chip de versión.

local UI = {}
UI.__index = UI

local VERSION = "v1.5"

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
local COLOR_LOG_BG = Color3.fromRGB(20, 20, 20)
local COLOR_LOG_TEXT = Color3.fromRGB(168, 215, 168)

local STATE_COLORS = {
	pending = COLOR_WARN,
	["pending (auto)"] = COLOR_ACCENT,
	approved = COLOR_OK,
	processing = COLOR_CODE,
}

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

-- Botón con efecto hover (aclara el color base al pasar el mouse).
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
	return button
end

local function sectionLabel(parent, text, order)
	local label = makeLabel(parent, text, 10)
	label.TextColor3 = COLOR_MUTED
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.new(1, 0, 0, 16)
	label.LayoutOrder = order
	return label
end

-- handlers: { onSync, onUndo, onSaveToken, onInspectSelection, onUploadCode }
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

	-- cabecera: título + chip de versión
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 22)
	header.LayoutOrder = 1
	header.Parent = root

	local title = makeLabel(header, "ROBLOX AGENT BRIDGE", 14)
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

	-- fila de token
	local tokenRow = Instance.new("Frame")
	tokenRow.BackgroundTransparency = 1
	tokenRow.Size = UDim2.new(1, 0, 0, 28)
	tokenRow.LayoutOrder = 3
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
	actions.Size = UDim2.new(1, 0, 0, 30)
	actions.LayoutOrder = 4
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

	-- acción secundaria (ancho completo)
	local undoButton = makeButton(root, "↩ Deshacer último comando", COLOR_NEUTRAL)
	undoButton.Size = UDim2.new(1, 0, 0, 24)
	undoButton.TextSize = 11
	undoButton.Font = Enum.Font.Gotham
	undoButton.LayoutOrder = 5
	undoButton.MouseButton1Click:Connect(handlers.onUndo)

	-- fila hover (v1.2): tarjeta con el path bajo el cursor
	local hoverCard = Instance.new("Frame")
	hoverCard.BackgroundColor3 = COLOR_PANEL
	hoverCard.Size = UDim2.new(1, 0, 0, 24)
	hoverCard.LayoutOrder = 6
	hoverCard.Parent = root
	rounded(hoverCard, 6)
	bordered(hoverCard)
	local hoverPad = Instance.new("UIPadding")
	hoverPad.PaddingLeft = UDim.new(0, 8)
	hoverPad.Parent = hoverCard

	self._hover = makeLabel(hoverCard, "🖱 (pasa el cursor sobre el mundo)", 11)
	self._hover.Size = UDim2.fromScale(1, 1)
	self._hover.TextColor3 = COLOR_HOVER

	-- sección: comandos
	sectionLabel(root, "COMANDOS", 7)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = COLOR_PANEL
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 0, 1, -322)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = COLOR_NEUTRAL
	list.LayoutOrder = 8
	list.Parent = root
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

	-- sección: registro
	sectionLabel(root, "REGISTRO", 9)

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
	log.Text = ""
	log.BorderSizePixel = 0
	log.Size = UDim2.new(1, 0, 0, 128)
	log.LayoutOrder = 10
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

function UI:ShowTokenRow(visible)
	self._tokenRow.Visible = visible
end

-- v1.2: actualiza la fila hover con el path bajo el cursor (nil = sin objetivo).
function UI:SetHover(path)
	if path then
		self._hover.Text = "🖱 " .. path
	else
		self._hover.Text = "🖱 (pasa el cursor sobre el mundo)"
	end
end

function UI:Log(message)
	local timestamp = DateTime.now():FormatLocalTime("HH:mm:ss", "es-co")
	self._log.Text ..= ("\n[%s] %s"):format(timestamp, message)
	self._log.CursorPosition = #self._log.Text + 1
end

-- items: { { id, title, state, progress?, actionLabel?, onAction? } }
function UI:SetCommands(items)
	for _, child in ipairs(self._list:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #items == 0 then
		local empty = makeLabel(self._list, "Sin comandos activos. Pulsa ⟳ Sync.", 11)
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

-- UI del dock widget: estado, lista de comandos, acciones y log.
-- v1.1: botón "🔍 Selección" (inspeccionar lo seleccionado con el mouse).
-- v1.2: fila "hover" que muestra el path del objeto bajo el cursor.

local UI = {}
UI.__index = UI

local COLOR_BG = Color3.fromRGB(32, 32, 32)
local COLOR_PANEL = Color3.fromRGB(40, 40, 40)
local COLOR_ROW = Color3.fromRGB(48, 48, 48)
local COLOR_TEXT = Color3.fromRGB(235, 235, 235)
local COLOR_MUTED = Color3.fromRGB(150, 150, 150)
local COLOR_ACCENT = Color3.fromRGB(0, 162, 255)
local COLOR_OK = Color3.fromRGB(80, 200, 120)
local COLOR_WARN = Color3.fromRGB(255, 180, 60)
local COLOR_NEUTRAL = Color3.fromRGB(90, 90, 90)
local COLOR_HOVER = Color3.fromRGB(0, 220, 255)

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

local function makeButton(parent, text)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = COLOR_ACCENT
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.Gotham
	button.TextSize = 12
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	return button
end

local function rounded(instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = instance
end

-- handlers: { onSync, onUndo, onSaveToken, onInspectSelection }
function UI.new(widget, handlers)
	local self = setmetatable({}, UI)

	local root = Instance.new("Frame")
	root.BackgroundColor3 = COLOR_BG
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = root

	local title = makeLabel(root, "ROBLOX AGENT BRIDGE", 14)
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.LayoutOrder = 1

	self._status = makeLabel(root, "● sin token de GitHub", 12)
	self._status.Size = UDim2.new(1, 0, 0, 16)
	self._status.TextColor3 = COLOR_WARN
	self._status.LayoutOrder = 2

	-- fila de token
	local tokenRow = Instance.new("Frame")
	tokenRow.BackgroundTransparency = 1
	tokenRow.Size = UDim2.new(1, 0, 0, 26)
	tokenRow.LayoutOrder = 3
	tokenRow.Parent = root
	local tokenLayout = Instance.new("UIListLayout")
	tokenLayout.FillDirection = Enum.FillDirection.Horizontal
	tokenLayout.Padding = UDim.new(0, 6)
	tokenLayout.Parent = tokenRow

	local tokenBox = Instance.new("TextBox")
	tokenBox.PlaceholderText = "Token de GitHub (fine-grained, solo este repo)"
	tokenBox.Text = ""
	tokenBox.Size = UDim2.new(1, -90, 1, 0)
	tokenBox.BackgroundColor3 = COLOR_PANEL
	tokenBox.TextColor3 = COLOR_TEXT
	tokenBox.Font = Enum.Font.Gotham
	tokenBox.TextSize = 12
	tokenBox.ClearTextOnFocus = false
	tokenBox.TextXAlignment = Enum.TextXAlignment.Left
	tokenBox.Parent = tokenRow
	rounded(tokenBox)
	local tokenPad = Instance.new("UIPadding")
	tokenPad.PaddingLeft = UDim.new(0, 6)
	tokenPad.Parent = tokenBox

	local saveToken = makeButton(tokenRow, "Guardar")
	saveToken.Size = UDim2.new(0, 84, 1, 0)
	saveToken.MouseButton1Click:Connect(function()
		local token = tokenBox.Text:gsub("^%s*(.-)%s*$", "%1")
		if #token > 0 then
			tokenBox.Text = ""
			handlers.onSaveToken(token)
		end
	end)
	self._tokenRow = tokenRow

	-- acciones globales
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, 26)
	actions.LayoutOrder = 4
	actions.Parent = root
	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Horizontal
	actionsLayout.Padding = UDim.new(0, 6)
	actionsLayout.Parent = actions

	local syncButton = makeButton(actions, "Sync")
	syncButton.Size = UDim2.new(0.333, -4, 1, 0)
	syncButton.MouseButton1Click:Connect(handlers.onSync)

	local inspectButton = makeButton(actions, "🔍 Selección")
	inspectButton.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
	inspectButton.Size = UDim2.new(0.333, -4, 1, 0)
	inspectButton.MouseButton1Click:Connect(handlers.onInspectSelection)

	local undoButton = makeButton(actions, "Deshacer")
	undoButton.BackgroundColor3 = COLOR_NEUTRAL
	undoButton.Size = UDim2.new(0.334, -4, 1, 0)
	undoButton.MouseButton1Click:Connect(handlers.onUndo)

	-- fila hover (v1.2): qué objeto está bajo el cursor ahora mismo
	self._hover = makeLabel(root, "🖱 (pasa el cursor sobre el mundo)", 11)
	self._hover.Size = UDim2.new(1, 0, 0, 18)
	self._hover.TextColor3 = COLOR_HOVER
	self._hover.LayoutOrder = 5

	-- lista de comandos
	local list = Instance.new("ScrollingFrame")
	list.BackgroundColor3 = COLOR_PANEL
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 0, 1, -262)
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.LayoutOrder = 6
	list.Parent = root
	rounded(list)
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = list
	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop = UDim.new(0, 6)
	listPad.PaddingBottom = UDim.new(0, 6)
	listPad.PaddingLeft = UDim.new(0, 6)
	listPad.PaddingRight = UDim.new(0, 6)
	listPad.Parent = list
	self._list = list

	-- log
	local log = Instance.new("TextBox")
	log.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	log.TextColor3 = Color3.fromRGB(170, 220, 170)
	log.Font = Enum.Font.Code
	log.TextSize = 11
	log.TextXAlignment = Enum.TextXAlignment.Left
	log.TextYAlignment = Enum.TextYAlignment.Top
	log.MultiLine = true
	log.ClearTextOnFocus = false
	log.TextEditable = false
	log.Text = ""
	log.Size = UDim2.new(1, 0, 0, 110)
	log.LayoutOrder = 7
	log.Parent = root
	rounded(log)
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
		local empty = makeLabel(self._list, "Sin comandos activos. Pulsa Sync.", 11)
		empty.Size = UDim2.new(1, 0, 0, 18)
		empty.TextColor3 = COLOR_MUTED
		return
	end
	for _, item in ipairs(items) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = COLOR_ROW
		row.Size = UDim2.new(1, 0, 0, 44)
		row.Parent = self._list
		rounded(row)

		local text = ("%s  ·  %s  ·  %s"):format(item.id, item.state, item.title)
		if item.progress then
			text ..= ("  (%d/%d)"):format(item.progress.done, item.progress.total)
		end
		local label = makeLabel(row, text, 11)
		label.Size = UDim2.new(1, -104, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)

		if item.actionLabel and item.onAction then
			local button = makeButton(row, item.actionLabel)
			button.Size = UDim2.new(0, 88, 0, 28)
			button.Position = UDim2.new(1, -94, 0.5, -14)
			button.MouseButton1Click:Connect(item.onAction)
		end
	end
end

return UI

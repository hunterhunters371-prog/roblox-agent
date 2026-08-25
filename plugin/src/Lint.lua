-- Lint.lua v2 (v3.0 del plugin) - analisis estatico leve sobre los scripts del place,
-- 100% Luau puro, sin servicios externos. Roblox no expone loadstring ni un parser
-- a plugins, asi que la deteccion de errores de sintaxis se hace con un chequeo
-- propio de balance de bloques (function/if/for/while/do/repeat contra end/until)
-- y de pares (), {}, []. Ademas busca:
-- 1) globals no declarados (typo detector: rastrea locales, parametros y for-vars)
-- 2) math.floor(a / b) -> sugiere //
-- 3) wait()/spawn()/delay() deprecados -> task.*
--
-- Devuelve hallazgos { path, line, severity, code, message, fix }. El campo fix es
-- el texto accionable que el agente pega en el issue de GitHub.

local Lint = {}

local SEVERITY = { ERROR = "error", WARN = "warn", INFO = "info" }
Lint.SEVERITY = SEVERITY

local BUILTINS = {
	assert = true, collectgarbage = true, error = true, getmetatable = true,
	ipairs = true, next = true, pairs = true, pcall = true, print = true,
	rawequal = true, rawget = true, rawlen = true, rawset = true, require = true,
	select = true, setmetatable = true, tonumber = true, tostring = true,
	type = true, typeof = true, unpack = true, xpcall = true, warn = true,
	math = true, string = true, table = true, os = true, coroutine = true,
	bit32 = true, utf8 = true, debug = true, buffer = true, vector = true,
	task = true,
	game = true, workspace = true, script = true, plugin = true,
	Instance = true, Enum = true, Vector2 = true, Vector3 = true, Vector2int16 = true,
	Vector3int16 = true, CFrame = true, Color3 = true, BrickColor = true,
	UDim = true, UDim2 = true, Rect = true, Region3 = true, Region3int16 = true,
	TweenInfo = true, NumberRange = true, NumberSequence = true, NumberSequenceKeypoint = true,
	ColorSequence = true, ColorSequenceKeypoint = true, PhysicalProperties = true,
	Random = true, DateTime = true, Font = true, Axes = true, Faces = true, Ray = true,
	OverlapParams = true, RaycastParams = true, CatalogSearchParams = true,
	settings = true, UserSettings = true, tick = true, time = true, wait = true,
	spawn = true, delay = true, elapsedTime = true,
	_G = true, shared = true, self = true, super = true,
	any = true, boolean = true, number = true, thread = true,
}

local KNOWN_SERVICES = {
	Workspace = true, Players = true, ReplicatedStorage = true,
	ServerStorage = true, ServerScriptService = true, StarterGui = true,
	StarterPack = true, StarterPlayer = true, Lighting = true,
	HttpService = true, RunService = true, TweenService = true,
	UserInputService = true, ContextActionService = true, TeleportService = true,
	DataStoreService = true, MemoryStoreService = true, MessagingService = true,
	BadgeService = true, MarketplaceService = true, InsertService = true,
	CollectionService = true, PhysicsService = true, SoundService = true,
	Chat = true, TextChatService = true, LocalizationService = true,
	PolicyService = true, AvatarEditorService = true, ProximityPromptService = true,
	PathfindingService = true, ContentProvider = true, GuiService = true,
	Debris = true, LogService = true, TestService = true,
	Teams = true, SocialService = true, GroupService = true,
	FriendService = true, AssetService = true, StudioService = true,
	ScriptContext = true, Stats = true, VoiceChatService = true,
	ChangeHistoryService = true, Selection = true, CoreGui = true,
}

local KEYWORDS = {
	["local"] = true, ["function"] = true, ["end"] = true, ["if"] = true,
	["then"] = true, ["else"] = true, ["elseif"] = true, ["for"] = true,
	["while"] = true, ["do"] = true, ["repeat"] = true, ["until"] = true,
	["return"] = true, ["break"] = true, ["continue"] = true, ["in"] = true,
	["and"] = true, ["or"] = true, ["not"] = true, ["true"] = true,
	["false"] = true, ["nil"] = true, ["export"] = true, ["type"] = true,
	["goto"] = true,
}

local IDENT = "[A-Za-z_][A-Za-z0-9_]*"
local MAX_POR_SCRIPT = 25

local function lineOf(src, pos)
	local _, n = src:sub(1, pos):gsub("\n", "")
	return n + 1
end

local function addFinding(out, path, line, severity, code, message, fix)
	if #out >= MAX_POR_SCRIPT then
		return
	end
	table.insert(out, {
		path = path, line = line, severity = severity,
		code = code, message = message, fix = fix,
	})
end

-- Conserva los saltos de linea del texto eliminado para que los numeros de linea
-- sigan siendo correctos.
local function keepLines(text)
	local _, n = text:gsub("\n", "")
	return string.rep("\n", n)
end

-- Quita cadenas y comentarios para no confundir texto con codigo.
local function stripNoise(src)
	src = src:gsub("%[%[.-%]%]", keepLines) -- cadenas largas y comentarios largos
	src = src:gsub("`(\\.|[^`\\])*`", keepLines) -- backticks con interpolacion
	src = src:gsub('"(\\.|[^"\\])*"', '""')
	src = src:gsub("'(\\.|[^'\\])*'", "''")
	src = src:gsub("%-%-[^\n]*", "") -- comentarios de linea
	return src
end

-- Chequeo sintactico propio: pila de bloques. 'for'/'while' esperan su 'do'
-- (ese 'do' no abre bloque extra); 'end' cierra todo menos 'repeat', que cierra
-- con 'until'.
local function checkBlocks(clean, path, out)
	local stack = {}
	local extraEnd = false
	for pos, tok in clean:gmatch("()(" .. IDENT .. ")") do
		if tok == "function" or tok == "if" or tok == "repeat" then
			table.insert(stack, { kind = tok, pos = pos })
		elseif tok == "for" or tok == "while" then
			table.insert(stack, { kind = tok, pos = pos, needsDo = true })
		elseif tok == "do" then
			local top = stack[#stack]
			if top and top.needsDo then
				top.needsDo = false
			else
				table.insert(stack, { kind = "do", pos = pos })
			end
		elseif tok == "end" then
			if #stack == 0 then
				if not extraEnd then
					extraEnd = true
					addFinding(out, path, lineOf(clean, pos), SEVERITY.ERROR, "UNBALANCED_BLOCK",
						"'end' de mas: no hay ningun bloque abierto que cerrar",
						"Sobra un 'end' o falta abrir el bloque (function/if/for/while/do).")
				end
			else
				table.remove(stack)
			end
		elseif tok == "until" then
			local top = stack[#stack]
			if top and top.kind == "repeat" then
				table.remove(stack)
			else
				addFinding(out, path, lineOf(clean, pos), SEVERITY.ERROR, "UNBALANCED_BLOCK",
					"'until' sin su 'repeat' correspondiente",
					"Cada 'until' cierra un 'repeat ...'. Revisa la estructura del bucle.")
			end
		end
	end
	if #stack > 0 then
		local first = stack[1]
		addFinding(out, path, lineOf(clean, first.pos), SEVERITY.ERROR, "UNBALANCED_BLOCK",
			("bloque '%s' abierto aqui no llega a cerrarse"):format(first.kind),
			first.kind == "repeat"
				and "Falta el 'until' que cierra este 'repeat'."
				or "Falta un 'end': cada function/if/for/while/do necesita su cierre.")
	end
end

local PAIR_OPEN = { ["("] = ")", ["{"] = "}", ["["] = "]" }

local function checkPairs(clean, path, out)
	local stack = {}
	local reported = false
	for pos, s in clean:gmatch("()([%(%){}%[%]])") do
		if PAIR_OPEN[s] then
			table.insert(stack, { ch = s, pos = pos })
		else
			local top = stack[#stack]
			if top and PAIR_OPEN[top.ch] == s then
				table.remove(stack)
			elseif not reported then
				reported = true
				addFinding(out, path, lineOf(clean, pos), SEVERITY.ERROR, "UNBALANCED_PAIR",
					("'%s' sin apertura correspondiente"):format(s),
					"Revisa parentesis/llaves/corchetes cerca de esta linea.")
			end
		end
	end
	if #stack > 0 and not reported then
		local top = stack[#stack]
		addFinding(out, path, lineOf(clean, top.pos), SEVERITY.ERROR, "UNBALANCED_PAIR",
			("'%s' abierto aqui no se cierra"):format(top.ch),
			("Falta cerrar con '%s'."):format(PAIR_OPEN[top.ch]))
	end
end

-- Rastrea identificadores declarados (locales, funciones, parametros, for-vars)
-- para que el detector de globals no marque falsos positivos.
local function noteIdents(declared, list)
	for name in list:gmatch(IDENT) do
		if name ~= "function" then
			declared[name] = true
		end
	end
end

local function collectDeclared(clean)
	local declared = {}
	for cap in clean:gmatch("%f[%w]local%s+([%w_][%w_,%s]-)[=\n]") do
		noteIdents(declared, cap)
	end
	for cap in clean:gmatch("%f[%w]local%s+function%s+([%w_%.:]+)") do
		local last = cap:match("([%w_]+)$")
		if last then
			declared[last] = true
		end
	end
	for cap in clean:gmatch("%f[%w]function%s+[%w_%.:]*%s*%(([^%)]*)%)") do
		noteIdents(declared, cap) -- parametros (los tipos quedan declarados: inofensivo)
	end
	for cap in clean:gmatch("%f[%w]for%s+([%w_][%w_,%s]-)%s+in%s+") do
		noteIdents(declared, cap)
	end
	for cap in clean:gmatch("%f[%w]for%s+([%w_][%w_,%s]-)=") do
		noteIdents(declared, cap) -- for numerico
	end
	return declared
end

local function checkGlobals(clean, path, out)
	local declared = collectDeclared(clean)
	local seen = {}
	for pos, ident in clean:gmatch("()(" .. IDENT .. ")") do
		if not BUILTINS[ident] and not KNOWN_SERVICES[ident] and not KEYWORDS[ident]
			and not declared[ident] and not seen[ident] then
			local prev = clean:sub(pos - 1, pos - 1)
			if prev ~= "." and prev ~= ":" then
				seen[ident] = true
				addFinding(out, path, lineOf(clean, pos), SEVERITY.WARN, "UNDEFINED_GLOBAL",
					("'%s' no esta declarado como local ni es builtin/servicio conocido"):format(ident),
					("Si es un servicio: local S = game:GetService('%s'). Si es una variable: declarala con 'local %s' antes. Si es un modulo: require(...)"):format(ident, ident))
			end
		end
	end
end

local function lintSource(path, src)
	local findings = {}
	local clean = stripNoise(src)
	checkBlocks(clean, path, findings)
	checkPairs(clean, path, findings)
	checkGlobals(clean, path, findings)
	for pos in clean:gmatch("()math%.floor%s*%([^%)]*/[^%)]*%)") do
		addFinding(findings, path, lineOf(clean, pos), SEVERITY.INFO, "FLOOR_DIV",
			"math.floor(a / b) es division de suelo doble",
			"En Luau puedes escribir a // b, mas claro y mas rapido.")
	end
	for pos, fn in clean:gmatch("()%f[%w](wait)%s*%(") do
		addFinding(findings, path, lineOf(clean, pos), SEVERITY.INFO, "DEPRECATED_WAIT",
			fn .. "() esta deprecado", "Usa task.wait() para el mismo comportamiento con mejor rendimiento.")
	end
	for pos, fn in clean:gmatch("()%f[%w](spawn)%s*%(") do
		addFinding(findings, path, lineOf(clean, pos), SEVERITY.INFO, "DEPRECATED_SPAWN",
			fn .. "() esta deprecado", "Usa task.spawn() o task.defer().")
	end
	for pos, fn in clean:gmatch("()%f[%w](delay)%s*%(") do
		addFinding(findings, path, lineOf(clean, pos), SEVERITY.INFO, "DEPRECATED_DELAY",
			fn .. "() esta deprecado", "Usa task.delay().")
	end
	table.sort(findings, function(a, b)
		if a.line ~= b.line then
			return a.line < b.line
		end
		return a.code < b.code
	end)
	return findings
end

-- Lint.Place(root) -> findings[]. Recorre el DataModel bajo `root` (o game).
-- Omite el propio plugin y la papelera del bridge.
function Lint.Place(root)
	root = root or game
	local out = {}
	local function walk(node)
		local name = node.Name
		if name == "RobloxAgentBridge" or name == "RuntimeStaging" or name == "_RBX_Trash" then
			return
		end
		if node:IsA("LuaSourceContainer") then
			local src = node.Source
			if type(src) == "string" and #src > 0 then
				local ok, res = pcall(lintSource, node:GetFullName(), src)
				if ok and res then
					for _, f in ipairs(res) do
						table.insert(out, f)
					end
				end
			end
		end
		for _, child in ipairs(node:GetChildren()) do
			walk(child)
		end
	end
	walk(root)
	return out
end

return Lint

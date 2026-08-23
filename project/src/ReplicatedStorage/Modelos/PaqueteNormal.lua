--[[
	PaqueteNormal.lua
	Constructor procedimental del paquete base del juego "60 SEC".

	Fuente de verdad de la geometria: este modulo.
	Proceso, criterios de aceptacion e historial de iteraciones: docs/modelado-3d/.

	Uso rapido:
		local PaqueteNormal = require(game.ReplicatedStorage.Modelos.PaqueteNormal)
		local modelo = PaqueteNormal.crear()
		modelo.Parent = workspace
		modelo:PivotTo(CFrame.new(0, 5, 0))

	Variantes:
		local fragil = PaqueteNormal.crearVariante("Fragil")

	Todo el marcado (etiqueta, direccion, codigo de barras, logo y simbolos de
	manejo) se dibuja con SurfaceGui, de modo que el modelo no depende de ningun
	asset subido a Roblox. Cuando existan las texturas PBR definitivas se
	sustituye unicamente la capa de marcado, sin tocar la geometria.
]]

local PaqueteNormal = {}

PaqueteNormal.VERSION = "1.0.0"

-- ---------------------------------------------------------------------------
-- Paleta y constantes
-- ---------------------------------------------------------------------------

local PALETA = {
	carton = Color3.fromRGB(176, 132, 84),
	cintaBase = Color3.fromRGB(186, 138, 84),
	papel = Color3.fromRGB(240, 238, 232),
	tinta = Color3.fromRGB(58, 44, 32),
	tintaSuave = Color3.fromRGB(104, 84, 64),
	selloRojo = Color3.fromRGB(178, 58, 46),
}

-- Separacion entre la caja y cualquier pieza pegada a su superficie. Evita
-- z-fighting sin que la pieza se vea despegada.
local HOLGURA = 0.006

local function materialSeguro(nombre, alternativa)
	local ok, material = pcall(function()
		return Enum.Material[nombre]
	end)
	if ok and material then
		return material
	end
	return alternativa
end

local MATERIAL_CARTON = materialSeguro("Cardboard", Enum.Material.SmoothPlastic)
local MATERIAL_CINTA = materialSeguro("Plastic", Enum.Material.SmoothPlastic)

local DEFAULTS = {
	nombre = "PaqueteNormal",
	variante = "Normal",

	-- Geometria. tamano se expresa en studs: ancho (X), alto (Y), fondo (Z).
	tamano = Vector3.new(1.25, 1.0, 1.25),
	anchoCinta = 0.18, -- fraccion del ancho de la caja
	caidaCinta = 0.32, -- fraccion de la altura que la cinta baja por el lateral
	cintaDoble = false,

	-- Materiales y color
	colorCarton = PALETA.carton,
	colorCinta = PALETA.cintaBase,

	-- Contenido impreso
	codigo = "60SEC-DEL-00017",
	direccion = { "House #17", "Sunset Street 12", "Delivery City" },
	segundosEntrega = 60,
	fragil = false,
	mantenerSeco = true,
	esteLadoArriba = true,
	sello = nil, -- texto diagonal opcional sobre la cara frontal

	-- Fisica y gameplay
	densidad = 0.55,
	anclado = false,
	colisiona = true,
	conProximityPrompt = true,

	-- Rendimiento del marcado
	pixelesPorStud = 340,
	distanciaGui = 60,
}

PaqueteNormal.PALETA = PALETA
PaqueteNormal.DEFAULTS = DEFAULTS

-- Variantes: solo cambian color, atributos y accesorios. Nunca rehacen la caja.
PaqueteNormal.VARIANTES = {
	Normal = {},
	Fragil = {
		variante = "Fragil",
		nombre = "PaqueteFragil",
		colorCinta = Color3.fromRGB(196, 72, 58),
		fragil = true,
		sello = "FRAGILE",
	},
	Pesado = {
		variante = "Pesado",
		nombre = "PaquetePesado",
		colorCarton = Color3.fromRGB(142, 104, 64),
		cintaDoble = true,
		densidad = 1.6,
		sello = "HEAVY",
	},
	Express = {
		variante = "Express",
		nombre = "PaqueteExpress",
		colorCinta = Color3.fromRGB(240, 190, 60),
		segundosEntrega = 45,
		sello = "EXPRESS",
	},
	Refrigerado = {
		variante = "Refrigerado",
		nombre = "PaqueteRefrigerado",
		colorCarton = Color3.fromRGB(198, 206, 212),
		colorCinta = Color3.fromRGB(92, 158, 206),
		segundosEntrega = 40,
		sello = "COLD",
	},
}

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

local function fusionar(base, extra)
	local salida = {}
	for clave, valor in pairs(base) do
		salida[clave] = valor
	end
	if extra then
		for clave, valor in pairs(extra) do
			salida[clave] = valor
		end
	end
	return salida
end

local function semillaDesdeTexto(texto)
	local acumulado = 7
	for indice = 1, #texto do
		acumulado = (acumulado * 31 + string.byte(texto, indice)) % 2147483647
	end
	return acumulado
end

local function nuevaParte(nombre, tamano, padre)
	local parte = Instance.new("Part")
	parte.Name = nombre
	parte.Size = tamano
	parte.Anchored = false
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.TopSurface = Enum.SurfaceType.Smooth
	parte.BottomSurface = Enum.SurfaceType.Smooth
	parte.Parent = padre
	return parte
end

local function soldar(principal, secundaria)
	local union = Instance.new("WeldConstraint")
	union.Name = "Union"
	union.Part0 = principal
	union.Part1 = secundaria
	union.Parent = secundaria
	return union
end

-- Devuelve el tamano de una placa plana apoyada sobre la cara indicada.
local function tamanoPlaca(cara, ancho, alto, grosor)
	local normal = Vector3.fromNormalId(cara)
	if math.abs(normal.X) > 0.5 then
		return Vector3.new(grosor, alto, ancho)
	elseif math.abs(normal.Y) > 0.5 then
		return Vector3.new(ancho, grosor, alto)
	end
	return Vector3.new(ancho, alto, grosor)
end

-- Apoya una placa sobre una cara de la caja, con desplazamiento local opcional.
local function apoyarEnCara(placa, caja, cara, desplazamiento)
	local normal = Vector3.fromNormalId(cara)
	local mitadCaja = (caja.Size * normal).Magnitude / 2
	local mitadPlaca = (placa.Size * normal).Magnitude / 2
	local offset = normal * (mitadCaja + mitadPlaca - HOLGURA / 2) + (desplazamiento or Vector3.zero)
	placa.CFrame = caja.CFrame * CFrame.new(offset)
end

local function nuevaSuperficie(parte, cara, cfg, nombre)
	local superficie = Instance.new("SurfaceGui")
	superficie.Name = nombre or "Impresion"
	superficie.Face = cara
	superficie.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	superficie.PixelsPerStud = cfg.pixelesPorStud
	superficie.LightInfluence = 1
	superficie.MaxDistance = cfg.distanciaGui
	superficie.Parent = parte
	return superficie
end

local function nuevoTexto(padre, contenido, posicion, tamano, fuente, color, alineacion)
	local etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.BorderSizePixel = 0
	etiqueta.Position = posicion
	etiqueta.Size = tamano
	etiqueta.Font = fuente
	etiqueta.Text = contenido
	etiqueta.TextColor3 = color
	etiqueta.TextScaled = true
	etiqueta.TextXAlignment = alineacion or Enum.TextXAlignment.Left
	etiqueta.TextYAlignment = Enum.TextYAlignment.Center
	etiqueta.Parent = padre
	return etiqueta
end

local function nuevoBloque(padre, posicion, tamano, color, rotacion)
	local bloque = Instance.new("Frame")
	bloque.BackgroundColor3 = color
	bloque.BorderSizePixel = 0
	bloque.Position = posicion
	bloque.Size = tamano
	bloque.Rotation = rotacion or 0
	bloque.Parent = padre
	return bloque
end

-- ---------------------------------------------------------------------------
-- Marcado: codigo de barras, etiqueta, logo y simbolos
-- ---------------------------------------------------------------------------

-- El patron de barras se deriva del codigo del paquete, asi que el mismo
-- codigo produce siempre las mismas barras y dos paquetes distintos no se ven
-- identicos.
local function construirCodigoBarras(padre, codigo, posicion, tamano)
	local contenedor = Instance.new("Frame")
	contenedor.Name = "CodigoBarras"
	contenedor.BackgroundTransparency = 1
	contenedor.Position = posicion
	contenedor.Size = tamano
	contenedor.Parent = padre

	local generador = Random.new(semillaDesdeTexto(codigo))
	local avance = 0
	while avance < 0.98 do
		local ancho = generador:NextInteger(1, 3) * 0.006
		nuevoBloque(contenedor, UDim2.fromScale(avance, 0), UDim2.fromScale(ancho, 1), PALETA.tinta)
		avance = avance + ancho + generador:NextInteger(1, 3) * 0.006
	end
	return contenedor
end

local function construirLogo(padre, posicion, tamano)
	local logo = Instance.new("Frame")
	logo.Name = "Logo60Sec"
	logo.BackgroundTransparency = 1
	logo.Position = posicion
	logo.Size = tamano
	logo.Parent = padre

	local esfera = Instance.new("Frame")
	esfera.Name = "Esfera"
	esfera.BackgroundTransparency = 1
	esfera.Position = UDim2.fromScale(0.16, 0.12)
	esfera.Size = UDim2.fromScale(0.68, 0.76)
	esfera.Parent = logo

	local redondeo = Instance.new("UICorner")
	redondeo.CornerRadius = UDim.new(0.5, 0)
	redondeo.Parent = esfera

	local contorno = Instance.new("UIStroke")
	contorno.Color = PALETA.tinta
	contorno.Thickness = 3
	contorno.Parent = esfera

	-- Boton y pulsador superior del cronometro.
	nuevoBloque(logo, UDim2.fromScale(0.44, 0.02), UDim2.fromScale(0.12, 0.10), PALETA.tinta)
	nuevoBloque(logo, UDim2.fromScale(0.80, 0.10), UDim2.fromScale(0.14, 0.06), PALETA.tinta, 35)

	nuevoTexto(esfera, "60", UDim2.fromScale(0, 0.06), UDim2.fromScale(1, 0.52), Enum.Font.GothamBold, PALETA.tinta, Enum.TextXAlignment.Center)
	nuevoTexto(esfera, "SEC", UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.28), Enum.Font.GothamBold, PALETA.tinta, Enum.TextXAlignment.Center)

	return logo
end

local function marcoSimbolo(padre, posicion, tamano)
	local marco = Instance.new("Frame")
	marco.BackgroundTransparency = 1
	marco.Position = posicion
	marco.Size = tamano
	marco.ClipsDescendants = true
	marco.Parent = padre

	local contorno = Instance.new("UIStroke")
	contorno.Color = PALETA.tinta
	contorno.Thickness = 2
	contorno.Parent = marco
	return marco
end

local function simboloEsteLadoArriba(marco)
	for indice = 0, 1 do
		local base = 0.24 + indice * 0.30
		nuevoBloque(marco, UDim2.fromScale(base, 0.34), UDim2.fromScale(0.10, 0.46), PALETA.tinta)
		nuevoBloque(marco, UDim2.fromScale(base - 0.07, 0.24), UDim2.fromScale(0.09, 0.22), PALETA.tinta, 42)
		nuevoBloque(marco, UDim2.fromScale(base + 0.08, 0.24), UDim2.fromScale(0.09, 0.22), PALETA.tinta, -42)
	end
end

local function simboloFragil(marco)
	local cuenco = nuevoBloque(marco, UDim2.fromScale(0.30, 0.18), UDim2.fromScale(0.40, 0.32), PALETA.tinta)
	local redondeo = Instance.new("UICorner")
	redondeo.CornerRadius = UDim.new(0.5, 0)
	redondeo.Parent = cuenco

	nuevoBloque(marco, UDim2.fromScale(0.46, 0.48), UDim2.fromScale(0.08, 0.24), PALETA.tinta)
	nuevoBloque(marco, UDim2.fromScale(0.32, 0.70), UDim2.fromScale(0.36, 0.08), PALETA.tinta)
end

local function simboloMantenerSeco(marco)
	local recorte = Instance.new("Frame")
	recorte.BackgroundTransparency = 1
	recorte.ClipsDescendants = true
	recorte.Position = UDim2.fromScale(0.18, 0.24)
	recorte.Size = UDim2.fromScale(0.64, 0.22)
	recorte.Parent = marco

	local cupula = nuevoBloque(recorte, UDim2.fromScale(0, 0), UDim2.fromScale(1, 2), PALETA.tinta)
	local redondeo = Instance.new("UICorner")
	redondeo.CornerRadius = UDim.new(0.5, 0)
	redondeo.Parent = cupula

	nuevoBloque(marco, UDim2.fromScale(0.47, 0.44), UDim2.fromScale(0.06, 0.30), PALETA.tinta)
	nuevoBloque(marco, UDim2.fromScale(0.38, 0.70), UDim2.fromScale(0.15, 0.06), PALETA.tinta, 20)
end

local function construirEtiqueta(superficie, cfg, compacta)
	local papel = Instance.new("Frame")
	papel.Name = "Papel"
	papel.BackgroundColor3 = PALETA.papel
	papel.BorderSizePixel = 0
	papel.Size = UDim2.fromScale(1, 1)
	papel.Parent = superficie

	local encabezado = string.format("DELIVERY: %d SECONDS", cfg.segundosEntrega)

	if compacta then
		nuevoTexto(papel, encabezado, UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.66, 0.20), Enum.Font.GothamBold, PALETA.tinta)
		nuevoTexto(papel, cfg.direccion[1] or "", UDim2.fromScale(0.05, 0.30), UDim2.fromScale(0.9, 0.18), Enum.Font.Gotham, PALETA.tintaSuave)
		construirCodigoBarras(papel, cfg.codigo, UDim2.fromScale(0.05, 0.54), UDim2.fromScale(0.9, 0.26))
		nuevoTexto(papel, cfg.codigo, UDim2.fromScale(0.05, 0.82), UDim2.fromScale(0.9, 0.14), Enum.Font.Code, PALETA.tinta)
		return papel
	end

	nuevoTexto(papel, encabezado, UDim2.fromScale(0.06, 0.05), UDim2.fromScale(0.60, 0.12), Enum.Font.GothamBold, PALETA.tinta)
	construirLogo(papel, UDim2.fromScale(0.74, 0.03), UDim2.fromScale(0.20, 0.16))
	nuevoBloque(papel, UDim2.fromScale(0.06, 0.21), UDim2.fromScale(0.88, 0.008), PALETA.tinta)

	nuevoTexto(papel, "TO:", UDim2.fromScale(0.06, 0.24), UDim2.fromScale(0.3, 0.10), Enum.Font.GothamBold, PALETA.tinta)
	for indice, linea in ipairs(cfg.direccion) do
		nuevoTexto(
			papel,
			linea,
			UDim2.fromScale(0.06, 0.34 + (indice - 1) * 0.10),
			UDim2.fromScale(0.88, 0.09),
			indice == 1 and Enum.Font.GothamBold or Enum.Font.Gotham,
			indice == 1 and PALETA.tinta or PALETA.tintaSuave
		)
	end

	nuevoBloque(papel, UDim2.fromScale(0.06, 0.66), UDim2.fromScale(0.88, 0.006), PALETA.tintaSuave)
	construirCodigoBarras(papel, cfg.codigo, UDim2.fromScale(0.06, 0.70), UDim2.fromScale(0.88, 0.18))
	nuevoTexto(papel, cfg.codigo, UDim2.fromScale(0.06, 0.89), UDim2.fromScale(0.88, 0.08), Enum.Font.Code, PALETA.tinta, Enum.TextXAlignment.Center)

	return papel
end

-- ---------------------------------------------------------------------------
-- Piezas del modelo
-- ---------------------------------------------------------------------------

local function construirCintas(modelo, caja, cfg)
	local tamano = cfg.tamano
	local ancho = tamano.X * cfg.anchoCinta
	local grosor = 0.012
	local caida = tamano.Y * cfg.caidaCinta
	local desplazamientos = cfg.cintaDoble and { -tamano.X * 0.22, tamano.X * 0.22 } or { 0 }

	for indice, desplazamiento in ipairs(desplazamientos) do
		local sufijo = cfg.cintaDoble and tostring(indice) or ""

		local superior = nuevaParte("CintaSuperior" .. sufijo, Vector3.new(ancho, grosor, tamano.Z + HOLGURA), modelo)
		superior.Color = cfg.colorCinta
		superior.Material = MATERIAL_CINTA
		superior.Transparency = 0.15
		superior.CFrame = caja.CFrame * CFrame.new(desplazamiento, tamano.Y / 2 + grosor / 2 - HOLGURA / 2, 0)
		soldar(caja, superior)

		for _, cara in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local normal = Vector3.fromNormalId(cara)
			local lateral = nuevaParte("CintaLateral" .. sufijo .. tostring(cara.Name), Vector3.new(ancho, caida, grosor), modelo)
			lateral.Color = cfg.colorCinta
			lateral.Material = MATERIAL_CINTA
			lateral.Transparency = 0.15
			lateral.CFrame = caja.CFrame
				* CFrame.new(desplazamiento, tamano.Y / 2 - caida / 2, normal.Z * (tamano.Z / 2 + grosor / 2 - HOLGURA / 2))
			soldar(caja, lateral)
		end
	end
end

local function construirJuntas(caja, cfg)
	-- Linea de cierre de las solapas superiores y patron en cruz de la base.
	local superior = nuevaSuperficie(caja, Enum.NormalId.Top, cfg, "JuntaSuperior")
	nuevoBloque(superior, UDim2.fromScale(0, 0.497), UDim2.fromScale(1, 0.006), PALETA.tintaSuave)

	local inferior = nuevaSuperficie(caja, Enum.NormalId.Bottom, cfg, "JuntaInferior")
	nuevoBloque(inferior, UDim2.fromScale(-0.2, 0.497), UDim2.fromScale(1.4, 0.005), PALETA.tintaSuave, 45)
	nuevoBloque(inferior, UDim2.fromScale(-0.2, 0.497), UDim2.fromScale(1.4, 0.005), PALETA.tintaSuave, -45)
end

local function construirEtiquetaPrincipal(modelo, caja, cfg)
	local tamano = cfg.tamano
	local placa = nuevaParte(
		"EtiquetaPrincipal",
		tamanoPlaca(Enum.NormalId.Back, tamano.X * 0.62, tamano.Y * 0.46, 0.01),
		modelo
	)
	placa.Color = PALETA.papel
	placa.Material = Enum.Material.SmoothPlastic
	apoyarEnCara(placa, caja, Enum.NormalId.Back, Vector3.new(0, tamano.Y * 0.10, 0))
	soldar(caja, placa)

	local superficie = nuevaSuperficie(placa, Enum.NormalId.Back, cfg, "Etiqueta")
	construirEtiqueta(superficie, cfg, false)
	return placa
end

local function construirEtiquetaSuperior(modelo, caja, cfg)
	local tamano = cfg.tamano
	local placa = nuevaParte(
		"EtiquetaSuperior",
		tamanoPlaca(Enum.NormalId.Top, tamano.X * 0.36, tamano.Z * 0.26, 0.008),
		modelo
	)
	placa.Color = PALETA.papel
	placa.Material = Enum.Material.SmoothPlastic
	apoyarEnCara(placa, caja, Enum.NormalId.Top, Vector3.new(tamano.X * 0.24, 0, tamano.Z * 0.24))
	soldar(caja, placa)

	local superficie = nuevaSuperficie(placa, Enum.NormalId.Top, cfg, "EtiquetaCompacta")
	construirEtiqueta(superficie, cfg, true)
	return placa
end

local function construirFrontal(caja, cfg)
	local superficie = nuevaSuperficie(caja, Enum.NormalId.Front, cfg, "Frontal")

	construirLogo(superficie, UDim2.fromScale(0.16, 0.20), UDim2.fromScale(0.40, 0.40))

	local simbolos = { "esteLadoArriba", "fragil", "mantenerSeco" }
	local activos = {
		esteLadoArriba = cfg.esteLadoArriba,
		fragil = true, -- el simbolo de copa aparece siempre en la caja base
		mantenerSeco = cfg.mantenerSeco,
	}

	local columna = 0
	for _, clave in ipairs(simbolos) do
		if activos[clave] then
			local marco = marcoSimbolo(
				superficie,
				UDim2.fromScale(0.52 + columna * 0.15, 0.66),
				UDim2.fromScale(0.13, 0.20)
			)
			if clave == "esteLadoArriba" then
				simboloEsteLadoArriba(marco)
			elseif clave == "fragil" then
				simboloFragil(marco)
			else
				simboloMantenerSeco(marco)
			end
			columna = columna + 1
		end
	end

	if cfg.sello then
		local sello = nuevoTexto(
			superficie,
			cfg.sello,
			UDim2.fromScale(0.10, 0.06),
			UDim2.fromScale(0.52, 0.14),
			Enum.Font.GothamBold,
			PALETA.selloRojo,
			Enum.TextXAlignment.Center
		)
		sello.Name = "Sello"
		sello.Rotation = -8
		sello.TextTransparency = 0.15

		local contorno = Instance.new("UIStroke")
		contorno.Color = PALETA.selloRojo
		contorno.Thickness = 2
		contorno.Transparency = 0.35
		contorno.Parent = sello
	end

	return superficie
end

local function aplicarGameplay(modelo, caja, cfg)
	local agarre = Instance.new("Attachment")
	agarre.Name = "PuntoAgarre"
	agarre.Position = Vector3.new(0, cfg.tamano.Y / 2, 0)
	agarre.Parent = caja

	local apoyo = Instance.new("Attachment")
	apoyo.Name = "PuntoApoyoBase"
	apoyo.Position = Vector3.new(0, -cfg.tamano.Y / 2, 0)
	apoyo.Parent = caja

	if cfg.conProximityPrompt then
		local aviso = Instance.new("ProximityPrompt")
		aviso.Name = "Recoger"
		aviso.ActionText = "Recoger"
		aviso.ObjectText = "Paquete"
		aviso.HoldDuration = 0.15
		aviso.MaxActivationDistance = 8
		aviso.RequiresLineOfSight = false
		aviso.Parent = caja
	end

	modelo:SetAttribute("VersionModelo", PaqueteNormal.VERSION)
	modelo:SetAttribute("TipoPaquete", cfg.variante)
	modelo:SetAttribute("Codigo", cfg.codigo)
	modelo:SetAttribute("Direccion", table.concat(cfg.direccion, ", "))
	modelo:SetAttribute("SegundosEntrega", cfg.segundosEntrega)
	modelo:SetAttribute("Fragil", cfg.fragil)
	modelo:SetAttribute("MantenerSeco", cfg.mantenerSeco)
	modelo:SetAttribute("EsteLadoArriba", cfg.esteLadoArriba)
end

-- ---------------------------------------------------------------------------
-- API publica
-- ---------------------------------------------------------------------------

--[[
	Construye el modelo y lo devuelve sin padre. El pivote queda en el centro
	geometrico de la caja, con el frente mirando hacia -Z.
]]
function PaqueteNormal.crear(config)
	local cfg = fusionar(DEFAULTS, config)
	assert(typeof(cfg.tamano) == "Vector3", "tamano debe ser Vector3")
	assert(type(cfg.direccion) == "table" and #cfg.direccion > 0, "direccion debe tener al menos una linea")

	local modelo = Instance.new("Model")
	modelo.Name = cfg.nombre

	local caja = nuevaParte("Caja", cfg.tamano, modelo)
	caja.Color = cfg.colorCarton
	caja.Material = MATERIAL_CARTON
	caja.CanCollide = cfg.colisiona
	caja.CanQuery = true
	caja.CanTouch = true
	caja.Massless = false
	caja.Anchored = cfg.anclado
	caja.CustomPhysicalProperties = PhysicalProperties.new(cfg.densidad, 0.7, 0.15, 1, 1)
	caja.CFrame = CFrame.new()
	modelo.PrimaryPart = caja

	construirJuntas(caja, cfg)
	construirCintas(modelo, caja, cfg)
	construirEtiquetaPrincipal(modelo, caja, cfg)
	construirEtiquetaSuperior(modelo, caja, cfg)
	construirFrontal(caja, cfg)
	aplicarGameplay(modelo, caja, cfg)

	return modelo
end

--[[
	Crea una variante declarada en PaqueteNormal.VARIANTES. Las variantes solo
	ajustan color, atributos y accesorios: la geometria base no cambia.
]]
function PaqueteNormal.crearVariante(nombreVariante, overrides)
	local base = PaqueteNormal.VARIANTES[nombreVariante]
	assert(base, "Variante desconocida: " .. tostring(nombreVariante))
	return PaqueteNormal.crear(fusionar(base, overrides))
end

--[[
	Crea el modelo, lo coloca bajo un padre y lo mueve al CFrame indicado.
]]
function PaqueteNormal.crearEn(padre, cframe, config)
	local modelo = PaqueteNormal.crear(config)
	modelo.Parent = padre
	modelo:PivotTo(cframe or CFrame.new())
	return modelo
end

return PaqueteNormal

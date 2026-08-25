--[[
	MochilaReparto.lua
	Constructor procedimental de la mochila de reparto del juego "60 SEC".

	Fuente de verdad de la geometria: este modulo.
	Proceso, criterios de aceptacion e historial: docs/modelado-3d/.

	Referencia: lamina «DELIVERY BACKPACK», estilo voxel de formas cuadradas.
	Toda la geometria son prismas rectos: la silueta escalonada se consigue con
	piezas ligeramente orgullosas del cuerpo, sin cuñas, esferas ni mallas.

	Uso rapido:
		local MochilaReparto = require(game.ReplicatedStorage.Modelos.MochilaReparto)
		local modelo = MochilaReparto.crear()
		modelo.Parent = workspace
		modelo:PivotTo(CFrame.new(0, 2.4, 0))

	Variantes:
		local roja = MochilaReparto.crearVariante("Roja")

	El logo «60 SEC» se dibuja con SurfaceGui, de modo que el modelo no depende
	de ningun asset subido a Roblox. Cuando existan las texturas definitivas se
	sustituye unicamente la capa del logo, sin tocar la geometria.
]]

local MochilaReparto = {}

MochilaReparto.VERSION = "1.0.0"

-- ---------------------------------------------------------------------------
-- Paleta y constantes
-- ---------------------------------------------------------------------------

local PALETA = {
	turquesa = Color3.fromRGB(56, 178, 169),
	turquesaOscura = Color3.fromRGB(34, 136, 128),
	turquesaClara = Color3.fromRGB(94, 206, 195),
	correa = Color3.fromRGB(30, 30, 34),
	hebilla = Color3.fromRGB(150, 156, 160),
	carton = Color3.fromRGB(198, 154, 102),
	crema = Color3.fromRGB(240, 238, 232),
	rojo = Color3.fromRGB(198, 62, 52),
}

-- Separacion entre piezas pegadas. Evita z-fighting sin verse despegadas.
local HOLGURA = 0.006

-- Lo que sobresalen las piezas de la silueta escalonada (voxel).
local ESCALON = 0.04

-- Cesta frontal, en fracciones del cuerpo salvo el fondo, que va en studs.
local CESTA = { ancho = 0.654, alto = 0.367, fondo = 0.55, centroY = -0.25, barrasV = 5, barrasH = 4, barrasLadoV = 2 }

-- Correa del lado +X: segmentos sobre un arco sinusoidal.
local SEGMENTOS_CORREA = 7

local function materialSeguro(nombre, alternativa)
	local ok, material = pcall(function()
		return Enum.Material[nombre]
	end)
	if ok and material then
		return material
	end
	return alternativa
end

local MATERIAL_CUERPO = materialSeguro("Fabric", Enum.Material.SmoothPlastic)

local DEFAULTS = {
	nombre = "MochilaReparto",
	variante = "Turquesa",

	-- Geometria del cuerpo en studs: ancho (X), alto (Y), fondo (Z).
	tamano = Vector3.new(2.6, 3.0, 1.6),

	colorCuerpo = PALETA.turquesa,
	colorDetalle = PALETA.turquesaOscura,
	colorRejilla = PALETA.turquesaOscura,
	colorCorrea = PALETA.correa,
	colorCarton = PALETA.carton,

	-- Paquetes kraft que sobresalen de la cesta.
	conPaquetes = true,
	capacidadPaquetes = 3,

	-- Fisica y gameplay
	densidad = 0.4,
	anclado = false,
	colisiona = true,
	conProximityPrompt = false,

	-- Rendimiento del marcado
	pixelesPorStud = 340,
	distanciaGui = 60,
}

MochilaReparto.PALETA = PALETA
MochilaReparto.DEFAULTS = DEFAULTS

-- Variantes: solo cambian color y atributos. Nunca rehacen la geometria.
MochilaReparto.VARIANTES = {
	Turquesa = {},
	Roja = {
		variante = "Roja",
		nombre = "MochilaRepartoRoja",
		colorCuerpo = Color3.fromRGB(196, 74, 62),
		colorDetalle = Color3.fromRGB(148, 48, 40),
		colorRejilla = Color3.fromRGB(148, 48, 40),
	},
	Azul = {
		variante = "Azul",
		nombre = "MochilaRepartoAzul",
		colorCuerpo = Color3.fromRGB(64, 118, 206),
		colorDetalle = Color3.fromRGB(44, 86, 160),
		colorRejilla = Color3.fromRGB(44, 86, 160),
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

-- Pieza soldada al cuerpo, con CFrame local relativo al centro del cuerpo.
local function nuevaPieza(modelo, cuerpo, nombre, tamano, localCF, color)
	local parte = nuevaParte(nombre, tamano, modelo)
	parte.Color = color
	parte.Material = Enum.Material.SmoothPlastic
	parte.CFrame = cuerpo.CFrame * localCF
	soldar(cuerpo, parte)
	return parte
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

local function nuevoTexto(padre, contenido, posicion, tamano, fuente, color)
	local etiqueta = Instance.new("TextLabel")
	etiqueta.BackgroundTransparency = 1
	etiqueta.BorderSizePixel = 0
	etiqueta.Position = posicion
	etiqueta.Size = tamano
	etiqueta.Font = fuente
	etiqueta.Text = contenido
	etiqueta.TextColor3 = color
	etiqueta.TextScaled = true
	etiqueta.TextXAlignment = Enum.TextXAlignment.Center
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
-- Logo «60 SEC» con cronometro, dibujado con GUI sobre la tapa
-- ---------------------------------------------------------------------------

local function construirLogo(tapa, cfg)
	local superficie = nuevaSuperficie(tapa, Enum.NormalId.Front, cfg, "LogoFrontal")

	-- El labio de la tapa cubre el 10 % inferior de la cara: el logo queda arriba.
	nuevoTexto(superficie, "6", UDim2.fromScale(0.30, 0.02), UDim2.fromScale(0.13, 0.40), Enum.Font.GothamBold, PALETA.crema)

	local reloj = Instance.new("Frame")
	reloj.Name = "Cronometro"
	reloj.BackgroundTransparency = 1
	reloj.Position = UDim2.fromScale(0.44, 0.02)
	reloj.Size = UDim2.fromScale(0.20, 0.40)
	reloj.Parent = superficie

	local esfera = Instance.new("Frame")
	esfera.Name = "Esfera"
	esfera.BackgroundTransparency = 1
	esfera.Position = UDim2.fromScale(0.05, 0.10)
	esfera.Size = UDim2.fromScale(0.90, 0.82)
	esfera.Parent = reloj

	local redondeo = Instance.new("UICorner")
	redondeo.CornerRadius = UDim.new(0.5, 0)
	redondeo.Parent = esfera

	local contorno = Instance.new("UIStroke")
	contorno.Color = PALETA.crema
	contorno.Thickness = 4
	contorno.Parent = esfera

	-- Pulsador superior del cronometro y manecillas: una arriba, una a la derecha.
	nuevoBloque(reloj, UDim2.fromScale(0.41, 0.0), UDim2.fromScale(0.18, 0.10), PALETA.crema)
	nuevoBloque(esfera, UDim2.fromScale(0.47, 0.14), UDim2.fromScale(0.06, 0.32), PALETA.crema)
	nuevoBloque(esfera, UDim2.fromScale(0.50, 0.43), UDim2.fromScale(0.26, 0.06), PALETA.crema)

	local centro = nuevoBloque(esfera, UDim2.fromScale(0.40, 0.36), UDim2.fromScale(0.20, 0.20), PALETA.rojo)
	local redondeoCentro = Instance.new("UICorner")
	redondeoCentro.CornerRadius = UDim.new(0.5, 0)
	redondeoCentro.Parent = centro

	nuevoTexto(superficie, "SEC", UDim2.fromScale(0.28, 0.44), UDim2.fromScale(0.34, 0.34), Enum.Font.GothamBold, PALETA.crema)

	return superficie
end

-- ---------------------------------------------------------------------------
-- Piezas del modelo
-- ---------------------------------------------------------------------------

local function construirTapa(modelo, cuerpo, cfg)
	local W, H, D = cfg.tamano.X, cfg.tamano.Y, cfg.tamano.Z
	local altoTapa = 0.3 * H
	local centroTapaY = H / 2 - altoTapa / 2 + ESCALON + HOLGURA

	local tapa = nuevaPieza(
		modelo,
		cuerpo,
		"Tapa",
		Vector3.new(W + 0.12, altoTapa, D + 0.12),
		CFrame.new(0, centroTapaY, 0),
		cfg.colorCuerpo
	)

	local labioY = centroTapaY - altoTapa / 2
	nuevaPieza(
		modelo,
		cuerpo,
		"LabioTapa",
		Vector3.new(W + 0.12, 0.18, 0.07),
		CFrame.new(0, labioY, -(D / 2 + 0.06 + 0.035 - HOLGURA)),
		cfg.colorDetalle
	)

	return tapa, centroTapaY + altoTapa / 2
end

local function construirAsa(modelo, cuerpo, cfg, tapaTop)
	local W = cfg.tamano.X
	local separacion = 0.19 * W

	for _, lado in ipairs({ -1, 1 }) do
		local sufijo = lado < 0 and "Izq" or "Der"
		nuevaPieza(
			modelo,
			cuerpo,
			"AsaPoste" .. sufijo,
			Vector3.new(0.16, 0.34, 0.16),
			CFrame.new(lado * separacion, tapaTop + 0.17 - HOLGURA, 0),
			cfg.colorDetalle
		)
	end

	nuevaPieza(
		modelo,
		cuerpo,
		"AsaBarra",
		Vector3.new(0.43 * W, 0.16, 0.16),
		CFrame.new(0, tapaTop + 0.34 + 0.08 - HOLGURA * 2, 0),
		cfg.colorDetalle
	)
end

local function construirSilueta(modelo, cuerpo, cfg)
	local W, H, D = cfg.tamano.X, cfg.tamano.Y, cfg.tamano.Z

	-- Esquinas orgullosas: el escalonado voxel de la referencia.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local nombre = "Esquina" .. (sx < 0 and "Izq" or "Der") .. (sz < 0 and "Front" or "Back")
			nuevaPieza(
				modelo,
				cuerpo,
				nombre,
				Vector3.new(0.2, H - 0.04, 0.2),
				CFrame.new(sx * (W / 2 - 0.06), 0, sz * (D / 2 - 0.06)),
				cfg.colorDetalle
			)
		end
	end

	-- Base orgullosa: segundo escalon de la silueta.
	nuevaPieza(
		modelo,
		cuerpo,
		"BaseInferior",
		Vector3.new(W + 0.06, 0.14, D + 0.06),
		CFrame.new(0, -H / 2 + 0.05, 0),
		cfg.colorDetalle
	)
end

local function construirBolsillos(modelo, cuerpo, cfg)
	local W, H, D = cfg.tamano.X, cfg.tamano.Y, cfg.tamano.Z

	-- Bolsillo derecho (+X): el que se ve completo en la referencia, con solapa.
	local altoDer = 0.27 * H
	nuevaPieza(
		modelo,
		cuerpo,
		"BolsilloDerecho",
		Vector3.new(0.34, altoDer, 0.44 * D),
		CFrame.new(W / 2 + 0.17 - HOLGURA, -0.2 * H, 0.06),
		cfg.colorCuerpo
	)
	nuevaPieza(
		modelo,
		cuerpo,
		"SolapaDerecha",
		Vector3.new(0.38, 0.22, 0.44 * D + 0.04),
		CFrame.new(W / 2 + 0.19 - HOLGURA, -0.2 * H + altoDer / 2 + 0.08, 0.06),
		cfg.colorDetalle
	)

	-- Bolsillo izquierdo (-X): en la referencia solo asoma una protuberancia.
	local altoIzq = 0.23 * H
	nuevaPieza(
		modelo,
		cuerpo,
		"BolsilloIzquierdo",
		Vector3.new(0.2, altoIzq, 0.38 * D),
		CFrame.new(-(W / 2 + 0.1 - HOLGURA), -0.23 * H, 0.03),
		cfg.colorCuerpo
	)
	nuevaPieza(
		modelo,
		cuerpo,
		"SolapaIzquierda",
		Vector3.new(0.24, 0.18, 0.38 * D + 0.04),
		CFrame.new(-(W / 2 + 0.12 - HOLGURA), -0.23 * H + altoIzq / 2 + 0.06, 0.03),
		cfg.colorDetalle
	)
end

local function construirCesta(modelo, cuerpo, cfg)
	local W, H, D = cfg.tamano.X, cfg.tamano.Y, cfg.tamano.Z
	local g = 0.05 -- grosor de barra de la rejilla
	local anchoC = CESTA.ancho * W
	local altoC = CESTA.alto * H
	local centroY = CESTA.centroY * H
	local centroZ = -(D / 2) - CESTA.fondo / 2 + HOLGURA
	local frenteZ = centroZ - CESTA.fondo / 2

	-- Barras verticales y horizontales de la cara frontal.
	for i = 1, CESTA.barrasV do
		local x = -anchoC / 2 + (i - 0.5) * (anchoC / CESTA.barrasV)
		nuevaPieza(modelo, cuerpo, "RejillaFrontalV" .. i, Vector3.new(g, altoC, g), CFrame.new(x, centroY, frenteZ + g / 2), cfg.colorRejilla)
	end
	for j = 1, CESTA.barrasH do
		local y = centroY - altoC / 2 + j * (altoC / (CESTA.barrasH + 1))
		nuevaPieza(modelo, cuerpo, "RejillaFrontalH" .. j, Vector3.new(anchoC, g, g), CFrame.new(0, y, frenteZ + g / 2), cfg.colorRejilla)
	end

	-- Laterales de la cesta. La cara trasera no lleva barras: queda oculta
	-- contra el cuerpo y serian caras invisibles consumiendo presupuesto.
	for _, lado in ipairs({ -1, 1 }) do
		local sufijo = lado < 0 and "Izq" or "Der"
		local x = lado * (anchoC / 2 - g / 2)
		for k = 1, CESTA.barrasLadoV do
			local z = frenteZ + k * (CESTA.fondo / (CESTA.barrasLadoV + 1))
			nuevaPieza(modelo, cuerpo, "RejillaLateral" .. sufijo .. "V" .. k, Vector3.new(g, altoC, g), CFrame.new(x, centroY, z), cfg.colorRejilla)
		end
		for j = 1, CESTA.barrasH do
			local y = centroY - altoC / 2 + j * (altoC / (CESTA.barrasH + 1))
			nuevaPieza(modelo, cuerpo, "RejillaLateral" .. sufijo .. "H" .. j, Vector3.new(g, g, CESTA.fondo), CFrame.new(x, y, centroZ), cfg.colorRejilla)
		end
	end

	-- Marcos superior e inferior: el borde grueso que remata la cesta.
	local marcoSup = centroY + altoC / 2 + 0.04
	local marcoInf = centroY - altoC / 2 - 0.04
	nuevaPieza(modelo, cuerpo, "RejillaMarcoSupFront", Vector3.new(anchoC + 0.16, 0.08, 0.08), CFrame.new(0, marcoSup, frenteZ + 0.01), cfg.colorDetalle)
	nuevaPieza(modelo, cuerpo, "RejillaMarcoInfFront", Vector3.new(anchoC + 0.16, 0.08, 0.08), CFrame.new(0, marcoInf, frenteZ + 0.01), cfg.colorDetalle)
	for _, lado in ipairs({ -1, 1 }) do
		local sufijo = lado < 0 and "Izq" or "Der"
		local x = lado * (anchoC / 2 + 0.01)
		nuevaPieza(modelo, cuerpo, "RejillaMarcoSup" .. sufijo, Vector3.new(0.08, 0.08, CESTA.fondo + 0.16), CFrame.new(x, marcoSup, centroZ), cfg.colorDetalle)
		nuevaPieza(modelo, cuerpo, "RejillaMarcoInf" .. sufijo, Vector3.new(0.08, 0.08, CESTA.fondo + 0.16), CFrame.new(x, marcoInf, centroZ), cfg.colorDetalle)
	end

	-- Fondo solido: los paquetes se apoyan aqui y no se ven huecos desde abajo.
	nuevaPieza(modelo, cuerpo, "RejillaFondo", Vector3.new(anchoC, 0.06, CESTA.fondo), CFrame.new(0, centroY - altoC / 2 + 0.03, centroZ), cfg.colorDetalle)

	if not cfg.conPaquetes then
		return
	end

	-- Tres paquetes kraft sobresaliendo por encima del marco, como en la lamina.
	local baseY = centroY - altoC / 2 + 0.06
	local datos = {
		{ fx = -0.30, w = 0.36, h = 1.18 },
		{ fx = 0.05, w = 0.33, h = 1.10 },
		{ fx = 0.38, w = 0.28, h = 1.30 },
	}
	for i, dato in ipairs(datos) do
		local alto = dato.h * altoC
		nuevaPieza(
			modelo,
			cuerpo,
			"PaqueteCesta" .. i,
			Vector3.new(dato.w * anchoC, alto, 0.45),
			CFrame.new(dato.fx * anchoC, baseY + alto / 2, centroZ),
			cfg.colorCarton
		)
	end
end

local function construirCorrea(modelo, cuerpo, cfg, tapaTop)
	local W, H, D = cfg.tamano.X, cfg.tamano.Y, cfg.tamano.Z

	-- Siete segmentos sobre un arco: sale de la hombrera, se abre y vuelve.
	for i = 1, SEGMENTOS_CORREA do
		local f = (i - 1) / (SEGMENTOS_CORREA - 1)
		local y = H * 0.45 - f * H * 0.92
		local x = W / 2 + 0.09 + math.sin(f * math.pi) * 0.20
		local giro = -math.cos(f * math.pi) * 12
		nuevaPieza(
			modelo,
			cuerpo,
			"CorreaSegmento" .. i,
			Vector3.new(0.16, 0.55, 0.4),
			CFrame.new(x, y, D * 0.22) * CFrame.Angles(0, 0, math.rad(giro)),
			cfg.colorCorrea
		)
	end

	-- Hombrera escalonada sobre la tapa, donde nace la correa.
	local xHombro = W / 2 - 0.1
	nuevaPieza(
		modelo,
		cuerpo,
		"Hombrera",
		Vector3.new(0.62, 0.18, 0.52),
		CFrame.new(xHombro, tapaTop + 0.09 - HOLGURA, D * 0.22),
		cfg.colorCorrea
	)
	nuevaPieza(
		modelo,
		cuerpo,
		"HombreraPaso",
		Vector3.new(0.42, 0.12, 0.36),
		CFrame.new(xHombro, tapaTop + 0.18 + 0.05 - HOLGURA, D * 0.22),
		cfg.colorCorrea
	)

	-- Hebilla plateada al final de la correa, con su pasador oscuro.
	local xHebilla = W / 2 + 0.09
	local yHebilla = -H * 0.47 - 0.30
	nuevaPieza(
		modelo,
		cuerpo,
		"Hebilla",
		Vector3.new(0.2, 0.3, 0.46),
		CFrame.new(xHebilla, yHebilla, D * 0.22),
		PALETA.hebilla
	)
	nuevaPieza(
		modelo,
		cuerpo,
		"HebillaPasador",
		Vector3.new(0.22, 0.05, 0.28),
		CFrame.new(xHebilla, yHebilla, D * 0.22),
		cfg.colorCorrea
	)
end

local function aplicarGameplay(modelo, cuerpo, cfg, tapaTop)
	local D = cfg.tamano.Z

	local agarre = Instance.new("Attachment")
	agarre.Name = "PuntoAgarreAsa"
	agarre.Position = Vector3.new(0, tapaTop + 0.49, 0)
	agarre.Parent = cuerpo

	local espalda = Instance.new("Attachment")
	espalda.Name = "PuntoSujecionEspalda"
	espalda.Position = Vector3.new(0, 0, D / 2)
	espalda.Parent = cuerpo

	if cfg.conProximityPrompt then
		local aviso = Instance.new("ProximityPrompt")
		aviso.Name = "Recoger"
		aviso.ActionText = "Recoger"
		aviso.ObjectText = "Mochila de reparto"
		aviso.HoldDuration = 0.15
		aviso.MaxActivationDistance = 8
		aviso.RequiresLineOfSight = false
		aviso.Parent = cuerpo
	end

	modelo:SetAttribute("VersionModelo", MochilaReparto.VERSION)
	modelo:SetAttribute("TipoModelo", "MochilaReparto")
	modelo:SetAttribute("Variante", cfg.variante)
	modelo:SetAttribute("CapacidadPaquetes", cfg.capacidadPaquetes)
end

-- ---------------------------------------------------------------------------
-- API publica
-- ---------------------------------------------------------------------------

--[[
	Construye el modelo y lo devuelve sin padre. El pivote queda en el centro
	geometrico del cuerpo, con el frente (la cesta) mirando hacia -Z.
]]
function MochilaReparto.crear(config)
	local cfg = fusionar(DEFAULTS, config)
	assert(typeof(cfg.tamano) == "Vector3", "tamano debe ser Vector3")

	local modelo = Instance.new("Model")
	modelo.Name = cfg.nombre

	local cuerpo = nuevaParte("Cuerpo", cfg.tamano, modelo)
	cuerpo.Color = cfg.colorCuerpo
	cuerpo.Material = MATERIAL_CUERPO
	cuerpo.CanCollide = cfg.colisiona
	cuerpo.CanQuery = true
	cuerpo.CanTouch = true
	cuerpo.Massless = false
	cuerpo.Anchored = cfg.anclado
	cuerpo.CustomPhysicalProperties = PhysicalProperties.new(cfg.densidad, 0.6, 0.1, 1, 1)
	cuerpo.CFrame = CFrame.new()
	modelo.PrimaryPart = cuerpo

	local tapa, tapaTop = construirTapa(modelo, cuerpo, cfg)
	construirSilueta(modelo, cuerpo, cfg)
	construirAsa(modelo, cuerpo, cfg, tapaTop)
	construirBolsillos(modelo, cuerpo, cfg)
	construirCesta(modelo, cuerpo, cfg)
	construirCorrea(modelo, cuerpo, cfg, tapaTop)
	construirLogo(tapa, cfg)
	aplicarGameplay(modelo, cuerpo, cfg, tapaTop)

	return modelo
end

--[[
	Crea una variante declarada en MochilaReparto.VARIANTES. Las variantes solo
	ajustan color y atributos: la geometria base no cambia.
]]
function MochilaReparto.crearVariante(nombreVariante, overrides)
	local base = MochilaReparto.VARIANTES[nombreVariante]
	assert(base, "Variante desconocida: " .. tostring(nombreVariante))
	return MochilaReparto.crear(fusionar(base, overrides))
end

--[[
	Crea el modelo, lo coloca bajo un padre y lo mueve al CFrame indicado.
]]
function MochilaReparto.crearEn(padre, cframe, config)
	local modelo = MochilaReparto.crear(config)
	modelo.Parent = padre
	modelo:PivotTo(cframe or CFrame.new())
	return modelo
end

return MochilaReparto

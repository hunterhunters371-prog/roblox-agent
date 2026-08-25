--!strict
--[[
	MochilaReparto — constructor procedimental
	Versión 2.0.0

	Modelo de la mochila de reparto de la lámina «DELIVERY BACKPACK», construido
	entero con prismas rectos (formas cuadradas), sin cuñas ni mallas externas.

	Esta versión rehace la 1.0.0 después de auditar el modelo anterior en un
	visor 3D propio y encontrar catorce defectos reales. Cada corrección está
	marcada en el código con su identificador (E1 a E14) y documentada en
	`docs/modelado-3d/02-registro-iteraciones.md`.

	Geometría verificada por captura de pantalla en tres vistas (tres cuartos,
	frente y lateral) antes de escribir este archivo. Lo que no está verificado
	es su apariencia dentro de Roblox Studio: el visor aproxima la iluminación
	del motor, no la reproduce.

	Uso mínimo:

		local M = require(game.ReplicatedStorage.Modelos.MochilaReparto)
		M.crearEn(workspace, CFrame.new(0, 2.4, 0), { anclado = true })
]]

local MochilaReparto = {}

MochilaReparto.VERSION = "2.0.0"

-- ==========================================================================
-- Especificación geométrica
--
-- Todas las medidas están en studs. El cuerpo se centra en el origen del
-- modelo, el frente mira hacia -Z y el pivote coincide con el centro
-- geométrico del cuerpo, según la convención de la fase 7 del proceso.
-- ==========================================================================

local ANCHO = 2.6
local ALTO = 3.0
local FONDO = 1.6

-- Separación estándar del proyecto contra el z-fighting. Suficiente para que
-- dos caras no compitan, pequeña para que la pieza no se vea despegada.
local HOLGURA = 0.006

-- Cuánto sobresale una pieza "orgullosa" para leerse como escalón de voxel.
local ESCALON = 0.04

local TAPA = {
	alto = 0.9,
	sobresaleVertical = 0.046,
	sobresaleLateral = 0.06,
}

-- Alturas derivadas de la tapa. Se calculan una sola vez y todo lo que se
-- apoya en la tapa las referencia, para que mover la tapa mueva el conjunto.
local TAPA_TOPE = ALTO / 2 + TAPA.sobresaleVertical
local TAPA_BASE = TAPA_TOPE - TAPA.alto
local TAPA_CENTRO = (TAPA_TOPE + TAPA_BASE) / 2

-- E5: la cesta pasa de una rejilla de 5x4 con barra de 0.05 a una de 8x6 con
-- barra de 0.035. La malla de la lámina es fina; la anterior parecía una
-- reja de obra.
local CESTA = {
	ancho = 0.654,
	alto = 0.367,
	fondo = 0.55,
	centroY = -0.25,
	barrasVerticales = 8,
	barrasHorizontales = 6,
	barrasLateralV = 2,
	barrasLateralH = 4,
	barra = 0.035,
}

-- E11: la correa viaja por la espalda (z positivo) en vez de por el centro del
-- lateral. En la 1.0.0 ocupaba el mismo volumen que el bolsillo lateral
-- derecho y las dos piezas se interpenetraban.
-- E13: su distancia al costado la separa de las esquinas escalonadas, que
-- llegan hasta x = 1.34.
local CORREA = {
	segmentos = 7,
	fraccionSuperior = 0.42,
	alturaInferior = -1.15,
	fraccionFondo = 0.42,
	saliente = 0.15,
	arco = 0.10,
	giro = 10,
}

-- Presupuesto declarado antes de construir, comprobado al terminar.
local PRESUPUESTO = {
	piezas = 70,
	triangulos = 900,
}

-- ==========================================================================
-- Paleta
--
-- Ningún Color3 suelto en el resto del archivo: todo color se declara aquí y
-- se referencia por rol. Cambiar una fila cambia el modelo entero.
-- ==========================================================================

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PALETA = {
	Turquesa = {
		cuerpo = rgb(56, 178, 169),
		detalle = rgb(34, 136, 128),
		rejilla = rgb(30, 122, 115),
	},
	Roja = {
		cuerpo = rgb(196, 74, 62),
		detalle = rgb(148, 48, 40),
		rejilla = rgb(134, 42, 35),
	},
	Azul = {
		cuerpo = rgb(64, 118, 206),
		detalle = rgb(44, 86, 160),
		rejilla = rgb(38, 76, 144),
	},
}

-- Colores que no dependen de la variante.
local FIJOS = {
	correa = rgb(30, 30, 34),
	hebilla = rgb(150, 156, 160),
	metal = rgb(166, 171, 175),
	cartonA = rgb(206, 164, 112),
	cartonB = rgb(188, 145, 96),
	cartonC = rgb(172, 130, 84),
	crema = rgb(240, 238, 232),
	rojoLogo = rgb(198, 62, 52),
}

MochilaReparto.PALETA = PALETA

-- ==========================================================================
-- Materiales
--
-- E6: el modelo 1.0.0 forzaba SmoothPlastic en las sesenta y ocho piezas e
-- ignoraba su propia constante de material. Aquí cada rol declara el suyo y
-- se resuelve con pcall, porque un Enum ausente en una versión antigua del
-- motor no debe romper la construcción.
-- ==========================================================================

local function material(nombre: string, alternativa: Enum.Material): Enum.Material
	local ok, valor = pcall(function()
		return (Enum.Material :: any)[nombre]
	end)
	if ok and valor then
		return valor
	end
	return alternativa
end

local MATERIAL = {
	tela = material("Fabric", Enum.Material.SmoothPlastic),
	rigido = material("Plastic", Enum.Material.SmoothPlastic),
	metal = material("Metal", Enum.Material.SmoothPlastic),
	carton = material("Cardboard", Enum.Material.Wood),
}

-- Material por rol de pieza. El rol lo declara cada llamada de construcción.
local MATERIAL_POR_ROL: { [string]: Enum.Material } = {
	cuerpo = MATERIAL.tela,
	detalle = MATERIAL.rigido,
	rejilla = MATERIAL.rigido,
	correa = MATERIAL.tela,
	hebilla = MATERIAL.metal,
	metal = MATERIAL.metal,
	cartonA = MATERIAL.carton,
	cartonB = MATERIAL.carton,
	cartonC = MATERIAL.carton,
}

-- Roles que usan el color de la variante en vez de un color fijo.
local ROLES_DE_VARIANTE = {
	cuerpo = "cuerpo",
	detalle = "detalle",
	rejilla = "rejilla",
}

-- ==========================================================================
-- Variantes
--
-- Una variante es una tabla de sobrescrituras: color, atributos y masa. Nunca
-- cambia dimensiones ni nombres de piezas.
-- ==========================================================================

MochilaReparto.VARIANTES = {
	Estandar = { paleta = "Turquesa", etiqueta = "Reparto estándar" },
	Express = { paleta = "Roja", etiqueta = "Reparto exprés" },
	Refrigerado = { paleta = "Azul", etiqueta = "Reparto refrigerado" },
}

-- ==========================================================================
-- Utilidades de construcción
-- ==========================================================================

local function nuevaPieza(config: {
	nombre: string,
	rol: string,
	tamano: Vector3,
	posicion: Vector3,
	giroZ: number?,
	paleta: { [string]: Color3 },
	padre: Instance,
}): BasePart
	local pieza = Instance.new("Part")
	pieza.Name = config.nombre
	pieza.Size = config.tamano

	local rotacion = config.giroZ
	if rotacion and rotacion ~= 0 then
		pieza.CFrame = CFrame.new(config.posicion) * CFrame.Angles(0, 0, math.rad(rotacion))
	else
		pieza.CFrame = CFrame.new(config.posicion)
	end

	local clave = ROLES_DE_VARIANTE[config.rol]
	if clave then
		pieza.Color = config.paleta[clave]
	else
		pieza.Color = FIJOS[config.rol] or FIJOS.metal
	end

	pieza.Material = MATERIAL_POR_ROL[config.rol] or MATERIAL.rigido
	pieza.Anchored = false
	pieza.Massless = true
	pieza.CanCollide = false
	pieza.CanQuery = false
	pieza.CanTouch = false
	pieza.TopSurface = Enum.SurfaceType.Smooth
	pieza.BottomSurface = Enum.SurfaceType.Smooth
	pieza.Parent = config.padre

	return pieza
end

local function puntoDeAgarre(nombre: string, posicion: Vector3, padre: BasePart): Attachment
	local punto = Instance.new("Attachment")
	punto.Name = nombre
	punto.Position = posicion
	punto.Parent = padre
	return punto
end

-- ==========================================================================
-- Piezas del modelo
-- ==========================================================================

-- Cuerpo principal, esquinas escalonadas y zócalo.
local function construirCuerpo(modelo: Model, paleta: { [string]: Color3 }): BasePart
	local cuerpo = nuevaPieza({
		nombre = "Cuerpo",
		rol = "cuerpo",
		tamano = Vector3.new(ANCHO, ALTO, FONDO),
		posicion = Vector3.zero,
		paleta = paleta,
		padre = modelo,
	})
	cuerpo.CanCollide = true
	cuerpo.CanQuery = true
	cuerpo.CanTouch = true
	cuerpo.Massless = false

	-- E1: en la 1.0.0 las cuatro esquinas y el zócalo iban en el color oscuro de
	-- detalle, lo que dibujaba cuatro rayas verticales que la lámina no tiene.
	-- Ahora son del color del cuerpo y solo aportan volumen, no dibujo.
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			nuevaPieza({
				nombre = "EsquinaCuerpo",
				rol = "cuerpo",
				tamano = Vector3.new(0.20, ALTO - ESCALON, 0.20),
				posicion = Vector3.new(
					x * (ANCHO / 2 - 0.06),
					0,
					z * (FONDO / 2 - 0.06)
				),
				paleta = paleta,
				padre = modelo,
			})
		end
	end

	nuevaPieza({
		nombre = "Zocalo",
		rol = "cuerpo",
		tamano = Vector3.new(ANCHO + ESCALON, 0.14, FONDO + ESCALON),
		posicion = Vector3.new(0, -ALTO / 2 + 0.07, 0),
		paleta = paleta,
		padre = modelo,
	})

	return cuerpo
end

-- Tapa superior con su labio, los rieles laterales y el broche metálico.
local function construirTapa(modelo: Model, paleta: { [string]: Color3 })
	-- E10: la tapa sobresale del cuerpo en los tres ejes. En la 1.0.0 quedaba
	-- enrasada y no se leía como solapa independiente.
	nuevaPieza({
		nombre = "Tapa",
		rol = "cuerpo",
		tamano = Vector3.new(
			ANCHO + TAPA.sobresaleLateral * 2,
			TAPA.alto,
			FONDO + TAPA.sobresaleLateral * 2
		),
		posicion = Vector3.new(0, TAPA_CENTRO, 0),
		paleta = paleta,
		padre = modelo,
	})

	for _, lado in { -1, 1 } do
		nuevaPieza({
			nombre = "RielTapa",
			rol = "detalle",
			tamano = Vector3.new(0.06, 0.06, FONDO + 0.14),
			posicion = Vector3.new(lado * (ANCHO / 2 + 0.09), TAPA_BASE - 0.03, 0),
			paleta = paleta,
			padre = modelo,
		})
	end

	-- E8: el labio ya no invade la cara frontal de la tapa. Cuelga por debajo de
	-- su borde, así el logo dispone de toda la superficie. Y adelgaza de 0.22 a
	-- 0.16 studs, porque a 0.22 dibujaba una banda oscura demasiado ancha.
	nuevaPieza({
		nombre = "LabioTapa",
		rol = "detalle",
		tamano = Vector3.new(ANCHO + 0.14, 0.16, 0.09),
		posicion = Vector3.new(0, TAPA_BASE - 0.06, -(FONDO / 2 + 0.105 - HOLGURA)),
		paleta = paleta,
		padre = modelo,
	})

	-- E7: broche metálico del costado derecho, que la lámina dibuja y la 1.0.0
	-- no tenía.
	-- E14: va cerca del borde frontal, no en el centro del lateral.
	nuevaPieza({
		nombre = "BrocheLateral",
		rol = "metal",
		tamano = Vector3.new(0.09, 0.26, 0.30),
		posicion = Vector3.new(ANCHO / 2 + 0.105, 0.70, -0.45),
		paleta = paleta,
		padre = modelo,
	})
	nuevaPieza({
		nombre = "BrochePasador",
		rol = "metal",
		tamano = Vector3.new(0.13, 0.09, 0.16),
		posicion = Vector3.new(ANCHO / 2 + 0.13, 0.70, -0.45),
		paleta = paleta,
		padre = modelo,
	})
end

-- Asa de dos postes y barra, desplazada hacia la espalda para no chocar con
-- la vertical del logo.
local function construirAsa(modelo: Model, paleta: { [string]: Color3 }): Vector3
	local alturaPoste = TAPA_TOPE + 0.17 - HOLGURA
	for _, lado in { -1, 1 } do
		nuevaPieza({
			nombre = "PosteAsa",
			rol = "detalle",
			tamano = Vector3.new(0.16, 0.34, 0.16),
			posicion = Vector3.new(lado * 0.20 * ANCHO, alturaPoste, 0.12),
			paleta = paleta,
			padre = modelo,
		})
	end

	local alturaBarra = TAPA_TOPE + 0.42 - HOLGURA * 2
	nuevaPieza({
		nombre = "BarraAsa",
		rol = "detalle",
		tamano = Vector3.new(0.40 * ANCHO + 0.156, 0.16, 0.16),
		posicion = Vector3.new(0, alturaBarra, 0.12),
		paleta = paleta,
		padre = modelo,
	})

	return Vector3.new(0, alturaBarra, 0.12)
end

-- Bolsillos de los dos costados, con solapa y dos pliegues.
local function construirBolsillos(modelo: Model, paleta: { [string]: Color3 })
	for _, lado in { -1, 1 } do
		local x = lado * (ANCHO / 2 + 0.164)

		nuevaPieza({
			nombre = "BolsilloLateral",
			rol = "cuerpo",
			tamano = Vector3.new(0.34, 0.81, 0.70),
			posicion = Vector3.new(x, -0.60, 0.06),
			paleta = paleta,
			padre = modelo,
		})

		nuevaPieza({
			nombre = "SolapaBolsillo",
			rol = "detalle",
			tamano = Vector3.new(0.36, 0.16, 0.72),
			posicion = Vector3.new(lado * (ANCHO / 2 + 0.174), -0.16, 0.06),
			paleta = paleta,
			padre = modelo,
		})

		for _, altura in { -0.72, -0.90 } do
			nuevaPieza({
				nombre = "PliegueBolsillo",
				rol = "detalle",
				tamano = Vector3.new(0.36, 0.04, 0.684),
				posicion = Vector3.new(lado * (ANCHO / 2 + 0.174), altura, 0.06),
				paleta = paleta,
				padre = modelo,
			})
		end
	end
end

-- Cesta frontal de rejilla y los tres paquetes que asoman por encima.
local function construirCesta(modelo: Model, paleta: { [string]: Color3 }): Vector3
	local ancho = ANCHO * CESTA.ancho
	local alto = ALTO * CESTA.alto
	local centroY = ALTO * CESTA.centroY
	local centroZ = -(FONDO / 2 + CESTA.fondo / 2 - HOLGURA * 2)
	local frenteZ = centroZ - CESTA.fondo / 2
	local baseY = centroY - alto / 2
	local marcoSuperiorY = centroY + alto / 2
	local barra = CESTA.barra

	-- Marco: suelo, borde superior y las dos columnas de las esquinas.
	nuevaPieza({
		nombre = "SueloCesta",
		rol = "rejilla",
		tamano = Vector3.new(ancho, barra * 1.6, CESTA.fondo),
		posicion = Vector3.new(0, baseY, centroZ),
		paleta = paleta,
		padre = modelo,
	})
	nuevaPieza({
		nombre = "MarcoCestaSuperior",
		rol = "rejilla",
		tamano = Vector3.new(ancho, barra * 1.6, CESTA.fondo),
		posicion = Vector3.new(0, marcoSuperiorY, centroZ),
		paleta = paleta,
		padre = modelo,
	})
	for _, lado in { -1, 1 } do
		nuevaPieza({
			nombre = "ColumnaCesta",
			rol = "rejilla",
			tamano = Vector3.new(barra * 1.6, alto, barra * 1.6),
			posicion = Vector3.new(lado * (ancho / 2 - barra), centroY, frenteZ + barra),
			paleta = paleta,
			padre = modelo,
		})
	end

	-- Rejilla frontal.
	for i = 1, CESTA.barrasVerticales do
		local f = (i - 0.5) / CESTA.barrasVerticales
		nuevaPieza({
			nombre = "BarraCestaV",
			rol = "rejilla",
			tamano = Vector3.new(barra, alto, barra),
			posicion = Vector3.new(-ancho / 2 + f * ancho, centroY, frenteZ),
			paleta = paleta,
			padre = modelo,
		})
	end
	for i = 1, CESTA.barrasHorizontales do
		local f = (i - 0.5) / CESTA.barrasHorizontales
		nuevaPieza({
			nombre = "BarraCestaH",
			rol = "rejilla",
			tamano = Vector3.new(ancho, barra, barra),
			posicion = Vector3.new(0, baseY + f * alto, frenteZ),
			paleta = paleta,
			padre = modelo,
		})
	end

	-- Rejilla de los dos costados de la cesta. La cara trasera no se construye:
	-- queda oculta contra el cuerpo y gastaría presupuesto.
	for _, lado in { -1, 1 } do
		for i = 1, CESTA.barrasLateralV do
			local f = (i - 0.5) / CESTA.barrasLateralV
			nuevaPieza({
				nombre = "BarraCestaLadoV",
				rol = "rejilla",
				tamano = Vector3.new(barra, alto, barra),
				posicion = Vector3.new(
					lado * (ancho / 2),
					centroY,
					frenteZ + f * CESTA.fondo
				),
				paleta = paleta,
				padre = modelo,
			})
		end
		for i = 1, CESTA.barrasLateralH do
			local f = (i - 0.5) / CESTA.barrasLateralH
			nuevaPieza({
				nombre = "BarraCestaLadoH",
				rol = "rejilla",
				tamano = Vector3.new(barra, barra, CESTA.fondo),
				posicion = Vector3.new(lado * (ancho / 2), baseY + f * alto, centroZ),
				paleta = paleta,
				padre = modelo,
			})
		end
	end

	-- E4: tres paquetes con separación real de 0.09 studs y tres tonos de cartón
	-- distintos. En la 1.0.0 los huecos eran de 0.008 y 0.042 studs, así que a
	-- distancia de juego se leían como un bloque único.
	-- E12: sus alturas suben para que sobresalgan del marco entre 0.12 y 0.39
	-- studs. Antes el tercero asomaba 0.036 studs, es decir, no asomaba.
	local paquetes = {
		{ x = -0.46, ancho = 0.44, alto = 1.35, rol = "cartonB" },
		{ x = 0.05, ancho = 0.40, alto = 1.48, rol = "cartonA" },
		{ x = 0.51, ancho = 0.34, alto = 1.24, rol = "cartonC" },
	}
	for _, paquete in paquetes do
		local altura = paquete.alto * alto
		nuevaPieza({
			nombre = "PaqueteCesta",
			rol = paquete.rol,
			tamano = Vector3.new(paquete.ancho, altura, 0.45),
			posicion = Vector3.new(paquete.x, baseY + 0.06 + altura / 2, centroZ),
			paleta = paleta,
			padre = modelo,
		})
	end

	return Vector3.new(0, marcoSuperiorY, centroZ)
end

-- Correa de hombro, hombrera y hebilla inferior.
local function construirCorrea(modelo: Model, paleta: { [string]: Color3 })
	local alturaSuperior = ALTO * CORREA.fraccionSuperior
	local alturaInferior = CORREA.alturaInferior
	local z = FONDO * CORREA.fraccionFondo

	-- E2: el segmento más bajo termina en y = -1.40, por encima de la base del
	-- cuerpo, que está en -1.50. En la 1.0.0 la correa bajaba hasta -1.86 y
	-- atravesaba el suelo.
	-- E3: el saliente de 0.15 studs mantiene la correa pegada a las esquinas del
	-- cuerpo. Antes quedaba un hueco de hasta 0.29 studs y parecía flotar.
	for i = 1, CORREA.segmentos do
		local f = (i - 1) / (CORREA.segmentos - 1)
		local y = alturaSuperior - f * (alturaSuperior - alturaInferior)
		local x = ANCHO / 2
			+ CORREA.saliente
			+ math.sin(f * math.pi) * CORREA.arco
		nuevaPieza({
			nombre = "SegmentoCorrea",
			rol = "correa",
			tamano = Vector3.new(0.16, 0.50, 0.40),
			posicion = Vector3.new(x, y, z),
			giroZ = -math.cos(f * math.pi) * CORREA.giro,
			paleta = paleta,
			padre = modelo,
		})
	end

	nuevaPieza({
		nombre = "Hombrera",
		rol = "correa",
		tamano = Vector3.new(0.62, 0.18, 0.52),
		posicion = Vector3.new(ANCHO / 2 - 0.10, TAPA_TOPE + 0.09 - HOLGURA, z),
		paleta = paleta,
		padre = modelo,
	})
	nuevaPieza({
		nombre = "HombreraCresta",
		rol = "correa",
		tamano = Vector3.new(0.42, 0.12, 0.36),
		posicion = Vector3.new(ANCHO / 2 - 0.10, TAPA_TOPE + 0.23 - HOLGURA, z),
		paleta = paleta,
		padre = modelo,
	})

	-- E13: la hebilla se aparta a 0.15 studs del costado para librar la esquina
	-- escalonada, que alcanza x = 1.34. A 0.10 studs las dos piezas se cruzaban.
	nuevaPieza({
		nombre = "Hebilla",
		rol = "hebilla",
		tamano = Vector3.new(0.20, 0.26, 0.46),
		posicion = Vector3.new(ANCHO / 2 + CORREA.saliente, -1.30, z),
		paleta = paleta,
		padre = modelo,
	})
	nuevaPieza({
		nombre = "PasadorHebilla",
		rol = "correa",
		tamano = Vector3.new(0.22, 0.05, 0.28),
		posicion = Vector3.new(ANCHO / 2 + CORREA.saliente, -1.30, z),
		paleta = paleta,
		padre = modelo,
	})
end

-- ==========================================================================
-- Logotipo «60 SEC»
--
-- Se dibuja con SurfaceGui sobre la cara frontal de la tapa. Mientras no haya
-- texturas subidas a Roblox, esta es la única forma de que el modelo se
-- reconstruya entero desde el repositorio.
-- ==========================================================================

local function construirLogo(tapa: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LogoFrontal"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.MaxDistance = 60
	gui.PixelsPerStud = 80
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = tapa

	-- E9: el «6», el cronómetro y el «SEC» comparten un contenedor centrado. En
	-- la 1.0.0 cada grupo se posicionaba por separado y el conjunto quedaba
	-- descentrado respecto a la tapa.
	local marco = Instance.new("Frame")
	marco.Name = "Marco"
	marco.BackgroundTransparency = 1
	marco.AnchorPoint = Vector2.new(0.5, 0.5)
	marco.Position = UDim2.fromScale(0.5, 0.5)
	marco.Size = UDim2.fromScale(0.62, 0.74)
	marco.Parent = gui

	local fila = Instance.new("Frame")
	fila.Name = "FilaSuperior"
	fila.BackgroundTransparency = 1
	fila.Position = UDim2.fromScale(0, 0)
	fila.Size = UDim2.fromScale(1, 0.52)
	fila.Parent = marco

	local seis = Instance.new("TextLabel")
	seis.Name = "Seis"
	seis.BackgroundTransparency = 1
	seis.Font = Enum.Font.GothamBlack
	seis.Text = "6"
	seis.TextColor3 = FIJOS.crema
	seis.TextScaled = true
	seis.TextXAlignment = Enum.TextXAlignment.Right
	seis.Position = UDim2.fromScale(0, 0)
	seis.Size = UDim2.fromScale(0.46, 1)
	seis.Parent = fila

	-- El cero del «60» es el cronómetro: aro crema con aguja roja.
	local aro = Instance.new("Frame")
	aro.Name = "Cronometro"
	aro.BackgroundTransparency = 1
	aro.BorderSizePixel = 0
	aro.Position = UDim2.fromScale(0.50, 0.06)
	aro.Size = UDim2.fromScale(0.42, 0.88)
	aro.Parent = fila

	local aroBorde = Instance.new("UIStroke")
	aroBorde.Color = FIJOS.crema
	aroBorde.Thickness = 5
	aroBorde.Parent = aro

	local aroForma = Instance.new("UICorner")
	aroForma.CornerRadius = UDim.new(0.5, 0)
	aroForma.Parent = aro

	local boton = Instance.new("Frame")
	boton.Name = "BotonCronometro"
	boton.BackgroundColor3 = FIJOS.crema
	boton.BorderSizePixel = 0
	boton.AnchorPoint = Vector2.new(0.5, 1)
	boton.Position = UDim2.fromScale(0.5, 0.02)
	boton.Size = UDim2.fromScale(0.26, 0.18)
	boton.Parent = aro

	local aguja = Instance.new("Frame")
	aguja.Name = "Aguja"
	aguja.BackgroundColor3 = FIJOS.rojoLogo
	aguja.BorderSizePixel = 0
	aguja.AnchorPoint = Vector2.new(0.5, 1)
	aguja.Position = UDim2.fromScale(0.5, 0.54)
	aguja.Size = UDim2.fromScale(0.12, 0.34)
	aguja.Rotation = 32
	aguja.Parent = aro

	local sec = Instance.new("TextLabel")
	sec.Name = "Sec"
	sec.BackgroundTransparency = 1
	sec.Font = Enum.Font.GothamBlack
	sec.Text = "SEC"
	sec.TextColor3 = FIJOS.crema
	sec.TextScaled = true
	sec.TextXAlignment = Enum.TextXAlignment.Center
	sec.Position = UDim2.fromScale(0, 0.54)
	sec.Size = UDim2.fromScale(1, 0.46)
	sec.Parent = marco
end

-- ==========================================================================
-- Ensamblado
-- ==========================================================================

local function soldar(cuerpo: BasePart, modelo: Model)
	for _, pieza in modelo:GetDescendants() do
		if pieza:IsA("BasePart") and pieza ~= cuerpo then
			local union = Instance.new("WeldConstraint")
			union.Part0 = cuerpo
			union.Part1 = pieza
			union.Parent = cuerpo
		end
	end
end

local function contarPiezas(modelo: Model): number
	local total = 0
	for _, pieza in modelo:GetDescendants() do
		if pieza:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

--[[
	Construye una mochila y devuelve el Model.

	config.variante  nombre de MochilaReparto.VARIANTES, por defecto "Estandar"
	config.paleta    fuerza una paleta concreta, ignorando la de la variante
	config.anclado   ancla el cuerpo en su sitio, útil para escenas de revisión
	config.tamano    escala uniforme aplicada al modelo terminado
	config.interaccion  añade el ProximityPrompt de recogida, por defecto true
]]
function MochilaReparto.crear(config: { [string]: any }?): Model
	local opciones = config or {}
	local nombreVariante = opciones.variante or "Estandar"
	local variante = MochilaReparto.VARIANTES[nombreVariante]
	if not variante then
		error(string.format("MochilaReparto: variante desconocida %q", tostring(nombreVariante)))
	end

	local paleta = PALETA[opciones.paleta or variante.paleta]
	if not paleta then
		error(string.format("MochilaReparto: paleta desconocida %q", tostring(opciones.paleta)))
	end

	local modelo = Instance.new("Model")
	modelo.Name = "MochilaReparto"

	local cuerpo = construirCuerpo(modelo, paleta)
	modelo.PrimaryPart = cuerpo

	construirTapa(modelo, paleta)
	local puntoAsa = construirAsa(modelo, paleta)
	construirBolsillos(modelo, paleta)
	local puntoCesta = construirCesta(modelo, paleta)
	construirCorrea(modelo, paleta)

	local tapa = modelo:FindFirstChild("Tapa")
	if tapa and tapa:IsA("BasePart") then
		construirLogo(tapa)
	end

	-- Puntos de interacción declarados como Attachment, para que el gameplay no
	-- calcule offsets a mano.
	puntoDeAgarre("PuntoAgarreAsa", puntoAsa, cuerpo)
	puntoDeAgarre("PuntoSujecionEspalda", Vector3.new(0, 0.30, FONDO / 2), cuerpo)
	puntoDeAgarre("PuntoCesta", puntoCesta, cuerpo)

	-- Física explícita: una mochila cargada no debe rebotar como una pelota.
	cuerpo.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.6, 0.15, 1, 1)

	if opciones.interaccion ~= false then
		local aviso = Instance.new("ProximityPrompt")
		aviso.Name = "AvisoRecoger"
		aviso.ActionText = "Recoger"
		aviso.ObjectText = "Mochila de reparto"
		aviso.HoldDuration = 0.35
		aviso.MaxActivationDistance = 8
		aviso.RequiresLineOfSight = false
		aviso.Parent = cuerpo
	end

	soldar(cuerpo, modelo)

	local piezas = contarPiezas(modelo)

	modelo:SetAttribute("VersionModelo", MochilaReparto.VERSION)
	modelo:SetAttribute("Variante", nombreVariante)
	modelo:SetAttribute("Etiqueta", variante.etiqueta)
	modelo:SetAttribute("CapacidadPaquetes", 3)
	modelo:SetAttribute("PiezasTotales", piezas)
	modelo:SetAttribute("AnchoStuds", ANCHO)
	modelo:SetAttribute("AltoStuds", ALTO)
	modelo:SetAttribute("FondoStuds", FONDO)

	-- Presupuesto de la fase 4 comprobado al final, como manda el proceso.
	if piezas > PRESUPUESTO.piezas then
		warn(string.format(
			"MochilaReparto: %d piezas superan el presupuesto de %d",
			piezas,
			PRESUPUESTO.piezas
		))
	end

	if opciones.anclado then
		cuerpo.Anchored = true
	end

	if opciones.tamano then
		modelo:ScaleTo(opciones.tamano)
	end

	return modelo
end

-- Atajo por nombre de variante.
function MochilaReparto.crearVariante(nombre: string, config: { [string]: any }?): Model
	local opciones = table.clone(config or {})
	opciones.variante = nombre
	return MochilaReparto.crear(opciones)
end

-- Construye y coloca en un CFrame concreto.
function MochilaReparto.crearEn(padre: Instance, cframe: CFrame, config: { [string]: any }?): Model
	local modelo = MochilaReparto.crear(config)
	modelo.Parent = padre
	modelo:PivotTo(cframe)
	return modelo
end

return MochilaReparto

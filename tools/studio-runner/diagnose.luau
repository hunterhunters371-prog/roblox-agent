-- Roblox Agent Bridge -- diagnostico de vehiculos con fisica real
-- Se ejecuta desde la linea de comandos de Studio (nivel barra de comandos):
--   RobloxStudioBeta.exe --task RunScript --runScriptFile diagnose.luau
--     --outputFile informe.txt --placeId <id> --universeId <id> --quitAfterExecution
--
-- SEGURIDAD: RunService:Stop() NO deshace lo que la fisica movio (documentado
-- por Roblox). Por eso guardamos el CFrame de toda pieza suelta del Workspace
-- antes de simular y lo restauramos al final. Ademas run.cmd cierra Studio sin
-- guardar, asi que nada de esto llega al archivo del place.

local RunService = game:GetService('RunService')
local Http = game:GetService('HttpService')

-- ---------------------------------------------------------------- ajustes
local OBJETIVOS = {
	'DeliveryTruck_MK2',
	'Dusty Trip Car With Auto Flip and NITRO',
}
local SIMULAR = true
local SEGUNDOS = 6
local INTERVALO = 0.1
local RESTAURAR = true
local MAX_SUELTAS = 4000

-- ---------------------------------------------------------------- utiles
local informe = {
	generado = os.date('!%Y-%m-%dT%H:%M:%SZ'),
	placeId = game.PlaceId,
	simulacion = {},
	vehiculos = {},
	avisos = {},
}

local function aviso(t)
	table.insert(informe.avisos, t)
end

local function r(n)
	if typeof(n) ~= 'number' then return n end
	return math.floor(n * 100 + 0.5) / 100
end

local function v3(v)
	return { r(v.X), r(v.Y), r(v.Z) }
end

local function inclinacion(cf)
	local d = cf.UpVector:Dot(Vector3.new(0, 1, 0))
	return math.deg(math.acos(math.clamp(d, -1, 1)))
end

local function baseParts(raiz)
	local t = {}
	if raiz:IsA('BasePart') then
		table.insert(t, raiz)
	end
	for _, d in ipairs(raiz:GetDescendants()) do
		if d:IsA('BasePart') then
			table.insert(t, d)
		end
	end
	return t
end

-- ------------------------------------------------------- analisis estatico
local function analizar(modelo)
	local partes = baseParts(modelo)
	local info = {
		clase = modelo.ClassName,
		piezas = #partes,
		masaViva = 0,
		masaIgnorada = 0,
		piezasSinPeso = 0,
		piezasAncladas = {},
		constraintsRotos = {},
		soldadurasRotas = {},
		ruedas = {},
	}

	for _, p in ipairs(partes) do
		local m = p:GetMass()
		if p.Massless then
			info.piezasSinPeso += 1
			info.masaIgnorada += m
		else
			info.masaViva += m
		end
		if p.Anchored then
			table.insert(info.piezasAncladas, p.Name)
		end
		local bajo = p.Position.Y - p.Size.Y / 2
		if info.puntoMasBajo == nil or bajo < info.puntoMasBajo then
			info.puntoMasBajo = bajo
			info.piezaMasBaja = p.Name
		end
	end
	info.masaViva = r(info.masaViva)
	info.masaIgnorada = r(info.masaIgnorada)
	info.puntoMasBajo = r(info.puntoMasBajo)

	-- masa del cuerpo rigido completo: la cifra que decide como responde
	-- la suspension. Si esto es bajo, los muelles rebotan y el coche baila.
	local raizFisica = nil
	if modelo:IsA('Model') and modelo.PrimaryPart then
		raizFisica = modelo.PrimaryPart
	else
		raizFisica = partes[1]
	end
	if raizFisica then
		info.raizFisica = raizFisica.Name
		info.masaEnsamblaje = r(raizFisica.AssemblyMass)
		info.posicionRaiz = v3(raizFisica.Position)
		info.inclinacionInicial = r(inclinacion(raizFisica.CFrame))
	else
		aviso(modelo.Name .. ': sin BasePart, no hay fisica que medir')
	end

	-- referencias sueltas: la causa tipica de que un clon no responda
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA('Constraint') then
			if d.Attachment0 == nil or d.Attachment1 == nil then
				table.insert(info.constraintsRotos, d.ClassName .. ' ' .. d:GetFullName())
			end
		elseif d:IsA('WeldConstraint') then
			if d.Part0 == nil or d.Part1 == nil then
				table.insert(info.soldadurasRotas, 'WeldConstraint ' .. d:GetFullName())
			end
		elseif d:IsA('JointInstance') then
			if d.Part0 == nil or d.Part1 == nil then
				table.insert(info.soldadurasRotas, d.ClassName .. ' ' .. d:GetFullName())
			end
		end
	end

	-- contacto con el suelo rueda por rueda
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { modelo }
	for _, p in ipairs(partes) do
		if string.find(p.Name, 'Wheel') then
			local res = workspace:Raycast(p.Position, Vector3.new(0, -80, 0), params)
			local fila = {
				nombre = p.Name,
				y = r(p.Position.Y),
				radio = r(p.Size.Y / 2),
			}
			if res then
				fila.suelo = res.Instance.Name
				fila.huecoBajoRueda = r((p.Position.Y - p.Size.Y / 2) - res.Position.Y)
			else
				fila.suelo = 'NADA DEBAJO'
			end
			table.insert(info.ruedas, fila)
		end
	end

	return info, raizFisica
end

-- ------------------------------------------------------- estado del mundo
local function fotografiarMundo()
	local t = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA('BasePart') and not d.Anchored then
			if #t >= MAX_SUELTAS then
				aviso('mas de ' .. MAX_SUELTAS .. ' piezas sueltas: restauracion parcial')
				break
			end
			table.insert(t, { p = d, cf = d.CFrame })
		end
	end
	return t
end

local function devolverMundo(foto)
	local hechas = 0
	for _, e in ipairs(foto) do
		if e.p and e.p.Parent then
			local ok = pcall(function()
				e.p.AssemblyLinearVelocity = Vector3.zero
				e.p.AssemblyAngularVelocity = Vector3.zero
				e.p.CFrame = e.cf
			end)
			if ok then
				hechas += 1
			end
		end
	end
	return hechas
end

-- ------------------------------------------------------------------ main
local encontrados = {}
for _, nombre in ipairs(OBJETIVOS) do
	local m = workspace:FindFirstChild(nombre)
	if m then
		table.insert(encontrados, m)
	else
		aviso('no esta en Workspace: ' .. nombre)
	end
end

local raices = {}
for _, m in ipairs(encontrados) do
	local info, raiz = analizar(m)
	informes = nil
	informe.vehiculos[m.Name] = info
	if raiz then
		raices[m.Name] = raiz
	end
end

if SIMULAR and next(raices) ~= nil then
	local foto = fotografiarMundo()
	informe.simulacion.piezasFotografiadas = #foto

	local arranco, fallo = pcall(function()
		RunService:Run()
	end)
	informe.simulacion.arranco = arranco
	if not arranco then
		informe.simulacion.error = tostring(fallo)
		aviso('no se pudo iniciar la simulacion; solo hay datos estaticos')
	else
		local series = {}
		for nombre in pairs(raices) do
			series[nombre] = {}
		end

		local t0 = os.clock()
		while os.clock() - t0 < SEGUNDOS do
			local t = os.clock() - t0
			for nombre, raiz in pairs(raices) do
				if raiz.Parent then
					table.insert(series[nombre], {
						t = r(t),
						pos = v3(raiz.Position),
						inc = r(inclinacion(raiz.CFrame)),
						vel = r(raiz.AssemblyLinearVelocity.Magnitude),
						giro = r(raiz.AssemblyAngularVelocity.Magnitude),
					})
				end
			end
			task.wait(INTERVALO)
		end

		pcall(function()
			RunService:Stop()
		end)

		-- resumen legible por vehiculo
		for nombre, muestras in pairs(series) do
			local v = informe.vehiculos[nombre]
			if v and #muestras > 0 then
				local primera = muestras[1]
				local ultima = muestras[#muestras]
				local incMax, incMin, velMax, giroMax = -1, 999, 0, 0
				local suma = 0
				for _, s in ipairs(muestras) do
					if s.inc > incMax then incMax = s.inc end
					if s.inc < incMin then incMin = s.inc end
					if s.vel > velMax then velMax = s.vel end
					if s.giro > giroMax then giroMax = s.giro end
					suma += s.inc
				end
				local dx = ultima.pos[1] - primera.pos[1]
				local dz = ultima.pos[3] - primera.pos[3]
				v.prueba = {
					segundos = SEGUNDOS,
					muestras = #muestras,
					inclinacionMax = r(incMax),
					inclinacionMin = r(incMin),
					inclinacionMedia = r(suma / #muestras),
					bamboleo = r(incMax - incMin),
					velocidadMax = r(velMax),
					giroMax = r(giroMax),
					derivaHorizontal = r(math.sqrt(dx * dx + dz * dz)),
					caidaVertical = r(primera.pos[2] - ultima.pos[2]),
					posInicial = primera.pos,
					posFinal = ultima.pos,
				}
				if v.prueba.bamboleo > 6 then
					aviso(nombre .. ': bambolea ' .. v.prueba.bamboleo .. ' grados en reposo')
				end
				if v.prueba.derivaHorizontal > 3 then
					aviso(nombre .. ': se desplaza ' .. v.prueba.derivaHorizontal .. ' studs sin conductor')
				end
				if v.prueba.caidaVertical > 3 then
					aviso(nombre .. ': se hunde ' .. v.prueba.caidaVertical .. ' studs')
				end
			end
		end

		if RESTAURAR then
			informe.simulacion.piezasRestauradas = devolverMundo(foto)
		end
	end
else
	informe.simulacion.arranco = false
	informe.simulacion.motivo = 'sin objetivos o SIMULAR=false'
end

-- ---------------------------------------------------------------- salida
local texto = Http:JSONEncode(informe)
print('===RBX_INFORME_INICIO===')
local i = 1
while i <= #texto do
	print(string.sub(texto, i, i + 1399))
	i += 1400
end
print('===RBX_INFORME_FIN===')
print('[diagnose] listo: ' .. #texto .. ' bytes de informe')

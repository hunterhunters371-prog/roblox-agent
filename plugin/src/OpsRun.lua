-- OpsRun.lua (v3.4.0) — op run_code: ejecuta Luau en el contexto del plugin
-- (equivalente a la barra de comandos de Studio), a petición expresa del dueño
-- del repo para evaluación profunda del place. Captura print/warn, errores y
-- valores devueltos; todo viaja en `data` del result.json.
-- ATENCIÓN: es la única op que ejecuta código arbitrario del repo en Studio;
-- el resto del protocolo sigue limitado a las listas blancas de siempre.
--
-- Convención: handler(op, cmdId) -> (action, detail?, data?) y
-- error({ code, message }) al fallar.

local OpsRun = {}

local function fail(code, message)
	error({ code = code, message = message }, 0)
end

-- run_code { source } (v3.4.0)
-- Ejecuta `source` con loadstring en el contexto del plugin. print/warn quedan
-- capturados en data.output; los valores del return van en data.returned.
function OpsRun.run_code(op, _cmdId)
	if type(op.source) ~= "string" or op.source == "" then
		fail("VALIDATION_FAILED", "run_code requiere 'source' no vacío")
	end

	local salida = {}
	local function registrar(...)
		local partes = {}
		for i = 1, select("#", ...) do
			partes[i] = tostring(select(i, ...))
		end
		table.insert(salida, table.concat(partes, "\t"))
	end

	local fn, errCompile = loadstring(op.source, "run_code")
	if not fn then
		fail("VALIDATION_FAILED", "no compila: " .. tostring(errCompile))
	end

	-- entorno con print/warn capturados; el resto hereda el entorno del plugin
	local env = setmetatable({ print = registrar, warn = registrar }, { __index = getfenv(0) })
	setfenv(fn, env)

	local t0 = os.clock()
	local res = table.pack(pcall(fn))
	local duracionMs = math.floor((os.clock() - t0) * 1000 + 0.5)

	local ok = res[1]
	local devueltos = {}
	for i = 2, res.n do
		devueltos[i - 1] = tostring(res[i])
	end

	return nil, (ok and "run_code ok" or "run_code falló") .. (" (%d ms)"):format(duracionMs), {
		ok = ok,
		duration_ms = duracionMs,
		error = (not ok) and devueltos[1] or nil,
		output = salida,
		returned = devueltos,
	}
end

return OpsRun

-- Operaciones extra del protocolo (v2.0). Ops.lua llegó al límite sano de tamaño de
-- este repo (~16 KB por archivo escrito), así que las ops nuevas viven aquí y
-- Executor las fusiona en el mismo registro al cargar. Mismas convenciones que Ops.lua:
-- handler(op, cmdId) → (action, detail?, data?) y error({ code, message }) al fallar.

local InsertService = game:GetService("InsertService")

local Resolver = require(script.Parent.PathResolver)

local OpsExtra = {}

local function fail(code, message)
	error({ code = code, message = message }, 0)
end

local function mustResolve(path)
	local instance, code = Resolver.Resolve(path)
	if not instance then
		fail(code or "PATH_NOT_FOUND", path)
	end
	return instance
end

-- Marca de autoría del bridge (best-effort; algunos objetos no aceptan atributos).
local function marcar(instance, cmdId)
	pcall(function()
		instance:SetAttribute("_RBX_Bridge", cmdId or "agent-bridge")
	end)
end

-- Elimina TODOS los scripts de lo insertado. La Toolbox es el vector clásico de
-- malware en Roblox (modelos con scripts ocultos); por defecto no entra ni uno.
-- Solo se conservan si el comando trae allow_scripts = true (y eso fuerza aprobación).
local function quitarScripts(root)
	local quitados = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			pcall(function()
				d:Destroy()
			end)
			quitados += 1
		end
	end
	return quitados
end

-- insert_asset { asset_id, path?, position?, name?, allow_scripts? }
-- Inserta un asset de la Toolbox/Creator Store con InsertService:LoadAsset bajo `path`
-- (default Workspace). El asset debe ser gratuito/público o propiedad de esta cuenta;
-- si no, LoadAsset falla y la op reporta OP_FAILED.
-- Nota: la búsqueda por nombre NO es posible desde un plugin (HttpService no puede
-- llamar a roblox.com); el agente trabaja con asset_id exactos.
function OpsExtra.insert_asset(op, cmdId)
	local assetId = op.asset_id
	if type(assetId) ~= "number" or assetId <= 0 or assetId % 1 ~= 0 then
		fail("VALIDATION_FAILED", "asset_id debe ser un número entero positivo")
	end
	local parent = mustResolve(op.path or "Workspace")

	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		fail(
			"OP_FAILED",
			("LoadAsset(%d) falló: %s — ¿asset privado, retirado o de pago?"):format(assetId, tostring(container))
		)
	end
	if not container then
		fail("OP_FAILED", ("LoadAsset(%d) devolvió nil"):format(assetId))
	end

	-- LoadAsset suele devolver un Model contenedor con el item dentro; si hay un
	-- único hijo, trabajamos con ese hijo directamente.
	local item = container
	local hijos = container:GetChildren()
	if container:IsA("Model") and #hijos == 1 then
		item = hijos[1]
	end

	if type(op.name) == "string" and op.name ~= "" then
		item.Name = op.name
	end

	local quitados = 0
	if op.allow_scripts ~= true then
		quitados = quitarScripts(item)
	end

	if op.position then
		assert(type(op.position) == "table" and #op.position == 3, "position se esperaba [x, y, z]")
		local destino = CFrame.new(op.position[1], op.position[2], op.position[3])
		if item:IsA("Model") then
			item:PivotTo(destino)
		elseif item:IsA("BasePart") then
			item.CFrame = destino
		end
	end

	item.Parent = parent
	marcar(item, cmdId)
	if container ~= item then
		container:Destroy()
	end

	local detail = ("%s (%s) → %s"):format(item.Name, item.ClassName, Resolver.PathOf(item))
	if quitados > 0 then
		detail ..= (" · %d script(s) eliminados por seguridad"):format(quitados)
	end
	return "created", detail
end

return OpsExtra

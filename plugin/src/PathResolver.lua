-- Resolución de paths del protocolo ("Workspace.Arena.CenterPlatform") a Instances.

local ROOTS = {
	Workspace = workspace,
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ServerStorage = game:GetService("ServerStorage"),
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterGui = game:GetService("StarterGui"),
	StarterPack = game:GetService("StarterPack"),
	StarterPlayer = game:GetService("StarterPlayer"),
	Lighting = game:GetService("Lighting"),
	SoundService = game:GetService("SoundService"),
	Teams = game:GetService("Teams"),
}

local Resolver = {}

-- Divide por '.' respetando el escape '\.' del protocolo (punto literal en un nombre).
function Resolver.Split(path)
	local segments, buffer = {}, {}
	local i = 1
	while i <= #path do
		local char = path:sub(i, i)
		if char == "\\" and i < #path then
			i += 1
			table.insert(buffer, path:sub(i, i))
		elseif char == "." then
			table.insert(segments, table.concat(buffer))
			buffer = {}
		else
			table.insert(buffer, char)
		end
		i += 1
	end
	table.insert(segments, table.concat(buffer))
	return segments
end

function Resolver.GetRoot(name)
	return ROOTS[name]
end

-- Devuelve (instancia) o (nil, "ROOT_NOT_ALLOWED" | "PATH_NOT_FOUND").
function Resolver.Resolve(path)
	local segments = Resolver.Split(path)
	local root = ROOTS[table.remove(segments, 1) or ""]
	if not root then
		return nil, "ROOT_NOT_ALLOWED"
	end
	local current = root
	for _, name in ipairs(segments) do
		current = current:FindFirstChild(name)
		if not current then
			return nil, "PATH_NOT_FOUND"
		end
	end
	return current
end

-- Devuelve (padre, nombreFinal). Si el padre no existe: (nil, nombreFinal, código).
function Resolver.ResolveParent(path)
	local segments = Resolver.Split(path)
	local finalName = table.remove(segments)
	if not finalName then
		return nil, nil, "PATH_NOT_FOUND"
	end
	local parent, code = Resolver.Resolve(table.concat(segments, "."))
	if not parent then
		return nil, finalName, code
	end
	return parent, finalName
end

-- Path de protocolo de una instancia (para reportes y snapshots).
function Resolver.PathOf(instance)
	return instance:GetFullName()
end

return Resolver

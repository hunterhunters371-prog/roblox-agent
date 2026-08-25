-- Cliente mínimo de la API REST de GitHub para el bridge.
-- Solo opera sobre el repo configurado en Config.lua.

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Base64 = require(script.Parent.Base64)

local GitHub = {}
GitHub.__index = GitHub

function GitHub.new(token)
	assert(type(token) == "string" and #token > 0, "token de GitHub vacío")
	return setmetatable({ _token = token }, GitHub)
end

function GitHub:_url(path)
	return ("%s/repos/%s/%s%s"):format(Config.API_BASE, Config.REPO_OWNER, Config.REPO_NAME, path)
end

function GitHub:_request(method, path, body)
	local response = HttpService:RequestAsync({
		Url = self:_url(path),
		Method = method,
		Headers = {
			["Authorization"] = "Bearer " .. self._token,
			["Accept"] = "application/vnd.github+json",
			["X-GitHub-Api-Version"] = "2022-11-28",
			["Content-Type"] = "application/json",
		},
		Body = body and HttpService:JSONEncode(body) or nil,
	})
	if not response.Success then
		error({
			code = "OP_FAILED",
			message = ("GitHub %s %s → HTTP %d: %s"):format(
				method,
				path,
				response.StatusCode,
				tostring(response.Body):sub(1, 300)
			),
		}, 0)
	end
	if response.Body == nil or response.Body == "" then
		return nil
	end
	return HttpService:JSONDecode(response.Body)
end

-- Lista archivos de una carpeta (omite .gitkeep y similares). {} si no existe.
function GitHub:ListFiles(folder)
	local ok, result = pcall(function()
		return self:_request("GET", "/contents/" .. folder .. "?ref=" .. Config.BRANCH)
	end)
	if not ok or type(result) ~= "table" then
		return {}
	end
	local files = {}
	for _, item in ipairs(result) do
		if item.type == "file" and item.name:sub(1, 1) ~= "." then
			table.insert(files, { name = item.name, path = item.path, sha = item.sha })
		end
	end
	return files
end

-- Lee un archivo crudo. Devuelve (contenido, sha).
function GitHub:ReadFile(path)
	local file = self:_request("GET", "/contents/" .. path .. "?ref=" .. Config.BRANCH)
	local content = Base64.Decode((file.content:gsub("%s", "")))
	return content, file.sha
end

function GitHub:ReadJson(path)
	local content, sha = self:ReadFile(path)
	return HttpService:JSONDecode(content), sha
end

-- Sha actual del archivo en el repo, o nil si no existe (v1.9.4 — deuda 2).
-- El 404 llega como error de _request; el pcall lo convierte en nil.
function GitHub:_currentSha(path)
	local ok, file = pcall(function()
		return self:_request("GET", "/contents/" .. path .. "?ref=" .. Config.BRANCH)
	end)
	if ok and type(file) == "table" and type(file.sha) == "string" then
		return file.sha
	end
	return nil
end

-- Escribe (crea o actualiza) un archivo. Devuelve el nuevo sha del blob.
-- v1.9.4 (deuda 2): si no se pasa sha, consulta el actual antes del PUT —
-- sin él GitHub rechaza con 422 la reescritura de un archivo existente
-- (y al aprobar, el MoveFile a medias derivaba en un 404 en cascada).
-- Si el PUT falla con un sha en conflicto, reintenta una vez con el sha fresco.
function GitHub:WriteFile(path, content, message, sha)
	if sha == nil then
		sha = self:_currentSha(path)
	end
	local body = {
		message = message,
		content = Base64.Encode(content),
		branch = Config.BRANCH,
	}
	if sha then
		body.sha = sha
	end
	local ok, response = pcall(function()
		return self:_request("PUT", "/contents/" .. path, body)
	end)
	if not ok then
		local freshSha = self:_currentSha(path)
		if freshSha ~= nil and freshSha ~= sha then
			-- sha obsoleto: un solo reintento con el sha fresco
			body.sha = freshSha
			response = self:_request("PUT", "/contents/" .. path, body)
		else
			error(response, 0)
		end
	end
	return response and response.content and response.content.sha or nil
end

function GitHub:WriteJson(path, data, message, sha)
	return self:WriteFile(path, HttpService:JSONEncode(data), message, sha)
end

function GitHub:DeleteFile(path, sha, message)
	self:_request("DELETE", "/contents/" .. path, {
		message = message,
		sha = sha,
		branch = Config.BRANCH,
	})
end

-- Mueve un archivo SIN modificar su contenido (regla de oro del protocolo).
function GitHub:MoveFile(fromPath, toPath, message)
	local content, sha = self:ReadFile(fromPath)
	self:WriteFile(toPath, content, message)
	self:DeleteFile(fromPath, sha, message)
end

return GitHub

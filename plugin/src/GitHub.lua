-- Cliente mínimo de la API REST de GitHub para el bridge.
-- Solo opera sobre el repo configurado en Config.lua.
-- v1.9.3: ListFiles propaga errores reales (antes una carpeta vacía ocultaba
-- tokens rotos: el sync decía "0 comandos" como si todo fuera bien).

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
-- v1.9.3: un error real (token inválido, HTTP bloqueado en Play) se propaga en vez
-- de disfrazarse de carpeta vacía — así el sync lo muestra en vez de decir "0 comandos".
function GitHub:ListFiles(folder)
	local ok, result = pcall(function()
		return self:_request("GET", "/contents/" .. folder .. "?ref=" .. Config.BRANCH)
	end)
	if not ok then
		local msg = tostring(type(result) == "table" and result.message or result)
		if msg:find("404") then
			return {} -- la carpeta no existe todavía
		end
		error(result, 0) -- error real: que se vea en el registro
	end
	if type(result) ~= "table" then
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

-- Escribe (crea o actualiza) un archivo. Devuelve el nuevo sha del blob.
function GitHub:WriteFile(path, content, message, sha)
	local body = {
		message = message,
		content = Base64.Encode(content),
		branch = Config.BRANCH,
	}
	if sha then
		body.sha = sha
	end
	local response = self:_request("PUT", "/contents/" .. path, body)
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

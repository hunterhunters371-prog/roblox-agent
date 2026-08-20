-- Base64 mínimo para hablar con la Contents API de GitHub
-- (GitHub exige base64 al escribir archivos y devuelve base64 al leerlos).

local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local Base64 = {}

function Base64.Encode(data)
	return ((data:gsub(".", function(x)
		local r, b = "", x:byte()
		for i = 8, 1, -1 do
			r ..= (b % 2 ^ i - b % 2 ^ (i - 1) > 0) and "1" or "0"
		end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then
			return ""
		end
		local c = 0
		for i = 1, 6 do
			c += (x:sub(i, i) == "1") and 2 ^ (6 - i) or 0
		end
		return CHARS:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

function Base64.Decode(data)
	data = data:gsub("[^" .. CHARS .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then
			return ""
		end
		local r, f = "", (CHARS:find(x, 1, true) - 1)
		for i = 6, 1, -1 do
			r ..= (f % 2 ^ i - f % 2 ^ (i - 1) > 0) and "1" or "0"
		end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then
			return ""
		end
		local c = 0
		for i = 1, 8 do
			c += (x:sub(i, i) == "1") and 2 ^ (8 - i) or 0
		end
		return string.char(c)
	end))
end

return Base64

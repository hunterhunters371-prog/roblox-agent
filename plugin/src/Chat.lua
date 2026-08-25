-- Chat con el agente (v1.7). Submódulo del runtime: lo carga Main.lua.
-- Canal: chat/inbox/ (mensajes del usuario) ↔ chat/outbox/ (respuestas del agente).
-- El agente no está siempre activo: escribe aquí y avísale en Notion («lee el chat»);
-- él lee inbox/, deja su respuesta en outbox/ y el plugin la muestra solo (sondeo 20 s).
-- Recibe `env` con getters porque ui/github se crean después del init.

local Chat = {}

function Chat.init(env)
	local CHAT_IN = "chat/inbox"
	local CHAT_OUT = "chat/outbox"
	local chatVistos = {}
	local chatPrimeraPasada = true

	local function ui()
		return env.getUi()
	end

	local function enviar(texto)
		texto = texto:gsub("^%s*(.-)%s*$", "%1")
		if texto == "" then
			return
		end
		if not env.guardGithub() then
			return
		end
		ui():AddChatBubble("usuario", texto)
		local ok, err = pcall(function()
			env.getGithub():WriteJson(CHAT_IN .. "/msg_" .. os.date("!%Y%m%d_%H%M%S") .. ".json", {
				autor = "usuario",
				texto = texto,
				enviado_at = env.nowIso(),
			}, "chat: mensaje del usuario")
		end)
		if ok then
			ui():Log("✓ Mensaje enviado al agente (avísale en Notion: «lee el chat»).")
		else
			env.reportError("enviar mensaje de chat", err)
		end
	end

	local function revisar()
		local github = env.getGithub()
		if not github then
			return
		end
		local ok, archivos = pcall(function()
			return github:ListFiles(CHAT_OUT)
		end)
		if not ok or type(archivos) ~= "table" then
			return
		end
		local huboRespuesta = false
		for _, archivo in ipairs(archivos) do
			if archivo.name:match("^resp_%d%d%d%d%d%d%d%d_%d%d%d%d%d%d%.json$") and not chatVistos[archivo.name] then
				chatVistos[archivo.name] = true
				if not chatPrimeraPasada then
					local ok2, resp = pcall(function()
						return github:ReadJson(archivo.path)
					end)
					if ok2 and resp and resp.texto then
						ui():AddChatBubble("agente", resp.texto)
						ui():Log("💬 Respuesta del agente recibida en el chat.")
						huboRespuesta = true
					end
				end
			end
		end
		chatPrimeraPasada = false
		if huboRespuesta then
			-- las respuestas suelen venir con comandos nuevos: sincroniza en silencio
			env.sync(true)
		end
	end

	return { enviar = enviar, revisar = revisar }
end

return Chat

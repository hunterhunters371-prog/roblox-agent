-- Configuracion del Roblox Agent Bridge (protocolo v0.1)
return {
	VERSION = "0.1",

	REPO_OWNER = "hunterhunters371-prog",
	REPO_NAME = "roblox-agent",
	BRANCH = "main",

	API_BASE = "https://api.github.com",

	PATHS = {
		pending = "commands/pending",
		approved = "commands/approved",
		processing = "commands/processing",
		completed = "commands/completed",
		failed = "commands/failed",
		rejected = "commands/rejected",
		snapshots = "snapshots",
		logs = "logs",
		lint = "lint", -- v3.0: hallazgos del auto-lint
		place = "place", -- v3.0: espejo del estado actual de Studio
	},

	MAX_OPS = 500,

	-- AutoSense (v3.0): el plugin publica solo cuando algo cambia (firma del
	-- contenido); estos intervalos son la frecuencia con que se COMPRUEBA.
	AUTO_LINT = true, -- lint automatico de todos los scripts -> lint/findings.json
	AUTO_LINT_SECONDS = 600,
	AUTO_MIRROR = true, -- espejo del place -> place/mirror.json
	AUTO_MIRROR_SECONDS = 300,
	MIRROR_MAX_NODES = 2500,
}

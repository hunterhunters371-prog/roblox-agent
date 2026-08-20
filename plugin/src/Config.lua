-- Configuración del Roblox Agent Bridge (protocolo v0.1)
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
	},

	MAX_OPS = 500,
}

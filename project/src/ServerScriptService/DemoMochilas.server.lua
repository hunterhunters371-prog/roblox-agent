--[[
	DemoMochilas.server.lua
	Escena de revision del modelo MochilaReparto y sus variantes.

	Genera una fila de mochilas ancladas detras de la fila de paquetes de
	DemoPaquetes (z = -8) para inspeccionarlas en Studio. Sirve como prueba
	visual del checklist de calidad descrito en
	docs/modelado-3d/11-mochila-reparto.spec.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MochilaReparto = require(ReplicatedStorage:WaitForChild("Modelos"):WaitForChild("MochilaReparto"))

local NOMBRE_CARPETA = "MochilasDemo"
local ORDEN_VARIANTES = { "Turquesa", "Roja", "Azul" }
local SEPARACION = 3.4
local ALTURA = 2.4
local FILA_Z = -8

local carpeta = workspace:FindFirstChild(NOMBRE_CARPETA)
if carpeta then
	carpeta:Destroy()
end

carpeta = Instance.new("Folder")
carpeta.Name = NOMBRE_CARPETA
carpeta.Parent = workspace

local centro = (#ORDEN_VARIANTES + 1) / 2

for indice, nombreVariante in ipairs(ORDEN_VARIANTES) do
	local modelo = MochilaReparto.crearVariante(nombreVariante, {
		anclado = true,
	})
	modelo.Parent = carpeta
	modelo:PivotTo(CFrame.new((indice - centro) * SEPARACION, ALTURA, FILA_Z))
end

print(string.format("[DemoMochilas] %d variantes generadas en workspace.%s", #ORDEN_VARIANTES, NOMBRE_CARPETA))

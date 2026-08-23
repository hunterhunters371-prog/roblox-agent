--[[
	DemoPaquetes.server.lua
	Escena de revision del modelo base y sus variantes.

	Genera una fila de paquetes anclados delante del punto de aparicion para
	inspeccionarlos en Studio. Sirve como prueba visual del checklist de calidad
	descrito en docs/modelado-3d/01-paquete-normal.spec.md.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PaqueteNormal = require(ReplicatedStorage:WaitForChild("Modelos"):WaitForChild("PaqueteNormal"))

local NOMBRE_CARPETA = "PaquetesDemo"
local ORDEN_VARIANTES = { "Normal", "Fragil", "Pesado", "Express", "Refrigerado" }
local SEPARACION = 2.2
local ALTURA = 3.5

local carpeta = workspace:FindFirstChild(NOMBRE_CARPETA)
if carpeta then
	carpeta:Destroy()
end

carpeta = Instance.new("Folder")
carpeta.Name = NOMBRE_CARPETA
carpeta.Parent = workspace

local centro = (#ORDEN_VARIANTES + 1) / 2

for indice, nombreVariante in ipairs(ORDEN_VARIANTES) do
	local modelo = PaqueteNormal.crearVariante(nombreVariante, {
		anclado = true,
		codigo = string.format("60SEC-DEL-%05d", indice * 17),
	})
	modelo.Parent = carpeta
	modelo:PivotTo(CFrame.new((indice - centro) * SEPARACION, ALTURA, 0))
end

print(string.format("[DemoPaquetes] %d variantes generadas en workspace.%s", #ORDEN_VARIANTES, NOMBRE_CARPETA))

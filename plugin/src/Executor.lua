-- Ejecutor de comandos: aplica operaciones en orden, reporta progreso
-- y gestiona waypoints de Undo/Redo (ChangeHistoryService).

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Ops = require(script.Parent.Ops)
local Resolver = require(script.Parent.PathResolver)

local Executor = {}

local function isReadOnly(opName)
	return opName == "inspect_tree" or opName == "inspect_instance" or opName == "find_instances"
end

-- Dry-run: valida resolución de paths sin tocar el DataModel.
function Executor.DryRun(command)
	local results = {}
	for _, op in ipairs(command.operations) do
		local detail = ("ejecutaría %s"):format(op.op)
		if type(op.path) == "string" then
			local found = Resolver.Resolve(op.path)
			detail ..= (" sobre %s (%s)"):format(op.path, found and "existe" or "no existe — se crearía")
		end
		table.insert(results, { id = op.id, status = "ok", detail = detail })
	end
	return results, {}
end

-- Ejecuta el comando. onProgress(done, total, opId) se llama tras cada operación.
-- Devuelve results, errors, doneCount.
function Executor.Run(command, onProgress, startIndex)
	local options = command.options or {}
	local results, errors = {}, {}
	local total = #command.operations
	local first = startIndex or 1
	local done = first - 1

	local isPureRead = true
	for _, op in ipairs(command.operations) do
		if not isReadOnly(op.op) then
			isPureRead = false
			break
		end
	end

	if not isPureRead and options.create_waypoint ~= false then
		ChangeHistoryService:SetWaypoint("RBX antes de " .. command.id)
	end

	for index = first, total do
		local op = command.operations[index]
		local handler = Ops[op.op]
		if not handler then
			table.insert(results, { id = op.id or ("op_" .. index), status = "failed", action = "failed", detail = "op desconocido: " .. tostring(op.op) })
			table.insert(errors, { op_id = op.id, code = "VALIDATION_FAILED", message = "op desconocido" })
		else
			local ok, action, detail, data = pcall(handler, op)
			if ok then
				local entry = { id = op.id, status = "ok" }
				if action then
					entry.action = action
				end
				if detail then
					entry.detail = detail
				end
				if data ~= nil then
					entry.data = data
				end
				table.insert(results, entry)
			else
				local code, message = "OP_FAILED", tostring(action)
				if type(action) == "table" then
					code = action.code or code
					message = action.message or message
				end
				table.insert(results, { id = op.id, status = "failed", action = "failed", detail = message })
				table.insert(errors, { op_id = op.id, code = code, message = message })
				if options.atomic then
					-- revierte todo lo aplicado por este comando
					ChangeHistoryService:Undo()
					done = index
					if onProgress then
						onProgress(done, total, op.id)
					end
					break
				end
			end
		end
		done = index
		if onProgress then
			onProgress(done, total, op.id)
		end
	end

	if not isPureRead and options.create_waypoint ~= false then
		ChangeHistoryService:SetWaypoint("RBX fin de " .. command.id)
	end

	return results, errors, done
end

return Executor

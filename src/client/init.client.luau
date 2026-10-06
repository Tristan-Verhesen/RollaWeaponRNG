--!strict
--[[
	Client entry point.
]]

local Controllers = script.Controllers
local StateController = require(Controllers.StateController)
local RollController = require(Controllers.RollController)
local ZoneController = require(Controllers.ZoneController)
local App = require(script.UI.App)

StateController.start()
RollController.start()
App.mount()
-- Gates need the first snapshot to know which zones are open.
StateController.await()
ZoneController.start()

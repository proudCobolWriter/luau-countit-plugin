-- /*
-- @module MonitorScripts  Self-explanatory, watches script changes via ScriptEditorService
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

-- Retrieving services

local ScriptEditorService = game:GetService("ScriptEditorService")

-- Retrieving dependencies

local Util = require(script.Parent:WaitForChild("Util")) ---@module Util  Just a bunch of utility functions to complement the plugin and keep things clean

-- CONSTANTS

local PLUGIN_DATA_SAVE_KEY = "LinesOfCodeWritten"
local AUTOSAVE_INTERVAL = 300 -- 5 minutes

local MAXIMUM_VALUE = 1e10

-- CONNECTIONS and COROUTINES

local SCRIPT_OPENED_CONNECTION = nil
local SCRIPT_CLOSED_CONNECTION = nil
local SCRIPT_CHANGED_CONNECTION = nil

local AUTOSAVE_COROUT = nil

-- States

local AUTOSAVE_COROUT_KILL = false

-- Containers

local SCRIPTS_OPENED = {}

-- Declaring module

local Module = {
	CharactersWritten = 0,
	LinesWritten = 0,
}

-- Main functions

-- function isScriptOpened ( doc: ScriptDocument ): any
--	    ^
--	    * Checks if the given script can be found in table SCRIPTS_OPENED
--	    *
--	    * @param doc ScriptDocument Instance
--	    *
--	    * @return tuple of boolean and number
--
local function isScriptOpened(doc: ScriptDocument): ...any
	local scriptOpened, scriptIndex = false, nil
	for i, v in ipairs(SCRIPTS_OPENED) do
		if v == doc:GetScript() then
			scriptOpened, scriptIndex = true, i
			break
		end
	end
	return scriptOpened, scriptIndex
end

-- function saveData ( PLUGIN: Plugin ): nil
--	    ^
--	    * Saves plugin data (lines & chars written...)
--	    *
--	    * @param PLUGIN Plugin Instance
--	    *
--	    * @return void
--
local function saveData(PLUGIN: Plugin): nil
	return PLUGIN:SetSetting(PLUGIN_DATA_SAVE_KEY, {
		localTime = DateTime.now():ToLocalTime(),
		linesWritten = Module.LinesWritten,
		charsWritten = Module.CharactersWritten
	})
end

-- function autosaveStop ( ): nil
--	    ^
--	    * Kills the while loop in the AUTOSAVE_COROUT coroutine making it ultimately turn dead when the task.wait yield is over
--	    *
--	    * @return void
--
local function autosaveStop(): nil
	AUTOSAVE_COROUT_KILL = true
	
	return
end

-- function autosaveStart ( PLUGIN: Plugin ): thread
--	    ^
--	    * Creates a coroutine whose purpose is to save the plugin data in a AUTOSAVE_INTERVAL interval
--	    *
--	    * @param PLUGIN Plugin Instance
--	    *
--	    * @return thread AUTOSAVE_COROUT coroutine
--
local function autosaveStart(PLUGIN: Plugin): thread
	if AUTOSAVE_COROUT then autosaveStop() end

	AUTOSAVE_COROUT_KILL = false
	AUTOSAVE_COROUT = coroutine.create(function()
		while not AUTOSAVE_COROUT_KILL do
			task.wait(AUTOSAVE_INTERVAL)
			if not AUTOSAVE_COROUT_KILL then
				saveData(PLUGIN)
			end
		end
	end)

	coroutine.resume(AUTOSAVE_COROUT)
	
	return AUTOSAVE_COROUT
end

-- Connection callback functions

local function scriptOpened(doc: ScriptDocument): nil
	local scriptOpened = isScriptOpened(doc)
	
	if not scriptOpened then
		table.insert(SCRIPTS_OPENED, doc:GetScript())
	end
	
	return
end

local function scriptClosed(doc: ScriptDocument): nil
	local scriptOpened, scriptIndex = isScriptOpened(doc)
	
	if scriptOpened and scriptIndex then
		table.remove(SCRIPTS_OPENED, scriptIndex)
	end
	
	return
end

local function scriptEdited(doc: ScriptDocument, changes: any): nil
	changes = changes[1] and changes[1].text
	local scriptOpened = isScriptOpened(doc)
	
	if scriptOpened and changes then
		local _, newLines = changes:gsub('\n', '\n')
		
		Module.LinesWritten = math.min(Module.LinesWritten + newLines, MAXIMUM_VALUE)
		Module.CharactersWritten = math.min(Module.CharactersWritten + (changes:sub(-1) == "\n" and 0 or #(changes:gsub("^%s+", ""))), MAXIMUM_VALUE)
	end
	
	return
end


-- method Set ( ...:number ): nil
--	  ^
--	  * Sets data
--	  *
--	  * @return void
--
function Module:Set(...:number): nil
	self.LinesWritten, self.CharactersWritten = ...
	
	return
end

-- method Init ( PLUGIN: Plugin, autosave: boolean ): nil
--	  ^
--	  * Retrieves all opened scripts and connects textdocument events
--	  *
--	  * @param PLUGIN Plugin Instance
--	  * @param autosave Defines whether or not data should saved in a AUTOSAVE_INTERVAL interval
--	  *
--	  * @return void
--
function Module:Init(PLUGIN: Plugin, autosave: boolean): nil
	for _, doc in ipairs(ScriptEditorService:GetScriptDocuments()) do
		table.insert(SCRIPTS_OPENED, doc:GetScript())
	end
	
	local data = PLUGIN:GetSetting(PLUGIN_DATA_SAVE_KEY)
	local localTime = DateTime.now():ToLocalTime()
	
	if not data or data.localTime.Day ~= localTime.Day or data.localTime.Month ~= localTime.Month or data.localTime.Year ~= localTime.Year then
		data = {}
		data["localTime"] = localTime
		data["linesWritten"] = 0
		data["charsWritten"] = 0
	end
	
	self:Set(data.linesWritten, data.charsWritten)
	
	if autosave then autosaveStart(PLUGIN) end
	
	SCRIPT_OPENED_CONNECTION = ScriptEditorService.TextDocumentDidOpen:Connect(scriptOpened)
	SCRIPT_CLOSED_CONNECTION = ScriptEditorService.TextDocumentDidClose:Connect(scriptClosed)
	SCRIPT_CHANGED_CONNECTION = ScriptEditorService.TextDocumentDidChange:Connect(scriptEdited)
	
	return
end

-- method Terminate ( PLUGIN: Plugin ): nil
--	  ^
--	  * Disconnects all connections and cleans all the traces left by the module (also saves the lines of code data)
--	  *
--	  * @param PLUGIN Plugin Instance
--	  *
--	  * @return void
--
function Module:Terminate(PLUGIN: Plugin): nil
	autosaveStop()
	saveData(PLUGIN)
	
	Util:DisconnectConnection(SCRIPT_OPENED_CONNECTION, function()
		SCRIPT_OPENED_CONNECTION = nil
	end)
	Util:DisconnectConnection(SCRIPT_CLOSED_CONNECTION, function()
		SCRIPT_CLOSED_CONNECTION = nil
	end)
	Util:DisconnectConnection(SCRIPT_CHANGED_CONNECTION, function()
		SCRIPT_CHANGED_CONNECTION = nil
	end)
	
	return
end

return Module
-- /*
-- @script PluginInit  Setups plugin and handles plugin-studio interactions
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

-- Retrieving services

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- Make sure the plugin only runs in edit mode or as client in run mode
local IS_MOUSE_PLUGIN = true
local _, isAllowedInGame = xpcall(function() -- wrapped in a protected call because methods like :IsEdit() can throw errors when lacking the sufficient permission (plugin level)
	IS_MOUSE_PLUGIN = RunService:IsRunning() and RunService:IsClient()
	return RunService:IsStudio() and (IS_MOUSE_PLUGIN or RunService:IsEdit())
end, function()
	warn("The plugin was tried to be run non-locally")
end)

if not isAllowedInGame then return end
IS_MOUSE_PLUGIN = not IS_MOUSE_PLUGIN

-- Retrieving dependencies

local Util = require(script.Parent:WaitForChild("Util")) ---@module Util  Just a bunch of utility functions to complement the plugin and keep things clean
local MonitorScripts = require(script.Parent:WaitForChild("MonitorScripts")) ---@module MonitorScripts  Self-explanatory, watches script changes via ScriptEditorService
local ResponsiveFrame = require(script.Parent:WaitForChild("ResponsiveFrame")) ---@module  ResponsiveFrame  Handles the position and the size of a given frame
local LinesOfCodeFrameInit = require(script.Parent:WaitForChild("LinesOfCodeFrameInit")) ---@module  LinesOfCodeFrameInit  Initializes LinesOfCode Frame

-- CONSTANTS

local RESERVED_GUI_NAMES = {
	["LinesOfCodeGui"] = true
}

-- Creating plugin

local Toolbar = plugin:CreateToolbar("Poggers' Toolbox")
local PluginCountButton = Toolbar:CreateButton("Toggle project stats", "An utility that counts all the lines of code in your project", "rbxassetid://11931509248")

-- Setup the plugin

ResponsiveFrame.IS_MOUSE_PLUGIN = IS_MOUSE_PLUGIN

--[[
me resisting the urge (hard) to write
;(function()
	
end)()
instead of just an inline statement like a normal human being 
]]

local function checkForDuplicateGUIs()
	for _, gui in ipairs(CoreGui:GetChildren()) do
		if RESERVED_GUI_NAMES[gui.Name] then
			gui:Destroy()
			warn("Found duplicate GUI " .. gui.Name)
		end
	end
end

local function pluginUnloading()
	MonitorScripts:Terminate(plugin) -- stop listening to script changes
	
	Util:UnDockSoundWidget()
	LinesOfCodeFrameInit:Terminate()
	
	-- Still doesn't work as of December of 2022
	-- https://devforum.roblox.com/t/plugintoolbarbuttondestroy-does-not-remove-itself-from-toolbar/721497
	local _, debugErr = pcall(function()
		PluginCountButton.Parent = nil
		PluginCountButton:Destroy()
		Toolbar:Destroy()
	end)

	if debugErr then
		warn(debugErr)
	end
end

local function pluginInit()
	checkForDuplicateGUIs()
	
	MonitorScripts:Init(plugin, true) -- start listening to script changes
	
	Util:DockSoundWidget(plugin)
	LinesOfCodeFrameInit:Init(plugin, PluginCountButton)
	
	plugin.Unloading:Connect(pluginUnloading)
end

pluginInit()
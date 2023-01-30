-- /*
-- @module LinesOfCodeFrameInit  Initializes LinesOfCode Frame
-- Last edited the 25/12/2022
-- Written by poggers
-- */

-- Probably one of the messiest and dirtiest code I've ever written but as Sun Tzu of programming once said - if it works, call it a day!
-- gl understanding it tho ☻

-- Retrieving services

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

-- Retrieving dependencies

local Util = require(script.Parent:WaitForChild("Util")) ---@module Util  Just a bunch of utility functions to complement the plugin and keep things clean
local ScanGameFunc = require(script.Parent:WaitForChild("CountLines")) ---@module CountLines  Returns advanced script statistics about the game
local GraphCreator = require(script.Parent:WaitForChild("GraphCreator")) ---@module GraphCreator  Creates and animates graphs using TweenService
local MonitorScripts = require(script.Parent:WaitForChild("MonitorScripts")) ---@module MonitorScripts  Self-explanatory, watches script changes via ScriptEditorService
local ResponsiveFrame = require(script.Parent:WaitForChild("ResponsiveFrame")) ---@module ResponsiveFrame  Handles the position and the size of a given frame

-- References

local GUI = script:WaitForChild("LinesOfCodeGUI")
local Background = GUI:WaitForChild("Background")

local HeaderLabel = Background:WaitForChild("HeaderLabel")
local FooterLabel = Background:WaitForChild("FooterLabel")

local Bar = Background:WaitForChild("ChartBar1")
local BarLabels = Background:WaitForChild("ChartBar1Labels")
local Bar2 = Background:WaitForChild("ChartBar2")
local Bar2Labels = Background:WaitForChild("ChartBar2Labels")
local Bar3 = Background:WaitForChild("ChartBar3")
local Bar3Labels = Background:WaitForChild("ChartBar3Labels")

local Statistics1Frame = Background:WaitForChild("Statistics1")
local Statistics2Frame = Background:WaitForChild("Statistics2")

local ExitButton = Background:WaitForChild("ExitButton")
local ExitButtonLabel = Background:WaitForChild("ExitButtonLabel")
local ExitButtonShadow = Background:WaitForChild("ExitButtonShadow")

local RecomputeButton = Background:WaitForChild("RecomputeButton")
local RecomputeButtonIcon = Background:WaitForChild("RecomputeButtonIcon")
local RecomputeButtonShadow = Background:WaitForChild("RecomputeButtonShadow")

local RepositionGUIElementsEvent = script.Parent:WaitForChild("ResponsiveFrame"):WaitForChild("RepositionGUIElements")

-- CACHED FUNCTIONS

local unpack = unpack

local POW = math.pow
local MAX = math.max

-- CONSTANTS

local BUTTON_CLICKED_SOUNDID = "6895079853"
local BUTTON_CLICKED_VOLUME = 0.25

local LINES_SCAN_FORMAT = "%i lines of code scanned (%i chars)"
local LINES_SCAN_FORMAT_SINGULAR = "%i line of code scanned (%i chars)"
local LINES_SCAN_ANIM_DURATION = 1.5

local OPENING_ANIM_TWEENINFO = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MINIMUN_VERTICAL_BACKGROUND_SIZE = 200

local SCRIPTS_COLOR_PALETTE = {
	["ModuleScript"] = Color3.new(255/255, 134/255, 29/255),
	["LocalScript"] = Color3.new(65/255, 198/255, 255/255),
	["Script"] = Color3.new(31/255, 225/255, 31/255),
}

local SERVER_CLIENT_COLOR_PALETTE = {
	["Server"] = Color3.new(13/255, 63/255, 202/255),
	["Client"] = Color3.new(208/255, 195/255, 8/255),
	["Shared"] = Color3.new(163/255, 19/255, 149/255),
}

local SERVICE_COLORS = {
	-- put down colors here if you want a service's color to always stay the same
	["Workspace"] = Color3.new(128/255, 214/255, 47/255),
	["ReplicatedFirst"] = Color3.new(80/255, 109/255, 84/255),
}

local BLOCK_GUI_ELEMENTS = { -- {gui instance, bottom margin}
	{HeaderLabel, 10},
	{Bar, 5},
	{BarLabels, 5},
	{Statistics1Frame, 10},
	{Bar2, 5},
	{Bar2Labels, 5},
	{Bar3, 5},
	{Bar3Labels, 0},
	{Statistics2Frame, 15},
}

local TRIMMABLE_GUI_LABELS = {
	["TrueLine"] = true,
	["TrueLineNoComment"] = true
}

-- CONNECTIONS

local REPOSITIONGUIELEMENTS_EVENT_CONNECTION = nil
local FOOTER_TEXT_BOUNDS_CHANGED_CONNECTION = nil
local BUTTON_CLICKED_CONNECTION = nil

local RECOMPUTE_BUTTON_HOVER_CONNECTION = nil
local RECOMPUTE_BUTTON_CLICKED_CONNECTION = nil

local EXIT_BUTTON_HOVER_CONNECTION = nil
local EXIT_BUTTON_CLICKED_CONNECTION = nil

-- States

local GUIOpened = false
local ExitButtonHovered = false
local RecomputeButtonHovered = false

local AnimatedBackgroundSize = false -- one time animation
local AnimatedLabels = false -- one time animation
local InterpolatedLabels = {} -- {label instance, starting value, target value}
local ScriptLinesLabelConnection = nil

local ScriptData = nil
local ComputationTime = nil

local CoreGuisEnabled = {}
local Statistics2FrameDefaultText = nil

-- Plugin related

local Plugin = nil -- necessary because global 'plugin' isn't available in module scripts
local PluginButton = nil
local SoundWidget = nil

-- Math functions

local function easeOutExpo(x)
	return x == 1 and 1 or 1 - POW(2, -10 * x)
end

-- Main functions

local function animateLabelNumbers()
	-- Whilst the following syntax is rather complicated (tuple manipulation...), it allows for an infinite amount of arguments
	-- to be passed to the string.format call as long as the startingValues and targetValues are passed in an even/odd order
	local timer = 0
	ScriptLinesLabelConnection = RunService.Heartbeat:Connect(function(dt)
		timer += dt / LINES_SCAN_ANIM_DURATION
		for _, v in ipairs(InterpolatedLabels) do
			local label, formatAndCallback = unpack(v)
			if not label or not formatAndCallback then continue end
			local data = {select(3, unpack(v))}
			for i = 1, #data + #data % 2 do
				data[i] = data[i] or 0
			end
			if timer <= 1 then
				local interpolatedTimer = easeOutExpo(timer)
				local interpolatedValues = {}
				for i = 1, #data + #data % 2, 2 do
					if type(data[i]) == "string" then
						table.insert(interpolatedValues, data[i])
					else
						table.insert(interpolatedValues, data[i] + (data[i + 1] - data[i]) * interpolatedTimer)
					end
				end
				label.Text = string.format(formatAndCallback[1], unpack(interpolatedValues))
			else
				Util:DisconnectConnection(ScriptLinesLabelConnection, function()
					ScriptLinesLabelConnection = nil
				end)
				local targetValues = {}
				for i = 2, #data + #data % 2, 2 do
					table.insert(targetValues, data[i])
				end
				if TRIMMABLE_GUI_LABELS[label.Name] then
					table.insert(ResponsiveFrame.TrimmableLabels, label)
				end
				local formattedText = string.format(formatAndCallback[1], unpack(targetValues))
				if formatAndCallback[2] then
					formatAndCallback[2](label, formattedText)
				else
					label.Text = formattedText
				end
			end
		end
	end)
end

local function animateBackgroundSize(animate)
	AnimatedBackgroundSize = true

	local sum = 0
	for _, element in ipairs(BLOCK_GUI_ELEMENTS) do
		local uigridlayout = element[1]:FindFirstChildWhichIsA("UIGridLayout")
		local isTextlabel = element[1]:IsA("TextLabel")

		if uigridlayout then
			sum += uigridlayout.AbsoluteContentSize.Y
		elseif isTextlabel and element[1] ~= HeaderLabel then
			sum += element[1].TextBounds.Y
		else
			sum += element[1].AbsoluteSize.Y
		end
		sum += element[2]
	end

	local targetSize = UDim2.new(Background.Size.X.Scale, Background.Size.X.Offset, Background.Size.Y.Scale, MAX(sum, MINIMUN_VERTICAL_BACKGROUND_SIZE))

	if animate then
		local tween = TweenService:Create(Background, OPENING_ANIM_TWEENINFO, { Size = targetSize })
		tween:Play()
	else
		Background.Size = targetSize
	end
end

local function animateGUIElementsInBlock(animate)
	local targetPositions = {[1] = BLOCK_GUI_ELEMENTS[1][1].Position}
	for order = 2, #BLOCK_GUI_ELEMENTS do
		local gui = BLOCK_GUI_ELEMENTS[order][1]

		local uigridlayout = BLOCK_GUI_ELEMENTS[order - 1][1]:FindFirstChildWhichIsA("UIGridLayout")
		local isTextlabel = BLOCK_GUI_ELEMENTS[order - 1][1]:IsA("TextLabel")

		local ySize
		if uigridlayout then
			ySize = uigridlayout.AbsoluteContentSize.Y
		elseif isTextlabel and BLOCK_GUI_ELEMENTS[order - 1][1] ~= HeaderLabel then
			ySize = BLOCK_GUI_ELEMENTS[order - 1][1].TextBounds.Y
		else
			ySize = BLOCK_GUI_ELEMENTS[order - 1][1].AbsoluteSize.Y
		end

		local newElementY = targetPositions[order - 1].Y.Offset + ySize + BLOCK_GUI_ELEMENTS[order - 1][2]
		local newElementPos = UDim2.new(gui.Position.X.Scale, gui.Position.X.Offset, gui.Position.Y.Scale, newElementY)

		targetPositions[order] = newElementPos

		if animate then
			TweenService:Create(gui, OPENING_ANIM_TWEENINFO, { Position = newElementPos }):Play()
		else
			gui.Position = newElementPos
		end
	end
end

local function matchNumber(label, parent)
	-- Two syntaxes:
	-- matchNumber(textlabel instance)
	-- matchNumber(textlabel string name, textlabel instance parent)
	if not label then return end
	if type(label) == "string" then
		if not parent or typeof(parent) ~= "Instance" then return end
		label = parent:FindFirstChild(label)
	end
	if label and label:IsA("TextLabel") then
		local arr = {}
		for i in string.gmatch(label.Text, "%d+") do
			table.insert(arr, i)
		end
		if label.Text == "" then table.insert(arr, 0) end
		return label, unpack(arr) -- return a tuple
	end
end

local function interpolatedLabelCallback(label, text)
	if label:FindFirstChild("initialText") then
		label.initialText.Value = text
		ResponsiveFrame:UpdateLabels()
	end
end

local function updateLabel(frame, labelName, animate, insert, ...)
	local label = frame:FindFirstChild(labelName)

	if label then
		local textFormat = label:FindFirstChild("textFormat")
		local textValue = label:FindFirstChild("initialText")

		if textFormat then
			textFormat = textFormat.Value
			local packed = {...}
			local t = textFormat:format(...)

			if not textValue then
				textValue = Instance.new("StringValue")
				textValue.Name = "initialText"
				textValue.Parent = label
			end

			textValue.Value = t
			
			if insert then
				-- dirty code here, basically it skips the animation if the difference between the two values is too small, to display the statistics more "instantly"
				local _, startingValue, startingValue2 = matchNumber(label)
				startingValue = tonumber(startingValue or 0)
				if #packed == 1 then
					table.insert(InterpolatedLabels, { label, { textFormat, interpolatedLabelCallback }, startingValue, packed[1] })
				elseif #packed == 2 then
					if math.abs(tonumber(packed[2]) - startingValue) > 10 then
						table.insert(InterpolatedLabels, { label, { textFormat }, packed[1], packed[1], startingValue, packed[2] })
					else
						label.Text = t
					end
				elseif #packed == 4 then
					startingValue2 = tonumber(startingValue2 or 0)
					if math.abs(tonumber(packed[2] or 0) - startingValue) > 10 then
						table.insert(InterpolatedLabels, { label, { textFormat }, packed[1], packed[1], startingValue, packed[2], startingValue2, packed[3], packed[4], packed[4] })
					else
						label.Text = t
					end
				end
				--
			end

			if animate then
				label.TextTransparency = 0
				TweenService:Create(label, OPENING_ANIM_TWEENINFO, { TextTransparency = 0 }):Play()
			else
				label.TextTransparency = 0
			end
		end
	end
end

local function createGraphs(animate)
	local scriptsTable = { {ScriptData.lineData.ModuleScript, SCRIPTS_COLOR_PALETTE.ModuleScript, "Module Script"}, {ScriptData.lineData.LocalScript, SCRIPTS_COLOR_PALETTE.LocalScript, "Local Script"}, {ScriptData.lineData.Script, SCRIPTS_COLOR_PALETTE.Script, "Script"} }
	table.sort(scriptsTable, function(a, b)
		return a[1] > b[1]
	end)

	local scriptsSideTable = { {ScriptData.lineDataScriptSide.ServerSide, SERVER_CLIENT_COLOR_PALETTE.Server, "Server-Sided"}, {ScriptData.lineDataScriptSide.ClientSide, SERVER_CLIENT_COLOR_PALETTE.Client, "Client-Sided"}, {ScriptData.lineDataScriptSide.Shared, SERVER_CLIENT_COLOR_PALETTE.Shared, "Shared (module)"} }
	table.sort(scriptsSideTable, function(a, b)
		return a[1] > b[1]
	end)

	local servicesTable = { }
	local scriptsSum = 0
	for _, service in ipairs(ScriptData.services) do
		local serviceName = service.Name
		local serviceScripts = ScriptData.lineDataServices[serviceName]
		if serviceScripts then
			local color3 = SERVICE_COLORS[serviceName] and SERVICE_COLORS[serviceName] or BrickColor.random().Color
			local sum = serviceScripts.ModuleScript + serviceScripts.LocalScript + serviceScripts.Script

			servicesTable[#servicesTable + 1] = { sum, color3, serviceName }
			scriptsSum += sum

			if not SERVICE_COLORS[serviceName] then SERVICE_COLORS[serviceName] = color3 end
		end
	end
	table.sort(servicesTable, function(a, b)
		return a[1] > b[1]
	end)

	REPOSITIONGUIELEMENTS_EVENT_CONNECTION = RepositionGUIElementsEvent.Event:Connect(function(newValue)
		animateBackgroundSize(false)
		animateGUIElementsInBlock(false)
	end)

	GraphCreator.newGraph(Bar, 3, scriptsTable, ScriptData.totalLines, ScriptData.totalLines > 0 and 1 or 0) -- Repeated animation
	GraphCreator.newLabels(BarLabels, 3, scriptsTable, BarLabels.Size.Y.Offset, not AnimatedLabels, RepositionGUIElementsEvent) -- One time animation, gui is dynamic meaning that it will adapt to the frame size

	GraphCreator.newGraph(Bar2, 3, scriptsSideTable, ScriptData.lineDataScriptSide.ServerSide + ScriptData.lineDataScriptSide.ClientSide + ScriptData.lineDataScriptSide.Shared, 0) -- Repeated animation
	GraphCreator.newLabels(Bar2Labels, 3, scriptsSideTable, Bar2Labels.Size.Y.Offset, not AnimatedLabels, RepositionGUIElementsEvent) -- One time animation, gui is dynamic meaning that it will adapt to the frame size

	GraphCreator.newGraph(Bar3, ScriptData.totalServices, servicesTable, scriptsSum, ScriptData.totalLines > 0 and 1 or 0) -- Repeated animation
	GraphCreator.newLabels(Bar3Labels, ScriptData.totalServices, servicesTable, Bar3Labels.Size.Y.Offset, not AnimatedLabels, RepositionGUIElementsEvent) -- One time animation, gui is dynamic meaning that it will adapt to the frame size

	AnimatedLabels = true

	if not Statistics2FrameDefaultText then
		Statistics2FrameDefaultText = Statistics2Frame:FindFirstChild("ServiceName")
		if Statistics2FrameDefaultText then
			Statistics2FrameDefaultText.Parent = nil
		end
	end
	if Statistics2FrameDefaultText then
		for _, v in ipairs(Statistics2Frame:GetChildren()) do
			if not v:IsA("UIGridLayout") then v:Destroy() end
		end
		local even = false
		for _, service in ipairs(ScriptData.services) do
			local serviceName = service.Name
			local scriptData = ScriptData.scriptDataServices[serviceName]
			local lineData = ScriptData.lineDataServices[serviceName]

			if scriptData and lineData then
				local totalScripts = scriptData.ModuleScript + scriptData.LocalScript + scriptData.Script
				local totalLines = lineData.ModuleScript + lineData.LocalScript + lineData.Script

				even = not even

				local newLabel = Statistics2FrameDefaultText:Clone()
				newLabel.Name = serviceName
				newLabel.TextXAlignment = even and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
				newLabel.Parent = Statistics2Frame
				if newLabel:FindFirstChild("textFormat") then
					updateLabel(Statistics2Frame, serviceName, animate, true, serviceName, totalScripts, totalLines, totalLines > 1 and "s" or "")
				end
			end
		end

		even = not even

		local totalServicesLabel = Statistics2FrameDefaultText:Clone()
		totalServicesLabel.Name = "TotalServices"
		totalServicesLabel.TextXAlignment = even and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
		totalServicesLabel.Parent = Statistics2Frame
		if totalServicesLabel:FindFirstChild("textFormat") then
			totalServicesLabel.textFormat.Value = "Total service%s: %i"
			updateLabel(Statistics2Frame, "TotalServices", animate, true, ScriptData.totalServices > 1 and "s" or "", ScriptData.totalServices)
		end

		even = not even

		local totalVirusesLabel = Statistics2FrameDefaultText:Clone()
		totalVirusesLabel.Name = "TotalViruses"
		totalVirusesLabel.TextXAlignment = even and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right
		totalVirusesLabel.Parent = Statistics2Frame
		if totalVirusesLabel:FindFirstChild("textFormat") then
			totalVirusesLabel.textFormat.Value = "Virus%s detected: %i"
			updateLabel(Statistics2Frame, "TotalViruses", animate, true, #ScriptData.potentialThreats > 1 and "es" or "", #ScriptData.potentialThreats)
		end
	end
end

local function pluginButtonClicked()
	GUIOpened = not GUIOpened
	GUI.Enabled = GUIOpened
	
	PluginButton:SetActive(GUIOpened)

	if GUIOpened then
		ScriptData, ComputationTime = ScanGameFunc(false)
		ResponsiveFrame:Init(Background, Plugin, "FRAME", function()
			GraphCreator.updateTextLabels(false, GraphCreator.percentageLabels, Background)
		end)

		print(ScriptData)

		local _, startingLinesOfCode, startingCharacters = matchNumber(HeaderLabel)
		table.insert(InterpolatedLabels, { HeaderLabel, { ScriptData.totalLines > 1 and LINES_SCAN_FORMAT or LINES_SCAN_FORMAT_SINGULAR }, tonumber(startingLinesOfCode), ScriptData.totalLines, tonumber(startingCharacters), ScriptData.totalChars })
		startingLinesOfCode, startingCharacters = nil, nil
		
		if ResponsiveFrame.IS_MOUSE_PLUGIN and BLOCK_GUI_ELEMENTS[#BLOCK_GUI_ELEMENTS][1] ~= FooterLabel then
			BLOCK_GUI_ELEMENTS[#BLOCK_GUI_ELEMENTS][2] = 0
			BLOCK_GUI_ELEMENTS[#BLOCK_GUI_ELEMENTS + 1] = {FooterLabel, 20}
		end
		
		createGraphs(not AnimatedLabels)
		animateBackgroundSize(not AnimatedBackgroundSize)
		animateGUIElementsInBlock(true)

		updateLabel(Statistics1Frame, "Module", true, true, ScriptData.scriptData.ModuleScript > 1 and "s" or "", ScriptData.scriptData.ModuleScript)
		updateLabel(Statistics1Frame, "Local", true, true, ScriptData.scriptData.LocalScript > 1 and "s" or "", ScriptData.scriptData.LocalScript)
		updateLabel(Statistics1Frame, "Script", true, true, ScriptData.scriptData.Script > 1 and "s" or "", ScriptData.scriptData.Script)
		updateLabel(Statistics1Frame, "Duplicate", true, true, ScriptData.duplicates > 1 and "s" or "", ScriptData.duplicates)
		updateLabel(Statistics1Frame, "TrueLine", true, true, ScriptData.totalTrueLines)
		updateLabel(Statistics1Frame, "TrueLineNoComment", true, true, ScriptData.totalLinesNoComment)
		
		if ResponsiveFrame.IS_MOUSE_PLUGIN then
			local numAbbreviation, abbreviatedNum = Util:AbbreviateSize(MonitorScripts.CharactersRealSize)
			updateLabel(Background, "FooterLabel", true, false, MonitorScripts.LinesWritten, MonitorScripts.LinesWritten > 1 and "s" or "", MonitorScripts.CharactersWritten, MonitorScripts.CharactersWritten > 1 and "s" or "", abbreviatedNum, numAbbreviation)

			local footerFormat = FooterLabel:FindFirstChild("textFormat") and FooterLabel:FindFirstChild("textFormat").Value or ""
			local _, startingLinesOfCode, startingCharacters, startingSize = matchNumber(FooterLabel)
			table.insert(InterpolatedLabels, { FooterLabel, { footerFormat, interpolatedLabelCallback }, tonumber(startingLinesOfCode), MonitorScripts.LinesWritten, MonitorScripts.LinesWritten > 1 and "s" or "", MonitorScripts.LinesWritten > 1 and "s" or "", tonumber(startingCharacters), MonitorScripts.CharactersWritten, MonitorScripts.CharactersWritten > 1 and "s" or "", MonitorScripts.CharactersWritten > 1 and "s" or "", tonumber(startingSize), abbreviatedNum, numAbbreviation, numAbbreviation })
		
			local lastBounds = FooterLabel.TextBounds
			FOOTER_TEXT_BOUNDS_CHANGED_CONNECTION = FooterLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
				local newBounds = FooterLabel.TextBounds

				if newBounds.Y ~= lastBounds.Y then
					print("changed")
					animateBackgroundSize(false)
					lastBounds = newBounds
				end
			end)
		end
		
		animateLabelNumbers()

		ResponsiveFrame:UpdateLabels()
		
		ExitButton.Position = UDim2.new(1, ExitButton.Position.X.Offset, 0, 3)
		ExitButtonLabel.Position = UDim2.new(1, ExitButtonLabel.Position.X.Offset, 0, 3)
		ExitButtonShadow.Position = UDim2.new(1, ExitButtonShadow.Position.X.Offset, 0, 4)
		RecomputeButton.Position = UDim2.new(1, RecomputeButton.Position.X.Offset, 0, 3)
		RecomputeButtonIcon.Position = UDim2.new(1, RecomputeButtonIcon.Position.X.Offset, 0, 3)
		RecomputeButtonShadow.Position = UDim2.new(1, RecomputeButtonShadow.Position.X.Offset, 0, 4)

		if not ResponsiveFrame.IS_MOUSE_PLUGIN then
			CoreGuisEnabled = {}
			for _, coreGuiType in ipairs(Enum.CoreGuiType:GetEnumItems()) do
				if game:GetService("StarterGui"):GetCoreGuiEnabled(coreGuiType) then
					table.insert(CoreGuisEnabled, coreGuiType)
					game:GetService("StarterGui"):SetCoreGuiEnabled(coreGuiType, false)
				end
			end
		end
	else
		Util:DisconnectConnection(ScriptLinesLabelConnection, function()
			ScriptLinesLabelConnection = nil
			for _, v in ipairs(InterpolatedLabels) do
				local label, formatAndCallback = unpack(v)
				if not label or not formatAndCallback then continue end
				local data = {select(3, unpack(v))}
				for i = 1, #data + #data % 2 do
					data[i] = data[i] or 0
				end
				local targetValues = {}
				for i = 2, #data + #data % 2, 2 do
					table.insert(targetValues, data[i])
				end
				label.Text = string.format(formatAndCallback[1], unpack(targetValues))
			end
			InterpolatedLabels = {}
		end)
		Util:DisconnectConnection(REPOSITIONGUIELEMENTS_EVENT_CONNECTION, function()
			REPOSITIONGUIELEMENTS_EVENT_CONNECTION = nil
		end)
		ResponsiveFrame:Remove()
		GraphCreator.cleanupGraphs()
		ResponsiveFrame.TrimmableLabels = {}

		if not ResponsiveFrame.IS_MOUSE_PLUGIN then
			for _, coreGuiType in ipairs(CoreGuisEnabled) do
				game:GetService("StarterGui"):SetCoreGuiEnabled(coreGuiType, true)
			end
		end
	end

	Bar.BackgroundTransparency = ScriptData.totalLines > 0 and 1 or 0
	Bar2.BackgroundTransparency = 0
	Bar3.BackgroundTransparency = ScriptData.totalLines > 0 and 1 or 0
	
	Util:PlaySound(false, BUTTON_CLICKED_SOUNDID, BUTTON_CLICKED_VOLUME)
end

local function buttonTerminate()
	-- Clean up connections
	BUTTON_CLICKED_CONNECTION:Disconnect()
	RECOMPUTE_BUTTON_CLICKED_CONNECTION:Disconnect()
	RECOMPUTE_BUTTON_HOVER_CONNECTION:Disconnect()
	EXIT_BUTTON_CLICKED_CONNECTION:Disconnect()
	EXIT_BUTTON_HOVER_CONNECTION:Disconnect()

	if GUIOpened then
		pluginButtonClicked()
	end

	GUI.Parent = nil
	GUI:Destroy()
end

local function recomputeButtonMouseHover()
	ResponsiveFrame.CanDrag = false
	RecomputeButtonHovered = true
	RecomputeButton.Position = UDim2.new(1, RecomputeButton.Position.X.Offset, 0, 1)
	RecomputeButtonIcon.Position = UDim2.new(1, RecomputeButtonIcon.Position.X.Offset, 0, 1)
	RecomputeButtonShadow.Position = UDim2.new(1, RecomputeButtonShadow.Position.X.Offset, 0, 2)
	RecomputeButton.MouseLeave:Wait()
	if not ExitButtonHovered then
		ResponsiveFrame.CanDrag = true
	end
	RecomputeButtonHovered = false
	RecomputeButton.Position = UDim2.new(1, RecomputeButton.Position.X.Offset, 0, 3)
	RecomputeButtonIcon.Position = UDim2.new(1, RecomputeButtonIcon.Position.X.Offset, 0, 3)
	RecomputeButtonShadow.Position = UDim2.new(1, RecomputeButtonShadow.Position.X.Offset, 0, 4)
end

local function recomputeButtonClicked() -- Does the same as void pluginButtonClicked() except that it doesn't enable/disable ResponsiveFrame
	if GUIOpened and not ResponsiveFrame.CanDrag then
		Util:DisconnectConnection(ScriptLinesLabelConnection, function()
			ScriptLinesLabelConnection = nil
			for _, v in ipairs(InterpolatedLabels) do
				local label, formatAndCallback = unpack(v)
				if not label or not formatAndCallback then continue end
				local data = {select(3, unpack(v))}
				for i = 1, #data + #data % 2 do
					data[i] = data[i] or 0
				end
				local targetValues = {}
				for i = 2, #data + #data % 2, 2 do
					table.insert(targetValues, data[i])
				end
				label.Text = string.format(formatAndCallback[1], unpack(targetValues))
			end
			InterpolatedLabels = {}
		end)
		
		Util:DisconnectConnection(REPOSITIONGUIELEMENTS_EVENT_CONNECTION, function()
			REPOSITIONGUIELEMENTS_EVENT_CONNECTION = nil
		end)
		
		ScriptData, ComputationTime = ScanGameFunc(false)
		GraphCreator.cleanupGraphs()
		ResponsiveFrame.TrimmableLabels = {}

		local _, startingLinesOfCode, startingCharacters = matchNumber(HeaderLabel)
		table.insert(InterpolatedLabels, { HeaderLabel, { ScriptData.totalLines > 1 and LINES_SCAN_FORMAT or LINES_SCAN_FORMAT_SINGULAR }, tonumber(startingLinesOfCode), ScriptData.totalLines, tonumber(startingCharacters), ScriptData.totalChars })
		startingLinesOfCode, startingCharacters = nil, nil
		
		if ResponsiveFrame.IS_MOUSE_PLUGIN and BLOCK_GUI_ELEMENTS[#BLOCK_GUI_ELEMENTS][1] ~= FooterLabel then
			BLOCK_GUI_ELEMENTS[#BLOCK_GUI_ELEMENTS][2] = 0
			BLOCK_GUI_ELEMENTS[#BLOCK_GUI_ELEMENTS + 1] = {FooterLabel, 20}
		end
		
		createGraphs(false)
		animateBackgroundSize(false)
		animateGUIElementsInBlock(false)

		updateLabel(Statistics1Frame, "Module", false, true, ScriptData.scriptData.ModuleScript > 1 and "s" or "", ScriptData.scriptData.ModuleScript)
		updateLabel(Statistics1Frame, "Local", false, true, ScriptData.scriptData.LocalScript > 1 and "s" or "", ScriptData.scriptData.LocalScript)
		updateLabel(Statistics1Frame, "Script", false, true, ScriptData.scriptData.Script > 1 and "s" or "", ScriptData.scriptData.Script)
		updateLabel(Statistics1Frame, "Duplicate", false, true, ScriptData.duplicates > 1 and "s" or "", ScriptData.duplicates)
		updateLabel(Statistics1Frame, "TrueLine", false, true, ScriptData.totalTrueLines)
		updateLabel(Statistics1Frame, "TrueLineNoComment", false, true, ScriptData.totalLinesNoComment)
		
		if ResponsiveFrame.IS_MOUSE_PLUGIN then
			local numAbbreviation, abbreviatedNum = Util:AbbreviateSize(MonitorScripts.CharactersRealSize)
			updateLabel(Background, "FooterLabel", true, false, MonitorScripts.LinesWritten, MonitorScripts.LinesWritten > 1 and "s" or "", MonitorScripts.CharactersWritten, MonitorScripts.CharactersWritten > 1 and "s" or "", abbreviatedNum, numAbbreviation)

			local footerFormat = FooterLabel:FindFirstChild("textFormat") and FooterLabel:FindFirstChild("textFormat").Value or ""
			local _, startingLinesOfCode, startingCharacters, startingSize = matchNumber(FooterLabel)
			table.insert(InterpolatedLabels, { FooterLabel, { footerFormat, interpolatedLabelCallback }, tonumber(startingLinesOfCode), MonitorScripts.LinesWritten, MonitorScripts.LinesWritten > 1 and "s" or "", MonitorScripts.LinesWritten > 1 and "s" or "", tonumber(startingCharacters), MonitorScripts.CharactersWritten, MonitorScripts.CharactersWritten > 1 and "s" or "", MonitorScripts.CharactersWritten > 1 and "s" or "", tonumber(startingSize), abbreviatedNum, numAbbreviation, numAbbreviation })
		end
		
		animateLabelNumbers()

		ResponsiveFrame:UpdateLabels()

		Bar.BackgroundTransparency = ScriptData.totalLines > 0 and 1 or 0
		Bar2.BackgroundTransparency = 0
		Bar3.BackgroundTransparency = ScriptData.totalLines > 0 and 1 or 0

		Util:PlaySound(false, BUTTON_CLICKED_SOUNDID, BUTTON_CLICKED_VOLUME)
	end
end

local function exitButtonMouseHover()
	ResponsiveFrame.CanDrag = false
	ExitButtonHovered = true
	ExitButton.Position = UDim2.new(1, ExitButton.Position.X.Offset, 0, 1)
	ExitButtonLabel.Position = UDim2.new(1, ExitButtonLabel.Position.X.Offset, 0, 1)
	ExitButtonShadow.Position = UDim2.new(1, ExitButtonShadow.Position.X.Offset, 0, 2)
	ExitButton.MouseLeave:Wait()
	if not RecomputeButtonHovered then
		ResponsiveFrame.CanDrag = true
	end
	ExitButtonHovered = false
	ExitButton.Position = UDim2.new(1, ExitButton.Position.X.Offset, 0, 3)
	ExitButtonLabel.Position = UDim2.new(1, ExitButtonLabel.Position.X.Offset, 0, 3)
	ExitButtonShadow.Position = UDim2.new(1, ExitButtonShadow.Position.X.Offset, 0, 4)
end

local function exitButtonClicked()
	if GUIOpened and not ResponsiveFrame.CanDrag then
		pluginButtonClicked()
	end
end

GUI.Parent = CoreGui

-- Declaring module

local Module = {}

function Module:Init(PLUGIN, PLUGIN_BUTTON)
	Plugin = PLUGIN
	PluginButton = PLUGIN_BUTTON
	
	-- Connections
	BUTTON_CLICKED_CONNECTION = PLUGIN_BUTTON.Click:Connect(pluginButtonClicked)
	RECOMPUTE_BUTTON_CLICKED_CONNECTION = RecomputeButton.MouseButton1Click:Connect(recomputeButtonClicked)
	RECOMPUTE_BUTTON_HOVER_CONNECTION = RecomputeButton.MouseEnter:Connect(recomputeButtonMouseHover)
	EXIT_BUTTON_CLICKED_CONNECTION = ExitButton.MouseButton1Click:Connect(exitButtonClicked)
	EXIT_BUTTON_HOVER_CONNECTION = ExitButton.MouseEnter:Connect(exitButtonMouseHover)
end

function Module:Terminate()
	buttonTerminate()
end

return Module
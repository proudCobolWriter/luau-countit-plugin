-- /*
-- @module ResponsiveFrame  Handles the position and the size of a given frame
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

local ResponsiveFrame = { IS_MOUSE_PLUGIN = false, CanDrag = true, TrimmableLabels = {}, RenderBindings = {} }

-- Retrieving services

local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

-- Retrieving dependencies

local Util = require(script.Parent:WaitForChild("Util")) ---@module Util  Just a bunch of utility functions to complement the plugin and keep things clean

-- CACHED FUNCTIONS

local CLAMP = math.clamp
local UDIM2 = UDim2.new
local WAIT = task.wait
local SIGN = math.sign

-- CONSTANTS

local MOUSE_BUTTON = Enum.UserInputType.MouseButton1
local VIEWPORT_MARGIN = 10 -- in px
local MINIMUM_FRAME_HORIZONTAL_SIZE = 200 -- in px

local RENDER_PRIORITY = Enum.RenderPriority.Input

local EMPTY_VECTOR2 = Vector2.new()

-- REFERENCES

local CAMERA = workspace.CurrentCamera

-- STATES AND CONNECTIONS

local OVERFLOW_Y_HOVERED_CONNECTION = nil
local VIEWPORT_CHANGED_CONNECTION = nil
local CLICK_CONNECTION = nil

local INITIAL_RESIZING_MOUSEPOS = EMPTY_VECTOR2
local FRAME_TARGET_POSITION = nil

local RESIZABLE = false
local RESIZING = false
local RELEASED = false
local DRAGGING = false

local PLUGIN = nil
local FRAME = nil

local FRAME_INITIAL_ABSOLUTE_SIZE = EMPTY_VECTOR2
local HEADER_TEXT_INITIAL_TEXT_SIZE = nil

local VIEWPORTSIZE_X = CAMERA.ViewportSize.X
local VIEWPORTSIZE_Y = CAMERA.ViewportSize.Y

-- Declaring functions

local function SAFECLAMP(x, min, max)
	return CLAMP(x, min, min > max and min or max)
end

local function setDraggerUI(bool)
	pcall(function()
		CoreGui.DraggerUI:FindFirstChildWhichIsA("ScreenGui").Enabled = bool
	end)
end

local function setCursorUI(cursorId)
	if cursorId then
		PLUGIN:Activate(true)
	else
		PLUGIN:Deactivate()
	end
	if ResponsiveFrame.IS_MOUSE_PLUGIN then
		PLUGIN:GetMouse().Icon = cursorId or "rbxasset://SystemCursors/Arrow"
	else
		Players.LocalPlayer:GetMouse().Icon = cursorId or ""
	end
end

local function viewportSizeChanged()
	VIEWPORTSIZE_X, VIEWPORTSIZE_Y = CAMERA.ViewportSize.X, CAMERA.ViewportSize.Y
	
	local viewportMargin = ResponsiveFrame.IS_MOUSE_PLUGIN and VIEWPORT_MARGIN or GuiService:GetGuiInset().Y / 2
	
	local viewportBoundXL, viewportBoundYT = (FRAME.AbsoluteSize.X * 0.5 + VIEWPORT_MARGIN) / VIEWPORTSIZE_X, (FRAME.AbsoluteSize.Y * 0.5 + viewportMargin) / VIEWPORTSIZE_Y
	local viewportBoundXR, viewportBoundYB = 1 - (FRAME.AbsoluteSize.X * 0.5 + VIEWPORT_MARGIN) / VIEWPORTSIZE_X, 1 - (FRAME.AbsoluteSize.Y * 0.5 + viewportMargin) / VIEWPORTSIZE_Y
	
	FRAME.Position = UDIM2(
		SAFECLAMP(FRAME.Position.X.Scale, viewportBoundXL, viewportBoundXR),
		-FRAME.AbsoluteSize.X / 2,
		SAFECLAMP(FRAME.Position.Y.Scale, viewportBoundYT, viewportBoundYB),
		-FRAME.AbsoluteSize.Y / 2
	)
	
	FRAME.Size = UDIM2(FRAME.Size.X.Scale, SAFECLAMP(FRAME.Size.X.Offset, MINIMUM_FRAME_HORIZONTAL_SIZE, VIEWPORTSIZE_X - VIEWPORT_MARGIN * 2), FRAME.Size.Y.Scale, FRAME.Size.Y.Offset)
end

local function withInBounds(mousePos)
	local absolutePos, absoluteSize = FRAME.AbsolutePosition, FRAME.AbsoluteSize
	local xBound = (mousePos.X >= absolutePos.X and mousePos.X < absolutePos.X + absoluteSize.X)
	local yBound = (mousePos.Y >= absolutePos.Y and mousePos.Y < absolutePos.Y + absoluteSize.Y)
	
	return (xBound and yBound)
end

local function updateFramePosition()
	local viewportMargin = ResponsiveFrame.IS_MOUSE_PLUGIN and VIEWPORT_MARGIN or GuiService:GetGuiInset().Y / 2
	
	local viewportBoundXL, viewportBoundYT = (FRAME.AbsoluteSize.X * 0.5 + VIEWPORT_MARGIN) / VIEWPORTSIZE_X, (FRAME.AbsoluteSize.Y * 0.5 + viewportMargin) / VIEWPORTSIZE_Y
	local viewportBoundXR, viewportBoundYB = 1 - (FRAME.AbsoluteSize.X * 0.5 + VIEWPORT_MARGIN) / VIEWPORTSIZE_X, 1 - (FRAME.AbsoluteSize.Y * 0.5 + viewportMargin) / VIEWPORTSIZE_Y

	FRAME.Position = FRAME.Position:Lerp(UDIM2(SAFECLAMP(FRAME_TARGET_POSITION.X.Scale, viewportBoundXL, viewportBoundXR), FRAME_TARGET_POSITION.X.Offset, SAFECLAMP(FRAME_TARGET_POSITION.Y.Scale, viewportBoundYT, viewportBoundYB), FRAME_TARGET_POSITION.Y.Offset), 0.25)
end

function ResponsiveFrame:UpdateLabels()
	local fontSize = HEADER_TEXT_INITIAL_TEXT_SIZE + 1
	repeat
		local computedSize = TextService:GetTextSize(FRAME.HeaderLabel.Text, fontSize, FRAME.HeaderLabel.Font, FRAME_INITIAL_ABSOLUTE_SIZE).X
		fontSize -= 1
	until computedSize < FRAME.AbsoluteSize.X - 30 or fontSize == 0

	FRAME.HeaderLabel.TextSize = fontSize
	
	for _, label in ipairs(self.TrimmableLabels) do
		local iterations = 0
		local newText = label.initialText.Value
		local labelTextSizeX = TextService:GetTextSize(newText, label.TextSize, label.Font, FRAME_INITIAL_ABSOLUTE_SIZE).X

		while (labelTextSizeX + 20 > FRAME.AbsoluteSize.X - 15 and iterations < 50) do
			iterations += 1
			newText = "..." .. newText:sub(iterations == 1 and 4 or 5, #newText)
			labelTextSizeX = TextService:GetTextSize(newText, label.TextSize, label.Font, FRAME_INITIAL_ABSOLUTE_SIZE).X
		end

		label.Text = newText
	end
end

function ResponsiveFrame:Start(frameIndex, onResizeCallback)
	local bindingName = "LOC" .. frameIndex .. "Update"
	if self.RenderBindings[bindingName] then return "Already running" end
	RunService:UnbindFromRenderStep(bindingName .. "Lerp")
	RunService:BindToRenderStep(bindingName, RENDER_PRIORITY.Value, function()
		if FRAME then
			local mousePosition = UserInputService:GetMouseLocation()
			if (RESIZABLE or RESIZING) and not DRAGGING then
				RESIZING = true
				setCursorUI(self.IS_MOUSE_PLUGIN and "rbxasset://SystemCursors/SizeEW" or "rbxassetid://11909998877")
				
				if INITIAL_RESIZING_MOUSEPOS == EMPTY_VECTOR2 then
					INITIAL_RESIZING_MOUSEPOS = mousePosition
				end
				
				local distX = (mousePosition - FRAME.AbsolutePosition).X
				local viewportMargin = ResponsiveFrame.IS_MOUSE_PLUGIN and VIEWPORT_MARGIN or GuiService:GetGuiInset().Y / 2
				
				FRAME.Size = FRAME.Size:Lerp(UDIM2(FRAME.Size.X.Scale, SAFECLAMP(distX, MINIMUM_FRAME_HORIZONTAL_SIZE, VIEWPORTSIZE_X - VIEWPORT_MARGIN * 2), FRAME.Size.Y.Scale, FRAME.Size.Y.Offset), 0.50)
				
				self:UpdateLabels()
				if onResizeCallback then onResizeCallback() end
			else
				local withInBounds = withInBounds(mousePosition) and self.CanDrag
				
				if withInBounds and not DRAGGING then
					setDraggerUI(false)
				end
				
				if withInBounds or DRAGGING then
					DRAGGING = true
					setCursorUI(self.IS_MOUSE_PLUGIN and "rbxasset://SystemCursors/ClosedHand" or "rbxassetid://11909973998")
					
					FRAME_TARGET_POSITION = UDIM2(mousePosition.X / VIEWPORTSIZE_X, -FRAME.Size.X.Offset / 2, mousePosition.Y / VIEWPORTSIZE_Y, -FRAME.Size.Y.Offset / 2)
					updateFramePosition()
				end
			end
		end
	end)
	self.RenderBindings[bindingName] = true
end

function ResponsiveFrame:Stop(frameIndex)
	local wasDragging = DRAGGING
	setDraggerUI(true)
	setCursorUI()
	DRAGGING = false
	RESIZING = false
	
	local bindingName = "LOC" .. frameIndex .. "Update"
	RunService:UnbindFromRenderStep(bindingName)
	local timer = 0
	RunService:BindToRenderStep(bindingName .. "Lerp", RENDER_PRIORITY.Value, function(dt)
		timer += dt
		if timer > 0.25 then
			RunService:UnbindFromRenderStep(bindingName .. "Lerp")
			return
		end
		if FRAME and FRAME_TARGET_POSITION and wasDragging then
			updateFramePosition()
		end
	end)
	self.RenderBindings[bindingName] = false
end

function ResponsiveFrame:IsDragging()
	return DRAGGING
end

function ResponsiveFrame:Remove()
	Util:DisconnectConnection(CLICK_CONNECTION, function()
		CLICK_CONNECTION = nil
		setDraggerUI(true)
		setCursorUI()
		RELEASED = true
		DRAGGING = false
		RESIZING = false
		FRAME = nil
		VIEWPORT_CHANGED_CONNECTION:Disconnect()
		VIEWPORT_CHANGED_CONNECTION = nil
		OVERFLOW_Y_HOVERED_CONNECTION:Disconnect()
		OVERFLOW_Y_HOVERED_CONNECTION = nil
		self.TrimmableLabels = {}
	end)
end

function ResponsiveFrame:Init(frame, plug, frameIndex, onResizeCallback)
	assert(typeof(frame) == "Instance" and frame:IsA("Frame"), "A frame must be passed to method :Init()")
	assert(frame:FindFirstChild("OverflowY"), "Overflow not found in frame")
	assert(frame:FindFirstChild("HeaderLabel"), "HeaderLabel not found in frame")
	assert(not CLICK_CONNECTION, "Module is already running")
	
	self.CanDrag = true
	
	RELEASED = false
	DRAGGING = false
	RESIZABLE = false
	INITIAL_RESIZING_MOUSEPOS = EMPTY_VECTOR2
	FRAME = frame
	if not FRAME_INITIAL_ABSOLUTE_SIZE then
		FRAME_INITIAL_ABSOLUTE_SIZE = frame.AbsoluteSize
	end
	if not HEADER_TEXT_INITIAL_TEXT_SIZE then
		HEADER_TEXT_INITIAL_TEXT_SIZE = frame.HeaderLabel.TextSize
	end
	PLUGIN = plug
	setCursorUI()
	
	CLICK_CONNECTION = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == MOUSE_BUTTON then
			local bind = self:Start(frameIndex, onResizeCallback)
			if bind == "Already running" then return end
			repeat WAIT() until not UserInputService:IsMouseButtonPressed(MOUSE_BUTTON) or RELEASED
			self:Stop(frameIndex)
		end
	end)
	VIEWPORT_CHANGED_CONNECTION = CAMERA:GetPropertyChangedSignal("ViewportSize"):Connect(viewportSizeChanged)
	OVERFLOW_Y_HOVERED_CONNECTION = frame.OverflowY.MouseEnter:Connect(function(mouseX, mouseY)
		RESIZABLE = true
		setCursorUI(self.IS_MOUSE_PLUGIN and "rbxasset://SystemCursors/SizeEW" or "rbxassetid://11909998877")
		frame.OverflowY.MouseLeave:Wait()
		RESIZABLE = false
		if not RESIZING then
			setCursorUI()
		end
	end)
end

return ResponsiveFrame

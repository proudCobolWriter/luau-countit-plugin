-- /*
-- @module GraphCreator  Creates and animates graphs using TweenService
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

local GraphCreator = {
	connections = {},
	graphs = {},
	labels = {},
	percentageLabels = {},
	garbage = {},
}

-- Retrieving services

local TweenService = game:GetService("TweenService")

-- Retrieving dependencies

local ResponsiveFrame = require(script.Parent:WaitForChild("ResponsiveFrame")) ---@module ResponsiveFrame  Handles the position and the size of a given frame

-- CACHED FUNCTIONS

local UDIM2 = UDim2.new
local WAIT = task.wait
local MAX = math.max

-- Declaring functions

local function iterate(t, func) -- ease of use function
	for _, v in ipairs(t) do
		func(v)
	end
end

function GraphCreator.cleanupGraphs()
	iterate(GraphCreator.connections, function(connection)
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end)
	iterate(GraphCreator.graphs, function(graph)
		for _, subgraph in ipairs(graph) do
			subgraph:Destroy()
		end
	end)
	iterate(GraphCreator.labels, function(label) label:Destroy() end)
	iterate(GraphCreator.garbage, function(garbage) garbage:Destroy() end)
	
	GraphCreator.connections = {}
	GraphCreator.graphs = {}
	GraphCreator.labels = {}
	GraphCreator.percentageLabels = {}
	GraphCreator.garbage = {}
end

local CELL_WIDTH
function GraphCreator.newLabels(parent, parts, data, cellHeight, animate, event)
	if not CELL_WIDTH then
		CELL_WIDTH = parent.AbsoluteSize.X * (1 / parts)
	end
	
	local uigridlayout = Instance.new("UIGridLayout")
	uigridlayout.CellPadding = UDIM2(0.05, 0, 0, 0)
	uigridlayout.CellSize = UDIM2(0, CELL_WIDTH, 0, cellHeight)
	uigridlayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uigridlayout.Parent = parent
	
	for i = 1, parts do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.Name = "Cell"
		cell.Parent = parent
		
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = animate and UDIM2(0, 4, 0.5, 0) or UDIM2(0, 12, 0.5, 0)
		label.Size = UDIM2(1, 0, 0.5, 0)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextTransparency = animate and 1 or 0
		label.TextSize = 20
		label.RichText = true
		label.Text = string.format('%s', data[i][3])
		label.Font = Enum.Font.SourceSansSemibold
		label.Parent = cell
		
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.Position = UDIM2(0.5, -label.TextBounds.X / 2, 0.5, 0)
		frame.Size = UDIM2(0, 6, 0, 6)
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = data[i][2]
		frame.Parent = cell
		
		if i == 1 and event then
			local lastValue = uigridlayout.AbsoluteContentSize.Y
			table.insert(GraphCreator.connections, uigridlayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				local newValue = uigridlayout.AbsoluteContentSize.Y
				if newValue ~= lastValue then
					event:Fire(newValue)
					lastValue = newValue
				end
			end))
		end
		
		if animate then
			local tweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			
			local labelTween = TweenService:Create(label, tweenInfo, { TextTransparency = 0, Position = UDIM2(0, 12, 0.5, 0) })
			task.delay(0.20 * (i - 1), function()
				labelTween:Play()
			end)
		end
		
		table.insert(GraphCreator.labels, cell)
		table.insert(GraphCreator.garbage, uigridlayout)
	end
end

function GraphCreator.updateTextLabels(bool, textTable, frame)
	for _, v in ipairs(textTable) do
		local text, valueText, percentageText = unpack(v)
		if not text or not text.Parent then continue end

		text.Text = bool and percentageText or valueText

		local initialOffset, i = text:FindFirstChild("initialOffset"), text:FindFirstChild("i")
		if not initialOffset or not i then continue end
		initialOffset, i = initialOffset.Value, i.Value

		local startingPoint = GraphCreator.graphs[initialOffset][i - 1] and GraphCreator.graphs[initialOffset][i - 1].Size.X.Scale or 0
		local nextPoint = GraphCreator.graphs[initialOffset][i] and GraphCreator.graphs[initialOffset][i].Size.X.Scale or 1

		local sizeHorizontal = nextPoint - startingPoint

		text.TextTransparency = sizeHorizontal > text.TextBounds.X / frame.AbsoluteSize.X and 0 or 1
	end
end

function GraphCreator.newGraph(parent, parts, data, maxValue, barTransparency)
	if maxValue == 0 then
		parent.BackgroundTransparency = barTransparency
		return
	end
	
	local invisibleButton = Instance.new("TextButton")
	invisibleButton.BackgroundTransparency = 1
	invisibleButton.Text = ""
	invisibleButton.BorderSizePixel = 0
	invisibleButton.Size = UDIM2(1, 0, 1, 0)
	invisibleButton.Active = false
	invisibleButton.Selected = false
	invisibleButton.AutoButtonColor = false
	invisibleButton.Parent = parent
	
	local tweenInfo = TweenInfo.new(0.60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(parent, tweenInfo, { BackgroundTransparency = barTransparency }):Play()
	
	local textTable = {}
	for i = 1, parts do
		if i ~= 1 and data[1][1] / maxValue == 1 then continue end
		local ui = Instance.new("Frame")
		ui.Size = UDIM2(0, 0, 1, 0)
		ui.BorderSizePixel = 0
		ui.BackgroundColor3 = data[i][2]
		ui.ZIndex = parts - i
		ui.Parent = parent
		
		local uicorner = Instance.new("UICorner")
		uicorner.CornerRadius = UDim.new(0, 4)
		uicorner.Parent = ui
		
		local uigradient = Instance.new("UIGradient")
		local h, s, v = data[i][2]:ToHSV()

		local middleValue = 1 - data[i][1] / maxValue
		if middleValue > 0 then
			uigradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1 - data[i][1] / maxValue, Color3.fromHSV(h, 0.45, v)),
				ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
			})
		else
			uigradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 0.45, v)),
				ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
			})
		end
		uigradient.Parent = ui
		
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.BorderSizePixel = 0
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Size = UDIM2(1, 0, 1, 0)
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextTransparency = 1
		text.TextSize = 16
		text.Font = Enum.Font.RobotoCondensed
		text.RichText = true
		text.Text = string.format('<font weight="Bold">%i</font>', data[i][1])
		text.ZIndex = 100
		text.TextWrapped = true
		text.Parent = parent
		
		if i == 1 then
			GraphCreator.graphs[#GraphCreator.graphs + 1] = {ui}
		else
			table.insert(GraphCreator.graphs[#GraphCreator.graphs], ui)
		end
		local initialOffset = #GraphCreator.graphs
		
		local sum = 0
		for k = 1, i do
			sum += data[k][1] / maxValue
		end
		
		local tweenCompleted = false
		local tween = TweenService:Create(ui, tweenInfo, { Size = UDim2.new(sum, 0, 1, 0) })
		
		tween:Play()
		
		task.spawn(function()
			local textTweened = false
			tween.Completed:Connect(function()
				tweenCompleted = true
			end)
			local intValue1, intValue2 = Instance.new("IntValue"), Instance.new("IntValue")
			intValue1.Value, intValue2.Value = initialOffset, i
			intValue1.Name, intValue2.Name = "initialOffset", "i"
			intValue1.Parent, intValue2.Parent = text, text
			repeat WAIT()
				if not GraphCreator.graphs[#GraphCreator.graphs] then tweenCompleted = true; return end
				
				local startingPoint = GraphCreator.graphs[initialOffset][i - 1] and GraphCreator.graphs[initialOffset][i - 1].Size.X.Scale or 0
				local nextPoint = GraphCreator.graphs[initialOffset][i] and GraphCreator.graphs[initialOffset][i].Size.X.Scale or ui.Size.X.Scale
				
				local sizeHorizontal = nextPoint - startingPoint
				
				if sizeHorizontal > text.TextBounds.X / parent.AbsoluteSize.X and not textTweened then
					textTweened = true
					TweenService:Create(text, tweenInfo, { TextTransparency = 0 }):Play()
				end
				
				text.Position = UDIM2(startingPoint + sizeHorizontal / 2, 0, 0.5, 1)
			until tweenCompleted
		end)
		
		local roundingFunction = i == parts and math.ceil or math.floor -- to make sure the percentages sum up to 100%
		local valueText, percentageText = text.Text, string.format('<font weight="Bold">%i%%</font>', roundingFunction(data[i][1] / maxValue * 100))
		
		local t = {text, valueText, percentageText}
		table.insert(textTable, t)
		table.insert(GraphCreator.percentageLabels, t)
		table.insert(GraphCreator.garbage, text)
	end
	
	table.insert(GraphCreator.connections, invisibleButton.MouseEnter:Connect(function()
		if not ResponsiveFrame:IsDragging() then
			GraphCreator.updateTextLabels(true, textTable, parent)
			invisibleButton.MouseLeave:Wait()
			GraphCreator.updateTextLabels(false, textTable, parent)
		end
	end))
end

return GraphCreator

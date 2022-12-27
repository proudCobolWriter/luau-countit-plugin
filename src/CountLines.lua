--!nocheck
-- ^ since LuaSourceContainers don't inherit the .Source property for some reasons

-- /*
-- @module CountLines  Returns advanced script statistics about the game
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

-- Retrieving dependencies

local VirusCheckFunc = require(script.Parent:WaitForChild("VirusSignatures")) ---@module VirusSignatures  Identifies viruses

-- The following constants define in which runcontext a given module script presumably runs according to the service it's located in
local BLACKLISTED_SERVICES = {
	["CoreGui"] = true,
}

local CLIENT_SIDE_SERVICES = {
	["ReplicatedStorage"] = true,
	["ReplicatedFirst"] = true,
	["StarterPlayer"] = true,
}

local SHARED_MODULE_SERVICES = {
	["ReplicatedStorage"] = true,
	["ReplicatedFirst"] = true,
	["StarterPack"] = true,
	["Workspace"] = true,
}

local SERVER_SIDE_SERVICES = { ["ServerScriptService"] = true, ["ServerStorage"] = true, }

-- function magiclines ( s: string ): (any) -> any
--	 		^
--	 		*
--			* @param s script source
--			*
--	 		* @return an iterator function
--
local function magiclines(s: string): (any) -> any
	if s:sub(-1) ~= "\n" then s = s .. "\n" end
	return s:gmatch("(.-)\n")
end

-- function getLinesInScript ( processedScript: LuaSourceContainer ): ...number
--	 		^ Manipulates the given script's source to retrieve how much lines it contains
--	 		*
--			* @param processedScript script instance that is being checked
--			*
--	 		* @return tuple of 3 numbers
--
local function getLinesInScript(processedScript: LuaSourceContainer): ...number
	local _, countNewlines = processedScript.Source:gsub('\n', '\n')
	local countTrueLines, countNoComments = 0, 0
	
	local index = 0
	local lastMultilineComment = nil
	for line in magiclines(processedScript.Source) do
		index += 1
		local containsLetters = string.match(line, "[%w%p]") -- includes dots and punctuation
		if line ~= "" and containsLetters then
			countTrueLines += 1
			-- Accounts for both multiline comments and inline comments
			if not lastMultilineComment and line:sub(1, 2) ~= "--" then
				countNoComments += 1
			elseif not lastMultilineComment and line:sub(1, 4) == "--[[" then
				lastMultilineComment = index
			elseif lastMultilineComment and line:sub(#line - 1, #line) == "]]" then
				lastMultilineComment = nil
			end
		end
	end
	
	return countNewlines + 1, countTrueLines, countNoComments
end

-- function evaluateDuplicate ( cache: {LuaSourceContainer}, processedScript: LuaSourceContainer ): number
--	 		^ Iterates through all the scripts in cache to test whether or not there's a duplicate of processedScript
--	 		*
--			* @param cache weak table reference
--			* @param processedScript script instance that is being checked
--			*
--	 		* @return 1 if a duplicate has been found, 0 if none has been found
--
local function evaluateDuplicate(cache: {LuaSourceContainer}, processedScript: LuaSourceContainer): number
	local duplicate = 0
	if processedScript.Source ~= "" then
		for _, cachedScript in ipairs(cache) do
			if cachedScript.Source == processedScript.Source then
				duplicate = 1
				break
			end
		end
	end
	return duplicate
end

local cachedScripts = setmetatable({}, { __mode = "k" }) -- used to find duplicates


-- anonymous function (checkVirusesOnly: boolean): ...any
--	 				  ^ Returns advanced script statistics about the game in the form of a dictionary (=hashtable)
--	 				  *
--	 				  * @param checkVirusesOnly self-explanatory parameter, defines whether or not anything else than viruses should be checked
--	 				  *
--	 				  * @return tuple containing both the dictionary and the time it took to compute the values in ms
--	 				  ** 								  ^example keys:
--					  ** 								   ["totalLines"] = 10,
--	 				  ** 								   ["totalServices"] = 2
--
return function(checkVirusesOnly: boolean): ...any
	local startingTime = DateTime.now().UnixTimestampMillis
	cachedScripts = {}
	
	local lineDataServices = {}
	local lineData = {
		ModuleScript = 0,
		LocalScript = 0,
		Script = 0,
	}
	local lineDataScriptSide = {
		ServerSide = 0,
		ClientSide = 0,
		Shared = 0,
	}
	local scriptDataServices = {}
	local scriptData = {
		ModuleScript = 0,
		LocalScript = 0,
		Script = 0,
	}
	local scriptDataScriptSide = {
		ServerSide = 0,
		ClientSide = 0,
		Shared = 0,
	}
	local services = {}
	
	
	local totalServices = 0
	local totalLines = 0
	local totalLinesNoComment = 0
	local totalTrueLines = 0
	local totalChars = 0
	local duplicates = 0
	
	
	local potentialThreats = {
		-- structure of array-like table potentialThreats:
		-- example item:
		-- {
		-- 		severityIndex: number, (on a range going from 0 (harmless) to 3 (dangerous))
		-- 		flaggedScript: Instance, (the script instance posing the virus threat)
		-- }
	}
	
	
	for _, service in next, game:GetChildren() do
		local serviceName
		local servicePermissionAvailable = pcall(function()
			serviceName = service.Name
		end)
		
		if not servicePermissionAvailable then continue end
		if BLACKLISTED_SERVICES[serviceName] then continue end
		
		-- Register service in table services
		table.insert(services, service)
		
		-- Iterate through all the scripts within the service
		for _, instance in ipairs(service:GetDescendants()) do
			if instance:IsA("LuaSourceContainer") then
				if instance:GetFullName():find(".rbxmx") then continue end
				if instance:GetAttribute("IsPluginScript") then continue end
				
				local virus = VirusCheckFunc(instance)
				table.insert(potentialThreats, virus)
				if checkVirusesOnly then continue end
				
				if instance:IsA("ModuleScript") then
					if not scriptDataServices[serviceName] then scriptDataServices[serviceName] = { ModuleScript = 0, LocalScript = 0, Script = 0 } end
					if not lineDataServices[serviceName] then lineDataServices[serviceName] = { ModuleScript = 0, LocalScript = 0, Script = 0 }; totalServices += 1 end
					
					local lines, trueLines, linesNoComment = getLinesInScript(instance)
					
					lineDataServices[serviceName].ModuleScript += lines
					scriptDataServices[serviceName].ModuleScript += 1
					lineData.ModuleScript += lines
					scriptData.ModuleScript += 1
					
					if SHARED_MODULE_SERVICES[serviceName] then
						lineDataScriptSide.Shared += lines
						scriptDataScriptSide.Shared += 1
					elseif SERVER_SIDE_SERVICES[serviceName] then
						lineDataScriptSide.ServerSide += lines
						scriptDataScriptSide.ServerSide += 1
					elseif CLIENT_SIDE_SERVICES[serviceName] then
						lineDataScriptSide.ClientSide += lines
						scriptDataScriptSide.ClientSide += 1
					end
					
					totalLines += lines
					totalTrueLines += trueLines
					totalLinesNoComment += linesNoComment
					totalChars += #instance.Source
					
					local duplicate = evaluateDuplicate(cachedScripts, instance)
					duplicates += duplicate
					if duplicate == 0 then
						table.insert(cachedScripts, instance)
					end
				elseif instance:IsA("LocalScript") or (instance:IsA("Script") and instance.RunContext == Enum.RunContext.Client) then
					if not scriptDataServices[serviceName] then scriptDataServices[serviceName] = { ModuleScript = 0, LocalScript = 0, Script = 0 } end
					if not lineDataServices[serviceName] then lineDataServices[serviceName] = { ModuleScript = 0, LocalScript = 0, Script = 0 }; totalServices += 1 end
					
					local lines, trueLines, linesNoComment = getLinesInScript(instance)
					
					lineDataServices[serviceName].LocalScript += lines
					scriptDataServices[serviceName].LocalScript += 1
					lineData.LocalScript += lines
					scriptData.LocalScript += 1
					
					lineDataScriptSide.ClientSide += lines
					scriptDataScriptSide.ClientSide += 1
					
					totalLines += lines
					totalTrueLines += trueLines
					totalLinesNoComment += linesNoComment
					totalChars += #instance.Source
					
					local duplicate = evaluateDuplicate(cachedScripts, instance)
					duplicates += duplicate
					if duplicate == 0 then
						table.insert(cachedScripts, instance)
					end
				elseif instance:IsA("Script") then
					if not scriptDataServices[serviceName] then scriptDataServices[serviceName] = { ModuleScript = 0, LocalScript = 0, Script = 0 } end
					if not lineDataServices[serviceName] then lineDataServices[serviceName] = { ModuleScript = 0, LocalScript = 0, Script = 0 }; totalServices += 1 end
					
					local lines, trueLines, linesNoComment = getLinesInScript(instance)
					
					lineDataServices[serviceName].Script += lines
					scriptDataServices[serviceName].Script += 1
					lineData.Script += lines
					scriptData.Script += 1
					
					lineDataScriptSide.ServerSide += lines
					scriptDataScriptSide.ServerSide += 1
					
					totalLines += lines
					totalTrueLines += trueLines
					totalLinesNoComment += linesNoComment
					totalChars += #instance.Source
					
					local duplicate = evaluateDuplicate(cachedScripts, instance)
					duplicates += duplicate
					if duplicate == 0 then
						table.insert(cachedScripts, instance)
					end
				end
			end
		end
	end
	
	return {
		totalServices = totalServices,
		totalLines = totalLines,
		totalTrueLines = totalTrueLines,
		totalLinesNoComment = totalLinesNoComment,
		totalChars = totalChars,
		duplicates = duplicates,
		services = services,
		scriptData = scriptData,
		scriptDataScriptSide = scriptDataScriptSide,
		scriptDataServices = scriptDataServices,
		lineData = lineData,
		lineDataScriptSide = lineDataScriptSide,
		lineDataServices = lineDataServices,
		potentialThreats = potentialThreats,
	}, (DateTime.now().UnixTimestampMillis - startingTime) .. "ms"
	
end

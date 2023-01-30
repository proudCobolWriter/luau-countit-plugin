-- /*
-- @module VirusSignatures  Identifies viruses
-- Last edited the 25/12/2022
-- Written by poggers
-- */

-- Type definitions

export type VirusResult = {
	message: string?, -- optional
	severityIndex: number,
	flaggedScript: LuaSourceContainer
}

-- Functions

local function constructFunction(message: string?, severityIndex: number)
	return function(flaggedScript: LuaSourceContainer & Script): VirusResult
		return {
			message = message or "",
			severityIndex = severityIndex,
			flaggedScript = flaggedScript
		}
	end
end

-- Feel free to contribute by expanding the following table,
-- Any function with key "any" will run on all scripts on this place, whereas
-- more specific keys like ["vaccine"] will only run on scripts named like so
-- The severityIndex goes from 0 (harmless) to 3 (dangerous), which will be
-- useful to know once I release the virus manager for the plugin
-- NOTE: Please keep code in the ["any"] key as unexpensive as possible since those functions are run across all the scripts (some places contain a lot!) when toggling the plugin
local VirusSignatures = {
	["any"] = {
		function(flaggedScript: LuaSourceContainer & Script): VirusResult
			local source = flaggedScript.Source
			local start = source:find("fenv")
			local sub = source:sub(start - 3, start - 1)

			if sub == "get" or sub == "set" then
				local message = "Suspicious usage of " .. sub "fenv()",
				return { 
					message = message,
					severityIndex = 3, -- maximum severity
					flaggedScript = flaggedScript,
				}
			end
		end,
		function(flaggedScript: LuaSourceContainer & Script): VirusResult
			local source = flaggedScript.Source
			local containsLoadstring = source:find("loadstring")

			if containsLoadstring then
				return { 
					message = "Script contains function loadstring",
					severityIndex = 3, -- maximum severity
					flaggedScript = flaggedScript,
				}
			end
		end,
		function(flaggedScript: LuaSourceContainer & Script): VirusResult
			if flaggedScript.Parent and flaggedScript.Parent:IsA("Fire") then
				print("fire")
				return { 
					message = "Found script parented to suspicious Fire Instance",
					severityIndex = 2,
					flaggedScript = flaggedScript,
				}
			end
		end,
		function(flaggedScript: LuaSourceContainer & Script): VirusResult
			local parents = #flaggedScript:GetFullName():split(".")

			if parents > 10 then
				print(parents)
				return { 
					message = "Highly nested script",
					severityIndex = 1,
					flaggedScript = flaggedScript,
				}
			end
		end,
		function(flaggedScript: LuaSourceContainer & Script): VirusResult
			local scriptName = flaggedScript.Name
			local specialChar = scriptName:gsub("[%w]", "")

			if specialChar ~= "" then
				return { 
					message = "Script name contains special characters such as " .. specialChar,
					severityIndex = 1, -- maximum severity
					flaggedScript = flaggedScript,
				}
			end
		end
	},
	-- The following keys are case-insensitive
	["vaccine"] = constructFunction("Possible freemodel virus", 2),
	["fx"] = constructFunction("Possible freemodel virus", 2),
	["spread"] = constructFunction("Possible freemodel virus", 2),
	["infected"] = constructFunction("Possible freemodel virus", 2),
	["inf3cted"] = constructFunction("Possible freemodel virus", 2),
	["virus"] = constructFunction("Possible freemodel virus", 2),
	[""] = constructFunction("Suspicious unnamed script", 1),
}

-- anonymous function ( processedScript: Instance ): VirusResult | nil
--	     ^ Virus checks a given script Instance
--	     *
--	     * @param processedScript script instance that is being checked
--	     *
--	     * @return dictionary (=hashtable) of type VirusResult or nil
--	     **        ^keys:
--	     **        ["message"]: string?
--	     **        ["severityIndex"]: number,
--	     **        ["flaggedScript"]: Instance
--
return function(processedScript: LuaSourceContainer): VirusResult | nil
	for _, func in ipairs(VirusSignatures["any"] or {}) do
		local result = func()
		if result.severityIndex > 0 then -- checks whether the severity level is anything above 0 (harmless)
			return result
		end
	end
	
	local func = VirusSignatures[processedScript.Name:lower()]
	if func then
		local result = func()
		if result.severityIndex > 0 then -- checks whether the severity level is anything above 0 (harmless)
			return result
		end
	end
	
	return
end
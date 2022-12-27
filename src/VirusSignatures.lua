-- /*
-- @module VirusSignatures  Identifies viruses
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

-- Type definitions

export type VirusResult = {
	severityIndex: number,
	flaggedScript: LuaSourceContainer
}

-- Feel free to contribute by expanding the following table,
-- Any function with key "any" will run on all scripts on this place, whereas
-- more specific keys like ["vaccine"] will only run on scripts named like so
-- The severityIndex goes from 0 (harmless) to 3 (dangerous), which will be
-- useful to know once I release the virus manager for the plugin
local VirusSignatures = {
	["any"] = {
		
	},
	["vaccine"] = {
		function(flaggedScript: LuaSourceContainer)
			return { 
				severityIndex = 3, -- maximum severity
				flaggedScript = flaggedScript,
			}
		end,
	}
}

-- anonymous function (processedScript: Instance): VirusResult | nil
--	 	      ^ Virus checks a given script Instance
--	 	      *
--	 	      * @param processedScript script instance that is being checked
--	 	      *
--	 	      * @return dictionary (=hashtable) of type VirusResult or nil
--	 	      ** 	^keys:
--		      ** 	 ["severityIndex"]: number,
--	 	      ** 	 ["flaggedScript"]: Instance
--
return function(processedScript: LuaSourceContainer): VirusResult | nil
	for _, func in ipairs(VirusSignatures["any"] or {}) do
		local result = func()
		if result.severityIndex > 0 then -- checks whether the severity level is anything above 0 (harmless)
			return result
		end
	end
	
	for _, func in ipairs(VirusSignatures[processedScript.Name:lower()] or {}) do
		local result = func()
		if result.severityIndex > 0 then -- checks whether the severity level is anything above 0 (harmless)
			return result
		end
	end
	
	return
end

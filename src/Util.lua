-- /*
-- @module Util  Just a bunch of utility functions to complement the plugin and keep things clean
-- Last edited the 25/12/2022
-- Written by poggers
-- Merry Christmas!
-- */

local Util = { }

-- method DisconnectConnection ( connection: RBXScriptConnection, callback: () -> any ): nil
--	 	    ^
--		    * Shorthand function
--		    *
--		    * @param connection RBXScriptConnection
--		    *
--	 	    * @return string Random Hex string
--
function Util:DisconnectConnection(connection: RBXScriptConnection, callback: () -> any): nil
	if connection and typeof(connection) == "RBXScriptConnection" then
		connection:Disconnect()
		if callback then
			callback()
		end
	end
	
	return
end

-- method RandomHex ( ): string
--	 	    ^
--		    * Generates a random hexadecimal lowercase string
--		    *
--	 	    * @return string Random Hex string
--
function Util:RandomHex(): string
	return string.format("%x", Random.new():NextInteger(0, 1e5))
end


-- method PlaySound ( sync: boolean, soundID: string | number, soundVolume: number ): Sound?
--	 	    ^
--		    * Plays a sound
--		    *
--		    * @param sync defines whether or not the method should be run synchronously (meaning the code yields till the sound has finished playing)
--		    * @param soundID roblox asset string or number (both works since it's concatenated)
--		    * @param soundVolume volume sound
--		    *
--	 	    * @return Sound Instance or nil
--
function Util:PlaySound(sync: boolean, soundID: string | number, soundVolume: number): Sound?
	if not self.SoundWidget then return end
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundID
	sound.Volume = soundVolume
	sound.Parent = self.SoundWidget
	sound:Play()
	
	if sync then
		sound.Ended:Wait()
		sound:Destroy()
	end
	
	return sound
end

-- method DockSoundWidget ( PLUGIN: Plugin ): DockWidgetPluginGui
--	 	    ^
--		    * Docks a widget meant to play sounds
--		    *
--		    * @param PLUGIN Plugin Instance
--		    *
--	 	    * @return DockWidgetPluginGui Instance
--
function Util:DockSoundWidget(PLUGIN: Plugin): DockWidgetPluginGui
	assert(not self.SoundWidget, "Sound widget has already been docked")
	assert(PLUGIN, "A plugin must be provided")

	local WidgetName = "SoundPlayer" .. self:RandomHex()
	self.SoundWidget = PLUGIN:CreateDockWidgetPluginGui(WidgetName, DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float,
		false, true,
		10, 10,
		10, 10
	))

	self.SoundWidget.Name, self.SoundWidget.Title = WidgetName, "Sound Player"
	
	return self.SoundWidget
end

-- method UnDockSoundWidget ( ): nil
--	 	    ^
--		    * Undocks the widget
--		    *
--	 	    * @return void
--
function Util:UnDockSoundWidget(): nil
	assert(self.SoundWidget, "Sound widget has already been undocked")
	
	self.SoundWidget:Destroy()
	
	return
end


return Util

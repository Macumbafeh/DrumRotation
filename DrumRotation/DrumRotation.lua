----------------------------------------------------------------------------------------------------
-- variables
----------------------------------------------------------------------------------------------------
DrumRotationSave    = nil -- saved settings - defaults are set up in the ADDON_LOADED event
local addonSettings = nil -- reference to DrumRotationSave

-- table for frames and information that isn't saved that's used by other components
DrumRotationInfo = {}
local addonInfo        = DrumRotationInfo
addonInfo.eventFrame   = CreateFrame("frame")
addonInfo.minorVersion = 4 -- version of the addon - 2.<minorVersion>

-- references to frames - some set up in the ADDON_LOADED event
local eventFrame     = addonInfo.eventFrame -- handles events and updates
local optionFrame    = nil                  -- the options window
local alertIconFrame = nil                  -- the icon to alert you when it's your turn
local alertBarFrame  = nil                  -- the bar to alert you when it's your turn

-- item and spell IDs instead of names so that the client's language doesn't matter
	-- drum spells
local DRUMS_OF_PANIC_SPELL_ID       = 35474
local DRUMS_OF_WAR_SPELL_ID         = 35475
local DRUMS_OF_BATTLE_SPELL_ID      = 35476
local DRUMS_OF_SPEED_SPELL_ID       = 35477
local DRUMS_OF_RESTORATION_SPELL_ID = 35478
	-- other spells that share cooldown
local CRYSTAL_YIELD_SPELL_ID        = 15235
	-- item IDs
local DRUMS_OF_WAR_ITEM_ID          = 29528
local DRUMS_OF_BATTLE_ITEM_ID       = 29529

-- list of drum IDs (value set to 1) and other items that share a cooldown (value set to 0)
local drumCooldownItem = {
	[CRYSTAL_YIELD_SPELL_ID]        = 0, -- Crystal Yield - ???
	[DRUMS_OF_PANIC_SPELL_ID]       = 1, -- Drums of panic - SPELL_CAST_START
	[DRUMS_OF_WAR_SPELL_ID]         = 1, -- Drums of War - SPELL_CAST_SUCCESS
	[DRUMS_OF_BATTLE_SPELL_ID]      = 1, -- Drums of Battle - SPELL_CAST_SUCCESS
	[DRUMS_OF_SPEED_SPELL_ID]       = 1, -- Drums of Speed - SPELL_CAST_SUCCESS
	[DRUMS_OF_RESTORATION_SPELL_ID] = 1, -- Drums of Restoration - SPELL_CAST_SUCCESS
}

-- miscellaneous information
local inGroupNumber      = nil               -- the subgroup the player is in
local drumBattleRotation = {name="Battle"}   -- the group's current rotation for Drums of Battle
local drumWarRotation    = {name="War"}      -- the group's current rotation for Drums of War
local playerRotation     = nil               -- reference to which rotation the player is in - drumBattleRotation or drumWarRotation
local drummerCooldown    = {}                -- table of players and when their drums will be off cooldown
local groupNextBattle    = {0,0,0,0,0,0,0,0} -- the GetTime() drums of battle will end for a group
local groupNextWar       = {0,0,0,0,0,0,0,0} -- the GetTime() drums of war will end for a group
local usedAlert          = false             -- if the player has shown an alert already - to not reshow if the group changes

-- tracking inventory and drum buff updates
local EventType = {
	USE_WARN    = 1, -- a warning event some time before it's time to use drums
	USE_NOW     = 2, -- a warning event when it's time to use drums
	INFORM_WARN = 3, -- inform others drums are about to end
	INFORM_NOW  = 4, -- inform someone to use their drums now
}
local bagsUpdated    = false -- if an inventory item has changed
local nextEventTime  = 0     -- the GetTime() of when to do the next event
local nextEventType  = 0     -- 0: checking for your turn, 1: telling the next drummer its their turn
local totalElapsed   = 0     -- counter for the update function to only update once per second

-- other local references or copies
local playerName            = UnitName("player")
local UnitInParty           = UnitInParty
local UnitInRaid            = UnitInRaid
local UnitHealth            = UnitHealth
local UnitIsDeadOrGhost     = UnitIsDeadOrGhost
local UnitIsConnected       = UnitIsConnected
local GetTime               = GetTime

----------------------------------------------------------------------------------------------------
-- helper functions
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- word wrap for tooltip lines - from http://rosettacode.org/wiki/Word_wrap#Lua
--------------------------------------------------
local function SplitTokens(text)
	local res = {}
	for word in text:gmatch("%S+") do
		res[#res+1] = word
	end
	return res
end

local function WordWrap(text, linewidth)
	if not linewidth then
		linewidth = 250
	end

	local spaceleft = linewidth
	local res = {}
	local line = {}
	for _, word in ipairs(SplitTokens(text)) do
		if #word + 1 > spaceleft then
			table.insert(res, table.concat(line, ' '))
			line = {word}
			spaceleft = linewidth - #word
		else
			table.insert(line, word)
			spaceleft = spaceleft - (#word + 1)
		end
	end
	table.insert(res, table.concat(line, ' '))
	return res
end

--------------------------------------------------
-- stop being active and hide any alerts
--------------------------------------------------
local function StopDrumming()
	alertBarFrame:Hide()
	alertIconFrame:Hide()
	nextEventType = 0
end

--------------------------------------------------
-- check and set if the player has drums
--------------------------------------------------
local function UpdateDrumInventory(send_update)
	local hasBattle = (GetItemCount(DRUMS_OF_BATTLE_ITEM_ID, false, false) > 0)
	local hasWar    = (GetItemCount(DRUMS_OF_WAR_ITEM_ID, false, false) > 0)

	local drummer = addonSettings.drummers[playerName]
	if drummer then
		local updated = nil
		if (hasBattle and not drummer.hasBattle) or (not hasBattle and drummer.hasBattle) then
			drummer.hasBattle = hasBattle
			updated = true
		end
		if (hasWar and not drummer.hasWar) or (not hasWar and drummer.hasWar) then
			drummer.hasWar = hasWar
			updated = true
		end
		if updated and send_update then
			SendAddonMessage("SSDRUM", string.format("NFO hasBattle=%d;hasWar=%d", (hasBattle and 1 or 0), (hasWar and 1 or 0)), "RAID")
		end
	end
end

--------------------------------------------------
-- send information to other players
--------------------------------------------------
local function UpdateDrummingInformation(send_information, request_info_back, whisper_target)
	local drummer = addonSettings.drummers[playerName]
	if not drummer then
		return
	end

	UpdateDrumInventory()

	local cooldown = 0
	local cd_start, cd_duration = GetItemCooldown(29529)
	if cd_start and cd_start > 0 then
		cooldown = math.ceil((cd_start+cd_duration)-GetTime())
		if cooldown > 0 then
			drummerCooldown[playerName] = GetTime() + cooldown
		end
	end

	drummer.version      = addonInfo.minorVersion
	drummer.preferFirst  = addonSettings.preferFirst
	drummer.preferWar    = addonSettings.preferWar
	drummer.alwaysWar    = addonSettings.alwaysWar
	drummer.alertWhisper = addonSettings.alertWhisper

	if send_information then
		local message = string.format("NFO version=%d;cooldown=%d;hasBattle=%d;hasWar=%d;preferFirst=%d;preferWar=%d;alwaysWar=%d;alertWhisper=%d;request=%d",
			addonInfo.minorVersion,
			cooldown,
			drummer.hasBattle and 1 or 0,
			drummer.hasWar and 1 or 0,
			drummer.preferFirst and 1 or 0,
			drummer.preferWar and 1 or 0,
			drummer.alwaysWar and 1 or 0,
			drummer.alertWhisper and 1 or 0,
			request_info_back and 1 or 0)
		SendAddonMessage("SSDRUM", message, whisper_target and "WHISPER" or "RAID", whisper_target)

		-- send any excluded people
		local excluded_message = nil
		for name,info in pairs(addonSettings.drummers) do
			if info.excluded and info.excluded == addonSettings.groupCount then
				if not excluded_message then
					excluded_message = "EX"
				end
				excluded_message = excluded_message .. " " .. name
			end
		end
		if excluded_message then
			SendAddonMessage("SSDRUM", excluded_message, whisper_target and "WHISPER" or "RAID", whisper_target)
		end
	end
end

--------------------------------------------------
-- return which group the player is in, or nil for none
--------------------------------------------------
local function GetGroupNumber(name)
	if GetNumRaidMembers() > 0 then
		for i=1,MAX_RAID_MEMBERS do
			local member,_,group = GetRaidRosterInfo(i)
			if member == name then
				return group
			end
		end
	end
	if GetNumPartyMembers() > 0 then
		return 1
	end
	return nil
end

--------------------------------------------------
-- return if someone can use drums of battle and drums of war
--------------------------------------------------
local function CanDrum(name, check_death, check_cooldown, need_battle, need_war)
	if check_death and (UnitIsDeadOrGhost(name) or UnitHealth(name) == 0 or (UnitHealth(name) == 1 and (UnitDebuff(name, 1)) == "Ghost") or not UnitIsConnected(name)) then
		return false
	end
	if check_cooldown and drummerCooldown[name] and GetTime() < drummerCooldown[name] then
		return false
	end

	local drummer = addonSettings.drummers[name]
	if not drummer then
		return false
	end

	if drummer.excluded and drummer.excluded == addonSettings.groupCount then
		return false
	end
	if not drummer.version then
		return (not need_war) -- assume people without the addon can only use drums of battle
	end
	return (not need_battle or drummer.hasBattle) and (not need_war or drummer.hasWar)
end

--------------------------------------------------
-- calculate how long until the next drum use should happen (for this player)
--------------------------------------------------
local function SecondsUntilDrumCheck()
	if not playerRotation then return 0 end

	-- first use the player's cooldown time to know when the next possible use is
	local duration = drummerCooldown[playerName] or 0
	-- check drum buffs on the group members - if any last longer than the cooldown then use its time instead
	local drum_end_time = (playerRotation.name == "Battle" and groupNextBattle[inGroupNumber] or groupNextWar[inGroupNumber])
	if inGroupNumber and drum_end_time > duration then
		duration = drum_end_time
	end
	duration = duration - GetTime()
	if duration < 0 then
		duration = 0
	end
	return math.ceil(duration)
end

--------------------------------------------------
-- update the time for when the next event (like drum buff fading/almost fading) is checked
--------------------------------------------------
function DrumRotationInfo:UpdateNextEventTime(cancel_informing)
	-- informing requires no special time updating, so do nothing unless informing is being canceled
	if nextEventType == EventType.INFORM_WARN or nextEventType == EventType.INFORM_NOW then
		if cancel_informing then
			nextEventType = EventType.USE_WARN
		else
			return
		end
	end

	-- update the event type if needed
	if nextEventType == 0 then
		nextEventType = EventType.USE_WARN
	end

	local duration = SecondsUntilDrumCheck()
	if nextEventType == EventType.USE_WARN and addonSettings.alertBefore and addonSettings.alertBeforeTime > 0 then
		nextEventTime = GetTime() + duration - addonSettings.alertBeforeTime
	else
		nextEventTime = GetTime() + duration
	end
end

--------------------------------------------------
-- build the group's rotation
--------------------------------------------------
function DrumRotationInfo:BuildRotation(cancel_informing)
	local battle_rotation = drumBattleRotation
	local war_rotation    = drumWarRotation

	-- clear the rotations to start over
	playerRotation = nil
	for i=1,5 do
		battle_rotation[i] = nil
		war_rotation[i] = nil
	end

	-- first put all the possible drummers in alphabetical order
	function InsertAlphabetically(name, list)
		for i=1,5 do
			if not list[i] or name < list[i].name then
				table.insert(list, i, addonSettings.drummers[name])
				return
			end
		end
	end
	-- the player
	local drummer = addonSettings.drummers[playerName]
	if drummer and CanDrum(playerName) then
		if drummer.alwaysWar and drummer.hasWar then
			playerRotation = drumWarRotation
			InsertAlphabetically(playerName, war_rotation)
		elseif not drummer.version or drummer.hasBattle then
			playerRotation = drumBattleRotation
			InsertAlphabetically(playerName, battle_rotation)
		elseif drummer.hasWar then
			playerRotation = drumWarRotation
			InsertAlphabetically(playerName, war_rotation)
		end
	end
	-- the rest of the group
	for i=1,GetNumPartyMembers() do
		local name = UnitName("party" .. i)
		drummer = addonSettings.drummers[name]
		if drummer and CanDrum(name) then
			if drummer.alwaysWar and drummer.hasWar then
				InsertAlphabetically(name, war_rotation)
			elseif not drummer.version or drummer.hasBattle then
				InsertAlphabetically(name, battle_rotation)
			elseif drummer.hasWar then
				InsertAlphabetically(name, war_rotation)
			end
		end
	end

	-- choose someone to use drums of war if needed
	if #battle_rotation == 5 then
		-- first try to find someone that prefers to use drums of war
		for i=1,5 do
			local drummer = battle_rotation[i]
			if drummer.preferWar and drummer.hasWar then
				if drummer.name == playerName then
					playerRotation = drumWarRotation
				end
				InsertAlphabetically(drummer.name, war_rotation)
				table.remove(battle_rotation, i)
				break
			end
		end
		-- if no one was found yet, then try each person
		if #battle_rotation == 5 then
			for i=1,5 do
				local drummer = battle_rotation[i]
				if drummer.hasWar then
					if drummer.name == playerName then
						playerRotation = drumWarRotation
					end
					InsertAlphabetically(drummer.name, war_rotation)
					table.remove(battle_rotation, i)
					break
				end
			end
		end
	end

	-- move people that prefer to go first to the front
	local at_position = 1
	for i=1,#battle_rotation do
		local drummer = battle_rotation[i]
		if drummer.preferFirst and at_position ~= i then
			drummer = table.remove(battle_rotation, i)
			table.insert(battle_rotation, at_position, drummer)
			at_position = at_position + 1
		end
	end
	at_position = 1
	for i=1,#war_rotation do
		local drummer = war_rotation[i]
		if drummer.preferFirst and at_position ~= i then
			drummer = table.remove(war_rotation, i)
			table.insert(war_rotation, at_position, drummer)
			at_position = at_position + 1
		end
	end

	DrumRotationInfo:UpdateNextEventTime(cancel_informing)
end

--------------------------------------------------
-- add a name to the known drummer list
--------------------------------------------------
function DrumRotationInfo:AddDrummer(name, request_info, share)
	if not addonSettings.drummers[name] then
		addonSettings.drummers[name] = {}
		addonSettings.drummers[name].name = name
		if optionFrame and optionFrame:IsVisible() then
			optionFrame:SetDrummerList()
		end
		if name == playerName then
			UpdateDrummingInformation(true, true)
		elseif request_info and (UnitInParty(name) or UnitInRaid(name)) then
			SendAddonMessage("SSDRUM", "NFO request=1", "WHISPER", name)
		end
	end
	if share then
		SendAddonMessage("SSDRUM", "AD " .. name, "RAID")
	end
	DrumRotationInfo:BuildRotation(false)
end

--------------------------------------------------
-- remove a name from the known drummer list
--------------------------------------------------
function DrumRotationInfo:RemoveDrummer(name, share)
	if addonSettings.drummers[name] then
		addonSettings.drummers[name] = nil
		if optionFrame and optionFrame:IsVisible() then
			optionFrame:SetDrummerList()
		end
	end
	if share then
		SendAddonMessage("SSDRUM", "RM " .. name, "RAID")
	end
	if name == playerName then
		StopDrumming()
	end
	DrumRotationInfo:BuildRotation(false)
end

--------------------------------------------------
-- return who the next drummer is - nil if no one is possible right now, or optionally return the
-- person with the shortest cooldown instead
--------------------------------------------------
local function GetNextDrummer(or_return_shortest_cooldown)
	if not playerRotation then
		return nil
	end

	local drums_of_battle = (playerRotation.name == "Battle")

	for i=1,#playerRotation do
		if CanDrum(playerRotation[i].name, true, true, drums_of_battle, (not drums_of_battle)) then
			return playerRotation[i].name
		end
	end

	-- no one available to drum instantly, so find who has the shortest cooldown
	if or_return_shortest_cooldown then
		local shortest_time = nil
		local shortest_name = nil
		for i=1,#playerRotation do
			if CanDrum(playerRotation[i].name, true, false, drums_of_battle, (not drums_of_battle)) then
				local cooldown = drummerCooldown[playerRotation[i].name] or 0
				if not shortest_time or cooldown < shortest_time then
					shortest_time = cooldown
					shortest_name = playerRotation[i].name
				end
			end
		end
		return shortest_name
	end
end

--------------------------------------------------
-- return the group's rotation
--------------------------------------------------
local function GetRotation()
	local battle_rotation = ""
	for i=1,#drumBattleRotation do
		if battle_rotation ~= "" then
			battle_rotation = battle_rotation .. " > "
		end
		battle_rotation = battle_rotation .. drumBattleRotation[i].name
	end

	local war_rotation = ""
	for i=1,#drumWarRotation do
		if war_rotation ~= "" then
			war_rotation = war_rotation .. " > "
		end
		war_rotation = war_rotation .. drumWarRotation[i].name
	end

	if drumBattleRotation[1] and drumWarRotation[1] then
		return string.format("Drum rotations: BATTLE=[%s] WAR=[%s]", battle_rotation, war_rotation)
	elseif drumBattleRotation[1] then
		return "Drums of Battle rotation: " .. battle_rotation
	elseif drumWarRotation[1] then
		return "Drums of War rotation: " .. war_rotation
	else
		return "Drum rotation: none!"
	end
end

--------------------------------------------------
-- handle scheduled updates
--------------------------------------------------
local function DrumRotation_OnUpdate(self, elapsed)
	totalElapsed = totalElapsed + elapsed
	if totalElapsed < 1 then return end
	totalElapsed = 0

	-- updating inventory is checked here so that it can be throttled to once per second because
	-- there can be quite a lot of BAG_UPDATE events all at once!
	if bagsUpdated then
		bagsUpdated = false
		UpdateDrumInventory(true)
	end

	-- checking for disconnected people here because events can come before they're actually disconnected
	if groupUpdated then
		groupUpdated = false
		local name
		if GetNumRaidMembers() > 0 then
			for i=1,40 do
				name = UnitName("raid" .. i)
				if name and not UnitIsConnected(name) then
					if addonSettings.drummers[name] then
						addonSettings.drummers[name].version = nil
					end
				end
			end
		else
			for i=1,GetNumPartyMembers() do
				name = UnitName("party" .. i)
				if name and not UnitIsConnected(name) then
					if addonSettings.drummers[name] then
						addonSettings.drummers[name].version = nil
					end
				end
			end
		end
	end

	if nextEventType == 0 then
		return
	end
	local update_time = GetTime()
	if update_time < nextEventTime then
		return
	end

	-- warning yourself when it's your turn to use drums
	if nextEventType == EventType.USE_WARN or nextEventType == EventType.USE_NOW then
		local next_drummer = GetNextDrummer(true)
		if playerName == next_drummer then
			-- if alerting some time before it's time to use them, figure out how long is left until then
			local duration = SecondsUntilDrumCheck()
			if duration <= 0 then
				duration = 0
				nextEventType = EventType.USE_NOW -- in case it was USE_WARN
			end
			if nextEventType == EventType.USE_NOW then
				if usedAlert then
					nextEventType = 0
					return
				end
				usedAlert = true
			end

			if UnitAffectingCombat("player") then
				-- play sound
				if addonSettings.alertPlaySound and duration == 0 then
					if addonSettings.alertSoundFile:find("/") or addonSettings.alertSoundFile:find("\\") then
						PlaySoundFile(addonSettings.alertSoundFile:gsub("\\\\","\\"))
					else
						PlaySound(addonSettings.alertSoundFile)
					end
				end
				-- show bar
				if addonSettings.alertBar and not alertBarFrame:IsVisible() then
					alertBarFrame:ShowBar(duration, (playerRotation.name == "Battle"))
				end
				-- show icon
				if addonSettings.alertIcon and not alertIconFrame:IsVisible() then
					alertIconFrame:ShowIcon(duration, true, (playerRotation.name == "Battle"))
				end
				-- show raid warning message
				if addonSettings.alertMessage then
					RaidNotice_AddMessage(RaidWarningFrame,
						string.format("Use Drums of %s %s!", (playerRotation and playerRotation.name or "Unknown"),
							duration > 0 and ("in " .. duration .. " seconds") or "NOW"),
						ChatTypeInfo["RAID_WARNING"])
				end
			end
		end

		if nextEventType == EventType.USE_WARN then
			nextEventType = EventType.USE_NOW
			DrumRotationInfo:UpdateNextEventTime(false)
		elseif next_drummer == playerName then
			nextEventType = EventType.USE_WARN
			DrumRotationInfo:UpdateNextEventTime(false)
		else
			nextEventType = 0
		end
		return
	end

	-- informing others when drums are ending soon
	if nextEventType == EventType.INFORM_WARN then
		if UnitAffectingCombat("player") then
			local next_drummer = GetNextDrummer(true)
			if next_drummer and next_drummer ~= playerName then
				local next_drum_time = math.ceil(playerRotation.name == "Battle" and (groupNextBattle[inGroupNumber]-GetTime()) or (groupNextWar[inGroupNumber]-GetTime()))
				SendChatMessage("Drums of " .. playerRotation.name .. " ending in 5 seconds! Next: " .. next_drummer, "PARTY")
				SendAddonMessage("SSDRUM", "NFO start=" .. next_drum_time, "WHISPER", next_drummer) -- in case they recently moved into the group
			end
		end
		nextEventType = EventType.INFORM_NOW
		nextEventTime = update_time + 5
		return
	end

	-- informing others when it's time to use drums now
	if nextEventType == EventType.INFORM_NOW then
		nextEventType = 0
		local next_drummer = GetNextDrummer(true)
		if UnitAffectingCombat("player") then
			local drummer_info = next_drummer and addonSettings.drummers[next_drummer]
			if next_drummer then
				if next_drummer == playerName then
					nextEventType = EventType.USE_WARN
					DrumRotationInfo:UpdateNextEventTime(false)
				else
					-- in case they recently moved into the group
					local next_drum_time = math.ceil(playerRotation.name == "Battle" and (groupNextBattle[inGroupNumber]-GetTime()) or (groupNextWar[inGroupNumber]-GetTime()))
					SendAddonMessage("SSDRUM", "NFO start=" .. next_drum_time, "WHISPER", next_drummer)
					-- only whisper to someone that doesn't use the addon or wants to be whispreded
					if not drummer_info or not drummer_info.version  or drummer_info.alertWhisper then
						-- their name is added to the whisper to make it more noticeable - some addons do things when seeing it
						-- +3 so that it uses the non-cooldown message if their cooldown is almost up
						if not drummerCooldown[next_drummer] or update_time + 3 >= drummerCooldown[next_drummer] then
							SendChatMessage(string.format("Use Drums of %s %s!", playerRotation.name, next_drummer:upper()), "WHISPER", nil, next_drummer)
						else
							SendChatMessage(string.format("Use Drums of %s when you can, %s!", playerRotation.name, next_drummer:upper()), "WHISPER", nil, next_drummer)
						end
					end
				end
			end
		end
	return
	end
end

----------------------------------------------------------------------------------------------------
-- /drum command
----------------------------------------------------------------------------------------------------
_G.SLASH_DRUMS1 = "/drum"
_G.SLASH_DRUMS2 = "/drums"
function SlashCmdList.DRUMS(input)
	input = input or ""

	local command, value = input:match("(%w+)%s*(.*)")
	command = command or input -- if using input, then it's a single command without a value
	command = command:lower()
	value = value and (value:gsub("(%a)(%w*)", function(first,rest) return first:upper() .. rest:lower() end)) -- capitalize

	function CheckInGroup()
		if GetNumRaidMembers() == 0 and GetNumPartyMembers() == 0 then
			DEFAULT_CHAT_FRAME:AddMessage("You aren't in a group.")
			return false
		end
		return true
	end

	--------------------------------------------------
	-- /drum options
	--------------------------------------------------
	if command == "options" then
		addonInfo.optionFrame:Show()
		return
	end

	--------------------------------------------------
	-- /drum say
	-- tell the rotation to the group
	--------------------------------------------------
	if command == "say" or command == "report" then -- "report" was used in an old version
		if CheckInGroup() then
			SendChatMessage(GetRotation(), "PARTY")
		end
		return
	end

	--------------------------------------------------
	-- /drum show
	-- show the rotation to only the player
	--------------------------------------------------
	if command == "show" then
		if CheckInGroup() then
			DEFAULT_CHAT_FRAME:AddMessage(GetRotation())
		end
		return
	end

	--------------------------------------------------
	-- /drum battle|war
	-- set a drum type preference
	--------------------------------------------------
	if command == "battle" or command == "war" then
		addonSettings.alwaysWar = (command == "war")
		SendAddonMessage("SSDRUM", "NFO alwaysWar=" .. (addonSettings.alwaysWar and "1" or "0"), "RAID")
		if addonSettings.drummers[playerName] then
			addonSettings.drummers[playerName].alwaysWar = addonSettings.alwaysWar
		end
		if optionFrame and optionFrame:IsVisible() then
			optionFrame:UpdateAlwaysWar()
		end
		UpdateDrummingInformation(true)
		DEFAULT_CHAT_FRAME:AddMessage("You now prefer to use drums of " .. command .. " when you have them.")
		return
	end

	--------------------------------------------------
	-- /drum info ["raid"]
	-- show information about the group's drummers
	--------------------------------------------------
	if command == "info" then
		function ShowInfo(name)
			local drummer = name and addonSettings.drummers[name] or nil
			if not drummer then return end

			local cooldown = drummerCooldown[name] and drummerCooldown[name] - GetTime()
			if not cooldown or cooldown < 0 then
				cooldown = 0
			end

			local message = string.format("%s: [%s] [CD:%d]",
				name, drummer.version and ("version 2." .. drummer.version) or "no addon", cooldown)
			if drummer.version then
				message = string.format("%s%s%s%s%s%s%s", message,
					(drummer.hasBattle    and " [Has Battle]"    or ""),
					(drummer.hasWar       and " [Has War]"       or ""),
					(drummer.preferFirst  and " [Prefer First]"  or ""),
					(drummer.preferWar    and " [Prefer War]"    or ""),
					(drummer.alwaysWar    and " [Always War]"    or ""),
					(drummer.alertWhisper and " [Wants Whisper]" or ""))
			end
			if drummer.excluded and drummer.excluded == addonSettings.groupCount then
				message = message .. " [Excluded]"
			end
			DEFAULT_CHAT_FRAME:AddMessage(message)
			return true
		end

		local found = false
		if value == "Raid" and GetNumRaidMembers() > 0 then
			for i=1,40 do
				if ShowInfo(UnitName("raid" .. i)) then
					found = true
				end
			end
		elseif CheckInGroup() then
			found = ShowInfo(playerName)
			for i=1,GetNumPartyMembers() do
				if ShowInfo(UnitName("party" .. i)) then
					found = true
				end
			end
		else
			return
		end

		if not found then
			DEFAULT_CHAT_FRAME:AddMessage("There are no known drummers in your group.")
		end
		return
	end

	--------------------------------------------------
	-- /drum join [name]
	-- add yourself or [name] back as a drummer after they've been excluded
	--------------------------------------------------
	if command == "join" or command == "include" then
		if CheckInGroup() then
			if not value or value == "" then
				value = playerName
			end
			if not addonSettings.drummers[value] then
				DEFAULT_CHAT_FRAME(value .. " isn't a known drummer.")
				return
			end
			addonSettings.drummers[value].excluded = nil
			DEFAULT_CHAT_FRAME:AddMessage(value .. " will be included in the drum rotations again.")
			SendAddonMessage("SSDRUM", "AD " .. value, "RAID")
		end
		return
	end

	--------------------------------------------------
	-- /drum leave [name]
	-- temporarily exclude yourself or [name] from drumming
	--------------------------------------------------
	if command == "leave" or command == "exclude" then
		if CheckInGroup() then
			if not value or value == "" then
				value = playerName
			end
			if not addonSettings.drummers[value] then
				DEFAULT_CHAT_FRAME(value .. " isn't a known drummer.")
				return
			end
			addonSettings.drummers[value].excluded = addonSettings.groupCount
			DEFAULT_CHAT_FRAME:AddMessage(value .. " has been temporarily excluded from drum rotations.")
			SendAddonMessage("SSDRUM", "EX " .. value, "RAID")
		end
		return
	end

	--------------------------------------------------
	-- /drum add <name>
	-- add somone as a known drummer
	--------------------------------------------------
	if command == "add" then
		if not value or value == "" then
			DEFAULT_CHAT_FRAME:AddMessage("Syntax: /drum add <name>")
		else
			DrumRotationInfo:AddDrummer(value, true, true)
			DEFAULT_CHAT_FRAME:AddMessage(value .. " has been set as a drummer.")
		end
		return
	end

	--------------------------------------------------
	-- /drum remove <name>
	-- remove someone from the known drummer list
	--------------------------------------------------
	if command == "remove" then
		if not value or value == "" then
			DEFAULT_CHAT_FRAME:AddMessage("Syntax: /drum remove <name>")
		else
			DrumRotationInfo:RemoveDrummer(value, true)
			DEFAULT_CHAT_FRAME:AddMessage(value .. " is no longer set as a drummer.")
		end
		return
	end

	--------------------------------------------------
	-- /drum share
	-- share all known drummers to the group
	--------------------------------------------------
	if command == "share" then
		if CheckInGroup() then
			local name_table = {}
			for name in pairs(addonSettings.drummers) do
				table.insert(name_table, name)
			end
			local name_list = table.concat(name_table, " ")

			local split_list = WordWrap(name_list, 240)
			for i=1,#split_list do
				SendAddonMessage("SSDRUM", "AD " .. split_list[i], "RAID")
			end
			DEFAULT_CHAT_FRAME:AddMessage("You shared your known drummer list with the group.")
		end
		return
	end

	--------------------------------------------------
	-- no command, so show syntax
	--------------------------------------------------
	DEFAULT_CHAT_FRAME:AddMessage('Drum Rotation commands:', 1, 1, 0)
	DEFAULT_CHAT_FRAME:AddMessage('/drum options  |cffffff00(open options window)|r')
	DEFAULT_CHAT_FRAME:AddMessage('/drum say||show  |cffffff00(tell group or show rotation)|r')
	DEFAULT_CHAT_FRAME:AddMessage('/drum join||leave [name]  |cffffff00(temp. include/exclude yourself or [name])|r')
	DEFAULT_CHAT_FRAME:AddMessage('/drum add||remove <name>  |cffffff00(add/remove <name> as drummer)|r')
	DEFAULT_CHAT_FRAME:AddMessage('/drum info ["raid"]  |cffffff00(show drummer info for group/raid)|r')
	DEFAULT_CHAT_FRAME:AddMessage('/drum battle||war  |cffffff00(set preference of type to use)|r')
	DEFAULT_CHAT_FRAME:AddMessage('/drum share  |cffffff00(share known drummers with group)|r')
end

----------------------------------------------------------------------------------------------------
-- handling events - drum cooldowns/new rotations/switching group/etc
----------------------------------------------------------------------------------------------------
local isLoading = true  -- if currently logging in/reloading - to not react to some events like party member changes

local function DrumRotation_OnEvent(self, event, ...)
	--------------------------------------------------
	-- combat log
	--------------------------------------------------
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _,action,_,source,source_flags,_,_,_,spell_id,spell_name = ...

		-- if spell == "Omen of Clarity" then spell = "Drums of Battle" elseif spell == "Mark of the Wild" then spell = "Drums of War" end -- for testing
		if (action == "SPELL_CAST_SUCCESS" or action == "SPELL_CAST_START") and drumCooldownItem[spell_id] and bit.band(source_flags, COMBATLOG_OBJECT_REACTION_FRIENDLY) > 0 then
			if drumCooldownItem[spell_id] == 1 then
				DrumRotationInfo:AddDrummer(source, true)
				nextEventType = EventType.INFORM_WARN
			else
				nextEventType = EventType.USE_WARN
			end
			drummerCooldown[source] = GetTime() + 120

			if UnitInParty(source) then
				usedAlert = false

				if playerName == source then
					alertBarFrame:Hide()
					alertIconFrame:Hide()
					SendAddonMessage("SSDRUM", "NFO " .. ((spell_id == DRUMS_OF_BATTLE_SPELL_ID and "cooldown=Battle") or (spell_id == DRUMS_OF_WAR_SPELL_ID and "cooldown=War") or "cooldown=120"), "RAID")

					if GetNumPartyMembers() > 0 then
						if (spell_id == DRUMS_OF_BATTLE_SPELL_ID and groupNextBattle[inGroupNumber]-GetTime() < 28) or
							(spell_id == DRUMS_OF_WAR_SPELL_ID and groupNextWar[inGroupNumber]-GetTime() < 28) then
							SendChatMessage("Using " .. spell_name .. (UnitAffectingCombat("player") and "!" or " to simulate the feeling of being in combat!"), "PARTY")
						end
					end
					-- still set future messages even when alone or when accidentally using drums right after someone
					-- in case the groups change and your message is needed then
					nextEventTime = GetTime() + 25
				end
			end

			if UnitInParty(source) or UnitInRaid(source) then
				if spell_id == DRUMS_OF_BATTLE_SPELL_ID then
					groupNextBattle[GetGroupNumber(source) or 1] = GetTime() + 30
				elseif spell_id == DRUMS_OF_WAR_SPELL_ID then
					groupNextWar[GetGroupNumber(source) or 1] = GetTime() + 30
				end
			end

			if playerName ~= source and UnitInParty(source) and playerRotation and UnitAffectingCombat("player") and
				((playerRotation.name == "Battle" and spell_id == DRUMS_OF_BATTLE_SPELL_ID) or (playerRotation.name == "War" and spell_id == DRUMS_OF_WAR_SPELL_ID)) then
				alertBarFrame:Hide()
				alertIconFrame:Hide()
				nextEventType = EventType.USE_WARN
				DrumRotationInfo:UpdateNextEventTime(false)
			end
		end
		return
	end

	--------------------------------------------------
	-- inventory changed
	--------------------------------------------------
	if event == "BAG_UPDATE" then
		bagsUpdated = true -- does the actual update in the OnUpdate function
		return
	end

	--------------------------------------------------
	-- handle addon messages
	--------------------------------------------------
	if event == "CHAT_MSG_ADDON" then
		local prefix, message, channel, name = ...
		if prefix ~= "SSDRUM" then
			return
		end

		-- only accept messages from group members
		if (not UnitInRaid(name) and not UnitInParty(name)) then
			return
		end

		if name == playerName then
			DrumRotationInfo:BuildRotation(false)
			return -- already have the information about whatever was sent
		end

		local command, value = message:match("(%w+)%s*(.*)")

		-- someone sends information about themselves
		if command == "NFO" then
			DrumRotationInfo:AddDrummer(name)
			local drummer = addonSettings.drummers[name]

			for key,value in value:gmatch("(%a+)=([%a%d]+)[^;]*") do
				if key == "request" then
					if value == "1" then
						UpdateDrummingInformation(true, false, name)
					end
				elseif key == "cooldown" then
					if value == "Battle" then
						if playerRotation and playerRotation.name == "Battle" and UnitInParty(name) and UnitAffectingCombat("player") then
							nextEventType = EventType.USE_WARN
							DrumRotationInfo:UpdateNextEventTime(false)
						end
						value = 120
					elseif value == "War" then
						if playerRotation and playerRotation.name == "War" and UnitInParty(name) and UnitAffectingCombat("player") then
							nextEventType = EventType.USE_WARN
							DrumRotationInfo:UpdateNextEventTime(false)
						end
						value = 120
					end
					local cooldown = drummerCooldown[name]
					value = tonumber(value)
					if value > 0 and (not cooldown or (GetTime()+120) - cooldown > 5) then
						drummerCooldown[name] = GetTime() + value
					end
				elseif key == "hasBattle" then
					drummer.hasBattle = (value == "1")
				elseif key == "hasWar" then
					drummer.hasWar = (value == "1")
				elseif key == "preferFirst" then
					drummer.preferFirst = (value == "1")
				elseif key == "preferWar" then
					drummer.preferWar = (value == "1")
				elseif key == "alwaysWar" then
					drummer.alwaysWar = (value == "1")
				elseif key == "alertWhisper" then
					drummer.alertWhisper = (value == "1")
				elseif key == "version" then
					drummer.version = value
				elseif key == "start" then -- it's your turn to drum soon/now
					if nextEventType == 0 then
						if playerRotation then
							if playerRotation.name == "Battle" then
								groupNextBattle[inGroupNumber] = GetTime() + tonumber(value)
							else
								groupNextWar[inGroupNumber] = GetTime() + tonumber(value)
							end
						end
						nextEventType = EventType.USE_WARN
						nextEventTime = GetTime()
					end
				end
			end
		-- someone sends a person to exclude as a drummer during this group
		elseif command == "EX" then
			if value then
				for drummer in value:gmatch("[^ ]+") do
					if addonSettings.allowEdits then
						DrumRotationInfo:AddDrummer(drummer, true)
					end
					if addonSettings.drummers[drummer] then
						addonSettings.drummers[drummer].excluded = addonSettings.groupCount
					end
				end
			end
		-- someone sends a person (or list of people) to add (or include again) to the drummer list
		elseif command == "AD" then
			if value then
				for drummer in value:gmatch("[^ ]+") do
					if addonSettings.allowEdits then
						DrumRotationInfo:AddDrummer(drummer, true)
					end
					if addonSettings.drummers[drummer] then
						addonSettings.drummers[drummer].excluded = nil
					end
				end
			end
		-- someone sends a person to remove from being a drummer
		elseif command == "RM" then
			if addonSettings.allowEdits then
				DrumRotationInfo:RemoveDrummer(value)
			end
		end

		DrumRotationInfo:BuildRotation(false)
	end

	--------------------------------------------------
	-- combat stopped
	--------------------------------------------------
	if event == "PLAYER_REGEN_ENABLED" then
		StopDrumming()
		return
	end

	--------------------------------------------------
	-- changing group
	--------------------------------------------------
	if event == "RAID_ROSTER_UPDATE" then
		groupUpdated = true
		return
	end

	if event == "PARTY_MEMBERS_CHANGED" then
		if isLoading then return end

		local previous_group = inGroupNumber
		inGroupNumber = GetGroupNumber(playerName)

		if inGroupNumber then
			groupUpdated = true
			if not previous_group then
				-- new group, so increase the group ID counter
				addonSettings.groupCount = addonSettings.groupCount and addonSettings.groupCount + 1 or 1
				-- if not the leader, send your information
				if not IsPartyLeader() then
					UpdateDrummingInformation(true, true)
				end
				bagsUpdated = true -- force update now since they aren't being watched when alone
				eventFrame:SetScript("OnUpdate", DrumRotation_OnUpdate)
			end

			DrumRotationInfo:BuildRotation((inGroupNumber ~= previous_group))
			if inGroupNumber ~= previous_group and playerName ~= GetNextDrummer(false) then
				alertBarFrame:Hide()
				alertIconFrame:Hide()
				DrumRotationInfo:UpdateNextEventTime(true)
			end
		else
			-- left the group
			StopDrumming()
			eventFrame:SetScript("OnUpdate", nil)
		end
		return
	end

	--------------------------------------------------
	-- finished logging in enough to do things
	--------------------------------------------------
	if event == "UPDATE_PENDING_MAIL" then
		eventFrame:UnregisterEvent(event)
		inGroupNumber = GetGroupNumber(playerName)
		isLoading = false
		UpdateDrummingInformation(true, true)
		if inGroupNumber then
			eventFrame:SetScript("OnUpdate", DrumRotation_OnUpdate)
		end
		return
	end

	--------------------------------------------------
	-- finished loading addon
	--------------------------------------------------
	if event == "ADDON_LOADED" and ... == "DrumRotation" then
		eventFrame:UnregisterEvent(event)

		DrumRotationSave = DrumRotationSave or {}
		addonSettings   = DrumRotationSave
		optionFrame     = addonInfo.optionFrame
		alertIconFrame  = addonInfo.alertIconFrame
		alertBarFrame   = addonInfo.alertBarFrame

		-- default alert settings
		if addonSettings.alertBefore       == nil then addonSettings.alertBefore       = true  end
		if addonSettings.alertBeforeTime   == nil then addonSettings.alertBeforeTime   = 4     end
		if addonSettings.alertMessage      == nil then addonSettings.alertMessage      = true  end
		if addonSettings.alertIcon         == nil then addonSettings.alertIcon         = false end
		if addonSettings.alertIconSize     == nil then addonSettings.alertIconSize     = 64    end
		if addonSettings.alertIconDuration == nil then addonSettings.alertIconDuration = 15    end
		if addonSettings.alertIconPosition == nil then addonSettings.alertIconPosition = {anchor1="CENTER", anchor2="CENTER", offsetX=0, offsetY=0} end
		if addonSettings.alertBar          == nil then addonSettings.alertBar          = false end
		if addonSettings.alertBarDuration  == nil then addonSettings.alertBarDuration  = 15    end
		if addonSettings.alertBarPosition  == nil then addonSettings.alertBarPosition  = 150   end
		if addonSettings.alertPlaySound    == nil then addonSettings.alertPlaySound    = false end
		if addonSettings.alertSoundFile    == nil then addonSettings.alertSoundFile    = "gsCharacterCreationCreateChar" end
		if addonSettings.alertWhisper      == nil then addonSettings.alertWhisper      = false end
		-- default miscellaneous settings
		if addonSettings.preferFirst       == nil then addonSettings.preferFirst       = false end
		if addonSettings.preferWar         == nil then addonSettings.preferWar         = false end
		if addonSettings.alwaysWar         == nil then addonSettings.alwaysWar         = false end
		if addonSettings.allowEdits        == nil then addonSettings.allowEdits        = true  end
		-- tracking/miscellaneous things
		if addonSettings.groupCount        == nil then addonSettings.groupCount        = 0 end
		-- default known drummers
		if addonSettings.drummers == nil then
			addonSettings.drummers = {}
			DrumRotationInfo:AddDrummer(playerName, false, true)
		else
			-- don't know if the drummer still uses the addon, so remove the version
			for _,info in pairs(addonSettings.drummers) do
				info.version = nil
			end
		end
		alertIconFrame:SetLock(true)
		return
	end
end

eventFrame:SetScript("OnEvent", DrumRotation_OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")                -- temporary - handle loading and fixing settings
eventFrame:RegisterEvent("UPDATE_PENDING_MAIL")         -- temporary - used when loading to know when party member information is available
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")        -- exiting combat, to hide any shown alerts
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") -- to watch when drums are used
eventFrame:RegisterEvent("CHAT_MSG_ADDON")              -- to synchronize things and share drummers
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")       -- to know when to share information, recalculate the next drummer, and know about disconnections
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")          -- to know about disconnections
eventFrame:RegisterEvent("BAG_UPDATE")                  -- to track drum items

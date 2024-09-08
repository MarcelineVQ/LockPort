local lockport_title = "|CFFB700B7L|CFFFF00FFo|CFFFF50FFc|CFFFF99FFk|CFFFFC4FFP|cffffffffort|r"

-- LOCKPORT_HEADER = lockport_title
BINDING_HEADER_LOCKPORT = lockport_title
BINDING_NAME_SUMMON_KEY = "Summon next queue target"

local LockPortOptions_DefaultSettings = {
	whisper = true,
	zone    = true,
	shards  = true,
	sound   = true,
}

local function LockPort_Initialize()
	LockPortOptions = LockPortOptions or {}
	for i in LockPortOptions_DefaultSettings do
		LockPortOptions[i] = (LockPortOptions[i] == nil and LockPortOptions_DefaultSettings[i]) or LockPortOptions[i]
	end

	WhisperCheckButton:SetChecked(LockPortOptions["whisper"] or nil)
	ZoneCheckButton:SetChecked(LockPortOptions["zone"] or nil)
	ShardsCheckButton:SetChecked(LockPortOptions["shards"] or nil)
	SoundCheckButton:SetChecked(LockPortOptions["sound"] or nil)
end

function LockPort_EventFrame_OnLoad()
	DEFAULT_CHAT_FRAME:AddMessage(string.format(lockport_title.." version %s by %s. Type /lockport to show.", GetAddOnMetadata("LockPort", "Version"), GetAddOnMetadata("LockPort", "Author")))
	this:RegisterEvent("VARIABLES_LOADED")
	this:RegisterEvent("CHAT_MSG_ADDON")
	this:RegisterEvent("CHAT_MSG_RAID")
	this:RegisterEvent("CHAT_MSG_RAID_LEADER")
	this:RegisterEvent("CHAT_MSG_SAY")
	this:RegisterEvent("CHAT_MSG_YELL")
	this:RegisterEvent("CHAT_MSG_WHISPER")
	-- Commands
	SlashCmdList["LockPort"] = LockPort_SlashCommand
	SLASH_LockPort1 = "/lockport"
	MSG_PREFIX_ADD		= "RSAdd"
	MSG_PREFIX_REMOVE	= "RSRemove"
	LockPortDB = {}
	-- Sync Summon Table between raiders ? (if in raid & raiders with unempty table)
	--localization
	LockPortLoc_Header = lockport_title
	LockPortLoc_Settings_Header = lockport_title.." Settings"
	LockPortLoc_Settings_Chat_Header = "|CFFB700B7C|CFFFF00FFh|CFFFF50FFa|CFFFF99FFt|CFFFFC4FF S|cffffffffett|rings"
end

function LockPort_EventFrame_OnEvent()
	if event == "VARIABLES_LOADED" then
		this:UnregisterEvent("VARIABLES_LOADED")
		LockPort_Initialize()
	elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_WHISPER" then
		-- if (string.find(arg1, "^123") and UnitClass("player")~=arg2) then
		if string.find(arg1, "^123") then
			-- DEFAULT_CHAT_FRAME:AddMessage("CHAT_MSG")
			SendAddonMessage(MSG_PREFIX_ADD, arg2, "RAID")
		end
	elseif event == "CHAT_MSG_ADDON" then
		if arg1 == MSG_PREFIX_ADD then
			-- DEFAULT_CHAT_FRAME:AddMessage("CHAT_MSG_ADDON - RSAdd : " .. arg2)
			if not LockPort_hasValue(LockPortDB, arg2) and UnitName("player")~=arg2 and UnitClass("player") == "Warlock" then
				table.insert(LockPortDB, arg2)
				LockPort_UpdateList()
				if LockPortOptions.sound then
					PlaySoundFile("Sound\\Creature\\Necromancer\\NecromancerReady1.wav")
				end
			end
		elseif arg1 == MSG_PREFIX_REMOVE then
			if LockPort_hasValue(LockPortDB, arg2) then
				-- DEFAULT_CHAT_FRAME:AddMessage("CHAT_MSG_ADDON - RSRemove : " .. arg2)
				for i, v in ipairs (LockPortDB) do
					if v == arg2 then
						table.remove(LockPortDB, i)
						LockPort_UpdateList()
					end
				end
			end
		end
	end
end

function LockPort_hasValue (tab, val)
    for i, v in ipairs (tab) do
        if v == val then
            return true
        end
    end
    return false
end

--GUI
function LockPort_DoSummon(name,button)
	local message, base_message, whisper_message, base_whisper_message, whisper_eviltwin_message, zone_message, subzone_message = ""
	local bag,slot,texture,count = FindItem("Soul Shard")
	local eviltwin_debuff = "Spell_Shadow_Charm"
	local has_eviltwin = false

	if button  == "LeftButton" and IsControlKeyDown() then
		LockPort_GetRaidMembers()
		if LockPort_UnitIDDB then
			for i, v in ipairs (LockPort_UnitIDDB) do
				if v.rName == name then
					UnitID = "raid"..v.rIndex
				end
			end
			if UnitID then
				TargetUnit(UnitID)
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." : no raid found")
		end
	elseif button == "LeftButton" and not IsControlKeyDown() then
		LockPort_GetRaidMembers()
		if LockPort_UnitIDDB then
			for i, v in ipairs (LockPort_UnitIDDB) do
				if v.rName == name then
					UnitID = "raid"..v.rIndex
				end
			end
			if UnitID then
				playercombat = UnitAffectingCombat("player")
				targetcombat = UnitAffectingCombat(UnitID)
			
				if not playercombat and not targetcombat then
					count = count-1
					base_message 			= "Summoning " .. name .. ""
					base_whisper_message    = "Summoning you"
					zone_message            = " to " .. GetZoneText()
					subzone_message         = " - " .. GetSubZoneText()
					shards_message          = " [" .. count .. " shards left]"
					message                 = base_message
					whisper_message         = base_whisper_message

					-- Evil Twin check
					for i=1,16 do
						s=UnitDebuff("target", i)
						if(s) then
							if (strfind(strlower(s), strlower(eviltwin_debuff))) then
						        has_eviltwin = true
							end
						end
					end

					TargetUnit(UnitID)

					if (Check_TargetInRange()) then
						DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." : <" .. name .. "> has been summoned already (|cffff0000in range|r)")
						-- Remove the already summoned target
						for i, v in ipairs (LockPortDB) do
							if v == name then
						    	SendAddonMessage(MSG_PREFIX_REMOVE, name, "RAID")
						    	table.remove(LockPortDB, i)
						    	LockPort_UpdateList()
						    end
						end
					else
						-- TODO: Detect if spell is aborted/cancelled : use SpellStopCasting if sit ("You must be standing to do that")
						CastSpellByName("Ritual of Summoning")

						-- Send Raid Message
						if LockPortOptions.zone then
							if GetSubZoneText() == "" then
						    	message         = message .. zone_message
						    	whisper_message = base_whisper_message .. zone_message
							else
						    	message         = message .. zone_message .. subzone_message
						    	whisper_message = whisper_message .. zone_message .. subzone_message
							end
						end
						if LockPortOptions.shards then
					    	message = message .. shards_message
						end
						SendChatMessage(message, "SAY")

						-- Send Whisper Message
						if LockPortOptions.whisper then
							SendChatMessage(whisper_message, "WHISPER", nil, name)
						end

						-- Remove the summoned target
						for i, v in ipairs (LockPortDB) do
							if v == name then
						    	SendAddonMessage(MSG_PREFIX_REMOVE, name, "RAID")
						    	table.remove(LockPortDB, i)
						    	LockPort_UpdateList()
						    end
						end
					end
				else
					DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." : Player is in combat")
				end
			else
				DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." : <" .. tostring(name) .. "> not found in raid. UnitID: " .. tostring(UnitID))
				SendAddonMessage(MSG_PREFIX_REMOVE, name, "RAID")
				LockPort_UpdateList()
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." : no raid found")
		end
	elseif button == "RightButton" then
		for i, v in ipairs (LockPortDB) do
			if v == name then
				SendAddonMessage(MSG_PREFIX_REMOVE, name, "RAID")
				table.remove(LockPortDB, i)
				LockPort_UpdateList()
			end
		end
	end
	LockPort_UpdateList()
end

function LockPort_NameListButton_OnClick(mouse_button)
	local name = getglobal(this:GetName().."TextName"):GetText()
	LockPort_DoSummon(name,mouse_button)
end

function LockPort_DirectSummon()
	if next(LockPortDB) then
		LockPort_GetRaidMembers()
		if LockPort_UnitIDDB and next(LockPort_UnitIDDB) then
			LockPort_DoSummon(LockPort_UnitIDDB[1].rName,"LeftButton")
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." : no names in queue to summon")
	end
end

function LockPort_UpdateList()
	LockPort_BrowseDB = {}
	--only Update and show if Player is Warlock
	 if (UnitClass("player") == "Warlock") then
		--get raid member data
		local raidnum = GetNumRaidMembers()
		if (raidnum > 0) then
			for raidmember = 1, raidnum do
				local rName, rRank, rSubgroup, rLevel, rClass = GetRaidRosterInfo(raidmember)
				--check raid data for LockPort data
				for i, v in ipairs (LockPortDB) do 
					--if player is found fill BrowseDB
					if v == rName then
						LockPort_BrowseDB[i] = {}
						LockPort_BrowseDB[i].rName = rName
						LockPort_BrowseDB[i].rClass = rClass
						LockPort_BrowseDB[i].rIndex = i
						if rClass == "Warlock" or rName == "Bennylava" then
							LockPort_BrowseDB[i].rVIP = true
						else
							LockPort_BrowseDB[i].rVIP = false
						end
					end
				end
			end

			--sort warlocks first
			table.sort(LockPort_BrowseDB, function(a,b) return tostring(a.rVIP) > tostring(b.rVIP) end)
		end
		
		for i=1,10 do
			if LockPort_BrowseDB[i] then
				getglobal("LockPort_NameList"..i.."TextName"):SetText(LockPort_BrowseDB[i].rName)

				-- set class color
				local class = string.upper(LockPort_BrowseDB[i].rClass)
				local c = LockPort_GetClassColour(class)
				getglobal("LockPort_NameList"..i.."TextName"):SetTextColor(c.r, c.g, c.b, 1)				

				getglobal("LockPort_NameList"..i):Show()
			else
				getglobal("LockPort_NameList"..i):Hide()
			end
		end
		
		if not LockPortDB[1] then
			if LockPort_RequestFrame:IsVisible() then
				LockPort_RequestFrame:Hide()
			end
		else
			ShowUIPanel(LockPort_RequestFrame, 1)
		end
	end	
end

--Slash Handler

function LockPort_SlashCommand(msg)
	if msg == "help" then
		DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." usage:")
		DEFAULT_CHAT_FRAME:AddMessage("/lockport { help  | summon | show | zone | whisper | shards | settings | sound }")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9help|r: prints out this help")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9summon|r: summons the next player")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9show|r: shows the current summon list")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9zone|r: toggles zoneinfo")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9whisper|r: toggles the usage of /w")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9shards|r: toggles shards count when you summon")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9settings|r: shows the settings window")
		DEFAULT_CHAT_FRAME:AddMessage(" - |cff9482c9sound|r: toggles sound on summon request")
		DEFAULT_CHAT_FRAME:AddMessage("To drag the frame use left mouse button")
	elseif msg == "summon" then
		LockPort_DirectSummon()
	elseif msg == "show" then
		for i, v in ipairs(LockPortDB) do
			DEFAULT_CHAT_FRAME:AddMessage(tostring(v))
		end
	elseif msg == "zone" then
		ZoneCheckButton:Click()
	elseif msg == "whisper" then
		WhisperCheckButton:Click()
	elseif msg == "shards" then
		ShardsCheckButton:Click()
	elseif msg == "sound" then
		SoundCheckButton:Click()
	elseif msg == "settings" then
		LockPort_Settings_Toggle()
	else
		LockPort_RequestFrame_Toggle()
	end
end

--class color
function LockPort_GetClassColour(class)
	if (class) then
		local color = RAID_CLASS_COLORS[class]
		if (color) then
			return color
		end
	end
	return {r = 0.5, g = 0.5, b = 1}
end

--raid member
function LockPort_GetRaidMembers()
    local raidnum = GetNumRaidMembers()
    if (raidnum > 0) then
		LockPort_UnitIDDB = {}
		for i = 1, raidnum do
		    local rName, rRank, rSubgroup, rLevel, rClass = GetRaidRosterInfo(i)
			LockPort_UnitIDDB[i] = {}
			if (not rName) then 
			    rName = "unknown"..i
			end
			LockPort_UnitIDDB[i].rName    = rName
			LockPort_UnitIDDB[i].rClass   = rClass
			LockPort_UnitIDDB[i].rIndex   = i
	    end
	end
end

function FindItem(item)
	if (not item) then return end
	item = string.lower(ItemLinkToName(item))
	local link
	local count, bag, slot, texture
	local totalcount = 0
	for i = 0,NUM_BAG_FRAMES do
       for j = 1,MAX_CONTAINER_ITEMS do
           link = GetContainerItemLink(i,j)
           if (link) then
               if (item == string.lower(ItemLinkToName(link))) then
	               bag, slot = i, j
	               texture, count = GetContainerItemInfo(i,j)
	               totalcount = totalcount + count
               end
           end
       end
	end
	return bag, slot, texture, totalcount
end

function ItemLinkToName(link)
	if ( link ) then
   	return gsub(link,"^.*%[(.*)%].*$","%1");
	end
end

-- Checks if the target is in range (28 yards)
function Check_TargetInRange()
   if not (GetUnitName("target")==nil) then
       local t = UnitName("target")
       if (CheckInteractDistance("target", 4)) then
           return true
       else
           return false
       end
   end
end

-- Settings Window
function LockPort_Settings_Toggle()
	if LockPort_SettingsFrame:IsVisible() then
		LockPort_SettingsFrame:Hide()
	else
		LockPort_SettingsFrame:Show()
	end
end

function LockPort_RequestFrame_Toggle(frame)
	if LockPort_RequestFrame:IsVisible() then
		LockPort_RequestFrame:Hide()
	else
		LockPort_UpdateList()
		ShowUIPanel(LockPort_RequestFrame, 1)
	end
end

local function boolean(bool)
	return bool and true or false
end

local function enabled_disabled(bool)
	return (bool and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
end

function WhisperCheckButton_OnClick()
	LockPortOptions["whisper"] = boolean(WhisperCheckButton:GetChecked())
	DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." - whisper: "..enabled_disabled(LockPortOptions["whisper"]))
end

function ZoneCheckButton_OnClick()
		LockPortOptions["zone"] = boolean(ZoneCheckButton:GetChecked())
		DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." - zoneinfo: "..enabled_disabled(LockPortOptions["zone"]))
end

function ShardsCheckButton_OnClick()
	LockPortOptions["shards"] = boolean(ShardsCheckButton:GetChecked())
	DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." - shards: "..enabled_disabled(LockPortOptions["shards"]))
end

function SoundCheckButton_OnClick()
	LockPortOptions["sound"] = boolean(SoundCheckButton:GetChecked())
	DEFAULT_CHAT_FRAME:AddMessage(lockport_title.." - sound: "..enabled_disabled(LockPortOptions["sound"]))
end

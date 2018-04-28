--[[
	Handles showing and interacting with the options window.
--]]

----------------------------------------------------------------------------------------------------
-- the window
----------------------------------------------------------------------------------------------------
DrumRotationInfo.optionFrame = CreateFrame("frame", "SSD_optionFrame", UIParent)
local optionFrame = DrumRotationInfo.optionFrame

table.insert(UISpecialFrames, optionFrame:GetName()) -- make it closable with escape key
optionFrame:Hide()
optionFrame:SetFrameStrata("HIGH")
optionFrame:SetBackdrop({
	bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
	tile=1, tileSize=32, edgeSize=32,
	insets={left=11, right=12, top=12, bottom=11}
})
optionFrame:SetBackdropColor(0,0,0,1)
optionFrame:SetPoint("CENTER")
optionFrame:SetWidth(540)
optionFrame:SetHeight(393)

--------------------------------------------------
-- make it draggable
--------------------------------------------------
optionFrame:SetMovable(true)
optionFrame:EnableMouse(true)
optionFrame:RegisterForDrag("LeftButton")
optionFrame:SetScript("OnDragStart", optionFrame.StartMoving)
optionFrame:SetScript("OnDragStop", optionFrame.StopMovingOrSizing)
optionFrame:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" and not self.isMoving then
		self:StartMoving()
		self.isMoving = true
	end
end)
optionFrame:SetScript("OnMouseUp", function(self, button)
	if button == "LeftButton" and self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end)
optionFrame:SetScript("OnHide", function(self)
	if self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end)

--------------------------------------------------
-- header title
--------------------------------------------------
local textureHeader = optionFrame:CreateTexture(nil, "ARTWORK")
textureHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
textureHeader:SetWidth(315)
textureHeader:SetHeight(64)
textureHeader:SetPoint("TOP", 0, 12)
local textHeader = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textHeader:SetPoint("TOP", textureHeader, "TOP", 0, -14)
textHeader:SetText("Drum Rotation 2." .. DrumRotationInfo.minorVersion)

--------------------------------------------------
-- close button
--------------------------------------------------
local buttonClose = CreateFrame("Button", "SSD_buttonClose", optionFrame, "UIPanelCloseButton")
buttonClose:SetPoint("TOPRIGHT", optionFrame, "TOPRIGHT", -8, -8)

----------------------------------------------------------------------------------------------------
-- alerting options
----------------------------------------------------------------------------------------------------
local headerAlert = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
headerAlert:SetPoint("TOPLEFT", optionFrame, "TOPLEFT", 16, -36)
headerAlert:SetText("When it's your turn:")

-- alert time
local checkboxAlertBefore = CreateFrame("CheckButton", "SSD_checkboxAlertBefore", optionFrame, "UICheckButtonTemplate")
checkboxAlertBefore:SetPoint("TOPLEFT", headerAlert, "BOTTOMLEFT", 0, -3)
_G[checkboxAlertBefore:GetName().."Text"]:SetText("Alert approximately this many seconds before your turn:")
checkboxAlertBefore:SetScript("OnClick", function()
	DrumRotationSave.alertBefore = this:GetChecked() or false
end)

local inputAlertBefore = CreateFrame("EditBox", "SSD_inputAlertBefore", optionFrame, "InputBoxTemplate")
inputAlertBefore:SetWidth(22)
inputAlertBefore:SetHeight(14)
inputAlertBefore:SetNumeric(true)
inputAlertBefore:SetMaxLetters(2)
inputAlertBefore:SetPoint("LEFT", _G[checkboxAlertBefore:GetName().."Text"], "RIGHT", 8, 0)
inputAlertBefore:SetAutoFocus(false)
inputAlertBefore:SetScript("OnEnterPressed", function() this:ClearFocus() end)
inputAlertBefore:SetScript("OnEditFocusLost", function()
	DrumRotationSave.alertBeforeTime = tonumber(this:GetText())
	if not DrumRotationSave.alertBeforeTime then
		DrumRotationSave.alertBeforeTime = 0
		this:SetText(0)
	elseif DrumRotationSave.alertBeforeTime > 30 then
		DrumRotationSave.alertBeforeTime = 30
		this:SetText(30)
	end
	DrumRotationInfo:UpdateNextEventTime()
end)

-- raid warning message
local checkboxAlertRaidWarning = CreateFrame("CheckButton", "SSD_checkboxAlertRaidWarning", optionFrame, "UICheckButtonTemplate")
checkboxAlertRaidWarning:SetPoint("TOPLEFT", checkboxAlertBefore, "BOTTOMLEFT", 0, 7)
_G[checkboxAlertRaidWarning:GetName().."Text"]:SetText("Show message in the raid warning area.")
checkboxAlertRaidWarning:SetScript("OnClick", function()
	DrumRotationSave.alertMessage = this:GetChecked() or false
end)

-- show icon
local checkboxAlertIcon = CreateFrame("CheckButton", "SSD_checkboxAlertIcon", optionFrame, "UICheckButtonTemplate")
checkboxAlertIcon:SetPoint("TOPLEFT", checkboxAlertRaidWarning, "BOTTOMLEFT", 0, 7)
_G[checkboxAlertIcon:GetName().."Text"]:SetText("Show icon")
checkboxAlertIcon:SetScript("OnClick", function()
	DrumRotationSave.alertIcon = this:GetChecked() or false
end)

local inputAlertIconSize = CreateFrame("EditBox", "SSD_inputAlertIconSize", optionFrame, "InputBoxTemplate")
inputAlertIconSize:SetWidth(28)
inputAlertIconSize:SetHeight(16)
inputAlertIconSize:SetNumeric(true)
inputAlertIconSize:SetMaxLetters(3)
inputAlertIconSize:SetPoint("LEFT", _G[checkboxAlertIcon:GetName().."Text"], "RIGHT", 8, 0)
inputAlertIconSize:SetAutoFocus(false)
inputAlertIconSize:SetScript("OnEnterPressed", function() this:ClearFocus() end)
inputAlertIconSize:SetScript("OnEditFocusLost", function()
	DrumRotationSave.alertIconSize = tonumber(this:GetText())
	if not DrumRotationSave.alertIconSize then
		DrumRotationSave.alertIconSize = 32
		this:SetText(DrumRotationSave.alertIconSize)
	elseif DrumRotationSave.alertIconSize < 8 then
		DrumRotationSave.alertIconSize = 8
		this:SetText(DrumRotationSave.alertIconSize)
	end
	if DrumRotationInfo.alertIconFrame:IsVisible() then
		DrumRotationInfo.alertIconFrame:SetWidth(DrumRotationSave.alertIconSize)
		DrumRotationInfo.alertIconFrame:SetHeight(DrumRotationSave.alertIconSize)
	end
end)

local textAlertIcon = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textAlertIcon:SetPoint("LEFT", inputAlertIconSize, "RIGHT", 2, 0)
textAlertIcon:SetText("pixels large for this many seconds:")

local inputAlertIconDuration = CreateFrame("EditBox", "SSD_inputAlertIconDuration", optionFrame, "InputBoxTemplate")
inputAlertIconDuration:SetWidth(28)
inputAlertIconDuration:SetHeight(14)
inputAlertIconDuration:SetNumeric(true)
inputAlertIconDuration:SetMaxLetters(3)
inputAlertIconDuration:SetPoint("LEFT", textAlertIcon, "RIGHT", 8, 0)
inputAlertIconDuration:SetAutoFocus(false)
inputAlertIconDuration:SetScript("OnEnterPressed", function() this:ClearFocus() end)
inputAlertIconDuration:SetScript("OnEditFocusLost", function()
	DrumRotationSave.alertIconDuration = tonumber(this:GetText())
	if not DrumRotationSave.alertIconDuration then
		DrumRotationSave.alertIconDuration = 0
		this:SetText(0)
	end
end)

-- show bar
local checkboxAlertBar = CreateFrame("CheckButton", "SSD_checkboxAlertBar", optionFrame, "UICheckButtonTemplate")
checkboxAlertBar:SetPoint("TOPLEFT", checkboxAlertIcon, "BOTTOMLEFT", 0, 7)
_G[checkboxAlertBar:GetName().."Text"]:SetText("Show bar")
checkboxAlertBar:SetScript("OnClick", function()
	DrumRotationSave.alertBar = this:GetChecked() or false
end)

local inputAlertBarPosition = CreateFrame("EditBox", "SSD_inputAlertBarPosition", optionFrame, "InputBoxTemplate")
inputAlertBarPosition:SetWidth(36)
inputAlertBarPosition:SetHeight(14)
inputAlertBarPosition:SetNumeric(true)
inputAlertBarPosition:SetMaxLetters(4)
inputAlertBarPosition:SetPoint("LEFT", _G[checkboxAlertBar:GetName().."Text"], "RIGHT", 8, 0)
inputAlertBarPosition:SetAutoFocus(false)
inputAlertBarPosition:SetScript("OnEnterPressed", function() this:ClearFocus() end)
inputAlertBarPosition:SetScript("OnEditFocusLost", function()
	DrumRotationSave.alertBarPosition = tonumber(this:GetText())
	if not DrumRotationSave.alertBarPosition then
		DrumRotationSave.alertBarPosition = 0
		this:SetText(0)
	end
	if DrumRotationInfo.alertBarFrame:IsVisible() then
		DrumRotationInfo.alertBarFrame:SetPoint("TOP", UIParent, "TOP", 0, DrumRotationSave.alertBarPosition * -1)
	end
end)

local textAlertBar = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textAlertBar:SetPoint("LEFT", inputAlertBarPosition, "RIGHT", 2, 0)
textAlertBar:SetText("pixels from top for this many seconds:")

local inputAlertBarDuration = CreateFrame("EditBox", "SSD_inputAlertBarDuration", optionFrame, "InputBoxTemplate")
inputAlertBarDuration:SetWidth(28)
inputAlertBarDuration:SetHeight(14)
inputAlertBarDuration:SetNumeric(true)
inputAlertBarDuration:SetMaxLetters(3)
inputAlertBarDuration:SetPoint("LEFT", textAlertBar, "RIGHT", 8, 0)
inputAlertBarDuration:SetAutoFocus(false)
inputAlertBarDuration:SetScript("OnEnterPressed", function() this:ClearFocus() end)
inputAlertBarDuration:SetScript("OnEditFocusLost", function()
	DrumRotationSave.alertBarDuration = tonumber(this:GetText())
	if not DrumRotationSave.alertBarDuration then
		DrumRotationSave.alertBarDuration = 0
		this:SetText(0)
	end
end)

-- be whispered by previous drummer
local checkboxAlertWhisper = CreateFrame("CheckButton", "SSD_checkboxAlertWhisper", optionFrame, "UICheckButtonTemplate")
checkboxAlertWhisper:SetPoint("TOPLEFT", checkboxAlertBar, "BOTTOMLEFT", 0, 7)
_G[checkboxAlertWhisper:GetName().."Text"]:SetText("Be whispered by previous drummer if they have the addon.")
checkboxAlertWhisper:SetScript("OnClick", function()
	DrumRotationSave.alertWhisper = this:GetChecked() or false
	if DrumRotationSave.drummers[UnitName("player")] then
		DrumRotationSave.drummers[UnitName("player")].alertWhisper = DrumRotationSave.alertWhisper and true or false
	end
	SendAddonMessage("SSDRUM", "NFO alertWhisper=" .. (DrumRotationSave.alertWhisper and "1" or "0"), "RAID")
end)

-- play sound
local checkboxAlertPlaySound = CreateFrame("CheckButton", "SSD_checkboxAlertPlaySound", optionFrame, "UICheckButtonTemplate")
checkboxAlertPlaySound:SetPoint("TOPLEFT", checkboxAlertWhisper, "BOTTOMLEFT", 0, 7)
_G[checkboxAlertPlaySound:GetName().."Text"]:SetText("Play sound:")
checkboxAlertPlaySound:SetScript("OnClick", function()
	DrumRotationSave.alertPlaySound = this:GetChecked() or false
end)

local inputAlertSound = CreateFrame("EditBox", "SSD_inputAlertSound", optionFrame, "InputBoxTemplate")
inputAlertSound:SetWidth(264)
inputAlertSound:SetHeight(14)
inputAlertSound:SetPoint("LEFT", _G[checkboxAlertPlaySound:GetName().."Text"], "RIGHT", 8, 0)
inputAlertSound:SetAutoFocus(false)
inputAlertSound:SetScript("OnEnterPressed", function() this:ClearFocus() end)
inputAlertSound:SetScript("OnEditFocusLost", function()
	DrumRotationSave.alertSoundFile = this:GetText()
end)

-- test alerts
local buttonAlertTest = CreateFrame("Button", "SSD_buttonAlertTest", optionFrame, "UIPanelButtonTemplate")
buttonAlertTest:SetWidth(100)
buttonAlertTest:SetHeight(22)
buttonAlertTest:SetPoint("TOPLEFT", checkboxAlertPlaySound, "BOTTOMLEFT", 0, 0)
_G[buttonAlertTest:GetName().."Text"]:SetText("Test Alerts")
buttonAlertTest:SetScript("OnClick", function()
	-- clear focus first to save settings if needed
	if GetCurrentKeyBoardFocus() then
		GetCurrentKeyBoardFocus():ClearFocus()
	end

	if DrumRotationSave.alertMessage then
		RaidNotice_AddMessage(RaidWarningFrame, "Use Drums of Battle Test!", ChatTypeInfo["RAID_WARNING"])
	end
	if DrumRotationSave.alertBar then
		DrumRotationInfo.alertBarFrame:ShowBar(5, true)
	end
	if DrumRotationSave.alertIcon then
		DrumRotationInfo.alertIconFrame:ShowIcon(5, false, true)
	end
	if DrumRotationSave.alertPlaySound then
		if DrumRotationSave.alertSoundFile:find("/") or DrumRotationSave.alertSoundFile:find("\\") then
			PlaySoundFile(DrumRotationSave.alertSoundFile:gsub("\\\\","\\"))
		else
			PlaySound(DrumRotationSave.alertSoundFile)
		end
	end
end)

local textTest = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textTest:SetPoint("LEFT", buttonAlertTest, "RIGHT", 4, 0)
textTest:SetText("(you can drag the icon when testing)")

----------------------------------------------------------------------------------------------------
-- Miscellaneous options
----------------------------------------------------------------------------------------------------
local headerMiscellaneous = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
headerMiscellaneous:SetPoint("TOP", buttonAlertTest, "BOTTOM", 0, -20)
headerMiscellaneous:SetPoint("LEFT", optionFrame, "LEFT", 16, 0)
headerMiscellaneous:SetText("Miscellaneous:")

-- try to be first drummer
local checkboxMiscFirstDrummer = CreateFrame("CheckButton", "SSD_checkboxMiscFirstDrummer", optionFrame, "UICheckButtonTemplate")
checkboxMiscFirstDrummer:SetPoint("TOPLEFT", headerMiscellaneous, "BOTTOMLEFT", 0, -3)
_G[checkboxMiscFirstDrummer:GetName().."Text"]:SetText("Prefer drumming first or near the beginning.")
checkboxMiscFirstDrummer:SetScript("OnClick", function()
	DrumRotationSave.preferFirst = this:GetChecked() or false
	if DrumRotationSave.drummers[UnitName("player")] then
		DrumRotationSave.drummers[UnitName("player")].preferFirst = DrumRotationSave.preferFirst and true or false
	end
	SendAddonMessage("SSDRUM", "NFO preferFirst=" .. (DrumRotationSave.preferFirst and "1" or "0"), "RAID")
end)

-- try to be drums of war user
local checkboxMiscPreferWar = CreateFrame("CheckButton", "SSD_checkboxMiscPreferWar", optionFrame, "UICheckButtonTemplate")
checkboxMiscPreferWar:SetPoint("TOPLEFT", checkboxMiscFirstDrummer, "BOTTOMLEFT", 0, 7)
_G[checkboxMiscPreferWar:GetName().."Text"]:SetText("Prefer to be the group's only Drums of War drummer.")
checkboxMiscPreferWar:SetScript("OnClick", function()
	DrumRotationSave.preferWar = this:GetChecked() or false
	if DrumRotationSave.drummers[UnitName("player")] then
		DrumRotationSave.drummers[UnitName("player")].preferWar = DrumRotationSave.preferWar and true or false
	end
	SendAddonMessage("SSDRUM", "NFO preferWar=" .. (DrumRotationSave.preferWar and "1" or "0"), "RAID")
end)

-- always be a drums of war user
local checkboxMiscAlwaysWar = CreateFrame("CheckButton", "SSD_checkboxMiscAlwaysWar", optionFrame, "UICheckButtonTemplate")
checkboxMiscAlwaysWar:SetPoint("TOPLEFT", checkboxMiscPreferWar, "BOTTOMLEFT", 0, 7)
_G[checkboxMiscAlwaysWar:GetName().."Text"]:SetText("Always use Drums of War if you have them.")
checkboxMiscAlwaysWar:SetScript("OnClick", function()
	DrumRotationSave.alwaysWar = this:GetChecked() or false
	if DrumRotationSave.drummers[UnitName("player")] then
		DrumRotationSave.drummers[UnitName("player")].alwaysWar = DrumRotationSave.alwaysWar and true or false
	end
	SendAddonMessage("SSDRUM", "NFO alwaysWar=" .. (DrumRotationSave.alwaysWar and "1" or "0"), "RAID")
end)

function optionFrame:UpdateAlwaysWar()
	checkboxMiscAlwaysWar:SetChecked(DrumRotationSave.alwaysWar)
end

-- allow drummer additions and removals from other people
local checkboxMiscAllowEdits = CreateFrame("CheckButton", "SSD_checkboxMiscAllowEdits", optionFrame, "UICheckButtonTemplate")
checkboxMiscAllowEdits:SetPoint("TOPLEFT", checkboxMiscAlwaysWar, "BOTTOMLEFT", 0, 7)
_G[checkboxMiscAllowEdits:GetName().."Text"]:SetText("Allow group members to modify known drummers.")
checkboxMiscAllowEdits:SetScript("OnClick", function()
	DrumRotationSave.allowEdits = this:GetChecked() or false
end)

----------------------------------------------------------------------------------------------------
-- known drummer list
----------------------------------------------------------------------------------------------------
local headerDrummers = optionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
headerDrummers:SetPoint("TOP", headerAlert, "TOP", 0, 0)
headerDrummers:SetPoint("LEFT", optionFrame, "RIGHT", -158, 0)
headerDrummers:SetText("Drummers:")

--------------------------------------------------
-- scrollable editbox
--------------------------------------------------
local editboxDrummers = CreateFrame("Frame", "SSD_editboxDrummers", optionFrame)
editboxDrummers:SetWidth(124)
editboxDrummers:SetHeight(headerDrummers:GetBottom()-checkboxMiscAllowEdits:GetBottom()-10)
editboxDrummers:SetPoint("TOPLEFT", headerDrummers, "BOTTOMLEFT", 3, -3)
editboxDrummers:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
	tile=1, tileSize=32, edgeSize=16,
	insets={left=5, right=5, top=5, bottom=5}})
editboxDrummers:SetBackdropColor(0,0,0,1)
editboxDrummersInput = CreateFrame("EditBox", "SSD_editboxDrummersInput", editboxDrummers)
editboxDrummersInput:SetMultiLine(true)
editboxDrummersInput:SetAutoFocus(false)
editboxDrummersInput:EnableMouse(true)
editboxDrummersInput:SetFont("Fonts/ARIALN.ttf", 15)
editboxDrummersInput:SetWidth(editboxDrummers:GetWidth()-20)
editboxDrummersInput:SetHeight(editboxDrummers:GetHeight()-8)
editboxDrummersInput:SetScript("OnEscapePressed", function() editboxDrummersInput:ClearFocus() end)

local editboxDrummersScroll = CreateFrame("ScrollFrame", "SSD_editboxDrummersScroll", editboxDrummers, "UIPanelScrollFrameTemplate")
editboxDrummersScroll:SetPoint("TOPLEFT", editboxDrummers, "TOPLEFT", 6, -6)
editboxDrummersScroll:SetPoint("BOTTOMRIGHT", editboxDrummers, "BOTTOMRIGHT", -7, 5)
editboxDrummersScroll:EnableMouse(true)
editboxDrummersScroll:SetScript("OnMouseDown", function() editboxDrummersInput:SetFocus() end)
editboxDrummersScroll:SetScrollChild(editboxDrummersInput)

-- taken from Blizzard's macro UI XML to handle scrolling
editboxDrummersInput:SetScript("OnTextChanged", function()
	local scrollbar = _G[editboxDrummersScroll:GetName().."ScrollBar"]
	local min, max = scrollbar:GetMinMaxValues()
	if max > 0 and this.max ~= max then
	this.max = max
	scrollbar:SetValue(max)
	end
end)
editboxDrummersInput:SetScript("OnUpdate", function(this) ScrollingEdit_OnUpdate(editboxDrummersScroll) end)
editboxDrummersInput:SetScript("OnCursorChanged", function() ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4) end)

--------------------------------------------------
-- set the edit box with the drummers
--------------------------------------------------
function optionFrame:SetDrummerList()
	-- sorting names alphabetically
	local alphabetical = {}
	local inserted
	for name in pairs(DrumRotationSave.drummers) do
		inserted = false
		for i=1,#alphabetical do
			if name < alphabetical[i] then
				table.insert(alphabetical, i, name)
				inserted = true
				break
			end
		end
		if not inserted then
			table.insert(alphabetical, name)
		end
	end
	table.insert(alphabetical, "") -- empty line at the end (or blank space if there are no names)

	-- if there's only the first blank line in the list then don't insert a new line after it
	editboxDrummersInput:SetText(table.concat(alphabetical, "\n"))
end

--------------------------------------------------
-- save any new drummers
--------------------------------------------------
editboxDrummersInput:SetScript("OnEditFocusLost", function()
	-- add new names and update a temporary ID on old ones to show they should be kept
	local current_id = GetTime()
	for name in this:GetText():gmatch("[^%s]+") do
		if not DrumRotationSave.drummers[name] then
			-- capitalize it before adding it
			name = (name:gsub("(%a)(%w*)", function(first,rest) return first:upper()..rest:lower() end))
			DrumRotationInfo:AddDrummer(name, true, true)
		end
		DrumRotationSave.drummers[name].temp_id = current_id
	end

	-- go through all names to remove those without the current ID
	for name,info in pairs(DrumRotationSave.drummers) do
		if not info.temp_id or info.temp_id ~= current_id then
			DrumRotationInfo:RemoveDrummer(name, true)
		else
			info.temp_id = nil
		end
	end

	optionFrame:SetDrummerList()
end)

----------------------------------------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------------------------------------
optionFrame:SetScript("OnShow", function()
	if not DrumRotationSave then
		this:Hide()
		return
	end

	checkboxAlertBefore:SetChecked(DrumRotationSave.alertBefore)
	inputAlertBefore:SetText(DrumRotationSave.alertBeforeTime)

	checkboxAlertRaidWarning:SetChecked(DrumRotationSave.alertMessage)

	checkboxAlertIcon:SetChecked(DrumRotationSave.alertIcon)
	inputAlertIconSize:SetText(DrumRotationSave.alertIconSize)
	inputAlertIconDuration:SetText(DrumRotationSave.alertIconDuration)

	checkboxAlertBar:SetChecked(DrumRotationSave.alertBar)
	inputAlertBarPosition:SetText(DrumRotationSave.alertBarPosition)
	inputAlertBarDuration:SetText(DrumRotationSave.alertBarDuration)

	checkboxAlertPlaySound:SetChecked(DrumRotationSave.alertPlaySound)
	inputAlertSound:SetText(DrumRotationSave.alertSoundFile)

	checkboxMiscFirstDrummer:SetChecked(DrumRotationSave.preferFirst)
	checkboxMiscPreferWar:SetChecked(DrumRotationSave.preferWar)
	checkboxMiscAlwaysWar:SetChecked(DrumRotationSave.alwaysWar)
	checkboxMiscAllowEdits:SetChecked(DrumRotationSave.allowEdits)

	optionFrame:SetDrummerList()
end)

--[[
	Handles showing a hopefully noticeable colored bar to make someone aware they should use drums.
--]]

----------------------------------------------------------------------------------------------------
-- Alert bar window
----------------------------------------------------------------------------------------------------
DrumRotationInfo.alertBarFrame = CreateFrame("frame", "SSD_alertBarFrame", UIParent)
local alertBarFrame = DrumRotationInfo.alertBarFrame
alertBarFrame:Hide()
alertBarFrame:SetFrameStrata("BACKGROUND")
alertBarFrame:SetHeight(30)

local textureBar = alertBarFrame:CreateTexture("BACKGROUND")
textureBar:SetAllPoints()
textureBar:SetTexture(1.0, 0.5, 0)
textureBar:SetAlpha(0.2)

local textBar1 = alertBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local textBar2 = alertBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
local textBar3 = alertBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
textBar1:SetPoint("LEFT", alertBarFrame, "LEFT", 150, 0)
textBar2:SetPoint("CENTER", alertBarFrame, "CENTER", 0, 0)
textBar3:SetPoint("RIGHT", alertBarFrame, "RIGHT", -150, 0)

----------------------------------------------------------------------------------------------------
-- Display update
----------------------------------------------------------------------------------------------------
local format        = string.format
local drumNextTime  = 0   -- seconds left until the player should use their drums
local hideTime      = 0   -- seconds left until the bar should be hidden
local totalElapsed  = 0   -- for keeping track of when to update the bar next
local drumType      = nil -- name of the type of drums to use, set up when showing the bar

alertBarFrame:SetScript("OnUpdate", function(self, elapsed)
	totalElapsed = totalElapsed + elapsed
	if totalElapsed > .1 then
		hideTime = hideTime - totalElapsed
		if hideTime <= 0 then
			alertBarFrame:Hide()
			return
		end
		drumNextTime = drumNextTime - totalElapsed
		totalElapsed = 0
		local text = drumNextTime <= 0 and (drumType .. " NOW") or format("%s %.1f", drumType, drumNextTime)
		textBar1:SetText(text)
		textBar2:SetText(text)
		textBar3:SetText(text)
	end
end)

----------------------------------------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------------------------------------
function DrumRotationInfo.alertBarFrame:ShowBar(time, use_battle)
	if not DrumRotationSave then
		self:Hide()
		return
	end

	drumNextTime = time
	hideTime = DrumRotationSave.alertBarDuration
	drumType = use_battle and "DRUMS OF BATTLE" or "DRUMS OF WAR"

	alertBarFrame:SetWidth(GetScreenWidth())
	alertBarFrame:SetPoint("TOP", UIParent, "TOP", 0, DrumRotationSave.alertBarPosition * -1)
	totalElapsed = 0
	alertBarFrame:Show()
end

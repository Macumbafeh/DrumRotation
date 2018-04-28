--[[
	Handle showing and moving the drumming icon that alerts someone that they should use drums.
--]]

----------------------------------------------------------------------------------------------------
-- Icon frame
----------------------------------------------------------------------------------------------------
local TEXTURE_DRUMS_OF_BATTLE = "Interface/ICONS/INV_Misc_Drum_02"
local TEXTURE_DRUMS_OF_WAR    = "Interface/ICONS/INV_Misc_Drum_03"

DrumRotationInfo.alertIconFrame = CreateFrame("frame", "SSD_alertIconFrame", UIParent)
local alertIconFrame = DrumRotationInfo.alertIconFrame
alertIconFrame:Hide()
alertIconFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

local iconTexture = alertIconFrame:CreateTexture("BACKGROUND")
iconTexture:SetAllPoints()
iconTexture:SetAlpha(0.5)

local iconText = alertIconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
iconText:SetFont("Fonts\\ARIALN.TTF", 64, "OUTLINE")
iconText:SetPoint("CENTER", iconText:GetParent(), "CENTER", 0, 0)

----------------------------------------------------------------------------------------------------
-- locking/unlocking
----------------------------------------------------------------------------------------------------
function DrumRotationInfo.alertIconFrame:SetLock(is_locked)
	if is_locked then
		alertIconFrame:SetMovable(false)
		alertIconFrame:EnableMouse(false)
		alertIconFrame:RegisterForDrag(nil)
		alertIconFrame:SetScript("OnDragStart", nil)
		alertIconFrame:SetScript("OnDragStop", nil)
		alertIconFrame:SetScript("OnMouseDown", nil)
		alertIconFrame:SetScript("OnMouseUp", nil)
		alertIconFrame:SetScript("OnHide", nil)
	else
		alertIconFrame:SetMovable(true)
		alertIconFrame:EnableMouse(true)
		alertIconFrame:RegisterForDrag("LeftButton")
		alertIconFrame:SetScript("OnDragStart", alertIconFrame.StartMoving)
		alertIconFrame:SetScript("OnDragStop", alertIconFrame.StopMovingOrSizing)
		alertIconFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" and not self.isMoving then
				self:StartMoving()
				self.isMoving = true
			end
		end)
		alertIconFrame:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" and self.isMoving then
				self:StopMovingOrSizing()
				self.isMoving = false
				local _
				DrumRotationSave.alertIconPosition.anchor1, _, DrumRotationSave.alertIconPosition.anchor2, DrumRotationSave.alertIconPosition.offsetX, DrumRotationSave.alertIconPosition.offsetY = self:GetPoint(1)
			end
		end)
		alertIconFrame:SetScript("OnHide", function(self)
			if self.isMoving then
				self:StopMovingOrSizing()
				self.isMoving = false
				local _
				DrumRotationSave.alertIconPosition.anchor1, _, DrumRotationSave.alertIconPosition.anchor2, DrumRotationSave.alertIconPosition.offsetX, DrumRotationSave.alertIconPosition.offsetY = self:GetPoint(1)
			end
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Display update
----------------------------------------------------------------------------------------------------
local drumNextTime = 0 -- seconds left until the player should use their drums
local hideTime     = 0 -- seconds left until the Icon should be hidden
local totalElapsed = 0 -- for keeping track of when to update the icon next

alertIconFrame:SetScript("OnUpdate", function(self, elapsed)
	totalElapsed = totalElapsed + elapsed
	if totalElapsed > .1 then
		hideTime = hideTime - totalElapsed
		if hideTime <= 0 then
			alertIconFrame:Hide()
			return
		end

		drumNextTime = drumNextTime - totalElapsed
		totalElapsed = 0
		if drumNextTime <= 0 then
			iconText:SetText("")
		else
			iconText:SetText(string.format("%.1f", drumNextTime))
		end
	end
end)

----------------------------------------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------------------------------------
function DrumRotationInfo.alertIconFrame:ShowIcon(time, lock, use_battle)
	if not DrumRotationSave then
		self:Hide()
		return
	end

	drumNextTime = time
	self:SetLock(lock)
	hideTime = DrumRotationSave.alertIconDuration

	alertIconFrame:ClearAllPoints()
	alertIconFrame:SetPoint(DrumRotationSave.alertIconPosition.anchor1, UIParent, DrumRotationSave.alertIconPosition.anchor2,
		DrumRotationSave.alertIconPosition.offsetX, DrumRotationSave.alertIconPosition.offsetY)
	alertIconFrame:SetWidth(DrumRotationSave.alertIconSize)
	alertIconFrame:SetHeight(DrumRotationSave.alertIconSize)
	iconText:SetTextHeight(DrumRotationSave.alertIconSize * .65)
	iconTexture:SetTexture(use_battle and TEXTURE_DRUMS_OF_BATTLE or TEXTURE_DRUMS_OF_WAR)

	totalElapsed = 0
	alertIconFrame:Show()
end

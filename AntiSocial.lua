-- Anti Social
-- The in-game half of the dungeon finder. It does two things:
--   1. Turns the code a group leader pastes from the companion app into party invites.
--   2. Saves a snapshot of your character (level, class, spec, item level) for the companion to read.
-- It cannot talk to the internet; the companion app does that.

local ADDON = ...
local NAME = "AntiSocial LFG"
local TAG = "|cffffd100" .. NAME .. "|r "

local db                 -- AntiSocialDB once saved variables are loaded
local frame              -- the /as window, built on first use
local current            -- the decoded group code being worked on
local quickPaste = false -- set by shift-clicking the minimap button: the next paste invites and closes the window

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function Print(msg)
	print(TAG .. msg)
end

-- Some values are hidden from addons inside instances; never touch those.
local function IsSecret(v)
	return type(issecretvalue) == "function" and issecretvalue(v)
end

local function Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-------------------------------------------------------------------------------
-- Group code:  AS1.<group>.<base64url payload>.<4 hex check>
-- The payload is text, one item per line: the instance name, then the names to invite.
-- The check is the sum of the payload's bytes modulo 65536.
-------------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_VALUE = {}
for i = 1, #B64 do B64_VALUE[B64:sub(i, i)] = i - 1 end

local function DecodeBase64Url(text)
	local out, acc, bits = {}, 0, 0
	for i = 1, #text do
		local v = B64_VALUE[text:sub(i, i)]
		if not v then return nil end
		acc = acc * 64 + v
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			local divisor = 2 ^ bits
			local byte = math.floor(acc / divisor)
			acc = acc - byte * divisor
			out[#out + 1] = string.char(byte)
		end
	end
	return table.concat(out)
end

-- Returns a table { group, instance, names } or nil plus a reason the player can act on.
local function ParseCode(text)
	text = Trim(text or "")
	if text == "" then return nil, "" end
	local prefix, group, payload, check = text:match("^(%w+)%.(%w+)%.([%w%-_]+)%.(%x%x%x%x)$")
	if not prefix then return nil, "That does not look like a group code." end
	if prefix ~= "AS1" then return nil, "This code needs a newer version of the addon." end

	local bytes = DecodeBase64Url(payload)
	if not bytes then return nil, "That code is damaged. Copy it again." end
	local sum = 0
	for i = 1, #bytes do sum = (sum + bytes:byte(i)) % 65536 end
	if string.format("%04x", sum) ~= check:lower() then
		return nil, "That code is damaged. Copy it again."
	end

	local lines = {}
	for line in (bytes .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
	local names = {}
	for i = 2, #lines do
		if lines[i] ~= "" then names[#names + 1] = lines[i] end
	end
	return { group = group, instance = lines[1] or "", names = names }
end

-------------------------------------------------------------------------------
-- Party
-------------------------------------------------------------------------------

-- A character's full name. Forever names have two parts, such as "Betty Dies": the game returns
-- the first part where the name usually is and the second part where a realm would usually be.
-- Returns nil when the name cannot be read (it can be hidden inside instances).
local function FullName(unit)
	local first, second = UnitName(unit)
	if not first or IsSecret(first) or first == "" then return nil end
	if second and not IsSecret(second) and second ~= "" then return first .. " " .. second end
	return first
end

-- Lower-cased full names of everyone currently in the party or raid, where readable.
local function PartyNames()
	local present = {}
	local function add(unit)
		local exists = UnitExists(unit)
		if IsSecret(exists) or not exists then return end
		local name = FullName(unit)
		if name then present[name:lower()] = true end
	end
	for i = 1, 4 do add("party" .. i) end
	for i = 1, 40 do add("raid" .. i) end
	return present
end

local function CanInvite()
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if IsSecret(n) then return true end
	if n == 0 then return true end
	local leader = UnitIsGroupLeader("player")
	if IsSecret(leader) then return true end
	return leader or (UnitIsGroupAssistant and UnitIsGroupAssistant("player")) or false
end

local Refresh -- defined with the window below

-- Updates who has joined. Returns how many are still missing.
local function UpdateJoined()
	if not current then return 0 end
	local present = PartyNames()
	local missing = 0
	for _, name in ipairs(current.names) do
		if present[name:lower()] then
			current.status[name] = "joined"
		else
			if current.status[name] == "joined" then current.status[name] = "left" end
			missing = missing + 1
		end
	end
	if db then
		local joined = {}
		for _, name in ipairs(current.names) do
			if current.status[name] == "joined" then joined[#joined + 1] = name end
		end
		db.lastGroup = { group = current.group, instance = current.instance, names = current.names, joined = joined, at = time() }
	end
	return missing
end

local function InviteMissing()
	if not current then return end
	if not CanInvite() then
		Print("Only the party leader can invite. Leave your current party or ask for lead first.")
		return
	end
	local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	if type(invite) ~= "function" then
		Print("This client does not let addons invite. Invite these players by hand: " .. table.concat(current.names, ", "))
		return
	end
	UpdateJoined()
	local sent = 0
	for _, name in ipairs(current.names) do
		if current.status[name] ~= "joined" then
			local ok = pcall(invite, name)
			if ok then
				current.status[name] = "invited"
				sent = sent + 1
			else
				current.status[name] = "failed"
			end
		end
	end
	if sent > 0 then
		Print("Invited " .. sent .. (sent == 1 and " player" or " players") .. " for " .. current.instance .. ".")
	else
		Print("Everyone on the list is already in your party.")
	end
	Refresh()
end

-- Takes pasted text. Returns true when it was a usable code.
local function LoadCode(text, fromPaste)
	local parsed, reason = ParseCode(text)
	if not parsed then
		current = nil
		Refresh(reason)
		return false
	end
	-- Temporary: the companion's "it works" test code. It proves the paste and decode path
	-- without inviting anyone.
	if parsed.group == "selftest" then
		current = nil
		quickPaste = false
		Print("test code received. The addon is working.")
		Refresh()
		if frame then frame.headline:SetText("|cff3fd06aTest code received. The addon is working.|r") end
		return true
	end
	if #parsed.names == 0 then
		current = nil
		Refresh("That code has nobody left to invite.")
		return false
	end
	parsed.status = {}
	for _, name in ipairs(parsed.names) do parsed.status[name] = "waiting" end
	current = parsed
	UpdateJoined()
	Refresh()
	if fromPaste and quickPaste then
		-- Shift-clicking the minimap button means "paste and go": invite, then get out of the way.
		quickPaste = false
		InviteMissing()
		if C_Timer and C_Timer.After then
			C_Timer.After(1.5, function() if frame and frame:IsShown() then frame:Hide() end end)
		end
	elseif fromPaste and db and db.autoInvite then
		InviteMissing()
	end
	return true
end

-------------------------------------------------------------------------------
-- Character snapshot for the companion
--   AntiSocialExport["Name"] = "v1|Name|faction|Class|level|spec|item level|time"
-- The game writes saved variables to disk on /reload and on logout.
-------------------------------------------------------------------------------

local function Clean(v)
	return (tostring(v or ""):gsub('[|"\\\r\n]', ""))
end

-- The last good readings this session. While logging out the game answers some of these
-- questions with nothing, and that must not wipe out what was read while playing.
local known = {}

local function Snapshot()
	local name = FullName("player")
	if not name then return end

	local _, classFile = UnitClass("player")
	if type(classFile) == "string" and not IsSecret(classFile) and classFile ~= "" then
		known.class = classFile:sub(1, 1):upper() .. classFile:sub(2):lower()
	end
	local faction = UnitFactionGroup("player")
	if type(faction) == "string" and not IsSecret(faction) and faction ~= "" then known.faction = faction:lower() end
	local level = UnitLevel("player")
	if type(level) == "number" and not IsSecret(level) and level > 0 then known.level = level end

	if type(GetAverageItemLevel) == "function" then
		local ok, _, equipped = pcall(GetAverageItemLevel)
		if ok and type(equipped) == "number" and not IsSecret(equipped) and equipped > 0 then known.ilvl = equipped end
	end

	local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
	local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
	if type(getSpec) == "function" and type(getInfo) == "function" then
		local ok, index = pcall(getSpec)
		if ok and type(index) == "number" and not IsSecret(index) then
			local ok2, _, specName = pcall(getInfo, index)
			if ok2 and type(specName) == "string" and not IsSecret(specName) and specName ~= "" then known.spec = specName end
		end
	end

	if not (known.class and known.faction and known.level) then return end

	-- Forever reports the class name as the spec name; that tells nobody anything, so leave it out.
	local spec = known.spec or ""
	if spec:lower() == known.class:lower() then spec = "" end

	AntiSocialExport = AntiSocialExport or {}
	AntiSocialExport[name] = table.concat({
		"v1",
		Clean(name),
		Clean(known.faction),
		Clean(known.class),
		tostring(known.level),
		Clean(spec),
		string.format("%.1f", known.ilvl or 0),
		tostring(time()),
	}, "|")

	-- Versions before 0.4 saved the entry under the first part of the name only.
	local first = UnitName("player")
	if first and not IsSecret(first) and first ~= name then AntiSocialExport[first] = nil end
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local STATUS_TEXT = {
	waiting = "|cffa8997eready to invite|r",
	invited = "|cffffb347invited|r",
	joined = "|cff3fd06ain your party|r",
	left = "|cffff5a4dleft the party|r",
	failed = "|cffff5a4dcould not invite|r",
}

-- Uses the game's own frame art when the template exists, and still works when it does not.
local function Create(kind, name, parent, template)
	if template then
		local ok, made = pcall(CreateFrame, kind, name, parent, template)
		if ok and made then return made end
	end
	return CreateFrame(kind, name, parent)
end

local function BuildFrame()
	local f = Create("Frame", "AntiSocialFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(380, 372)
	f:SetPoint("CENTER", 0, 80)
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	if f.TitleText then f.TitleText:SetText(NAME) end

	local prompt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	prompt:SetPoint("TOPLEFT", 16, -34)
	prompt:SetText("Paste the code from the companion (Ctrl+V)")

	-- A bordered box several lines tall, so the whole code is visible and wraps.
	local box = Create("Frame", nil, f, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 14, -52)
	box:SetPoint("TOPRIGHT", -12, -52)
	box:SetHeight(96)
	if box.SetBackdrop then
		box:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		box:SetBackdropColor(0, 0, 0, 0.65)
		box:SetBackdropBorderColor(0.7, 0.6, 0.35)
	end
	box:EnableMouse(true)

	local edit = Create("EditBox", "AntiSocialCodeBox", box)
	edit:SetMultiLine(true)
	edit:SetPoint("TOPLEFT", 9, -8)
	edit:SetWidth(380 - 14 - 12 - 18)
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(1200)
	edit:SetFontObject(ChatFontNormal)
	if edit.SetTextColor then edit:SetTextColor(1, 0.82, 0.3) end
	-- Clicking anywhere in the box puts the cursor in it.
	box:SetScript("OnMouseDown", function() edit:SetFocus() end)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput then LoadCode(self:GetText(), true) end
	end)
	edit:SetScript("OnEnterPressed", function(self)
		if LoadCode(self:GetText(), false) then InviteMissing() end
		self:ClearFocus()
	end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	f.edit = edit

	local headline = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	headline:SetPoint("TOPLEFT", 16, -156)
	headline:SetPoint("TOPRIGHT", -16, -156)
	headline:SetJustifyH("LEFT")
	f.headline = headline

	local list = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	list:SetPoint("TOPLEFT", 16, -178)
	list:SetPoint("TOPRIGHT", -16, -178)
	list:SetJustifyH("LEFT")
	list:SetJustifyV("TOP")
	list:SetSpacing(4)
	f.list = list

	local invite = Create("Button", nil, f, "UIPanelButtonTemplate")
	invite:SetSize(150, 26)
	invite:SetPoint("BOTTOMLEFT", 14, 62)
	invite:SetText("Invite")
	invite:SetScript("OnClick", InviteMissing)
	f.invite = invite

	local auto = Create("CheckButton", nil, f, "UICheckButtonTemplate")
	auto:SetSize(26, 26)
	auto:SetPoint("BOTTOMLEFT", 170, 62)
	auto:SetChecked(db and db.autoInvite)
	auto:SetScript("OnClick", function(self) db.autoInvite = self:GetChecked() and true or false end)
	local autoText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	autoText:SetPoint("LEFT", auto, "RIGHT", 2, 0)
	autoText:SetText("Invite as soon as I paste")
	f.auto = auto

	local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	note:SetPoint("BOTTOMLEFT", 16, 18)
	note:SetPoint("BOTTOMRIGHT", -130, 18)
	note:SetJustifyH("LEFT")
	note:SetText("Your level and gear are saved for the companion when you reload or log out.")

	local reload = Create("Button", nil, f, "UIPanelButtonTemplate")
	reload:SetSize(110, 22)
	reload:SetPoint("BOTTOMRIGHT", -14, 16)
	reload:SetText("Save stats now")
	reload:SetScript("OnClick", function()
		local fn = (C_UI and C_UI.Reload) or ReloadUI
		if type(fn) == "function" then fn() end
	end)

	if UISpecialFrames then tinsert(UISpecialFrames, "AntiSocialFrame") end
	f:Hide()
	return f
end

function Refresh(problem)
	if not frame then return end
	if not current then
		frame.headline:SetText(problem and problem ~= "" and ("|cffff5a4d" .. problem .. "|r") or "|cffa8997eWaiting for a code.|r")
		frame.list:SetText("")
		frame.invite:SetText("Invite")
		frame.invite:Disable()
		return
	end
	local missing = 0
	local lines = {}
	for _, name in ipairs(current.names) do
		local status = current.status[name] or "waiting"
		if status ~= "joined" then missing = missing + 1 end
		lines[#lines + 1] = "|cffffd100" .. name .. "|r  " .. (STATUS_TEXT[status] or status)
	end
	frame.headline:SetText("|cffffd100" .. current.instance .. "|r  " .. (missing == 0 and "|cff3fd06aEveryone is here.|r" or (missing .. " to go")))
	frame.list:SetText(table.concat(lines, "\n"))
	local anyInvited = false
	for _, status in pairs(current.status) do
		if status ~= "waiting" then anyInvited = true end
	end
	frame.invite:SetText(anyInvited and "Invite again" or "Invite")
	if missing == 0 then frame.invite:Disable() else frame.invite:Enable() end
end

-- Opens the window with an empty, focused box so one Ctrl+V pastes a new code, invites and closes.
-- (An addon cannot read the clipboard itself; the paste has to be the player's own key press.)
local function QuickPaste()
	frame = frame or BuildFrame()
	quickPaste = true
	frame:Show()
	frame.edit:SetText("")
	frame.edit:SetFocus()
	frame.headline:SetText("|cffffd100Press Ctrl+V to paste the code and invite.|r")
end

local function Toggle()
	frame = frame or BuildFrame()
	quickPaste = false
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		Refresh()
		frame.edit:SetFocus()
		if frame.edit.HighlightText then frame.edit:HighlightText() end
	end
end

-------------------------------------------------------------------------------
-- Minimap button
-- Registered through LibDataBroker and LibDBIcon, the libraries most addons share for this,
-- so it behaves like every other minimap button and works with addons that collect them.
-------------------------------------------------------------------------------

local MINIMAP_ICON = "Interface\\AddOns\\AntiSocial\\Media\\minimap"
local BUTTON_KEY = "AntiSocialLFG" -- the name the libraries file the button under
local minimapIcon -- the LibDBIcon library, once the button is registered

local function MinimapClick(_, button)
	if button == "RightButton" then
		if current then
			InviteMissing()
		else
			Print("no group code loaded yet. Shift-click to paste one.")
		end
	elseif IsShiftKeyDown and IsShiftKeyDown() then
		QuickPaste()
	else
		Toggle()
	end
end

local function MinimapTooltip(tooltip)
	tooltip:AddLine(NAME)
	if current then
		local missing = 0
		for _, name in ipairs(current.names) do
			if current.status[name] ~= "joined" then missing = missing + 1 end
		end
		tooltip:AddLine(current.instance .. ": " .. (missing == 0 and "everyone is here" or (missing .. " to go")), 1, 1, 1)
	end
	tooltip:AddLine("Click: open the window", 0.66, 0.6, 0.5)
	tooltip:AddLine("Shift-click: paste a new code (Ctrl+V) and invite", 0.66, 0.6, 0.5)
	tooltip:AddLine("Right-click: invite whoever is still missing", 0.66, 0.6, 0.5)
	tooltip:AddLine("Drag: move this button", 0.66, 0.6, 0.5)
end

-- Returns false when the libraries are not available.
local function RegisterMinimapButton()
	if minimapIcon then return true end
	local broker = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not broker or not icon then return false end
	local object = broker:NewDataObject(BUTTON_KEY, {
		type = "launcher",
		text = NAME,
		icon = MINIMAP_ICON,
		OnClick = MinimapClick,
		OnTooltipShow = MinimapTooltip,
	})
	icon:Register(BUTTON_KEY, object, db.minimap)
	minimapIcon = icon
	return true
end

local function ShowMinimapButton(show)
	db.minimap.hide = not show
	if not RegisterMinimapButton() then return end
	if show then minimapIcon:Show(BUTTON_KEY) else minimapIcon:Hide(BUTTON_KEY) end
end

-- The addon menu next to the minimap calls this (see AddonCompartmentFunc in the .toc).
function AntiSocial_OnAddonCompartmentClick()
	Toggle()
end

-------------------------------------------------------------------------------
-- Events and slash commands
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
local handlers = {}
events:SetScript("OnEvent", function(_, event, ...)
	local h = handlers[event]
	if h then h(...) end
end)
local function On(event, fn)
	handlers[event] = fn
	pcall(events.RegisterEvent, events, event)
end

On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	AntiSocialDB = AntiSocialDB or {}
	AntiSocialExport = AntiSocialExport or {}
	db = AntiSocialDB
	if db.autoInvite == nil then db.autoInvite = true end
	-- Where the minimap button sits and whether it is hidden; LibDBIcon keeps this table up to date.
	if type(db.minimap) ~= "table" then db.minimap = { hide = false, minimapPos = 215 } end
	db.minimapHidden, db.minimapPos = nil, nil -- left over from the first version
end)

On("PLAYER_LOGIN", function()
	Snapshot()
	-- A broken minimap button must never stop the rest of the addon from working.
	local ok, made = pcall(RegisterMinimapButton)
	if not ok or not made then Print("could not create the minimap button. Use /as instead.") end
	Print("loaded. Click the minimap button or type |cffffd100/as|r to paste a group code.")
end)

-- Keep the snapshot current in memory, so whatever gets written at logout is right.
On("PLAYER_ENTERING_WORLD", function() pcall(Snapshot) end)
On("PLAYER_LEVEL_UP", function() pcall(Snapshot) end)
On("PLAYER_EQUIPMENT_CHANGED", function() pcall(Snapshot) end)
On("PLAYER_LOGOUT", function() pcall(Snapshot) end)

On("GROUP_ROSTER_UPDATE", function()
	if not current then return end
	local before = {}
	for name, status in pairs(current.status) do before[name] = status end
	local missing = UpdateJoined()
	for _, name in ipairs(current.names) do
		if current.status[name] == "joined" and before[name] ~= "joined" then
			Print(name .. " joined." .. (missing == 0 and " Everyone is here." or ""))
		end
	end
	Refresh()
end)

SLASH_ANTISOCIAL1 = "/as"
SLASH_ANTISOCIAL2 = "/antisocial"
SlashCmdList["ANTISOCIAL"] = function(msg)
	msg = Trim(msg or "")
	if msg == "" then
		Toggle()
	elseif msg:lower() == "invite" then
		InviteMissing()
	elseif msg:lower() == "minimap" then
		ShowMinimapButton(db.minimap.hide and true or false)
		Print(db.minimap.hide and "minimap button hidden. Type /as minimap to bring it back." or "minimap button shown.")
	else
		-- "/as <code>" works too, for anyone who prefers typing it in chat.
		frame = frame or BuildFrame()
		if not frame:IsShown() then frame:Show() end
		if LoadCode(msg, false) then
			frame.edit:SetText(msg)
			InviteMissing()
		end
	end
end

-- Exposed for testing.
AntiSocial_ParseCode = ParseCode

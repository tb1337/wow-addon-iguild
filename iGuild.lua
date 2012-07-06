-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName = select(1, ...); -- vararg returns "addonname, scope" in this case
iGuild = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibQTip = LibStub("LibQTip-1.0");

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local Tooltip; -- our tooltip
local RosterTimer; -- timer when the roster is fetched again

local COLOR_GOLD = "|cfffed100%s|r";

-- the Roster table, which is the basic data storage of iGuild. Every index is a guild member array.
iGuild.Roster = {};

local TradeSkillDB; -- table for the tradeskill database, f.e. mining, skinning, etc. Indexes are named as well, see below.
iGuild.TradeSkills = {}; -- table[charname] => { [1] = TradeSkillDB-Object, [2] = TradeSkillDB-Object }

local ClassTranslate = {};
for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
	ClassTranslate[v] = k;
end
for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
	ClassTranslate[v] = k;
end

-----------------------------
-- Setting up the feed
-----------------------------

iGuild.Feed = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "",
	icon = "Interface\\Addons\\iGuild\\Images\\iGuild",
});

iGuild.Feed.OnClick = function(_, button)
	if( button == "LeftButton" ) then
		if( _G.IsAltKeyDown() and _G.CanGuildInvite() ) then
			if( _G.StaticPopup_FindVisible("ADD_GUILDMEMBER") ) then
				_G.StaticPopup_Hide("ADD_GUILDMEMBER");
			else
				_G.StaticPopup_Show("ADD_GUILDMEMBER");
			end
		else
			_G.ToggleGuildFrame(1);
		end
	elseif( button == "RightButton" ) then
		iGuild:OpenOptions();
--@do-not-package@
	elseif( button == "MiddleButton" ) then
		iGuild:CountAchievements();	
--@end-do-not-package@
	end
end

iGuild.Feed.OnEnter = function(anchor)
	if( not _G.IsInGuild() ) then
		return; -- When not in a guild, fires no tooltip. I dislike addons which show a tooltip with the info "You are not in a guild!".
	end
	
	-- LibQTip has the power to show one or more tooltips, but on a broker bar, where more than one QTips are present, this is really disturbing.
	-- So we release the tooltips of the i-Addons here.
	for k, v in LibQTip:IterateTooltips() do
		if( type(k) == "string" and strsub(k, 1, 6) == "iSuite" ) then
			v:Release(k);
		end
	end
		
	Tooltip = LibQTip:Acquire("iSuite"..AddonName);
	Tooltip:SetAutoHideDelay(0.1, anchor);
	Tooltip:SmartAnchorTo(anchor);
	iGuild:UpdateTooltip();
	Tooltip:Show();
end

-- the DisplayedColumns table defines which columns gonna be displayed in the tooltip. It sorts out columns we cannot use (CanUse option).
iGuild.DisplayedColumns = {};
function iGuild:GetDisplayedColumns()
	_G.wipe(self.DisplayedColumns);
	
	local cols = {strsplit(",", self.db.Display)};
	local canUse;
	
	for i, v in ipairs(cols) do
		v = strtrim(v);
		canUse = self.Columns[v].canUse;
		
		if( canUse ) then
			if( canUse() ) then
				table.insert(self.DisplayedColumns, v);
			end
		else
			table.insert(self.DisplayedColumns, v);
		end
	end
end

----------------------
-- OnInitialize
----------------------

function iGuild:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("iGuildDB", self:CreateDB(), "Default").profile;

	-- dirty check if someone is using an old iGuild config, where this setting was a table
	if( type(self.db.Display) == "table" ) then
		self.db.Display = "grouped, level, class, name, zone, rank";
	end

	self:GetDisplayedColumns();
	-- the following code snippet is used once and deleted after
	self.show_colored_columns();
	self.show_colored_columns = nil;

	self:RegisterEvent("GUILD_MOTD", "RosterUpdate");
	self:RegisterEvent("PLAYER_GUILD_UPDATE", "RosterUpdate");
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "EnterWorld");
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "GroupChanged");
end

function iGuild:EnterWorld()
	if( _G.IsInGuild() ) then
		self:RegisterEvent("GUILD_ROSTER_UPDATE", "RosterUpdate");
		self:RegisterEvent("GUILD_XP_UPDATE", "RosterUpdate");
		self:RegisterEvent("GUILD_TRADESKILL_UPDATE", "TradeSkillUpdate");
		
		-- this three functions are required to query much data from the WoW server.
		_G.GuildRoster();
		_G.QueryGuildXP();
		_G.QueryGuildRecipes();
		
		RosterTimer = LibStub("AceTimer-3.0"):ScheduleRepeatingTimer(_G.GuildRoster, 15);
	else
		self.Feed.text = L["No guild"];
	end
end

----------------------
-- GroupChanged
----------------------

function iGuild:GroupChanged()
	self:GetDisplayedColumns();
	
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

----------------------
-- RosterUpdate
----------------------

function iGuild:RosterUpdate(event)
	if( _G.IsInGuild() ) then
		if( not RosterTimer ) then
			self:EnterWorld();
		end
		
		local total, totalOn = _G.GetNumGuildMembers();
		local feedText = ("%d/%d"):format(totalOn, total);
		
		local guildLevel, maxLevel = _G.GetGuildLevel();
		local guildName = _G.GetGuildInfo("player");
		
		-- check if guildname is to be shown on the feed
		if( self.db.ShowGuildName and guildName ) then
			feedText = (COLOR_GOLD.." %s"):format(guildName, feedText);
		end
		
		-- check if guildlevel is to be shown on the feed
		if( self.db.ShowGuildLevel ) then
			feedText = ("%s "..COLOR_GOLD.."%d"):format(feedText, "| ", guildLevel);
		end
		
		-- check if guild XP is to be shown on the feed
		if( self.db.ShowGuildXP ) then
			local currXP, nextUp = _G.UnitGetGuildXP("player");
			feedText = ("%s (%d%%)"):format(feedText, guildLevel < maxLevel and math.ceil(currXP / (currXP + nextUp) * 100) or 100);
		end
		
		self.Feed.text = feedText;		
		self:SetupGuildRoster();
		
		-- we just require this event once, thus removing it here.
		if( event == "GUILD_XP_UPDATE" ) then
			self:UnregisterEvent("GUILD_XP_UPDATE");
		end
	else -- Not in Guild!
		if( RosterTimer ) then
			self:UnregisterEvent("GUILD_ROSTER_UPDATE");
			self:UnregisterEvent("GUILD_XP_UPDATE");
			self:UnregisterEvent("GUILD_TRADESKILL_UPDATE");
			LibStub("AceTimer-3.0"):CancelTimer(RosterTimer);
			RosterTimer = nil;
		end
		
		_G.wipe(self.Roster);
		_G.wipe(self.TradeSkills);
		
		self.Feed.text = L["No guild"];
	end
	
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

--------------------------
-- SetupGuildRoster
--------------------------

do
	-- This metatable achieves that we don't need to declare table key pairs.
	-- The Guild Roster is saved in an array, but we may access the values via keys, tho! So clever and not too memory intensive. :)
	local mt = {
		__index = function(t, k)
			if    ( k == "name"  ) then return t[1]
			elseif( k == "level" ) then return t[2]
			elseif( k == "class" ) then return t[3]
			elseif( k == "CLASS" ) then return ClassTranslate[t[3]]
			elseif( k == "zone"  ) then return t[4]
			elseif( k == "status") then return t[5]
			elseif( k == "mobile") then return t[6]
			elseif( k == "apoints")then return t[7]
			elseif( k == "arank" ) then return t[8]
			elseif( k == "grank" ) then return t[9]
			elseif( k == "grankn") then return t[10]
			elseif( k == "note"  ) then return t[11]
			elseif( k == "onote" ) then return t[12]
			elseif( k == "gxp"   ) then return t[13]
			elseif( k == "trade" ) then return t[14]
			else return nil end
		end,
	};
	
	local iter = 1;
	function iGuild:SetupGuildRoster()
		local total = _G.GetNumGuildMembers();
		iter = 1;
		
		_G.wipe(self.Roster);
		
		-- preventing Lua from declaring local values 10000x times per loop - saving memory!
		local _, charName, guildRank, guildRankN, charLevel, charClass, charZone, guildNote,
			officerNote, isOnline, charStatus, _, acmPoints, acmRank, charMobile;
		local maxXP;
		
		for i = 1, total do
			charName, guildRank, guildRankN, charLevel, charClass, charZone, guildNote, 
			officerNote, isOnline, charStatus, _, acmPoints, acmRank, charMobile = _G.GetGuildRosterInfo(i);
			
			_, maxXP, _, _ = _G.GetGuildRosterContribution(i);
			
			if( isOnline ) then
				self.Roster[iter] = {
					[1]  = charName,
					[2]  = charLevel,
					[3]  = charClass,
					[4]  = charZone or _G.UNKNOWN, -- actually may happen o_O
					[5]  = charStatus,
					[6]  = charMobile,
					[7]  = acmPoints,
					[8]  = acmRank,
					[9]  = guildRank,
					[10] = guildRankN,
					[11] = guildNote or "",
					[12] = officerNote or "",
					[13] = maxXP
				};
				
				if( self.db.Column.tradeskills.Enable ) then
					self.Roster[iter][14] = self.TradeSkills[charName];
				end
				
				setmetatable(self.Roster[iter], mt);
				iter = iter + 1;
			end
		end
		
		table.sort(self.Roster, self.Sort[self.db.Sort]);
	end
end

--------------------------
-- TradeskillUpdate
--------------------------

-- This is a really tricky one. Due to memory and CPU load, we just want to update the tradeskills once: when the UI is (re)loaded.
-- TradeSkillsFetched determines if the tradeskills are previously updated and quits the function.
-- TradeSkillsUpdating is set to 1 when the below function is working. This is strongly recommended to prevent recursion!

do
	local mt = {
		__index = function(t, k)
			if( k == "name" ) then return t[1]
			elseif( k == "id" ) then return t[2]
			elseif( k == "texture" ) then return t[3]
			elseif( k == "collapsed" ) then return t[4]
			end
		end,
	};

	local TradeSkillsFetched, TradeSkillsUpdating;
	function iGuild:TradeSkillUpdate()
		if( not self.db.Column.tradeskills.Enable ) then
			return;
		end
		
		-- no tradeskill db, so we generate it from scratch.
		if( not TradeSkillDB ) then
			TradeSkillDB = {};
			
			for i = 1, _G.GetNumGuildTradeSkill() do
				local skillID, isCollapsed, iconTexture, headerName, _, _, _, _, _, _, _, _, _, _ = _G.GetGuildTradeSkillInfo(i);
				
				-- when headerName is set, this is a tradeskill for our DB
				if( headerName ) then
					TradeSkillDB[headerName] = {
						[1] = headerName,
						[2] = skillID,
						[3] = iconTexture,
						[4] = isCollapsed
					};
					
					setmetatable(TradeSkillDB[headerName], mt);
				end
			end
		end
		
		-- prevent recursion
		if( TradeSkillsFetched or TradeSkillsUpdating ) then
			return;
		end
		TradeSkillsUpdating = 1;
		
		-- We need to expand the tradeskills in the guild-tradeskill tab in order to fetch the members.
		for _, skill in pairs(TradeSkillDB) do
			_G.ExpandGuildTradeSkillHeader(skill.id);
		end
		
		-- loop through all tradeskills and users
		_G.wipe(iGuild.TradeSkills);
		local showOffline = _G.GetGuildRosterShowOffline(); -- store showOffline info set by the user
		_G.SetGuildRosterShowOffline(true);
		
		local currentTradeSkill;
		for i = 1, _G.GetNumGuildTradeSkill() do
			local _, _, _, headerName, _, _, _, playerName, _, _, _, _, _, _ = _G.GetGuildTradeSkillInfo(i);
			
			if( headerName ) then
				currentTradeSkill = headerName;
			elseif( playerName ) then
				if( not self.TradeSkills[playerName] ) then
					self.TradeSkills[playerName] = {};
				end
				
				table.insert(self.TradeSkills[playerName], TradeSkillDB[currentTradeSkill]);
			end
		end
		
		_G.SetGuildRosterShowOffline(showOffline); -- reset showOffline to not change users configuration
		
		-- We collapse the headers again if they were collapsed by the user before.
		for _, skill in pairs(TradeSkillDB) do		
			if( skill.collapsed ) then
				_G.CollapseGuildTradeSkillHeader(skill.id);
			end
		end
		
		TradeSkillsFetched = 1;
		TradeSkillsUpdating = nil;
	end
end

-----------------------
-- UpdateTooltip
-----------------------

local function LineClick(_, name, button)
	if( button == "LeftButton" ) then
		if( _G.IsAltKeyDown() ) then
			_G.InviteUnit(name);
		else
			_G.SetItemRef(("player:%s"):format(name), ("|Hplayer:%s|h[%s]|h"):format(name, name), "LeftButton");
		end
	end
end

local function RosterMOTDChangeClick(_, var, button)
	if( button == "LeftButton" ) then
		_G.GuildTextEditFrame_Show("motd");
	end
end

function iGuild:UpdateTooltip()
	Tooltip:Clear();
	Tooltip:SetColumnLayout(#self.DisplayedColumns);
	
	local name, info, line;
	
	-- if MOTD is to be shown, place it first!
	if( self.db.ShowGuildMOTD and _G.GetGuildRosterMOTD() and _G.GetGuildRosterMOTD() ~= "" ) then
		local edit = _G.CanEditMOTD();
		
		-- at first, we add MOTD title and eventually a change button
		line = Tooltip:AddLine(" ");
		Tooltip:SetCell(line, 1, (COLOR_GOLD):format(_G.GUILD_MOTD..":"), nil, "LEFT", #self.DisplayedColumns - (edit and 1 or 0));
		
		-- if we may change MOTD, the change button will be shown
		if( edit ) then
			Tooltip:SetCell(line, #self.DisplayedColumns, (COLOR_GOLD):format("["..L["Change"].."]"), nil, "RIGHT");
			Tooltip:SetCellScript(line, #self.DisplayedColumns, "OnMouseDown", RosterMOTDChangeClick);
		end
		
		-- now we add the MOTD text
		line = Tooltip:AddLine(" ");
		Tooltip:SetCell(line, 1, _G.GetGuildRosterMOTD(), nil, "LEFT", #self.DisplayedColumns);
		
		Tooltip:AddLine(" "); -- space between MOTD and Roster
	end
	
	-- Looping thru Roster and displaying columns and lines
	for y = 0, #self.Roster do
		local member;
		
		for x = 1, #self.DisplayedColumns do
			name = self.DisplayedColumns[x];
			info = self.Columns[name];
			
			-- check if we add a line or a header
			if( x == 1 ) then
				if( y == 0 ) then
					line = Tooltip:AddHeader(" "); -- we have line 0, it's the header line.
				else
					line = Tooltip:AddLine(" "); -- all others are member lines.
				end
			end
			
			-- fill lines with content
			if( y == 0 ) then
				if( self.db.Column[name].ShowLabel ) then
					-- in the header line (y = 0), we check if column labels are to be shown.
					Tooltip:SetCell(line, x, info.label, nil, self.db.Column[name].Align);
				end
			else
				member = self.Roster[y]; -- fetch member from Roster and brush infos to the cells
				Tooltip:SetCell(line, x, info.brush(member), nil, self.db.Column[name].Align);
				
				if( info.script and self.db.Column[name].EnableScript and info.scriptUse(member) ) then
					Tooltip:SetCellScript(line, x, "OnMouseDown", info.script, member);
				end
			end
		end
		
		if( member ) then
			Tooltip:SetLineScript(line, "OnMouseDown", LineClick, member.name);
		end
	end
	
end
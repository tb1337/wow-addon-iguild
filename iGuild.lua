--
-- Author: $Author$
-- Last updated: $Date$
-- Revision: $Revision$
-- Web: $HeadURL$
--

-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName = select(1, ...); -- vararg returns "addonname, scope" in this case
iGuild = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibQTip = LibStub("LibQTip-1.0");
local LibTourist = LibStub("LibTourist-3.0"); -- a really memory-eating lib.
local LibCrayon = LibStub("LibCrayon-3.0");

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local Tooltip; -- our tooltip
local RosterTimer; -- timer when the roster is fetched again

local MAX_ACMPOINTS = 15240; -- I use the handy app to get this, tricky business.

local COLOR_GOLD = "|cfffed100%s|r";
local COLOR_MASTER  = "|cffff6644%s|r";
local COLOR_OFFICER = "|cff40c040%s|r";

-- the Roster table, which is the basic data storage of iGuild. To save memory, data is stored by index, not by key.
-- To prevent using constructs like Roster[2] for selecting a Level, we set some names for the indexes. Looks like a table with keys now!
local Roster = {};
local R_CHAR_NAME = 1;
local R_CHAR_LEVEL = 2;
local R_CHAR_CLASS = 3;
local R_CHAR_ZONE = 4;
local R_CHAR_STATUS = 5;
local R_CHAR_MOBILE = 6;
local R_ACM_POINTS = 7;
local R_ACM_RANK = 8;
local R_GUILD_RANK = 9;
local R_GUILD_NOTE = 10;
local R_OFFICER_NOTE = 11;
local R_GUILD_RANK_NUM = 12;
local R_TRADESKILLS = 13;
local R_CHAR_CLASS_LOCALIZED = 14;
local R_XP_MAX = 15;
---------------------------------------------------------------

local TradeSkillDB; -- table for the tradeskill database, f.e. mining, skinning, etc. Indexes are named as well, see below.
local TRADE_ID = 1;
local TRADE_ICON = 2;
local TRADE_COLLAPSED = 3;
local TradeSkillMates = {}; -- table[charname] => { [1] = tradeskill1-name, [2] = tradeskill2-name }

-- this is my try to clean up some memory.
local function tclear(t, wipe)
	if( type(t) ~= "table" ) then return end;
	for k in pairs(t) do
		t[k] = nil;
	end
	t[''] = 1;
	t[''] = nil;
	if( wipe ) then
		t = nil;
	end
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

-----------------------------
-- Sorting and Columns
-----------------------------

iGuild.Sort = {
	-- sort by name
	name = function(a, b)
		return a[R_CHAR_NAME] < b[R_CHAR_NAME];
	end,
	-- sort by level and fall back to name
	level = function(a, b)
		if( a[R_CHAR_LEVEL] < b[R_CHAR_LEVEL] ) then
			return true;
		elseif( a[R_CHAR_LEVEL] > b[R_CHAR_LEVEL] ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by class and fall back to name
	class = function(a, b)
		if( a[R_CHAR_CLASS] < b[R_CHAR_CLASS] ) then
			return true;
		elseif( a[R_CHAR_CLASS] > b[R_CHAR_CLASS] ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by guild rank and fall back to name
	rank = function(a, b)
		if( a[R_GUILD_RANK_NUM] < b[R_GUILD_RANK_NUM] ) then
			return true;
	elseif( a[R_GUILD_RANK_NUM] > b[R_GUILD_RANK_NUM] ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by achievement points and fall back to name
	points = function(a, b)
		if( a[R_ACM_POINTS] > b[R_ACM_POINTS] ) then
			return true;
		elseif( a[R_ACM_POINTS] < b[R_ACM_POINTS] ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by zone and fall back to name
	zone = function(a, b)
		if( a[R_CHAR_ZONE] < b[R_CHAR_ZONE] ) then
			return true;
		elseif( a[R_CHAR_ZONE] > b[R_CHAR_ZONE] ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end
};

-- iGuild dynamically displays columns in the order defined by the user. That's why we need to set up a table containing column info.
-- Each key of the table is named by the internal column name and stores another table, which defines how the column will behave. Keys:
--   label: simply stores the displayed name of a column.
--   brush(v): the brush defines how content in a column-cell is displayed. v is Roster-data (see top of file)
--   canUse(v): this OPTIONAL function checks if a column can be displayed for the user. Returns 1 or nil.
--   script(anchor, v, button): defines the click handler of a column-cell. This is optional! v is Roster-data.
--   scriptUse(v): this OPTIONAL function will check if a click handler will be attached to the column-cell. v is Roster-data. Returns 1 or nil.

iGuild.Columns = {
	level = {
		label = L["Level"],
		brush = function(v)
			-- encolor by difficulty
			if( iGuild.db.Column.level.Color == 2 ) then
				local c = _G.GetQuestDifficultyColor(v[R_CHAR_LEVEL]);
				return ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, v[R_CHAR_LEVEL]);
			-- encolor by threshold
			elseif( iGuild.db.Column.level.Color == 3 ) then
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(v[R_CHAR_LEVEL], MAX_PLAYER_LEVEL), v[R_CHAR_LEVEL]);
			-- no color
			else
				return (COLOR_GOLD):format(v[R_CHAR_LEVEL]);
			end
		end,
	},
	name = {
		label = L["Name"],
		brush = function(v)
			local status = "";
			if( v[R_CHAR_STATUS] == 1 ) then
				status = ("<%s>"):format(_G.AFK);
			elseif( v[R_CHAR_STATUS] == 2 ) then
				status = ("<%s>"):format(_G.DND);
			end
			
			-- encolor by class color
			if( iGuild.db.Column.name.Color == 2 ) then
				local c = _G.RAID_CLASS_COLORS[v[R_CHAR_CLASS]];
				return ("|cff%02x%02x%02x%s%s|r"):format(c.r *255, c.g *255, c.b *255, status, v[R_CHAR_NAME]);
			-- no color
			else
				return (COLOR_GOLD):format(status..v[R_CHAR_NAME]);
			end
		end,
	},
	zone = {
		label = L["Zone"],
		brush = function(v)
			-- encolor by hostility
			local r, g, b = LibTourist:GetFactionColor(v[R_CHAR_ZONE]);
			return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, v[R_CHAR_ZONE]);
		end,
	},
	rank = {
		label = L["Rank"],
		brush = function(v)
			-- encolor by threshold
			if( iGuild.db.Column.rank.Color == 2 ) then
				local max_rank = _G.GuildControlGetNumRanks();
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(max_rank - v[R_GUILD_RANK_NUM], max_rank -1), v[R_GUILD_RANK]);
			-- no color
			else
				return (COLOR_GOLD):format(v[R_GUILD_RANK]);
			end
		end,
		script = function(_, v, button)
			-- left clicks will promote, if we can promote
			if( _G.IsAltKeyDown() and button == "LeftButton" and _G.CanGuildPromote() ) then
				_G.GuildPromote(v[R_CHAR_NAME]);
			end
			-- right clicks will demote, if we can demote
			if( _G.IsAltKeyDown() and button == "RightButton" and _G.CanGuildDemote() ) then
				_G.GuildDemote(v[R_CHAR_NAME]);
			end
		end,
		scriptUse = function() return ( _G.CanGuildPromote() or _G.CanGuildDemote() ) end,
	},
	note = {
		label = L["Note"],
		brush = function(v)
			return (COLOR_GOLD):format(v[R_GUILD_NOTE]);
		end,
	},
	officernote = {
		label = L["OfficerNote"],
		brush = function(v)
			return (COLOR_OFFICER):format(v[R_OFFICER_NOTE]);
		end,
		canUse = function() return _G.CanViewOfficerNote() end,
	},
	notecombi = {
		label = L["Note"],
		brush = function(v)
			local normal;
			local officer;
			
			if( v[R_GUILD_NOTE] and v[R_GUILD_NOTE] ~= "" ) then
				normal = 1;
			end
			if( _G.CanViewOfficerNote() and v[R_OFFICER_NOTE] and v[R_OFFICER_NOTE] ~= "" ) then
				officer = 1;
			end
			
			local note = "";
			if( normal and not officer ) then
				note = (COLOR_GOLD):format(v[R_GUILD_NOTE]);
			elseif( officer and not normal ) then
				note = (COLOR_OFFICER):format(v[R_OFFICER_NOTE]);
			elseif( normal and officer ) then
				note = ("%s / %s"):format( (COLOR_GOLD):format(v[R_GUILD_NOTE]), (COLOR_OFFICER):format(v[R_OFFICER_NOTE]) );
			end
			return note;
		end,
	},
	acmpoints = {
		label = L["Points"],
		brush = function(v)
			-- encolor by threshold
			if( iGuild.db.Column.acmpoints.Color == 2 ) then
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(v[R_ACM_POINTS], MAX_ACMPOINTS), v[R_ACM_POINTS]);
			-- no color
			else
				return (COLOR_GOLD):format(v[R_ACM_POINTS]);
			end
		end,
	},
	tradeskills = {
		label = L["TradeSkills"],
		brush = function(v)
			if( not iGuild.db.Column.tradeskills.Enable ) then
				return (COLOR_GOLD):format(UNKNOWN);
			end
			
			local ts = TradeSkillMates[v[R_CHAR_NAME]];
			local label = "";

			if( ts ) then
				if( #ts >= 1 ) then
					label = ("|T%s:14:14|t"):format("Interface\\Addons\\iGuild\\Images\\"..iGuild:GetTradeSkill(ts[1], TRADE_ICON));
				end
				if( #ts >= 2 ) then
					label = ("%s |T%s:14:14|t"):format(label, "Interface\\Addons\\iGuild\\Images\\"..iGuild:GetTradeSkill(ts[2], TRADE_ICON));
				end
			end
			
			return label;
		end,
		script = function(_, v, button)
			local ts = TradeSkillMates[v[R_CHAR_NAME]];
			if( not ts ) then
				return;
			end
			
			if( button == "LeftButton" and #ts >= 1 and _G.CanViewGuildRecipes(iGuild:GetTradeSkill(ts[1], TRADE_ID)) ) then
				_G.GetGuildMemberRecipes(v[R_CHAR_NAME], iGuild:GetTradeSkill(ts[1], TRADE_ID));
			elseif( button == "RightButton" and #ts >= 2 and _G.CanViewGuildRecipes(iGuild:GetTradeSkill(ts[2], TRADE_ID)) ) then
				_G.GetGuildMemberRecipes(v[R_CHAR_NAME], iGuild:GetTradeSkill(ts[2], TRADE_ID));
			end
		end,
		scriptUse = function(v)
			local ts = TradeSkillMates[v[R_CHAR_NAME]];
			if( ts and #ts > 0 ) then
				return 1;
			end
			return nil;
		end,
	},
	class = {
		label = L["Class"],
		brush = function(v)
			if( iGuild.db.Column.class.Icon == true ) then
				return "|TInterface\\Addons\\iGuild\\Images\\"..v[R_CHAR_CLASS]..":14:14|t";
			end
			
			-- encolor by class color
			if( iGuild.db.Column.class.Color == 2 ) then
				local c = _G.RAID_CLASS_COLORS[v[R_CHAR_CLASS]];
				return ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, v[R_CHAR_CLASS_LOCALIZED]);
			-- no color
			else
				return (COLOR_GOLD):format(v[R_CHAR_CLASS_LOCALIZED]);
			end
		end,
	},
	exp = {
		label = XP,
		brush = function(v)
			return (COLOR_GOLD):format(v[R_XP_MAX] /1000);
		end,
	},
	grouped = {
		label = _G.GROUP,
		brush = function(v)
			if( _G.UnitInParty(v[R_CHAR_NAME]) or _G.UnitInRaid(v[R_CHAR_NAME]) ) then
				return "|TInterface\\Buttons\\UI-PlusButton-Up:14:14|t";
			else
				return "";
			end
		end,
		canUse = function()
			return _G.GetNumPartyMembers() ~= 0 or _G.GetNumRaidMembers() ~= 0;
		end,
	}
};

-- the DisplayedColumns table defines which columns gonna be displayed in the tooltip. It sorts out columns we cannot use (CanUse option).
local DisplayedColumns = {};
function iGuild:GetDisplayedColumns()
	tclear(DisplayedColumns);
	
	local canUse;
	for i = 1, #self.ConfigColumns do
		canUse = self.Columns[self.ConfigColumns[i]].canUse;
		if( canUse and not canUse() ) then else
			table.insert(DisplayedColumns, self.ConfigColumns[i]);
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

	self:GetConfigColumns();
	self:GetDisplayedColumns();

	self:RegisterEvent("GUILD_MOTD", "RosterUpdate");
	self:RegisterEvent("PLAYER_GUILD_UPDATE", "RosterUpdate");
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "EnterWorld");
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "PartyChanged");
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
-- PartyChanged
----------------------

function iGuild:PartyChanged()
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
		local level, guild = _G.GetGuildLevel(), _G.GetGuildInfo("player");
		
		-- check if guildname is to be shown on the feed
		if( self.db.ShowGuildName and guild ) then
			feedText = (COLOR_GOLD.." %s"):format(guild, feedText);
		end
		
		-- check if guildlevel is to be shown on the feed
		if( self.db.ShowGuildLevel ) then
			feedText = ("%s "..COLOR_GOLD.."%d"):format(feedText, "| ", level);
		end
		
		-- check if guild XP is to be shown on the feed
		if( self.db.ShowGuildXP ) then
			local currXP, nextUp = _G.UnitGetGuildXP("player");
			feedText = ("%s (%d%%)"):format(feedText, level < _G.MAX_GUILD_LEVEL and math.ceil(currXP / (currXP + nextUp) * 100) or 100);
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
		
		tclear(Roster);
		self:TradeSkillRemove();
		self.Feed.text = L["No guild"];
	end
	
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

--------------------------
-- TradeskillUpdate
--------------------------

-- This is a really tricky one. Due to memory and CPU load, we just want to update the tradeskills once: when the UI is (re)loaded.
-- TradeSkillsFetched determines if the tradeskills are previously updated and quits the function.
-- TradeSkillsUpdating is set to 1 when the below function is working. This is strongly recommended to prevent recursion!
local TradeSkillsFetched, TradeSkillsUpdating;
function iGuild:TradeSkillUpdate()
	if( self.db.Column.tradeskills.Enable == false ) then
		return;
	end
	
	-- no tradeskill db, so we generate it from scratch.
	if( not TradeSkillDB ) then
		TradeSkillDB = {};
		
		for i = 1, _G.GetNumGuildTradeSkill() do
			local skillID, isCollapsed, iconTexture, headerName, _, _, _, _, _, _, _, _, _, _ = _G.GetGuildTradeSkillInfo(i);
			
			-- when headerName is set, this is a tradeskill for our DB
			if( headerName ) then
				TradeSkillDB[headerName] = {};
				TradeSkillDB[headerName][TRADE_ID] = skillID;
				TradeSkillDB[headerName][TRADE_ICON] = iconTexture;
				TradeSkillDB[headerName][TRADE_COLLAPSED] = isCollapsed;
			end
		end
	end
	
	-- prevent recursion
	if( TradeSkillsFetched or TradeSkillsUpdating ) then
		return;
	end
	TradeSkillsUpdating = 1;
	
	-- We need to expand the tradeskills in the guild-tradeskill tab in order to fetch the members.
	for _, v in pairs(TradeSkillDB) do
		_G.ExpandGuildTradeSkillHeader(v[TRADE_ID]);
	end
	
	-- loop through all tradeskills and users
	tclear(TradeSkillMates);
	local showOffline = _G.GetGuildRosterShowOffline(); -- store showOffline info set by the user
	_G.SetGuildRosterShowOffline(true);
	
	local currentTradeSkill;
	for i = 1, _G.GetNumGuildTradeSkill() do
		local _, _, _, headerName, _, _, _, playerName, _, _, _, _, _, _ = _G.GetGuildTradeSkillInfo(i);
		
		if( headerName ) then
			currentTradeSkill = headerName;
		elseif( playerName ) then
			if( not TradeSkillMates[playerName] ) then
				TradeSkillMates[playerName] = {};
			end
			
			table.insert(TradeSkillMates[playerName], currentTradeSkill);
		end
	end
	
	_G.SetGuildRosterShowOffline(showOffline); -- reset showOffline to not change users configuration
	
	-- We collapse the headers again if they were collapsed by the user before.
	for _, v in pairs(TradeSkillDB) do		
		if( v[TRADE_COLLAPSED] ) then
			_G.CollapseGuildTradeSkillHeader(v[TRADE_ID]);
		end
	end
	
	TradeSkillsFetched = 1;
	TradeSkillsUpdating = nil;
end

function iGuild:TradeSkillRemove()
	tclear(TradeSkillDB, 1);
	tclear(TradeSkillMates);
end

function iGuild:GetTradeSkill(name, index)
	if( index ) then
		return TradeSkillDB[name][index];
	end
	return TradeSkillDB[name];
end

--------------------------
-- SetupGuildRoster
--------------------------

local GuildIter = 1;
function iGuild:SetupGuildRoster()
	local total, totalOn = _G.GetNumGuildMembers();
	
	tclear(Roster);
	
	-- preventing Lua from declaring local values 10000x times per loop - saving memory!
	local _, charName, guildRank, guildRankN, charLevel, charClassLoc, charZone, guildNote,
		officerNote, isOnline, charStatus, charClass, acmPoints, acmRank, charMobile;
	local maxXP;
	
	for i = 1, total do
		charName, guildRank, guildRankN, charLevel, charClassLoc, charZone, guildNote, 
		officerNote, isOnline, charStatus, charClass, acmPoints, acmRank, charMobile = _G.GetGuildRosterInfo(i);
		
		_, maxXP, _, _ = _G.GetGuildRosterContribution(i);
		
		if( isOnline ) then
			Roster[GuildIter] = {};
			Roster[GuildIter][R_CHAR_NAME] = charName;
			Roster[GuildIter][R_CHAR_LEVEL] = charLevel;
			Roster[GuildIter][R_CHAR_CLASS] = charClass;
			Roster[GuildIter][R_CHAR_CLASS_LOCALIZED] = charClassLoc;
			Roster[GuildIter][R_CHAR_ZONE] = charZone or UNKNOWN;
			Roster[GuildIter][R_CHAR_STATUS] = charStatus;
			Roster[GuildIter][R_CHAR_MOBILE] = charMobile or false;
			Roster[GuildIter][R_ACM_POINTS] = acmPoints;
			Roster[GuildIter][R_ACM_RANK] = acmRank;
			Roster[GuildIter][R_GUILD_RANK] = guildRank;
			Roster[GuildIter][R_GUILD_RANK_NUM] = guildRankN;
			Roster[GuildIter][R_GUILD_NOTE] = guildNote or nil;
			Roster[GuildIter][R_OFFICER_NOTE] = officerNote or nil;
			Roster[GuildIter][R_XP_MAX] = maxXP;
			
			if( self.db.Column.tradeskills.Enable == true and TradeSkillMates[charName] ) then
				Roster[GuildIter][R_TRADESKILLS] = TradeSkillMates[charName];
			end
			
			GuildIter = GuildIter + 1;
		end
	end
	
	table.sort(Roster, self.Sort[self.db.Sort]);
	GuildIter = 1;
end

-----------------------
-- UpdateTooltip
-----------------------

local function RosterLineClicked(_, name, button)
	if( button == "LeftButton" ) then
		if( _G.IsAltKeyDown() ) then
			_G.InviteUnit(name);
		else
			_G.SetItemRef(("player:%s"):format(name), ("|Hplayer:%s|h[%s]|h"):format(name, name), "LeftButton");
		end
	end
end

local function RosterMOTDChangeClicked(_, var, button)
	if( button == "LeftButton" ) then
		_G.GuildTextEditFrame_Show("motd");
	end
end

function iGuild:UpdateTooltip()
	Tooltip:Clear();
	Tooltip:SetColumnLayout(#DisplayedColumns);
	
	local name, info, line;
	
	-- if MOTD is to be shown, place it first!
	if( self.db.ShowGuildMOTD == true and _G.GetGuildRosterMOTD() and _G.GetGuildRosterMOTD() ~= "" ) then
		local edit = _G.CanEditMOTD();
		
		-- at first, we add MOTD title and eventually a change button
		line = Tooltip:AddLine(" ");
		Tooltip:SetCell(line, 1, (COLOR_GOLD):format(_G.GUILD_MOTD..":"), nil, "LEFT", #DisplayedColumns - (edit and 1 or 0));
		
		-- if we may change MOTD, the change button will be shown
		if( edit ) then
			Tooltip:SetCell(line, #DisplayedColumns, (COLOR_GOLD):format("["..L["Change"].."]"), nil, "RIGHT");
			Tooltip:SetCellScript(line, #DisplayedColumns, "OnMouseDown", RosterMOTDChangeClicked);
		end
		
		-- now we add the MOTD text
		line = Tooltip:AddLine(" ");
		Tooltip:SetCell(line, 1, _G.GetGuildRosterMOTD(), nil, "LEFT", #DisplayedColumns);
		
		Tooltip:AddLine(" "); -- space between MOTD and Roster
	end
	
	-- Looping thru Roster and displaying columns and lines
	for y = 0, #Roster do
		local member;
		
		for x = 1, #DisplayedColumns do
			name = DisplayedColumns[x];
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
				member = Roster[y]; -- fetch member from Roster and brush infos to the cells
				Tooltip:SetCell(line, x, info.brush(member), nil, self.db.Column[name].Align);
				
				if( info.script and self.db.Column[name].EnableScript == true and info.scriptUse(member) ) then
					Tooltip:SetCellScript(line, x, "OnMouseDown", info.script, member);
				end
			end
		end
		
		if( member ) then
			Tooltip:SetLineScript(line, "OnMouseDown", RosterLineClicked, member[R_CHAR_NAME]);
		end
	end
	
end
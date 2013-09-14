-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iGuild = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibCrayon = LibStub("LibCrayon-3.0");
local LibTourist = LibStub("LibTourist-3.0"); -- a really memory-eating lib.

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

local iconSize = 14;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local COLOR_GOLD = "|cfffed100%s|r";
local COLOR_MASTER  = "|cffff6644%s|r";
local COLOR_OFFICER = "|cff40c040%s|r";

local MAX_ACMPOINTS = 21985; -- see iGuild/Developer.lua
local MAX_PROFESSION_SKILL = 600; -- Mists of Pandaria

local working_member; -- set and resetted by OnEnter/OnLeave handlers

----------------------------
-- Sorting and Columns
-----------------------------

iGuild.Sort = {
	-- sort by name
	name = function(a, b)
		return a.name < b.name;
	end,
	-- sort by level and fall back to name
	level = function(a, b)
		if( a.level < b.level ) then
			return true;
		elseif( a.level > b.level ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by class and fall back to name
	class = function(a, b)
		if( a.class < b.class ) then
			return true;
		elseif( a.class > b.class ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by guild rank and fall back to name
	rank = function(a, b)
		if( a.grank < b.grank ) then
			return true;
	elseif( a.grank > b.grank ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by achievement points and fall back to name
	points = function(a, b)
		if( a.apoints > b.apoints ) then
			return true;
		elseif( a.apoints < b.apoints ) then
			return false;
		else
			return iGuild.Sort.name(a, b);
		end
	end,
	-- sort by zone and fall back to name
	zone = function(a, b)
		if( a.zone < b.zone ) then
			return true;
		elseif( a.zone > b.zone ) then
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
--   scriptOnEnter(anchor, v): defines an OnEnter handler of a column-cell. This is optional! v is Roster-data.
--   scriptOnLeave(anchor, v): defines an OnLeave handler. It must be defined in ordner to get OnEnter handlers work. v is Roster-data.
--   scriptUse(v): this OPTIONAL function will check if a script handler will be attached to the column-cell. v is Roster-data. Returns 1 or nil.

iGuild.Columns = {
	level = {
		label = _G.LEVEL,
		brush = function(member)
			-- encolor by difficulty
			if( iGuild.db.Column.level.Color == 2 ) then
				local c = _G.GetQuestDifficultyColor(member.level);
				return ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, member.level);
			-- encolor by threshold
			elseif( iGuild.db.Column.level.Color == 3 ) then
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(member.level, _G.MAX_PLAYER_LEVEL), member.level);
			-- no color
			else
				return (COLOR_GOLD):format(member.level);
			end
		end,
	},
	name = {
		label = _G.NAME,
		brush = function(member)
			local status = "";
			
			if( member.status == 1 ) then
				status = ("<%s>"):format(_G.AFK);
			elseif( member.status == 2 ) then
				status = ("<%s>"):format(_G.DND);
			end
			
			if( member.mobile ) then
				status = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:14:14:0:0:16:16:0:16:0:16:73:177:73|t"..status;
			end
			
			-- encolor by class color
			if( iGuild.db.Column.name.Color == 2 ) then
				return ("|c%s%s|r"):format(_G.RAID_CLASS_COLORS[member.CLASS].colorStr, status..member.name);
			-- no color
			else
				return (COLOR_GOLD):format(status..member.name);
			end
		end,
	},
	zone = {
		label = _G.ZONE,
		brush = function(member)
			-- encolor by hostility
			local r, g, b = LibTourist:GetFactionColor(member.zone);
			return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, member.zone);
		end,
	},
	rank = {
		label = _G.RANK,
		brush = function(member)
			-- encolor by threshold
			if( iGuild.db.Column.rank.Color == 2 ) then
				local max_rank = _G.GuildControlGetNumRanks();
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(max_rank - member.grank, max_rank -1), _G.GuildControlGetRankName(member.grank));
			-- no color
			else
				return (COLOR_GOLD):format(_G.GuildControlGetRankName(member.grank));
			end
		end,
		script = function(_, member, button)
			-- left clicks will promote, if we can promote
			if( _G.IsAltKeyDown() and button == "LeftButton" and _G.CanGuildPromote() ) then
				_G.GuildPromote(member.name);
			end
			-- right clicks will demote, if we can demote
			if( _G.IsAltKeyDown() and button == "RightButton" and _G.CanGuildDemote() ) then
				_G.GuildDemote(member.name);
			end
		end,
		scriptOnEnter = function(anchor, member)
			working_member = member;
			local tip = iGuild:GetTooltip("Ranks", "UpdateRanksTooltip");
			tip:SetPoint("TOPLEFT", anchor:GetParent(), "TOPRIGHT", 10, 10);
			tip:Show();
		end,
		scriptOnLeave = function(anchor, member)
			iGuild:GetTooltip("Ranks"):Release();
			working_member = nil;
		end,
		scriptUse = function() return ( _G.CanGuildPromote() or _G.CanGuildDemote() ) end,
	},
	note = {
		label = L["Note"],
		brush = function(member)
			return (COLOR_GOLD):format(member.note);
		end,
	},
	officernote = {
		label = L["OfficerNote"],
		brush = function(member)
			return (COLOR_OFFICER):format(member.onote);
		end,
		canUse = function() return _G.CanViewOfficerNote() end,
	},
	notecombi = {
		label = L["Note"].."*",
		brush = function(member)
			local normal, officer;
			local note = "";
			
			if( member.note ~= "" ) then
				normal = 1;
			end
			if( _G.CanViewOfficerNote() and member.onote ~= "" ) then
				officer = 1;
			end
			
			if( normal and not officer ) then
				note = (COLOR_GOLD):format(member.note);
			elseif( officer and not normal ) then
				note = (COLOR_OFFICER):format(member.onote);
			elseif( normal and officer ) then
				note = ("%s / %s"):format( (COLOR_GOLD):format(member.note), (COLOR_OFFICER):format(member.onote) );
			end
			
			return note;
		end,
	},
	acmpoints = {
		label = L["Points"],
		brush = function(member)
			local displayPoints = _G.BreakUpLargeNumbers(member.apoints);
			
			-- encolor by threshold
			if( iGuild.db.Column.acmpoints.Color == 2 ) then
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(member.apoints, MAX_ACMPOINTS), displayPoints);
			-- no color
			else
				return (COLOR_GOLD):format(displayPoints);
			end
		end,
	},
	tradeskills = {
		label = L["Tradeskills"],
		brush = function(member)
			local label = "";
			
			for i = 1, 2 do
				if( member["ts"..i] ) then
					label = label..(i == 1 and "" or " ")..("|T%s:%d:%d|t"):format("Interface\\Addons\\iGuild\\Images\\"..member["ts"..i.."tex"], iconSize, iconSize);
					if( iGuild.db.Column.tradeskills.ShowProgress ) then
						if( iGuild.db.Column.tradeskills.Color == 2 ) then
							label = ("%s|cff%s%s|r"):format(label, LibCrayon:GetThresholdHexColor(member["ts"..i.."prog"], MAX_PROFESSION_SKILL), member["ts"..i.."prog"]);
						else
							label = ("%s"..COLOR_GOLD):format(label, member["ts"..i.."prog"]);
						end
					end
				end
			end
			
			return label;
		end,
		canUse = function() return iGuild.db.Column.tradeskills.Enable end,
		script = function(_, member, button)
			if( button == "LeftButton" and member.ts1 and _G.CanViewGuildRecipes(member.ts1id) ) then
				_G.GetGuildMemberRecipes(member.name, member.ts1id);
			elseif( button == "RightButton" and member.ts2 and _G.CanViewGuildRecipes(member.ts2id) ) then
				_G.GetGuildMemberRecipes(member.name, member.ts2id);
			end
		end,
		scriptUse = function(member) return ( member.ts1 and true or false ) end,
	},
	class = {
		label = _G.CLASS,
		brush = function(member)
			if( iGuild.db.Column.class.Icon ) then
				return "|TInterface\\Addons\\iGuild\\Images\\"..member.CLASS..":"..iconSize..":"..iconSize.."|t";
			end
			
			-- encolor by class color
			if( iGuild.db.Column.class.Color == 2 ) then
				return ("|c%s%s|r"):format(_G.RAID_CLASS_COLORS[member.CLASS].colorStr, member.class);
			-- no color
			else
				return (COLOR_GOLD):format(member.class);
			end
		end,
	},
	exp = {
		label = _G.XP,
		brush = function(member)			
			return (COLOR_GOLD):format(
				_G.BreakUpLargeNumbers(math.ceil(member.gxp / 1000))
			);
		end,
	},
	grouped = {
		label = _G.GROUP,
		brush = function(member)
			if( _G.UnitInParty(member.name) or _G.UnitInRaid(member.name) ) then
				return "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:"..iconSize..":"..iconSize.."|t";
			else
				return "";
			end
		end,
		canUse = function()
			return (_G.GetNumGroupMembers() ~= 0 or _G.GetNumSubgroupMembers() ~= 0);
		end,
	}
};

----------------------------
-- UpdateRanksTooltip
----------------------------

function iGuild:UpdateRanksTooltip(tip)
	tip:Clear();
	tip:SetColumnLayout(1, "LEFT");
	
	local rankNum = _G.GuildControlGetNumRanks();
	
	for i = 1, rankNum do
		tip:AddLine( 
			("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(rankNum - i, rankNum - 1), _G.GuildControlGetRankName(i))
			..( i == working_member.grank and " |TInterface\\RAIDFRAME\\ReadyCheck-Ready:"..iconSize..":"..iconSize.."|t" or "")
		);
	end
end
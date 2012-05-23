-----------------------------
-- Get the addon table
-----------------------------

local AddonName = select(1, ...)
local iGuild = LibStub("AceAddon-3.0"):GetAddon(AddonName);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

---------------------------
-- Utility functions
---------------------------

-- a better strsplit function :)
local function strsplit(delimiter, text)
  local list = {}
  local pos = 1
  if strfind("", delimiter, 1) then -- this would result in endless loops
    --error("delimiter matches empty string!")
  end
  while 1 do
    local first, last = strfind(text, delimiter, pos)
    if first then -- found?
      tinsert(list, strsub(text, pos, first-1))
      pos = last+1
    else
      tinsert(list, strsub(text, pos))
      break
    end
  end
  return list
end

---------------------------------
-- The configuration table
---------------------------------

function iGuild:GetConfigColumns()
	self.ConfigColumns = strsplit(",%s*", self.db.Display);
end

local function CreateConfig()
	CreateConfig = nil; -- we just need this function once, thus removing it from memory.

	local db = {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			return iGuild.db.Column[info.arg.k][info.arg.v];
		end,
		set = function(info, value, arg)
			iGuild.db.Column[info.arg.k][info.arg.v] = value;
		end,
		args = {
			Infotext1 = {
				type = "description",
				name = L["iGuild provides some pre-layoutet columns for character names, zones, etc. In order to display them in the tooltip, write their names in the desired order into the beneath input."].."\n",
				fontSize = "medium",
				order = 1,
			},
			Infotext2 = {
				type = "description",
				name = "",
				fontSize = "medium",
				order = 2,
			},
			Display = {
				type = "input",
				name = "",
				order = 3,
				width = "full",
				validate = function(info, value)
					local list = strsplit(",%s*", value);
					for i = 1, #list do
						if( not iGuild.Columns[list[i]] ) then
							return L["Invalid column name!"];
						end
					end
					return true;
				end,
				get = function(info)
					return iGuild.db.Display;
				end,
				set = function(info, value)
					iGuild.db.Display = value;
					iGuild:GetConfigColumns();
					iGuild:GetDisplayedColumns();
				end,
			},
			Sorting = {
				type = "select",
				name = L["Sorting"],
				order = 4,
				values = {
					["name"] = L["By Name"],
					["level"] = L["By Level"],
					["class"] = L["By Class"],
					["rank"] = L["By Guildrank"],
					["points"] = L["By Achievement Points"],
					["zone"] = L["By Zone"],
				},
				get = function() return iGuild.db.Sort end,
				set = function(info, value) iGuild.db.Sort = value end,
			},
			Infotext3 = {
				type = "description",
				name = "\n"..L["Toggle extra information on the LDB feed."],
				fontSize = "medium",
				order = 5,
			},
			ShowGuildName = {
				type = "toggle",
				name = L["Show Guild Name"],
				order = 6,
				get = function() return iGuild.db.ShowGuildName end,
				set = function(info, value) iGuild.db.ShowGuildName = value end,
			},
			ShowGuildMOTD = {
				type = "toggle",
				name = _G.GUILD_MOTD,
				order = 7,
				width = "double",
				get = function() return iGuild.db.ShowGuildMOTD end,
				set = function(info, value) iGuild.db.ShowGuildMOTD = value end,
			},
			ShowGuildLevel = {
				type = "toggle",
				name = L["Show Guild Level"],
				order = 8,
				get = function() return iGuild.db.ShowGuildLevel end,
				set = function(info, value) iGuild.db.ShowGuildLevel = value end,
			},
			ShowGuildXP = {
				type = "toggle",
				name = L["Show Guild XP"],
				order = 9,
				get = function() return iGuild.db.ShowGuildXP end,
				set = function(info, value) iGuild.db.ShowGuildXP = value end,
			},
			Spacer2 = {
				type = "description",
				name = " ",
				order = 10,
			},
			Column_level = {
				type = "group",
				name = L["Level"],
				order = 11,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "level", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "level", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = COLOR,
						order = 3,
						values = {
							[1] = _G.NONE,
							[2] = L["By Difficulty"],
							[3] = L["By Threshold"],
						},
						arg = {k = "level", v = "Color"},
					},
				},
			},
			Column_name = {
				type = "group",
				name = L["Name"],
				order = 12,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "name", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "name", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 3,
						values = {
							[1] = _G.NONE,
							[2] = L["By Class"],
						},
						arg = {k = "name", v = "Color"},
					},
				},
			},
			Column_zone = {
				type = "group",
				name = L["Zone"],
				order = 13,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "zone", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "zone", v = "Align"},
					},
				},
			},
			Column_rank = {
				type = "group",
				name = L["Rank"],
				order = 13,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "rank",v = "ShowLabel"},
					},
					EnableScript = {
						type = "toggle",
						name = L["Enable Script"],
						desc = L["If activated, clicking on the given cell will result in something special."],
						order = 2,
						arg = {k = "rank", v = "EnableScript"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 3,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "rank", v = "Align"},
					},
					EmptyLine = {
						type = "description",
						name = "",
						width = "full",
						order = 4,
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 5,
						values = {
							[1] = _G.NONE,
							[2] = L["By Threshold"],
						},
						arg = {k = "rank", v = "Color"},
					},
				},
			},
			Column_note = {
				type = "group",
				name = L["Note"],
				order = 14,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "note", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "note", v = "Align"},
					},
				},
			},
			Column_officernote = {
				type = "group",
				name = L["OfficerNote"],
				order = 15,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "officernote", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "officernote", v = "Align"},
					},
				},
			},
			Column_notecombi = {
				type = "group",
				name = L["Note"].."**",
				order = 16,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "notecombi", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "notecombi", v = "Align"},
					},
				},
			},
			Column_acmpoints = {
				type = "group",
				name = L["Points"],
				order = 17,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "acmpoints", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "acmpoints", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 3,
						values = {
							[1] = _G.NONE,
							[2] = L["By Threshold"],
						},
						arg = {k = "acmpoints", v = "Color"},
					},
				},
			},
			Column_tradeskills = {
				type = "group",
				name = L["TradeSkills"],
				order = 18,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "tradeskills", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "tradeskills", v = "Align"},
					},
					EnableScript = {
						type = "toggle",
						name = L["Enable Script"],
						desc = L["If activated, clicking on the given cell will result in something special."],
						order = 3,
						width = "full",
						arg = {k = "tradeskills", v = "EnableScript"},
					},
					EnableOption = {
						type = "toggle",
						name = "|cffff0000"..L["Enable TradeSkills"].."|r",
						width = "full",
						order = 4,
						arg = {k = "tradeskills", v = "Enable"},
					},
					Infotext1 = {
						type = "description",
						name = "|cffff0000"..L["Querying tradeskills needs extra memory. This is why you explicitly have to enable that. Don't forget to reload your UI!"].."\n",
						fontSize = "medium",
						order = 5,
					},
				},
			},
			Column_class = {
				type = "group",
				name = L["Class"],
				order = 19,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "class", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "class", v = "Align"},
					},
					UseIcon = {
						type = "toggle",
						name = L["Use Icon"],
						order = 3,
						arg = {k = "class", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 4,
						values = {
							[1] = _G.NONE,
							[2] = L["By Class"],
						},
						arg = {k = "class", v = "Color"},
					},
				},
			},
			Column_exp = {
				type = "group",
				name = XP,
				order = 20,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "exp", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "exp", v = "Align"},
					},
				},
			},
			Column_grouped = {
				type = "group",
				name = _G.GROUP,
				order = 21,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "grouped", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "grouped", v = "Align"},
					},
				},
			},
		},
	};
	
	local colnames = {};
	for k, _ in pairs(iGuild.Columns) do
		table.insert(colnames, k);
	end
	
	db.args.Infotext2.name = ("%s: |cfffed100%s|r\n"):format(
		L["Available columns"],
		table.concat(colnames, ", ")
	);
	
	return db;
end

function iGuild:CreateDB()
	iGuild.CreateDB = nil;
	
	return { profile = {
		Display = "grouped, level, class, name, zone, rank",
		Sort = "name",
		ShowGuildName = false,
		ShowGuildMOTD = false,
		ShowGuildLevel = false,
		ShowGuildXP = false,
		Column = {
			level = {
				ShowLabel = false,
				Align = "RIGHT",
				Color = 2,
			},
			name = {
				ShowLabel = true,
				Align = "LEFT",
				Color = 2,
			},
			zone = {
				ShowLabel = true,
				Align = "CENTER",
			},
			rank = {
				ShowLabel = true,
				Align = "LEFT",
				Color = 1,
				EnableScript = true,
			},
			note = {
				ShowLabel = true,
				Align = "LEFT",
			},
			officernote = {
				ShowLabel = true,
				Align = "LEFT",
			},
			notecombi = {
				ShowLabel = true,
				Align = "LEFT",
			},
			acmpoints = {
				ShowLabel = true,
				Align = "CENTER",
				Color = 1,
			},
			tradeskills = {
				ShowLabel = true,
				Align = "CENTER",
				Enable = false,
				EnableScript = true,
			},
			class = {
				ShowLabel = true,
				Align = "LEFT",
				Icon = true,
				Color = 2,
			},
			exp = {
				ShowLabel = true,
				Align = "LEFT",
			},
			grouped = {
				ShowLabel = false,
				Align = "RIGHT",
			},
		},
	}};
end

function iGuild:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, CreateConfig);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IGUILD"] = iGuild.OpenOptions;
_G["SLASH_IGUILD1"] = "/iguild";
-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iGuild = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local Dialog = LibStub("LibDialog-1.0");

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local cfg; -- this stores our configuration GUI

local COLOR_RED  = "|cffff0000%s|r";
local COLOR_GREEN= "|cff00ff00%s|r";

---------------------------
-- The options table
---------------------------

function iGuild:CreateDB()
	iGuild.CreateDB = nil;
	
	return { profile = {
		Display = "grouped, level, class, name, zone, rank",
		Sort = "level_desc",
		ShowGuildName = true,
		ShowGuildMOTD = false,
		ShowLabels = true, -- this option can just be set by the mod itself
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
			class = {
				ShowLabel = false,
				Align = "LEFT",
				Icon = true,
				Color = 2,
			},
			grouped = {
				ShowLabel = false,
				Align = "RIGHT",
			},
		},
	}};
end

---------------------------------
-- The configuration table
---------------------------------

local function sort_colored_columns(a, b) return a < b end
local function show_colored_columns()
	local cols = {};
	
	local configuredColumns = {};
	if( iGuild.db and iGuild.db.Display ) then
		configuredColumns = {strsplit(",", iGuild.db.Display)};
		
		for k, v in pairs(configuredColumns) do
			configuredColumns[k] = strtrim(v);
		end
	end
	
	for k, _ in pairs(iGuild.Columns) do
		table.insert(cols, (_G.tContains(configuredColumns, k) and COLOR_GREEN or COLOR_RED):format(k) );
	end
	table.sort(cols, sort_colored_columns);
	
	cfg.args.Infotext2.name = ("%s: |cfffed100%s|r\n"):format(
		L["Available columns"],
		table.concat(cols, ", ")
	);
	
	local clean, prefix, suffix;
	for i, v in ipairs(cols) do
		clean  = v:sub(11,-3); -- **
		prefix = v:sub(1, 10); -- since I formatted the string to spare out another table, we need some CPU here. :-P
		suffix = v:sub(-3, 0); -- **
		cfg.args["Column_"..clean].name = prefix..iGuild.Columns[clean].label..suffix;
	end
end
-- for usage once
iGuild.show_colored_columns = show_colored_columns;

local function check_labels_hide()
	local show = false;
	
	for i, v in ipairs(iGuild.DisplayedColumns) do
		if( iGuild.db.Column[v].ShowLabel ) then
			show = true;
			break;
		end
	end
	
	iGuild.db.ShowLabels = show;
end

cfg = {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			if( not info.arg ) then
				return iGuild.db[info[#info]];
			else
				return iGuild.db.Column[info.arg.k][info.arg.v];
			end
		end,
		set = function(info, value)
			if( not info.arg ) then
				iGuild.db[info[#info]] = value;
			else
				iGuild.db.Column[info.arg.k][info.arg.v] = value;
				if( info[#info] == "ShowLabel" ) then
					check_labels_hide();
				end
			end
		end,
		args = {
			Header1 = {
				type = "header",
				name = L["Plugin Options"],
				order = 2,
			},
			ShowGuildName = {
				type = "toggle",
				name = L["Show Guild Name"],
				order = 5,
			},
			Spacer2 = {
				type = "description",
				name = " ",
				fontSize = "small",
				order = 20,
			},
			Header2 = {
				type = "header",
				name = L["Tooltip Options"],
				order = 30,
			},
			Infotext1 = {
				type = "description",
				name = L["iGuild provides some pre-layoutet columns for character names, zones, etc. In order to display them in the tooltip, write their names in the desired order into the beneath input."].."\n",
				fontSize = "medium",
				order = 40,
			},
			Infotext2 = {
				type = "description",
				name = "",
				fontSize = "small",
				order = 50,
			},
			Display = {
				type = "input",
				name = "",
				order = 60,
				width = "full",
				validate = function(info, value)
					local list = {strsplit(",", value)};
					
					for i, v in ipairs(list) do
						if( not iGuild.Columns[strtrim(v)] ) then
							Dialog:Spawn("iGuildFriendsColumnError");
							return L["Invalid column name!"];
						end
					end
					
					return true;
				end,
				set = function(info, value)
					iGuild.db.Display = value;
					iGuild:GetDisplayedColumns();
					show_colored_columns();
				end,
			},
			ShowGuildMOTD = {
				type = "toggle",
				name = _G.GUILD_MOTD,
				order = 80,
				--width = "double",
			},
			Sort = {
				type = "select",
				name = L["Sorting"],
				order = 90,
				width = "double",
				values = {
					["classic"] = "Classic",
					["name_asc"] = L["By Name"].." "..L["ASC"],
					["level_asc"] = L["By Level"].." "..L["ASC"],
					["level_desc"] = L["By Level"].." "..L["DESC"],
					["class_asc"] = L["By Class"].." "..L["ASC"],
					["class_desc"] = L["By Class"].." "..L["DESC"],
					["rank_asc"] = L["By Guildrank"].." "..L["ASC"],
					["rank_desc"] = L["By Guildrank"].." "..L["DESC"],
					["zone_asc"] = L["By Zone"].." "..L["ASC"],
					["zone_desc"] = L["By Zone"].." "..L["DESC"],
				},
			},			
			Spacer3 = {
				type = "description",
				name = " ",
				order = 100,
			},
			Column_grouped = {
				type = "group",
				name = "",
				order = 110,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the following green icon when you are grouped with guild mates:"].." |TInterface\\RAIDFRAME\\ReadyCheck-Ready:14:14|t\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "grouped", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "grouped", v = "Align"},
					},
				},
			},
			Column_level = {
				type = "group",
				name = "",
				order = 120,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the level of your guild mates."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "level", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
						values = {
							[1] = _G.NONE,
							[2] = L["By Difficulty"],
							[3] = L["By Threshold"],
						},
						arg = {k = "level", v = "Color"},
					},
				},
			},
			Column_class = {
				type = "group",
				name = "",
				order = 130,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the class of your guild mates. Choose whether to show the class name or the class icon."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "class", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
						arg = {k = "class", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 20,
						values = {
							[1] = _G.NONE,
							[2] = L["By Class"],
						},
						arg = {k = "class", v = "Color"},
					},
				},
			},
			Column_name = {
				type = "group",
				name = "",
				order = 140,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the name of your guild mates. In addition, a short info is shown if they are AFK or DND."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "name", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
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
				name = "",
				order = 150,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the zone of your guild mates."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "zone", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
				name = "",
				order = 170,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the guild rank of your guild mates."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "rank",v = "ShowLabel"},
					},
					EnableScript = {
						type = "toggle",
						name = L["Enable Script"],
						desc = L["If activated, clicking on the given cell will result in something special."],
						order = 10,
						arg = {k = "rank", v = "EnableScript"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 15,
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
						order = 20,
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 25,
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
				name = "",
				order = 180,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the public note of your guild mates."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "note", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
				name = "",
				order = 190,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the officer note of your guild mates, if you can see it. The whole column is not shown otherwise."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "officernote", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
				name = "",
				order = 200,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays both public and officer notes of your guild mates in a single column."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "notecombi", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "notecombi", v = "Align"},
					},
				},
			},
		},
};
show_colored_columns();

function iGuild:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, cfg);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IGUILD"] = iGuild.OpenOptions;
_G["SLASH_IGUILD1"] = "/iguild";

Dialog:Register("iGuildFriendsColumnError", {
	text = L["Invalid column name!"],
	hide_on_escape = true,
	duration = 3,
	buttons = {
		{text = _G.OKAY},
	},
});
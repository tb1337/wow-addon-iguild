-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iGuild = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

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
		Sort = "name",
		ShowGuildName = true,
		ShowGuildMOTD = false,
		ShowGuildLevel = false,
		ShowGuildXP = false,
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
			acmpoints = {
				ShowLabel = true,
				Align = "LEFT",
				Color = 1,
			},
			tradeskills = {
				ShowLabel = false,
				Align = "CENTER",
				Enable = false,
				EnableScript = true,
				ShowProgress = true,
				Color = 2,
			},
			class = {
				ShowLabel = false,
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

---------------------------------
-- The configuration table
---------------------------------

local function sort_colored_columns(a, b) return a < b end
local function show_colored_columns()
	local cols = {};
	
	for k, _ in pairs(iGuild.Columns) do
		table.insert(cols, (_G.tContains(iGuild.DisplayedColumns, k) and COLOR_GREEN or COLOR_RED):format(k) );
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
			ShowGuildLevel = {
				type = "toggle",
				name = L["Show Guild Level"],
				order = 10,
			},
			ShowGuildXP = {
				type = "toggle",
				name = L["Show Guild XP"],
				order = 15,
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
							_G.StaticPopup_Show("IADDONS_ERROR_CFG");
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
				width = "double",
			},
			Sort = {
				type = "select",
				name = L["Sorting"],
				order = 90,
				values = {
					["name"] = L["By Name"],
					["level"] = L["By Level"],
					["class"] = L["By Class"],
					["rank"] = L["By Guildrank"],
					["points"] = L["By Achievement Points"],
					["zone"] = L["By Zone"],
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
			Column_tradeskills = {
				type = "group",
				name = "",
				order = 160,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the tradeskills of your guild mates as little icons. Be sure to activate the red option if you want to use it."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "tradeskills", v = "ShowLabel"},
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
						arg = {k = "tradeskills", v = "Align"},
					},
					ShowProgress = {
						type = "toggle",
						name = L["Show Progress"],
						order = 15,
						arg = {k = "tradeskills", v = "ShowProgress"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 20,
						values = {
							[1] = _G.NONE,
							[2] = L["By Threshold"],
						},
						arg = {k = "tradeskills", v = "Color"},
					},
					EnableScript = {
						type = "toggle",
						name = L["Enable Script"],
						desc = L["If activated, clicking on the given cell will result in something special."],
						order = 25,
						width = "full",
						arg = {k = "tradeskills", v = "EnableScript"},
					},
					EnableOption = {
						type = "toggle",
						name = "|cffff0000"..L["Enable Tradeskills"].."|r",
						width = "full",
						order = 30,
						arg = {k = "tradeskills", v = "Enable"},
					},
					Infotext1 = {
						type = "description",
						name = "|cffff0000"..L["Querying tradeskills needs extra memory. This is why you explicitly have to enable that. Don't forget to reload your UI!"].."\n",
						fontSize = "medium",
						order = 35,
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
			Column_acmpoints = {
				type = "group",
				name = "",
				order = 210,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the achievement points of your guild mates."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "acmpoints", v = "ShowLabel"},
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
						arg = {k = "acmpoints", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 15,
						values = {
							[1] = _G.NONE,
							[2] = L["By Threshold"],
						},
						arg = {k = "acmpoints", v = "Color"},
					},
				},
			},
			Column_exp = {
				type = "group",
				name = "",
				order = 220,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the guild exp contributed by your guild mates. The displayed number is divided by 1000."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "exp", v = "ShowLabel"},
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
						arg = {k = "exp", v = "Align"},
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

_G.StaticPopupDialogs["IADDONS_ERROR_CFG"] = {
	preferredIndex = 3, -- apparently avoids some UI taint
	text = L["Invalid column name!"],
	button1 = _G.OKAY,
	showAlert = 1,
	timeout = 2.5,
	hideOnEscape = true,
};
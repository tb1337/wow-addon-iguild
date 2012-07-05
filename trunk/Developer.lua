-----------------------------
-- Get the addon table
-----------------------------

local AddonName = select(1, ...);
local iGuild = LibStub("AceAddon-3.0"):GetAddon(AddonName);

----------------------------
-- Achievement Points
----------------------------

-- Cataclysm
-- Patch 4.3.4 = 15250

----------------------------

-- Mists of Pandaria
-- Patch 5.0.1 = 19540

----------------------------
----------------------------

local achievements = {};

function iGuild:CountAchievements()
	local cats = _G.GetCategoryList();
	
	local numAchs = 0;
	local numPoints = 0;
	
	for i, v in ipairs(cats) do
		if( v == 81 ) then -- Feets of Strength
			table.remove(cats, i);
		end
	end
	
	for i, category in ipairs(cats) do
		local catName, catParent, catUnknown = _G.GetCategoryInfo(category);
		local catTotal, catCompleted = _G.GetCategoryNumAchievements(category);
		
		for ach = 1, catTotal do
			local achID, achName, achPoints, achComplete, _, _, _, _, achFlags, _, _ = _G.GetAchievementInfo(category, ach);
			local thisID = achID;
			
			if( not achievements[achID] ) then
				achievements[achID] = achPoints;
				numAchs = numAchs + 1;
				numPoints = numPoints + achPoints;
			end
			
			local prev = thisID;
			while( _G.GetPreviousAchievement(prev) ) do
				prev = _G.GetPreviousAchievement(prev);
				if( not achievements[prev] ) then
					achID, achName, achPoints, achComplete, _, _, _, _, achFlags, _, _ = _G.GetAchievementInfo(prev);
					achievements[achID] = achPoints;
					numAchs = numAchs + 1;
					numPoints = numPoints + achPoints;
				end
			end
			
			prev = thisID;
			while( _G.GetNextAchievement(prev) ) do
				prev = _G.GetNextAchievement(prev);
				if( not achievements[prev] ) then
					achID, achName, achPoints, achComplete, _, _, _, _, achFlags, _, _ = _G.GetAchievementInfo(prev);
					achievements[achID] = achPoints;
					numAchs = numAchs + 1;
					numPoints = numPoints + achPoints;
				end
			end
		end
	end
	
	print("[Dev] Total Achievements: "..numAchs);
	print("[Dev] Total Achievement Points: "..numPoints);
end
-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iGuild = ...;

----------------------------
-- Achievement Points
----------------------------

-- Cataclysm
-- Patch 4.3.4 = 15250

----------------------------

-- Mists of Pandaria
-- Patch 5.0.1 = 19540
-- Patch 5.0.4 = 19465
-- Patch 5.0.4 = 19470
-- Patch 5.1.0 = 19800
-- Patch 5.2.0 = 20745
-- Patch 5.4.0 = 21985
-- Patch 5.4.1 = 21995

----------------------------

-- Warlords of Draenor
-- Patch 6.0.2 = 24635
-- Patch 6.1.0 = 24990

----------------------------

-- Legion
-- Patch 7.0.3 = 27590
-- Patch 7.2.0 = 28990
-- Patch 7.3.0 = 29145

----------------------------

-- Battle for Azeroth
-- Patch 8.0.1 = 30960
-- Patch 8.1.0 = 31495
-- Patch 8.2.0 = 32850

----------------------------
----------------------------

local achievements = {};

function iGuild:CountAchievements()
	local cats = _G.GetCategoryList();
	
	local numAchs = 0;
	local numPoints = 0;
	
	local catName, catParent, catUnknown, catTotal, catCompleted, achID, achName, achPoints, achComplete, _, achFlags, thisID;
	
	for i, v in ipairs(cats) do
		if( v == 81 or v == 15234 ) then -- Feets of Strength or Classic achievements
			table.remove(cats, i);
		end
	end
	
	for i, category in ipairs(cats) do
		catName, catParent, catUnknown = _G.GetCategoryInfo(category);
		catTotal, catCompleted = _G.GetCategoryNumAchievements(category);
		
		for ach = 1, catTotal do
			achID, achName, achPoints, achComplete, _, _, _, _, achFlags, _, _ = _G.GetAchievementInfo(category, ach);
			thisID = achID;
			
			if( achID ) then
			
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
	end
	
	print("[Dev] Total Achievements: "..numAchs);
	print("[Dev] Total Achievement Points: "..numPoints);
end
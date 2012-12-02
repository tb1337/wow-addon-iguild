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

----------------------------
----------------------------

local achievements = {};

function iGuild:CountAchievements()
	local cats = _G.GetCategoryList();
	
	local numAchs = 0;
	local numPoints = 0;
	
	local catName, catParent, catUnknown, catTotal, catCompleted, achID, achName, achPoints, achComplete, _, achFlags, thisID;
	
	for i, v in ipairs(cats) do
		if( v == 81 ) then -- Feets of Strength
			table.remove(cats, i);
		end
	end
	
	for i, category in ipairs(cats) do
		catName, catParent, catUnknown = _G.GetCategoryInfo(category);
		catTotal, catCompleted = _G.GetCategoryNumAchievements(category);
		
		for ach = 1, catTotal do
			achID, achName, achPoints, achComplete, _, _, _, _, achFlags, _, _ = _G.GetAchievementInfo(category, ach);
			thisID = achID;
			
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
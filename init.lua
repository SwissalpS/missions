
local MP = minetest.get_modpath("missions")

missions = {
	list={} -- playername -> missionObj[]
}

dofile(MP.."/functions.lua")
dofile(MP.."/hud.lua")

-- mission blocks
dofile(MP.."/transport.lua")
dofile(MP.."/kill.lua")
dofile(MP.."/walk.lua")
dofile(MP.."/goto.lua")
dofile(MP.."/dig.lua")
dofile(MP.."/craft.lua")

-- target chest
dofile(MP.."/chest.lua")

print("[OK] Missions")
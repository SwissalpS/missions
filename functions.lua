local has_xp_redo_mod = minetest.get_modpath("xp_redo")

missions.is_book = function(stack)
	return stack:get_count() == 1 and stack:get_name() == "default:book_written"
end

missions.pos_equal = function(pos1, pos2)
	return pos1.x == pos2.x and pos1.y == pos2.y and pos1.z == pos2.z
end

missions.save_missions = function()
	-- TODO
end

missions.load_missions = function()
	-- TODO
end

-- create a book for given pos and title
missions.pos_to_book = function(pos, title)
	minetest.pos_to_string(pos)

	local stack = ItemStack("default:book_written")
	local stackMeta = stack:get_meta()

	local data = {}

	data.owner = "missions"
	data.title = title or "Coordinate"
	data.description = data.title
	data.text = minetest.serialize({x=pos.x, y=pos.y, z=pos.z, title=data.title})
	data.page = 1
	data.page_max = 1

	stack:get_meta():from_table({ fields = data })

	return stack
end

-- parse a position from a book stack (returns pos+title)
missions.book_to_pos = function(bookstack)
	if not bookstack or not missions.is_book(bookstack) then
		return
	end

	local meta = bookstack:get_meta()
	if not meta:get_string("owner") == "missions" then
		return
	end

	return minetest.deserialize(meta:get_string("text"))
end

missions.start_mission = function(player, mission)

	local playername = player:get_player_name()

	-- mark start of mission
	local now = os.time(os.date("!*t"))
	mission.start = now

	if mission.cooldown and mission.cooldown > 0 then
		-- check cooldown timer
		last_time = missions.cooldown_get(mission.name, playername)

		if last_time > 0 and last_time < mission.cooldown then
			local remaining = mission.cooldown - last_time
			minetest.chat_send_player(playername, "Mission not cooled down, wait " .. remaining .. " seconds")
			return
		end
	end

	-- print(dump(mission)) --XXX


	if has_xp_redo_mod and mission.entryxp then
		local xp = xp_redo.get_xp(playername)
		if xp < mission.entryxp then
			minetest.chat_send_player(playername, "Not enough xp for mission, needed: " .. mission.entryxp)
			return
		end
	end

	local playermissions = missions.list[playername]
	if playermissions == nil then playermissions = {} end

	for i,m in pairs(playermissions) do
		if m.name == mission.name then
			minetest.chat_send_player(playername, "Mission already running: " .. mission.name)
			return
		end
	end

	table.insert(playermissions, mission)

	missions.list[playername] = playermissions
	missions.save_missions()
end

missions.remove_mission = function(player, mission)
	local playername = player:get_player_name()
	local playermissions = missions.list[playername]
	if playermissions == nil then playermissions = {} end

	for i,m in pairs(playermissions) do
		if m.name == mission.name then
			table.remove(playermissions, i)
			return
		end
	end
end



local check_player_mission = function(player, mission, remaining)
	if remaining <= 0 then
		-- mission timed-out
		missions.hud_remove_mission(player, mission)
		missions.remove_mission(player, mission)
		minetest.chat_send_player(player:get_player_name(), "Mission timed out!: " .. mission.name)
		minetest.log("action", "[missions] " .. player:get_player_name() .. " -- mission timed out: " .. mission.name)

		if has_xp_redo_mod and mission.xp and mission.xp.penalty ~= nil then
			xp_redo.add_xp(player:get_player_name(), -mission.xp.penalty)
		end

	end

	local finished = false;

	if mission.type == "transport" or mission.type == "build" or mission.type == "dig" or mission.type == "craft" then
		-- check transport list
		local openCount = 0
		for i,itemStr in pairs(mission.context.list) do
			-- check if items placed
			local stack = ItemStack(itemStr)
			if not stack:is_empty() then
				openCount = openCount + 1
			end
		end

		if openCount == 0 then
			finished = true
		end
	end

	if finished then
		-- mission finished

		-- reset cooldown timer
		missions.cooldown_reset(mission.name, player:get_player_name())

		missions.hud_remove_mission(player, mission)
		missions.remove_mission(player, mission)
		minetest.chat_send_player(player:get_player_name(), "Mission finished: " .. mission.name)
		minetest.log("action", "[missions] " .. player:get_player_name() .. " -- mission finished: " .. mission.name)

		minetest.sound_play({name="missions_generic", gain=0.25}, {to_player=player:get_player_name()})


		local one = player:hud_add({
			hud_elem_type = "image",
			name = "award_bg",
			scale = {x = 2, y = 1},
			text = "missions_bg_default.png",
			position = {x = 0.5, y = 0},
			offset = {x = 0, y = 138},
			alignment = {x = 0, y = -1}
		})

		local two = player:hud_add({
			hud_elem_type = "text",
			name = "award_au",
			number = 0xFFFFFF,
			scale = {x = 100, y = 20},
			text = "Mission complete!",
			position = {x = 0.5, y = 0},
			offset = {x = 0, y = 40},
			alignment = {x = 0, y = -1}
		})

		local three = player:hud_add({
			hud_elem_type = "text",
			name = "award_title",
			number = 0xFFFFFF,
			scale = {x = 100, y = 20},
			text = mission.name,
			position = {x = 0.5, y = 0},
			offset = {x = 30, y = 100},
			alignment = {x = 0, y = -1}
		})

		local four = player:hud_add({
			hud_elem_type = "image",
			name = "award_icon",
			scale = {x = 4, y = 4},
			text = "default_gold_ingot.png",
			position = {x = 0.4, y = 0},
			offset = {x = -81.5, y = 126},
			alignment = {x = 0, y = -1}
		})

		minetest.after(4, function()
			player:hud_remove(one)
			player:hud_remove(two)
			player:hud_remove(three)
			player:hud_remove(four)
		end)

		if has_xp_redo_mod and mission.xp and mission.xp.reward then
			xp_redo.add_xp(player:get_player_name(), mission.xp.reward)
		end


		local inv = player:get_inventory()
		for i,stackStr in pairs(mission.reward.list) do
			-- reward player
			local stack = ItemStack(stackStr)
			inv:add_item("main", stack)
		end
	end
end

-- timeout check
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 1 then
		local now = os.time(os.date("!*t"))
		local players = minetest.get_connected_players()
		for i,player in pairs(players) do
			local playername = player:get_player_name()
			local playermissions = missions.list[playername]
			if playermissions ~= nil then
				for j,mission in pairs(playermissions) do
					local remaining = mission.time - (now - mission.start)

					check_player_mission(player, mission, remaining)
				end
			end
			missions.hud_update(player, playermissions)
		end

		timer = 0
	end
end)



-- transport, dig, craft, build mission
-- returns count of items moved to target (if any)
missions.update_mission = function(player, mission, stack)

	minetest.log("action", "[missions] " .. player:get_player_name() .. " updates context items: " .. stack:to_string())
	local count = 0

	for i,targetStackStr in pairs(mission.context.list) do
		local targetStack = ItemStack(targetStackStr)

		if targetStack:get_name() == stack:get_name() then
			-- same type
			local takenStack = targetStack:take_item(stack:get_count())

			-- update current stack
			stack:set_count(stack:get_count() - takenStack:get_count())

			-- update return stack
			count = count + takenStack:get_count()

			-- save remaining stack
			mission.context.list[i] = targetStack:to_string()
		end
	end

	return count
end


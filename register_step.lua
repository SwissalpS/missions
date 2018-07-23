
missions.steps = {}

missions.register_step = function(spec)
	table.insert(missions.steps, spec)
end

missions.get_step_spec_by_type = function(type)
	for i,spec in ipairs(missions.steps) do
		if type == spec.type then
			-- step spec found
			return spec			
		end
	end
end

local FORMNAME = "mission_block_editstep"

missions.show_step_editor = function(pos, node, player, stepnumber, step, stepdata)
	for i,spec in ipairs(missions.steps) do
		if spec.type == step.type then
			local formspec = spec.edit_formspec(pos, node, player, stepnumber, step, stepdata)

			minetest.show_formspec(player:get_player_name(),
				FORMNAME .. ";" .. minetest.pos_to_string(pos) .. ";" .. stepnumber .. ";" .. spec.type,
				formspec
			)
		end
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local parts = formname:split(";")
	local name = parts[1]
	if name ~= FORMNAME then
		return
	end

	-- TODO: priv/player check

	local pos = minetest.string_to_pos(parts[2])
	local node = minetest.get_node(pos)
	local stepnumber = tonumber(parts[3])
	local spectype = parts[4]

	local steps = missions.get_steps(pos)

	local step = steps[stepnumber]
	local stepdata = step.data

	for i,spec in ipairs(missions.steps) do
		if spec.type == spectype then
			local show_editor = function()
				minetest.after(0.1, function()
					missions.show_step_editor(pos, node, player, stepnumber, step, stepdata)
				end)
			end

			local show_mission = function()
				minetest.after(0.1, function()
					missions.form.missionblock(pos, node, player)
				end)
			end

			spec.update(fields, player, step, stepdata, show_editor, show_mission)

			-- write back data
			missions.set_steps(pos, steps)
		end
	end
	

end)



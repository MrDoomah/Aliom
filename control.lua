require "util"
function print(s)
	for _,player in pairs(game.players) do
		player.print(s)
	end
end
function dbg(s)
	print("aliom: " .. s)
	log("aliom: " .. s)
end


-- init
function init()
	global.resources = global.resources or {}
	global.start_area = global.start_area or {} -- no infinite resources in starting area
	global.start_area_size = {["none"] = 0, ["very-low"] = 150,  ["low"] = 250, ["normal"] = 350, ["high"] = 500, ["very-high"] = 700}
	global.resource_amount = global.resource_amount or {} -- The first count of infinite resources should reflect the map_gen_settings
	global.resource_richness = global.resource_richness or {}
	global.resource_richness.default = {["none"] = 0, ["very-low"] = 1.5, ["low"] = 3, ["normal"] = 5, ["high"] = 7, ["very-high"] = 9}
	for name, entity in pairs(game.entity_prototypes) do
		if entity.type == "resource" and not entity.infinite_resource and game.entity_prototypes[entity.name .. "-infinite"] then
			global.resources[entity.name] = global.resources[entity.name] or {}
			global.resource_amount[entity.name] = global.resource_amount[entity.name] or {}
		end
	end
	global.inf_resource_chance = global.inf_resource_chance or {}
	global.inf_resource_chance.default = 1/5
	
	global.direction = {[-1] = {[-1] = defines.direction.northwest, [0] = defines.direction.west, [1] = defines.direction.southwest}, 
						[0] = {[-1] = defines.direction.north, [0] = -1, [1] = defines.direction.south}, 
						[1] = {[-1] = defines.direction.northeast, [0] = defines.direction.east, [1] = defines.direction.southeast}}
	global.tiles_to_check = {[defines.direction.northwest] = {{dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}, {dx = 0, dy = -1}, {dx = 1, dy = -1}}, 
							[defines.direction.north] = {{dx = -1, dy = -1}, {dx = 0, dy = -1}, {dx = 1, dy = -1}}, 
							[defines.direction.northeast] = {{dx = -1, dy = -1}, {dx = 0, dy = -1}, {dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1}}, 
							[defines.direction.east] = {{dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1}}, 
							[defines.direction.southeast] = {{dx = 1, dy = -1}, {dx = 1, dy = 0}, {dx = 1, dy = 1}, {dx = 0, dy = 1}, {dx = -1, dy = 1}}, 
							[defines.direction.south] = {{dx = 1, dy = 1}, {dx = 0, dy = 1}, {dx = -1, dy = 1}}, 
							[defines.direction.southwest] = {{dx = 1, dy = 1}, {dx = 0, dy = 1}, {dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}}, 
							[defines.direction.west] = {{dx = -1, dy = 1}, {dx = -1, dy = 0}, {dx = -1, dy = -1}}
							}
end

function add_resource(name, richness, chance)
	-- name is resource entity name
	-- richness is table, see global.resource_richness.default ^^
	-- chance is the chance that an ore patch is infinite between 0 - 1 (0 = 0%, 1 = 100%)
	-- Leave richness and chance nil for default values
    
	-- logging new ore, for debugging
	local s = "aliom:\n  Adding resource: " .. tostring(name) .. "\n  Chance: " .. tostring(chance) .. "\n  Richness: "
	if type(richness) == "table" then
		for k,v in pairs(richness) do
			s = s .."\n    " .. tostring(k) .. ": " .. tostring(v)
		end
	else
		s = s .. tostring(richness)
	end
	log(s)
	
	-- fill in unspecified fields
	if not global.resources then init() end
	if not chance then chance = global.inf_resource_chance.default end
	if not richness or type(richness) ~= "table" then richness = global.resource_richness.default end
	
	
	if game.entity_prototypes[name].type == "resource" and not game.entity_prototypes[name].infinite_resource and game.entity_prototypes[name .. "-infinite"] then
		global.resource_richness[name] = util.table.deepcopy(richness)
		global.inf_resource_chance[name] = chance
		global.resources[name] = global.resources[name] or {}
		global.resource_amount[name] = global.resource_amount[name] or {}
		for _, surface in pairs(game.surfaces) do
			local richness = "normal"
			if surface.map_gen_settings.autoplace_controls[name] then
				local richness = surface.map_gen_settings.autoplace_controls[name].richness
			elseif resource.prototype.autoplace_specification then
				local richness = game.surfaces["nauvis"].map_gen_settings.autoplace_controls[name].richness
			end
			global.resource_amount[name][surface.name] = global.resource_richness[name][richness] * game.entity_prototypes[name .. "-infinite"].minimum_resource_amount
		end
	end	
end

script.on_init(init)
script.on_configuration_changed(init)


-- for other mods to add custom values for inf chance and richness do:
-- for name,version in pairs(game.active_mods) do
	-- if name == "aliom" and remote.interfaces.aliom.add_resource then 
		-- remote.call("aliom","add_resource",<ore name>, <richness table>, <infinite chance>})
		-- break
	-- end
-- end
remote.add_interface("aliom", {init = init, add_resource = add_resource})



-- create inf resource patches
function find_field(resource)
	local field = {ores = {resource}}
	local new_ores = {{ore = resource, direction = -1}}
	-- find touching ores (incl diagonals)
	repeat
		local added = false
		
		for i, data in ipairs(new_ores) do
			if data.direction == -1 then
				for dx = -1,1 do
					for dy = -1,1 do
						if dx ~= 0 or dy ~= 0 then
							local position = data.ore.position
							local entities = resource.surface.find_entities_filtered{area = {{math.floor(position.x) +dx,math.floor(position.y) +dy},{math.ceil(position.x) +dx,math.ceil(position.y) +dy}}, name = resource.name} -- Resources don't always spawn in the center of the tile, so position = ore.position doesn't work.
							for _,entity in pairs(entities) do
								table.insert(field.ores,entity)
								table.insert(new_ores,{ore = entity, direction = global.direction[dx][dy]})
								added = true
							end
						end
					end
				end
			else
				for j,relative_position in pairs(global.tiles_to_check[data.direction]) do
					local dx = relative_position.dx
					local dy = relative_position.dy
					local position = data.ore.position
					local entities = resource.surface.find_entities_filtered{area = {{math.floor(position.x) +dx,math.floor(position.y) +dy},{math.ceil(position.x) +dx,math.ceil(position.y) +dy}}, name = resource.name}
					for _,entity in pairs(entities) do
						local new_ore = true
						for k = #field.ores,1,-1 do  -- transverse table in reverse order as new entities will most likely neighbour newly added entities
							if entity == field.ores[k] then
								new_ore = false
								break
							end
						end
						if new_ore then
							table.insert(field.ores,entity)
							table.insert(new_ores,{ore = entity, direction = global.direction[dx][dy]})
							added = true
						end
					end
				end
			end
			table.remove(new_ores,i)
		end
	until not added
	
	-- find the 'center' of the field
	for _,ore in pairs(field.ores) do
		if not field.position then 
			field.position = ore.position
		else
			field.position.x = field.position.x+ore.position.x
			field.position.y = field.position.y+ore.position.y
		end
	end
	field.position.x = field.position.x / #field.ores
	field.position.y = field.position.y / #field.ores
	return field	
end

script.on_event(defines.events.on_resource_depleted, function(event)
	local resource = event.entity
	local surface = resource.surface
	local position = resource.position
	local new_field = false
	if global.resources[resource.name] then
		if global.resources[resource.name][surface.name] then
			if global.resources[resource.name][surface.name][position.x] then
				if not global.resources[resource.name][surface.name][position.x][position.y] then
					new_field = true
				end
			else
				global.resources[resource.name][surface.name][position.x] = {}
				new_field = true
			end
		else
			global.resources[resource.name][surface.name] = {}
			global.resources[resource.name][surface.name][position.x] = {}
			new_field = true
			global.start_area[surface.name] = global.start_area_size[surface.map_gen_settings.starting_area]
			
			local richness = "normal"
			if surface.map_gen_settings.autoplace_controls[resource.name] then
				local richness = surface.map_gen_settings.autoplace_controls[resource.name].richness
			elseif resource.prototype.autoplace_specification then
				local richness = game.surfaces["nauvis"].map_gen_settings.autoplace_controls[resource.name].richness
			end
			if global.resource_richness[resource.name] then
				global.resource_amount[resource.name][surface.name] = global.resource_richness[resource.name][richness] * game.entity_prototypes[resource.name .. "-infinite"].minimum_resource_amount
			else
				global.resource_amount[resource.name][surface.name] = global.resource_richness.default[richness] * game.entity_prototypes[resource.name .. "-infinite"].minimum_resource_amount
			end
		end
		
		if new_field then
			local field = find_field(resource)
			local chance = global.inf_resource_chance[resource.name] or global.inf_resource_chance.default
			if math.random() < chance and util.distance(field.position,{x = 0, y = 0}) > global.start_area[surface.name] then
				for _,ore in pairs(field.ores) do
					local dist = util.distance(ore.position,field.position)
					local ore_value = math.exp(-dist/20) * math.random(global.resource_amount[ore.name][ore.surface.name]*2/3,global.resource_amount[ore.name][ore.surface.name]*3/2)
					global.resources[ore.name][ore.surface.name] = global.resources[ore.name][ore.surface.name] or {}
					global.resources[ore.name][ore.surface.name][ore.position.x] = global.resources[ore.name][ore.surface.name][ore.position.x] or {}
					global.resources[ore.name][ore.surface.name][ore.position.x][ore.position.y] = ore_value
				end
			else
				for _,ore in pairs(field.ores) do
					global.resources[ore.name][ore.surface.name] = global.resources[ore.name][ore.surface.name] or {}
					global.resources[ore.name][ore.surface.name][ore.position.x] = global.resources[ore.name][ore.surface.name][ore.position.x] or {}
					global.resources[ore.name][ore.surface.name][ore.position.x][ore.position.y] = 0	
				end
			
			end
		end
		if global.resources[resource.name][surface.name][position.x][position.y] > 0 then
			surface.create_entity{	name=resource.name .. "-infinite", 
									position=position, 
									force=resource.force, 
									amount = math.ceil(global.resources[resource.name][surface.name][position.x][position.y])} -- amount must be an integer, otherwise defaults to 50
		end
		global.resources[resource.name][surface.name][position.x][position.y] = nil -- to keep the table small
	end
end)
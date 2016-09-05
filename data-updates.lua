require("util")

local drill = {mining_power = 3, mining_speed = 0.5} -- inserts values equal to the base electric mining drill
local target = 0.1 -- ore/s
-- Mining drills will report a higher number as they can mine 25 tiles by default.
-- However, since they only mine 1 tile at the time and cycle through
-- The actual mining rate will be the target.


for name, resource in pairs(data.raw.resource) do
	if not resource.infinite then
		local inf = util.table.deepcopy(resource)
		inf.name = name .. "-infinite"
		inf.localised_name = "Infinite " .. name:gsub("%-"," ")
		inf.infinite = true
		inf.autoplace = nil
		inf.map_color = {r = resource.map_color.r+0.15, g = resource.map_color.g+0.15, b = resource.map_color.b+0.15}
		inf.normal = resource.stage_counts[1] * 4  -- the higher this number, the more ores need to be mined to drop in %
		inf.minimum = math.ceil(inf.normal * target * resource.minable.mining_time / ((drill.mining_power - resource.minable.hardness) * drill.mining_speed)) --> results in mining rate = target
		
		log(inf.localised_name .. ": minimum / normal = " .. inf.minimum .. " / " .. inf.normal)
		
		inf.localised_description = "Yield reduces to " .. math.floor((100 * inf.minimum / inf.normal) + 0.5) .. "% (" .. target .. "/s)"
		for i = 1,#resource.stage_counts do
			local relative_scale = resource.stage_counts[i]/resource.stage_counts[1]
			inf.stage_counts[i] = math.ceil(relative_scale * inf.normal + (1-relative_scale)*inf.minimum)
		end
		data:extend({inf})
	end
end
_addon.name = 'Puller'
_addon.author = 'Cliff'
_addon.version = '0.0.1'
_addon.commands = {'puller','pull','pu'}

require('logger')
require('mylibs/fsd_lite')
require('mylibs/utils')
require('mylibs/aggro')


local enabled = false
local timer = os.clock()
local targets = {}
local cb_cmd = nil

-- Settings
config = require('config')
default = {
	text_setting = {
		pos = {
			x = 15,
			y = 344
		}
	},
	-- cure_threshold = 60,
	monitor_range = 15,
	pull_back = true,
	-- pull_max = 5,
	-- pull_min = 0,
}
settings = config.load(default)

local IN_FRONT_MOBS = {
	'Tiger',
	'Beetle',
	'Rabbit',
	'Lizard',
}

-- Widget
local texts = require('texts')
local function setup_text(text)
    text:bg_alpha(255)
    text:bg_visible(true)
    text:font('ＭＳ ゴシック')
    text:size(21)
    text:color(255,255,255,255)
    text:stroke_alpha(200)
    text:stroke_color(20,20,20)
    text:stroke_width(2)
	text:show()
end
widget = texts.new("${msg}", settings.text_setting, default.text_setting)
setup_text(widget)

function update_widget(aggr)
	str = 'Ta: '..#targets
	str = str .. ',Ag: '..aggr
	widget.msg = str
end

function tsp_nearest_neighbor(points)
    local n = #points
    if n == 0 then return {}, 0 end
    if n == 1 then return {points[1].id}, 0 end

    local visited = {}
    local path = {}
    local total_dist = 0

    local current = 1
    table.insert(path, points[current].id)
    visited[current] = true

    for _ = 1, n-1 do
        local min_d = math.huge
        local next_point = nil

        for i = 1, n do
            if not visited[i] then
                local d = xy_get_distance(points[current], points[i])
                if d < min_d then
                    min_d = d
                    next_point = i
                end
            end
        end

        table.insert(path, points[next_point].id)
        total_dist = total_dist + min_d
        visited[next_point] = true
        current = next_point
    end

    return path, total_dist
end

windower.register_event('prerender', function(...)
	if os.clock() - timer >= 0.5 then
		
		local aggr = aggroCount()
		update_widget(aggr)
		timer = os.clock()
	end
end)

function go_path(path, curr)
	if not enabled then return end

	log(curr..'/'..#path)
	local node = nil
	if path[curr] == -1 then
		node = targets[#targets]
	else
		node = windower.ffxi.get_mob_by_id(path[curr])
	end
	-- log(dump(node))
	fsd_to('pu', node.x, node.y, function()
		if curr+1 <= #path then
			if array_in_string(IN_FRONT_MOBS, node.name) then
				coroutine.sleep(0.5)
			end
			go_path(path, curr+1)
		else
			log('Finished!!!')
			if cb_cmd then
				windower.send_command('input //'..cb_cmd..' PULLER_done')
			end
		end
	end)
end

function get_position_in_front(mob)
    if not mob or not mob.x or not mob.y or not mob.facing then
        return nil
    end

	local distance = (array_in_string(IN_FRONT_MOBS, mob.name)) and mob.model_size or 0
    local rad = mob.facing
    local dx = distance * math.sin(rad + math.pi / 2)
    local dy = distance * math.cos(rad + math.pi / 2)

    return mob.x + dx, mob.y + dy, mob.z
end

function main(middle)
	targets = {}
	for key,mob in pairs(windower.ffxi.get_mob_array()) do
		if mob["valid_target"] and mob['spawn_type']==16 and xy_get_distance(mob, middle) < settings.monitor_range and mob.hpp > 0 then
			local x, y, z = get_position_in_front(mob)
			table.insert(targets, {
				['index'] = mob.index,
				['id'] = mob.id,
				['name'] = mob.name,
				['x'] = x,
				['y'] = y,
				['z'] = z,
			})
		end
	end
	path, d = tsp_nearest_neighbor(targets)
	if settings.pull_back then
		local self = windower.ffxi.get_mob_by_index(windower.ffxi.get_player().index)
		table.insert(targets, {
			['name'] = 'goal',
			['id'] = -1,
			['x'] = self.x,
			['y'] = self.y,
			['z'] = self.z,
		})
		table.insert(path, -1)
	end
	-- for k,v in pairs(targets) do log(v.id) end
	-- for k,v in pairs(path) do log(v) end
	go_path(path, 1)
end

windower.register_event('addon command', function (command, ...)
	command = command and command:lower()
	local args = T{...}

	if T{"go","g"}:contains(command) then
		local target = windower.ffxi.get_mob_by_target('t')
		if target then
			enabled = true
			log('Let\'s Pull!!!!')
			if #args >= 1 then
				cb_cmd = args[1]
			end
			main(target)
		else
			windower.add_to_chat(2, 'Not target...')
		end
	elseif T{"stop","s"}:contains(command) then
		enabled = false
		windower.send_command('fsd stop')
		log('Stopped')
	elseif T{"trigger"}:contains(command) then
		if enabled then
			windower.send_command('pu stop')
		else
			windower.send_command('pu go')
		end

	elseif T{"dist"}:contains(command) then
		if args[1] then
			settings.monitor_range = tonumber(args[1])
		end
        windower.add_to_chat(11,"Dist: "..settings.monitor_range)
	elseif T{"back"}:contains(command) then
		if args[1] then
			settings.pull_back = T{'1','on'}:contains(args[1])
		else
			settings.pull_back = not settings.pull_back
		end
        windower.add_to_chat(11,"Pull back: "..tostring(settings.pull_back))

	elseif command == 'save' then
		log('Settings saved')
		settings:save()
	end
end)

windower.register_event('load', function()
    log('===========loaded===========')
    windower.send_command('bind @p input //pu trigger')
end)

windower.register_event('unload', function()
    windower.send_command('fsd stop')
    windower.send_command('unbind @p')
end)
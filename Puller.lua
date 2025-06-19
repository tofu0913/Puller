_addon.name = 'Puller'
_addon.author = 'Cliff'
_addon.version = '0.0.1'
_addon.commands = {'puller','pull','pu'}

require('logger')
require('mylibs/fsd_lite')
require('mylibs/utils')
require('mylibs/aggro')


local enabled = false
local STATES = {
	INIT = 0,
	PULLING = 1,
	PULLING_CURE = 1.5,
	BACK = 2,
	BACK_CURE = 2.5,
	WAITKILL = 3,
}
local state = STATES.INIT
local timer = os.clock()

-- Settings
config = require('config')
default = {
	text_setting = {
		pos = {
			x = 15,
			y = 344
		}
	},
	cure_threshold = 60,
	monitor_range = 15,
	pull_max = 5,
	pull_min = 0,
}
settings = config.load(default)

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

function update_widget(aggr, near)
	str = 'Agg: '..aggr
	if near > 0 then
		str = str .. ' Near'..near
	end
	widget.msg = '('..state..')'..str
end

function scan_nearby_mobs()
	local count = 0
	for key,mob in pairs(windower.ffxi.get_mob_array()) do
		if mob["valid_target"] and mob['spawn_type']==16 and math.sqrt(mob.distance) < settings.monitor_range and mob.hpp > 0 then
			count = count + 1
		end
	end
	return count
end

windower.register_event('prerender', function(...)
	if os.clock() - timer >= 0.5 then
		if windower.ffxi.get_player() and windower.ffxi.get_player().vitals.hpp <= settings.cure_threshold then
			if state == STATES.PULLING or state == STATES.BACK then
				state = state + 0.5
				windower.send_command('fsd stop')
			end
			windower.send_command(windower.to_shift_jis('input /ma ケアルIV <me>'))
			timer = os.clock() + 2
			return
		else
			if state == STATES.PULLING_CURE or state == STATES.BACK_CURE then
				state = state - 0.5
				windower.send_command('fsd continue')
			elseif state == STATES.WAITKILL and not hasBuff('プロテス') then
				windower.send_command(windower.to_shift_jis('input /ma プロテスV <me>'))
			end
		end

		local aggr = aggroCount()
		if state == STATES.PULLING and aggr >= settings.pull_max then
			state = STATES.BACK
			log('Pull done, go back')
			windower.send_command('fsd stop')
			coroutine.sleep(0.5)
			main()
		end
		local near = scan_nearby_mobs()
		if state == STATES.WAITKILL and scan_nearby_mobs() <= settings.pull_min then
			state = STATES.INIT
			log('No mob, go pull')
			main()
		end
		update_widget(aggr, near)
		timer = os.clock()
	end
end)

function main()
	if state == STATES.INIT then
		state = STATES.PULLING
		waitfor(function()
			windower.ffxi.cancel_buff(116)
			coroutine.sleep(2)
			windower.send_command(windower.to_shift_jis('input /ma ファランクス <me>'))
			return hasBuff('ファランクス')
		end, function()
			fsd_go_loop('puller', 'puller')
		end)
	elseif state == STATES.BACK then
		fsd_go_back('puller', function()
			log('wait for mobs killed')
			state = STATES.WAITKILL
		end)
	end
end

windower.register_event('addon command', function (command, ...)
	command = command and command:lower()
	local args = T{...}

	if T{"go","g"}:contains(command) then
		enabled = true
		state = STATES.INIT
		log('Let\'s Pull!!!!')
		main()
	elseif T{"stop","s"}:contains(command) then
		enabled = false
		log('Stopped')
	elseif command == 'save' then
		log('Settings saved')
		settings:save()

	elseif command == 'debug' then
		log(state)
	end
end)

windower.register_event('load', function()
    log('===========loaded===========')
end)

windower.register_event('unload', function()
    windower.send_command('fsd stop')
end)
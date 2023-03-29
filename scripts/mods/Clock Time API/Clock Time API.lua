local mod = get_mod("Clock Time API")

-- VARIABLES --
local json = require("PlayFab.json")
local SCREEN_WIDTH = 3840
local SCREEN_HEIGHT = 2160
local update1 = false
local time_wait = 0
local update2 = false
local update_done = false
local clock_time_api_time_begin = ""
local clock_time_os_clock_saved = 0
local clock_time_api_time_actual = ""
local API_false = false

-- USER FUNCTIONS --
mod.curl_get_api_time = function ()
    local url = "http://worldtimeapi.org/api/timezone/Etc/GMT"
    local gmt = mod:get("clock_time_api_gmt")
    gmt = gmt * (-1)

    if gmt >= 0 then
        url = url .. "+"
    end
    url = url .. tostring(gmt)

    Managers.curl:get(url, {}, callback(mod, "curl_get_api_time_cb"), nil, {})
end

mod.curl_get_api_time_cb = function (success, code, headers, data, userdata)
    if (not success) or (headers ~= 200) then
        mod:echo("HTTP GET Request failed. Error %d.", headers)
		mod:set("clock_time_api", false)
		API_false = true
		return
	end

	if not API_false then
		local clock_time_userdata = userdata
		local clock_time_decoded = json.decode(clock_time_userdata)
		local clock_time_datetime = clock_time_decoded.datetime
		clock_time_api_time_begin = string.sub(clock_time_datetime, string.find(clock_time_datetime, "%d%d:%d%d:%d%d"))
	end
end

mod.update_clock_time = function ()
	if not API_false then
		local hours = tonumber(clock_time_api_time_begin:sub(1,2))
		local minutes = tonumber(clock_time_api_time_begin:sub(4,5))
		local seconds = tonumber(clock_time_api_time_begin:sub(7,8))
		local total_seconds = hours*60*60 + minutes*60 + seconds
		local diff = math.floor(os.clock()) - clock_time_os_clock_saved
		total_seconds = total_seconds + diff
		hours = tostring(math.floor((total_seconds / 3600) % 24))
		minutes = tostring(math.floor((total_seconds / 60) % 60))
		seconds = tostring(math.floor(total_seconds % 60))
		if #hours == 1 then
			hours = "0" .. hours
		end
		if #minutes == 1 then
			minutes = "0" .. minutes
		end
		if #seconds == 1 then
			seconds = "0" .. seconds
		end
		clock_time_api_time_actual = tostring(hours) .. ":" .. tostring(minutes) .. ":" .. tostring(seconds)
	end
end

-- UI FUNCTIONS --
local function get_x()
	local x =  mod:get("clock_time_offset_x")
	local x_limit = SCREEN_WIDTH / 2
	local max_x = math.min(mod:get("clock_time_offset_x"), x_limit)
	local min_x = math.max(mod:get("clock_time_offset_x"), -x_limit)
	if x == 0 then
		return 0
	end
	local clamped_x =  x > 0 and max_x or min_x
	return clamped_x
end

local function get_y()
	local y =  mod:get("clock_time_offset_y")
	local y_limit = SCREEN_HEIGHT / 2
	local max_y = math.min(mod:get("clock_time_offset_y"), y_limit)
	local min_y = math.max(mod:get("clock_time_offset_y"), -y_limit)
	if y == 0 then
		return 0
	end
	local clamped_y = -(y > 0 and max_y or min_y)
	return clamped_y
end

local fake_input_service = {
	get = function ()
	 	return
	end,
	has = function ()
		return
	end
}

local scenegraph_definition = {
	root = {
	  	scale = "fit",
	  	size = {
			SCREEN_WIDTH,
			SCREEN_HEIGHT
	  	},
	  	position = {
			0,
			0,
			UILayer.hud
	  	}
	}
}

local clock_time_ui_definition = {
	scenegraph_id = "root",
	element = {
	  	passes = {
			{
				style_id = "clock_time_text",
				pass_type = "text",
				text_id = "clock_time_text",
				retained_mode = false,
				fade_out_duration = 5,
				content_check_function = function(content)
					return true
				end
			}
	  	}
	},
	content = {
		clock_time_text = ""
	},
	style = {
		clock_time_text = {
			font_type = "hell_shark",
			font_size = mod:get("clock_time_font_size"),
			vertical_alignment = "center",
			horizontal_alignment = "center",
			text_color = Colors.get_table("white"),
			offset = {
				get_x(),
				get_y(),
				0
			}
		}
	},
	offset = {
		0,
		0,
		0
	},
}

-- MOD EVENTS --
function mod:on_enabled()
	mod:on_setting_changed()
end

function mod:on_disabled()
	mod.ui_renderer = nil
	mod.ui_scenegraph = nil
	mod.ui_widget = nil
end

function mod:update(t)
    if mod:get("clock_time_api") and not update_done and not update2 and not API_false then
        mod:curl_get_api_time()
        update1 = true
    end
    if update1 then
        time_wait = os.clock()
        update1 = false
        update2 = true
    end
    if update2 and (os.clock() - time_wait > 0.5) then
        clock_time_api_time_actual = clock_time_api_time_begin
        clock_time_os_clock_saved = math.floor(os.clock())
        update_done = true
        update2 = false
    end

    if update_done then
        mod:update_clock_time()
    end
end

function mod:on_setting_changed()
    update_done = false
	API_false = false

	if not mod.ui_widget then
	  	return
	end
	mod.ui_widget.style.clock_time_text.offset[1] = get_x()
	mod.ui_widget.style.clock_time_text.offset[2] = get_y()
	mod.ui_widget.style.clock_time_text.font_size = mod:get("clock_time_font_size")
    mod.ui_widget.style.clock_time_text.text_color = {mod:get("clock_time_alpha"), mod:get("clock_time_red"), mod:get("clock_time_green"), mod:get("clock_time_blue")}
end

function mod:init()
	if mod.ui_widget then
	  	return
	end

	local world = Managers.world:world("top_ingame_view")
	mod.ui_renderer = UIRenderer.create(world, "material", "materials/fonts/gw_fonts")
	mod.ui_scenegraph = UISceneGraph.init_scenegraph(scenegraph_definition)
	mod.ui_widget = UIWidget.init(clock_time_ui_definition)
end

-- HOOKS --
mod:hook_safe(IngameHud, "update", function(self)
	if self:is_own_player_dead() then
		return
	end

	if not mod.ui_widget then
	  	mod.init()
	end

	local widget = mod.ui_widget
	local ui_renderer = mod.ui_renderer
	local ui_scenegraph = mod.ui_scenegraph

    if mod:get("clock_time_api") and update_done then
        widget.content.clock_time_text = clock_time_api_time_actual
    else
        widget.content.clock_time_text = os.date("%X")
    end
	widget.style.clock_time_text.font_size = mod:get("clock_time_font_size")
    widget.style.clock_time_text.text_color = {mod:get("clock_time_alpha"), mod:get("clock_time_red"), mod:get("clock_time_green"), mod:get("clock_time_blue")}
	widget.style.clock_time_text.offset[1] = get_x()
	widget.style.clock_time_text.offset[2] = get_y()

	UIRenderer.begin_pass(ui_renderer, ui_scenegraph, fake_input_service, dt)
	UIRenderer.draw_widget(ui_renderer, widget)
	UIRenderer.end_pass(ui_renderer)
end)
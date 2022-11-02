-- TODO: wait till stand released on_pad_shake, integrate nicely
-- maybe add som more rotate and pump presets too, that would b cool ig

util.require_natives("1663599433")
local debug = false

local function notify(text) 
    util.toast("[LOVENSE] " .. text)
end

local function debug_notify(text) 
    if debug then 
        util.toast("[LOVENSE DEBUG] " .. text)
    end
end

local all_toys = {}
local unique_toys = {}
local unique_toy_names = {}
local root = menu.my_root()
local is_vibration_active = false
local is_pump_active = false 
local is_rotation_active = false
local vibration_strength = 20
local max_vibration_strength = 20
local rotation_speed = 20
local max_rotation_speed = 20

local function vibrate() end 
local function rotate() end 
local function pump() end 

-- some functions need to be re-ran if they are on because they do not get updated every tick. the only exception at the moment may be pump
function overlap_fix()
    if is_vibration_active then 
        vibrate(vibration_strength, 0, 0, 0)
    end
    if is_rotation_active then 
        rotate(rotation_speed, 0, 0, 0)
    end
end

root:divider("Version 0.1.3")
root:divider("Features")
local vibration_root = root:list("Vibrate", {}, "Configure vibration-related settings")
local pump_root = root:list("Pump/Contract", {}, "Configure pump-related settings, which is what controls the \"contraction\" feature of the toy. Note that the pump is still an air pump, so don\'t expect any rapid adjustment options.")
local rotate_root = root:list("Rotate", {}, "Configure rotation-related settings, which are really only found in Nora")
local custom_control = root:list("Custom control", {}, "Design a custom combination of features for your toy to use together in a continuous loop, and finetune every single aspect of it to your liking.\nThis feature exists because it is not possible to have the other features run together reliably all the time.")

root:divider("Misc")
local chatcomms_root = root:list("Chat Commands", {}, "Configure chat command settings.")

local chat_comms = false
chatcomms_root:toggle("Chat commands", {}, "", function(on)
    chat_comms = on
end, false)

local cc_friend_only = true
chatcomms_root:toggle("Friends only", {}, "Only allow friends to send chat commands", function(on)
    cc_friend_only = on
end, true)

local cc_max_duration_secs = 10
chatcomms_root:slider("Max duration", {}, "The max duration players can request your toy to vibrate for, in seconds", 1, 300, 10, 1, function(val)
    cc_max_duration_secs = val
end)

local cc_cooldown = 1000
chatcomms_root:slider("Command cooldown", {}, "The cooldown each user will have to wait between sending each command, in milliseconds.", 1, 120000, 1000, 1, function(val)
    cc_cooldown = val
end)

local chat_prefixes = {'-', '\\', "'", ">"}
local command_chat_prefix = '-'
chatcomms_root:list_select("Command prefix", {}, "", chat_prefixes, 1, function(index, value)
    command_chat_prefix = value
end)

local valid_presets = {"pulse", "wave", "fireworks", "earthquake"}
local valid_commands = {"vibrate", "pump", "rotate"}
chatcomms_root:action("Send valid commands", {}, "Show the session which commands are valid.", function()
    chat.send_message("> Valid commands include " .. command_chat_prefix .. table.concat(valid_commands, ', ' .. command_chat_prefix), false, true, true)
    chat.send_message("> Each command has 2 arguments, strength (1-20), and duration in seconds (1 - " .. cc_max_duration_secs .. ").", false, true, true)
    chat.send_message("> You may also send " .. command_chat_prefix .. "stop to stop all current functions, as well as " .. command_chat_prefix .. "pattern " .. table.concat(valid_presets, '/') .. " duration", false, true, true)
end)

local hhs = "To connect, you need to download Lovense Connect on your phone, turn on your toy and connect it to your phone via Bluetooth, and connect it to the same network as your PC."
hhs = hhs .. "\n\nNOT Lovense Remote. Lovense CONNECT. Yes, there is a difference. Yes, it matters. You can\'t have it connected to both apps at once."
hhs = hhs .. "\n\nIf you are having issues, tap the green shield icon in the top right of Lovense Connect, and try visiting the URL it says to visit in a browser on your PC. Turn off any VPN or configure it so that you can see local devices."
hhs = hhs .. "\n\nIf your toy isn\'t supported or working, let me know.\n\nAlso, when in doubt, restart your toy and the Lovense Connect app. There are a lot of issues that are Lovense's fault, sadly."

root:action("Hover over for help", {}, hhs, function()
    notify("It says \"hover for help\", not \"click for help\". Dummy.")
end)

local supported_toy_features = {
    nora = {"Vibrate", "Rotate"},
    max = {"Vibrate", "Pump"},
    exomoon = {"Vibrate"},
    calor = {"Vibrate"},
    hush = {"Vibrate"},
    gush = {"Vibrate"},
    hyphy = {"Vibrate"},
    dolce = {"Vibrate"},
    lush = {"Vibrate"},
    diamo = {"Vibrate"},
    edge = {"Vibrate"},
    ferri = {"Vibrate"},
    domi = {"Vibrate"},
    osci = {"Vibrate"},
    ambi = {"Vibrate"}
}

--https://stackoverflow.com/questions/2421695/first-character-uppercase-lua
function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

function count_occurences(table, value)
    local ct = 0
    for _, v in pairs(table) do 
        if v == value then 
            ct += 1 
        end
    end
    return ct
end

local function get_all_toys()
    async_http.init("api.lovense.com", "/api/lan/getToys", function(response)
        local this_json = soup.json.decode(response)
        assert(this_json ~= nil, "The API encountered an error.")
        -- fill list using a toy_id:toy_data formula
        local all_toy_copy = all_toys
        all_toys = {}
        for _, value in pairs(this_json) do
            if value.toys ~= nil then
                for toy_id, toy_data in pairs(value.toys) do
                    if toy_data.status == "1" then
                        local data_copy = toy_data
                        data_copy.domain = value.domain
                        data_copy.port = value.httpsPort
                        all_toys[toy_id] = data_copy
                        if unique_toys[toy_id] == nil then
                            table.insert(unique_toy_names, toy_data.name)
                            local fmt_name = firstToUpper(toy_data.name)
                            local toy_num = count_occurences(unique_toy_names, toy_data.name)
                            local toggle_name = ""
                            if toy_num == 1 then 
                                toggle_name = fmt_name 
                            else
                                toggle_name = fmt_name .. " " .. toy_num
                            end
                            notify(fmt_name .. " (" .. toy_id .. ") connected! Battery reading: " .. toy_data.battery .. '%')
                            local features = table.concat(supported_toy_features[toy_data.name], ', ')
                            root:toggle(toggle_name, {}, "Toy ID: " .. toy_id .. "\nSupported features: " .. features, function(on)
                                unique_toys[toy_id] = on
                            end, true)
                            unique_toys[toy_id] = true
                        end
                    end
                end
            end
        end
        -- check for missing toys from this get 
        for toy_id, toy_data in pairs(all_toy_copy) do
            if all_toys[toy_id] == nil then 
                notify("The connection to toy \"" .. toy_data.name .. "\" (" .. toy_id .. ") was lost. This toy will remain in the list but will not be sent commands.")
            end
        end
    end, function()
        debug_notify("Failed to find toys. This is possibly just a blip, but if this issue continues, check your connection.")
    end)
    async_http.dispatch()
end


local current_commands = {}
-- i was torturing my cock and balls with my toy when i noticed, hm, thats strange.. when i send a new command, the other one cancels out! 
-- the answer is, technical limitation! this sucks.
-- however the toy API lets us send commands together.
-- so what we do here, is we will keep track of each currently running command, and remove it when it is done being "played", then in the send_command, we will set the length to the max() of the lens 

function set_command_to_expire(command, time_in_ms)
    util.create_thread(function()
        debug_notify(command .. " command will expire in " .. time_in_ms .. " ms.")
        util.yield(time_in_ms)
        debug_notify(command .. " command has expired.")
        for index, cmd_data in pairs(current_commands) do 
            if cmd_data.name == command then 
                table.remove(current_commands, index)
            end 
        end
    end)
end

function add_current_command(command, strength, length)
    -- if a command already exists within the list, we will overwrite it and favor the new one's strength
    for index, _command in pairs(current_commands) do
        if string.lower(_command.name) == string.lower(command) then 
            table.remove(current_commands, index)
        end
    end
    table.insert(current_commands, {
        name = command,
        length = length, 
        strength = strength,
        command_string = command .. ':' .. tostring(strength)
    })
    debug_notify("Created a command of " .. command .. " with strength of " .. strength .. " and length of " .. length)
    -- if we have a length that is non-zero, that means that the command is not meant to be played infinitely and we should eventually kill it
    -- the toy will eventually kill it anyways, so no additional processing is needed in that regard
    if length ~= 0 then
        set_command_to_expire(command, length*1000)
    end
end

local function send_command(cmd, toy_name, toy_id, host, port, the_action, strength, length, loop_run_sec, loop_pause_sec)
    local duration = 0
    local all_commands = {}
    if cmd == "Function" then
        if strength ~= nil and strength ~= 0 and the_action ~= "Stop" then
            add_current_command(the_action, strength, length)
            debug_notify("Command added to queue, setting duration")
            -- get the max length of the current commands
            -- also build our full request strings
            for index, command in pairs(current_commands) do 
                if command.length > duration then 
                    duration = command.length 
                end
                table.insert(all_commands, command.command_string)
            end
            if #all_commands == 0 then 
                debug_notify("All commands was 0, exiting")
                return 
            end
            if not table.contains(supported_toy_features[toy_name], the_action) then
                debug_notify(toy_name .. " does not support action: " .. the_action)
                return
            end
        end
    end

    if not unique_toys[toy_id] then 
        debug_notify(toy_id .. " is disabled, not sending action.")
        return
    end
    
    debug_notify("All good, sending command")

    local app_host = host .. ':' .. tostring(port)
    async_http.init(app_host, '/command', function(data, hdr_fields, status)
        debug_notify("send command return: " .. data)
    end, function()
        debug_notify("Failed to command " .. host .. ":" .. tostring(port) .. " to " .. the_action)
    end)

    local payload = 
    {
        command = cmd,
        toy = toy_id,
        apiVer = 1
    }
    -- if we reached here, we should probably have duration set as the max of the current command lengths.
    if cmd == "Function" then
        payload.timeSec = duration
        if strength ~= nil then
            payload.action = table.concat(all_commands, ',')
        else
            payload.action = the_action
        end
    else 
        payload.timeSec = length
        payload.name = the_action 
    end

    if loop_run_sec > 1 then 
        payload.loopRunningSec = loop_run_sec
    end

    if loop_pause_sec > 1 then 
        payload.loopPauseSec = loop_pause_sec
    end
    payload = soup.json.encode(payload)
    if debug then 
        notify("SEND CMD PAYLOAD: " .. payload)
    end
    async_http.set_post("application/json", payload)
    async_http.dispatch()
end

-- there are so many differences with the pattern shit that i figured i would just make an entirely new function
local function send_pattern_command(toy_name, toy_id, host, port, pattern, toy_functions_string, interval, length)
    if not unique_toys[toy_id] then 
        debug_notify(toy_id .. " is disabled, not sending action.")
        return
    end
    
    local app_host = host .. ':' .. tostring(port)
    async_http.init(app_host, '/command', function(data, hdr_fields, status)
        debug_notify("send pattern command return: " .. data)
    end, function()
        debug_notify("Failed to command " .. host .. ":" .. tostring(port) .. " to " .. the_action)
    end)

    local payload = 
    {
        command = "Pattern",
        rule = "V:1;F:" .. toy_functions_string:lower() .. ';S:' .. interval .. '#',
        strength = pattern:gsub(',', ';'),
        timeSec = length,
        toy = toy_id,
        apiVer = 1
    }

    payload = soup.json.encode(payload)
    debug_notify("PATTERN CMD PAYLOAD: " .. payload)
    async_http.set_post("application/json", payload)
    async_http.dispatch()
end

-- vibrations
function vibrate(speed, length, loop_sec, pause_sec)
    local speed = math.min(speed, max_vibration_strength)
    for toy_id, toy_data in pairs(all_toys) do 
        send_command("Function", toy_data.name, toy_id, toy_data.domain, toy_data.port, 'Vibrate', speed, length, loop_sec, pause_sec)
        if debug then
            util.draw_debug_text("VIBRATE TOY " .. toy_data.name .. " ON DOMAIN " .. toy_data.domain .. " AT SPEED " .. speed .. " for len " .. length)
        end
    end
end

local function preset_vibrate(preset, length)
    for toy_id, toy_data in pairs(all_toys) do 
        send_command("Preset", toy_data.name, toy_id, toy_data.domain, toy_data.port, preset, 0, length, 0, 0)
        if debug then
            util.draw_debug_text("VIBRATE TOY AT PRESET" .. toy_data.name .. " ON DOMAIN " .. toy_data.domain .. " for len " .. length)
        end
    end
end

function stop_vibrate()
    for index, command in pairs(current_commands) do 
        if string.lower(command.name) == "vibrate" then 
            table.remove(current_commands, index)
        end
    end
    vibrate(0, 1, 0, 0)
end

vibration_root:slider("Default vibration strength", {"vibratestrength"}, "The default strength/speed of the vibration. This setting will not affect modes with dynamically-scaled vibration strength.", 1, 20, 20, 1, function(val)
    vibration_strength = val
end)

vibration_root:slider("Max vibration strength", {"maxvibratestrength"}, "The max strength/speed of the vibration, applicable to all modes.", 1, 20, 20, 1, function(val)
    max_vibration_strength = val
end)


vibration_duration = 10
vibration_root:slider("Vibration duration (seconds)", {"vibrateduration"}, "The length of the vibration. This setting will not affect modes with dynamically-scaled vibration duration, or any continuous modes.", 1, 300, 10, 1, function(val)
    vibration_duration = val
end)

local vibe_mode = 1
local vibe_modes = {"Continuous", "Vehicle RPM", "Event feedback", "Preset: Pulse", "Preset: Wave", "Preset: Fireworks", "Preset: Earthquake", "Random"}
vibration_root:list_select("Vibration mode", {"vibratemode"}, "What mode to control the vibrator with. Some modes have lists below with additional config.\nIf you use a preset and then turn vibration off, the preset will continue running the rest of the pattern and will then stop; this cannot be avoided.", vibe_modes, 1, function(mode)
    vibe_mode = mode
end)

local vibe_event_feedback_settings = vibration_root:list("Event feedback settings", {}, "")

local vibe_ef_intensity_threshold = 10
vibe_event_feedback_settings:click_slider("Intensity threshold", {}, "The game vibration must be at least this strong to actually make vibrations occur.", 0, 300, 100, 1, function(val)
    vibe_ef_intensity_threshold = val
end)

local do_vibrate = false
vibration_root:toggle("Vibration", {"vibrate"}, "Whether to do vibration at all. As soon as you turn this on, the vibrator may immediately start depending on your settings.", function(on)
    do_vibrate = on
    if not on then 
        stop_vibrate()
        is_vibration_active = false
    end
end, false)

local ef_cooldown = false
util.on_pad_shake(function(light_duration, light_intensity, heavy_duration, heavy_intensity, delay_after_this_one)
    if do_vibrate and vibe_mode == 3 and not ef_cooldown and light_intensity >= vibe_ef_intensity_threshold then
        local duration = math.max(math.ceil(math.max(light_duration, heavy_duration) / 200), 1)
        vibrate(vibration_strength, duration, 0, 0)
        ef_cooldown = true
        util.yield(duration*1000)
        ef_cooldown = false
    end
end)



-- MAIN VIBRATION HANDLER TICK
local last_rpm = 0
local last_hp = ENTITY.GET_ENTITY_HEALTH(players.user_ped())
local last_vibration_strength = 0
util.create_tick_handler(function()
    if do_vibrate then
        pluto_switch vibe_mode do 
            case 1:
                if not is_vibration_active or vibration_strength ~= last_vibration_strength then
                    vibrate(vibration_strength, 0, 0, 0)
                    is_vibration_active = true
                    last_vibration_strength = vibration_strength
                end
                break
            case 2:
                local user_cur_car = entities.get_user_vehicle_as_pointer()
                if user_cur_car ~= 0 then 
                    local rpm = entities.get_rpm(user_cur_car)
                    if math.abs(rpm - last_rpm) > 0.100 or vibration_strength ~= last_vibration_strength then 
                        if PED.IS_PED_IN_ANY_VEHICLE(players.user_ped(), true) and PED.GET_VEHICLE_PED_IS_IN(players.user_ped(), false) ~= 0 then 
                            last_vibration_strength = vibration_strength
                            last_rpm = rpm
                            vibrate(math.ceil(rpm*vibration_strength), 0, 0, 0)
                            is_vibration_active = true
                            util.yield(500)
                        end
                    end
                end
                break
             -- case 3 is handled by an external tick handler
            case 4: 
                preset_vibrate("pulse", vibration_duration)
                util.yield(vibration_duration*1000)
                break
            case 5:
                preset_vibrate("wave", vibration_duration)
                util.yield(vibration_duration*1000)
                break
            case 6:
                preset_vibrate("fireworks", vibration_duration)
                util.yield(vibration_duration*1000)
                break
            case 7:
                preset_vibrate("earthquake", vibration_duration)
                util.yield(vibration_duration*1000)
                break
            case 8: 
                local duration = math.random(1, 5)
                vibrate(math.random(1, 20), duration, 0, 0)
                util.yield(duration * 1000)
        end
    else
        if is_vibration_active then 
            stop_vibrate()
            is_vibration_active = false
        end
    end

end)

-- pump
local max_pump_tightness = 20
local pump_tightness = 20

function pump(speed, length, loop_sec, pause_sec)
    local speed = math.min(speed, max_pump_tightness)
    for toy_id, toy_data in pairs(all_toys) do 
        send_command("Function", toy_data.name, toy_id, toy_data.domain, toy_data.port, 'Pump', speed, length, loop_sec, pause_sec)
        if debug then
            util.draw_debug_text("PUMP TOY " .. toy_data.name .. " ON DOMAIN " .. toy_data.domain .. " AT SPEED " .. speed .. " for len " .. length)
        end
    end
end

pump_root:slider("Default tightness", {"pumptightness"}, "The default strength/speed of the pump. This setting will not affect modes with dynamically-scaled pump tightness.", 1, 20, 20, 1, function(val)
    pump_tightness = val
end)


pump_root:slider("Max pump tightness", {"pumptightness"}, "The max strength/speed of the pump, applicable to all modes.", 1, 20, 20, 1, function(val)
    max_pump_tightness = val
end)


local pump_mode = 1
local pump_modes = {"Continuously tight", "Higher HP = Tighter"}
pump_root:list_select("Pump mode", {"pumpmode"}, "What mode to control the pump with. Some modes have lists below with additional config.", pump_modes, 1, function(mode)
    pump_mode = mode
end)

function stop_pump()
    for index, command in pairs(current_commands) do 
        if string.lower(command.name) == "pump" then 
            table.remove(current_commands, index)
        end
    end
    pump(0, 1, 0, 0)
    overlap_fix()
end

local do_pump = false
pump_root:toggle("Pump", {"pump"}, "Make sure your pump air vent is open! ;)\nWhether to use the pump at all. As soon as you turn this on, the pump may immediately start depending on your settings.", function(on)
    do_pump = on
    if not on then 
        stop_pump()
    end
end, false)


-- MAIN PUMP HANDLER TICK
local last_pump_tightness = 0
util.create_tick_handler(function()
    if do_pump then
        pluto_switch pump_mode do 
            case 1:
                pump(pump_tightness, 0, 0, 0)
                util.yield(3000)
                break
            case 2: 
                local cur_hp = ENTITY.GET_ENTITY_HEALTH(players.user_ped())
                local hp_diff = last_hp - cur_hp
                if hp_diff > 5 then
                    last_hp = cur_hp
                    local max_hp = PED.GET_PED_MAX_HEALTH(players.user_ped())
                    local this_pump_stren = (cur_hp / max_hp) * 20
                    pump(this_pump_stren, 0, 0, 0)
                end
                break
        end
    else
        if is_pump_active then 
            stop_pump()
            is_pump_active = false
        end
    end

end)

-- ROTATE

function rotate(speed, length, loop_sec, pause_sec)
    local speed = math.min(speed, max_rotation_speed)
    for toy_id, toy_data in pairs(all_toys) do 
        send_command("Function", toy_data.name, toy_id, toy_data.domain, toy_data.port, 'Rotate', speed, length, loop_sec, pause_sec)
        if debug then
            util.draw_debug_text("ROTATE TOY " .. toy_data.name .. " ON DOMAIN " .. toy_data.domain .. " AT SPEED " .. speed .. " for len " .. length)
        end
    end
end

rotate_root:slider("Default rotation speed", {"rotatespeed"}, "The strength/speed of the rotations. This setting will not affect modes with dynamically-scaled rotation speed.", 1, 20, 20, 1, function(val)
    rotation_speed = val
end)

rotate_root:slider("Max rotation speed", {"maxvibratestrength"}, "The max strength/speed of the rotation, applicable to all modes.", 1, 20, 20, 1, function(val)
    max_rotation_speed = val
end)

local rotate_mode = 1
local rotate_modes = {"Continuous", "Vehicle speed"}
rotate_root:list_select("Rotate mode", {"rotatemode"}, "What mode to control the rotations with. Some modes have lists below with additional config.", rotate_modes, 1, function(mode)
    rotate_mode = mode
end)

function stop_rotation()
    for index, command in pairs(current_commands) do 
        if string.lower(command.name) == "rotate" then 
            table.remove(current_commands, index)
        end
    end
    rotate(0, 1, 0, 0)
    overlap_fix()
end

local do_rotate = false
rotate_root:toggle("Rotate", {"rotate"}, "Whether to use rotations at all. As soon as you turn this on, the rotation may immediately start depending on your settings.", function(on)
    do_rotate = on
    if not on then 
        stop_rotation()
    end
end, false)


-- MAIN ROTATION HANDLER TICK
local is_rotation_active = false
local last_car_speed = 0
local last_rotation_speed = 0
util.create_tick_handler(function()
    if do_rotate then
        pluto_switch rotate_mode do 
            case 1:
                if not is_rotation_active or last_rotation_speed ~= rotation_speed then
                    rotate(rotation_speed, 0, 0, 0)
                    is_rotation_active = true
                    last_rotation_speed = rotation_speed
                end
                break
            case 2: 
                local user_cur_car = entities.get_user_vehicle_as_pointer()
                if user_cur_car ~= 0 then 
                    local car = entities.pointer_to_handle(user_cur_car)
                    local speed = ENTITY.GET_ENTITY_SPEED(car)
                    local max = VEHICLE.GET_VEHICLE_ESTIMATED_MAX_SPEED(car)
                    if math.abs(last_car_speed - speed) > 10 and last_rotation_speed ~= rotation_speed then 
                        last_car_speed = speed
                        rotate((speed/max)*rotation_speed, 0, 0, 0)
                        util.yield(500)
                    end
                end
        end
    else
        if is_rotation_active then 
            stop_rotation()
            is_rotation_active = false
        end
    end

end)


local function stop_all_functions()
    if debug then 
        notify("STOP received")
    end
    for toy_id, toy_data in pairs(all_toys) do 
        send_command("Function", toy_data.name, toy_id, toy_data.domain, toy_data.port, 'Stop', 0, 0, 0, 0)
        send_pattern_command(toy_data.name, toy_data.id, toy_data.domain, toy_data.port, "0", "vpr", 100, 1)
        if debug then
            notify("STOP TOY " .. toy_data.name .. " ON DOMAIN " .. toy_data.domain)
        end
    end
    stop_vibrate()
    stop_pump()
    stop_rotation()
end



root:action("Emergency stop all functions", {}, "Sends your toys a \"stop\" command, which has varying degrees of success depending on what the toy is doing, because the design does not always allow a complete stop.\n\nIf your toy is stuck, restart it as well as the Lovense Connect app. Both have a command queue that can get filled with nonsense.", function()
    stop_all_functions()
end)

menu.hyperlink(menu.my_root(), "Join Discord", "https://discord.gg/N6pZcACDZ8", "")

-- simultaneous stacks

local fs_vibrate = true
custom_control:toggle("Vibrate", {}, "", function(on)
    fs_vibrate = on
end, true)

local fs_vibrate_strength = 20 
custom_control:slider("Vibrate strength", {}, "", 1, 20, 20, 1, function(val)
    fs_vibrate_strength = val
end)


local fs_pump = true
custom_control:toggle("Pump", {}, "", function(on)
    fs_pump = on
end, true)

local fs_pump_tightness = 20 
custom_control:slider("Pump tightness", {}, "", 1, 20, 20, 1, function(val)
    fs_pump_tightness = val
end)

local fs_rotate = true
custom_control:toggle("Rotate", {}, "", function(on)
    fs_rotate = on
end, true)

local fs_rotation_speed = 20 
custom_control:slider("Rotation speed", {}, "", 1, 20, 20, 1, function(val)
    fs_rotation_speed = val
end)

local fs_loop_sec = 5
custom_control:slider("Loop time (seconds)", {}, "The amount of time to loop for before considering pause time. ", 1, 300, 5, 1, function(val)
    fs_loop_sec = val
end)

local fs_pause_sec = 0
custom_control:slider("Pause time (seconds)", {}, "The amount of time to pause for between loops. ", 0, 300, 0, 1, function(val)
    fs_pause_sec = val
end)

custom_control:divider("Pattern")

local fs_pattern = "5,10,15,20"
custom_control:text_input("Pattern", {"setpattern"}, "Enter strengths separated by commas", function(pattern)
    local pattern = pattern:gsub(' ', '')
    local test = pattern:split(',', '')
    for _, e in pairs(test) do 
        local num = tonumber(e)
        if num == nil then 
            notify("The pattern you entered is invalid. You should enter numbers and only numbers, separated by commas. Each number is the strength at that \"frame\" of the pattern.")
            menu.trigger_commands("setpattern " .. fs_pattern)
            return 
        elseif num > 20 or num < 1 then
            notify("You have entered a number that is outside of the range of 1-20, which is an invalid strength.")
            menu.trigger_commands("setpattern " .. fs_pattern)
            return
        end
    end
    fs_pattern = pattern:gsub(' ', '')
end, fs_pattern)

local fs_pattern_interval = 100
custom_control:slider("Pattern interval (ms)", {"patterninterval"}, "The amount of time, in ms, between each pattern \"frame\". ", 50, 30000, 100, 1, function(val)
    fs_pattern_interval = val
end)

custom_control:divider("Run")

local fs_use_pattern = false
custom_control:toggle("Use pattern strengths", {}, "Enabling this will use your pattern and not your individual strengths for each function. The same strength will be applied to all enabled features dependent on your pattern\'s currently playing frame.", function(on)
    fs_use_pattern = on
end, false)


local fs_loop_on = false
custom_control:toggle("Run loop", {}, "Restart this loop whenever you want changes you make in this section to be reflected.\n\nNote that if you have patterns on, any currently-playing pattern must finish its current queue before the toy will actually stop motion.", function(on)
    if not fs_loop_on and on then
        fs_loop_on = true
        local action_components = {}
        local toy_functions_string = ""
        if fs_vibrate then
            toy_functions_string = toy_functions_string .. "v"
            table.insert(action_components, "Vibrate:" .. tostring(fs_vibrate_strength))
        end
        if fs_pump then 
            toy_functions_string = toy_functions_string .. "p"
            table.insert(action_components, "Pump:" .. tostring(fs_pump_tightness))
        end
        if fs_rotate then 
            toy_functions_string = toy_functions_string .. "r"
            table.insert(action_components, "Rotate:" .. tostring(fs_rotation_speed))
        end
        local action_string = table.concat(action_components, ',')
        for toy_id, toy_data in pairs(all_toys) do 
            if fs_use_pattern then 
                local total_time = 0
                for _, n in pairs(fs_pattern:split(',')) do
                    total_time += fs_pattern_interval
                end 
                send_pattern_command(toy_data.name, toy_data.id, toy_data.domain, toy_data.port, fs_pattern, toy_functions_string, fs_pattern_interval, 0)
            else
                for toy_id, toy_data in pairs(all_toys) do 
                    send_command("Function", toy_data.name, toy_id, toy_data.domain, toy_data.port, action_string, nil, 0, fs_loop_sec, fs_pause_sec)
                end
            end
        end
    else
        fs_loop_on = false
        stop_all_functions()
    end
end, false)

-- TOY DISCOVERY
root:divider("Discovered toys")

util.create_tick_handler(function()
    get_all_toys()
    util.yield(5000)
end)

local handle_ptr = memory.alloc(13*8)
local function pid_to_handle(pid)
    NETWORK.NETWORK_HANDLE_FROM_PLAYER(pid, handle_ptr, 13)
    return handle_ptr
end

local cooldown_players = {}
local valid_chat_commands = {"vibrate", "pump", "rotate", "pattern", "stop"}
chat.on_message(function(sender, reserved, text, team_chat, networked, is_auto)
    local is_friend = true
    if not chat_comms then 
        return 
    end
    local hdl = pid_to_handle(sender)
    if not NETWORK.NETWORK_IS_FRIEND(hdl) then
        is_friend = false
    end

    if players.user() ~= sender and not is_friend then 
        if cc_friend_only then 
            return 
        end
    end

    if cooldown_players[sender] ~= nil then 
        return 
    end

    if text:startswith(command_chat_prefix) then
        if text == command_chat_prefix .. "stop" then 
            stop_all_functions()
            chat.send_message("> All functions were stopped.", false, true, true)
            return 
        end
        if text.startswith(text, command_chat_prefix .. "pattern") then
            local command = text:split(' ')
            if #command ~= 3 then 
                chat.send_message("> Invalid number of arguments", false, true, true)
                return
            end
            local preset = string.lower(command[2])
            local duration = tonumber(command[3])
            if duration == nil then 
                chat.send_message("> Duration must be a number in seconds", false, true, true)
                return 
            end
            if not table.contains(valid_presets, preset) then 
                chat.send_message("> That is not a valid preset. Valid presets are " .. table.concat(valid_presets, ', '), false, true, true)
                return
            end
            if duration > cc_max_duration_secs then 
                chat.send_message("> Duration may not exceed " .. cc_max_duration_secs .. " seconds", false, true, true)
                return 
            end
            preset_vibrate(preset, duration)
            chat.send_message("> Preset vibration \"" .. preset .. "\" is now playing for " .. duration .. " seconds.", false, true, true)
            return
        end
        local command = text:split(' ')
        if #command >= 1 then
            if not table.contains(valid_chat_commands, string.lower(command[1]:gsub(command_chat_prefix, ''))) then 
                if debug then 
                    notify("That was not a valid chat command.")
                end
                return 
            end
        end
        if #command ~= 3 then 
            chat.send_message("> Invalid number of arguments", false, true, true)
            return
        end
        local strength = tonumber(command[2])
        local duration = tonumber(command[3])
        if strength == nil or duration == nil then 
            chat.send_message("> Arguments must be numbers only.", false, true, true)
            return 
        end
        if strength > 20 or strength < 1 then 
            chat.send_message("> Strength may not exceed 20 or be below 1", false, true, true)
            return 
        end
        if duration > cc_max_duration_secs then 
            chat.send_message("> Duration may not exceed " .. cc_max_duration_secs .. " seconds", false, true, true)
            return 
        end
        local p1 = string.lower(command[1]:gsub(command_chat_prefix, ''))
        if not table.contains(valid_commands, p1) then 
            chat.send_message("> Invalid command", false, true, true)
            return 
        end
        pluto_switch p1 do 
            case "vibrate":
            chat.send_message("> Vibration command sent for " .. duration .. " seconds at strength of " .. strength, false, true, true)
                vibrate(strength, duration, 0, 0)
                break
            case "pump":
                chat.send_message("> Pump command sent for " .. duration .. " seconds at strength of " .. strength, false, true, true)
                pump(strength, duration, 0, 0)
                break
            case "rotate":
                chat.send_message("> Rotation command sent for " .. duration .. " seconds at strength of " .. strength, false, true, true)
                rotate(strength, duration, 0, 0)
                break
        end
        cooldown_players[sender] = true 
        util.yield(cc_cooldown)
        cooldown_players[sender] = nil
    end
end)


-- DEBUG
util.create_tick_handler(function()
    if debug then
        for index, command in pairs(current_commands) do 
            util.draw_debug_text(command.command_string)
        end
    end
end)
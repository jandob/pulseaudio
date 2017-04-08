local pulseaudio = {}
local awful = require("awful")

-- Device Class
local Device = {}
function Device:set_volume(level)
    local commands = {
        ["Sink"] = "set-sink-volume",
        ["Sink Input"] = "set-sink-input-volume",
        ["Source"] = "set-source-volume",
        ["Source Output"] = "set-source-output-volume",
    }
    local command = commands[self.type]
    if command then
        awful.spawn.easy_async("pactl " .. command .. " " .. self.id
            .. " " .. level .."%" , function() end)
    end
end

function Device:parse_info()
    local info = self.info
    local active_port = string.match(info, "Active Port: (.-)\n")
    --local ports =  string.match(info, "Ports:.-Active Port")
    local active_port_description = nil
    if active_port then
        -- escape magic characters
        active_port_pattern  = string.gsub(active_port, "%p", "%%%1")
        active_port_description = string.match(
            info, active_port_pattern .. ": (.-) %("
        )
    end
    self.volume = tonumber(string.match(info, "Volume:.- (%d+)%%"))
    self.state = string.match(info, "State: (%w+)")
    self.client = string.match(info, "Client: (%d+)")
    self.description = string.match(info, "Description: (.-)\n")
    self.app_binary = string.match(info,
        "application.process.binary = \"([^\"]+)\"")
    self.active_port = active_port
    self.active_port_description = active_port_description
    self.ports = ports

    -- delete the raw info
    self.info = nil
end

-- public interface
function pulseaudio.get_devices(callback)
    awful.spawn.easy_async("pactl list", function(stdout)
        local devices = {}
        local current_device = nil

        -- discover devices
        for line in string.gmatch(stdout, "(.-\n)") do
            local i,_,deviceType,id = string.find(line,"(%w+.-) #(%d+)")
            if i == 1 then -- new device
                current_device = {
                    type = deviceType,
                    id = tonumber(id),
                    info = "",
                }
                -- add methods
                setmetatable(current_device, {__index = Device })
                -- add device to list
                devices[#devices + 1] = current_device
            elseif current_device then
                current_device.info = current_device.info .. line
            end
        end
        local filteredDevices = {}
        for i, device in ipairs(devices) do
            device:parse_info()
            -- filter out unwanted devices
            if device.volume and device.type ~= "Source Output" then
                filteredDevices[#filteredDevices + 1] = device
            end
        end
        callback(filteredDevices)
    end)
end
return pulseaudio

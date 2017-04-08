local wibox = require("wibox")
local beautiful = require("beautiful")
local awful = require("awful")
local gears = require("gears")

local pactl = require("pulseaudio.pactl")

-- helper functions {{{
local function array_has_value(tab, val)
    if tab == nil or val == nil then
        return false
    end
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end
-- }}}

local function tooltip_wibox(args)
    local tooltip = wibox {
        width = args.width,
        height = args.height,
        ontop = true,
        widget = args.widget,
    }
    -- since we cannot check if the mouse leaves the parent_widget and
    -- enters the tooltip wibox, we use a timer for closing the wibox
    local close_timer = gears.timer({ timeout = 0.5, })
    function tooltip:show(geometry)
        close_timer:connect_signal("timeout", function ()
            if array_has_value(mouse.current_widgets, args.parent_widget) or
                mouse.current_wibox == self
            then
                return
            end
            self.visible = false
            close_timer:stop()
        end)
        close_timer:start()

        -- place next to geometry
        awful.placement.next_to(self, {
            preferred_positions = {"top", "right", "left", "bottom"},
            geometry = geometry,
            honor_workarea = true,
        })
        awful.placement.no_offscreen(self)
        self.visible = true
    end
    -- manual hide
    function tooltip:hide()
        self.visible = false
    end
    return tooltip
end


local function factory(args)
    local slider_properties = {
        bar_shape = gears.shape.rounded_rect,
        bar_height = 3,
        bar_color = beautiful.volume_slider_color or beautiful.fg_urgent,
        handle_color = beautiful.volume_slider_handle_color or beautiful.fg_urgent,
        handle_shape = gears.shape.circle,
        handle_border_width = 0,
        handle_width = beautiful.volume_slider_handle_size or 10,
        forced_width = beautiful.volume_slider_width or 100,
        value = 25,
        visible = true,
        maximum = 153,
        minimum = 0,
        widget = wibox.widget.slider,
    }
    local args = args or {}
    local timeout = args.timeout or 53

    -- main slider
    local main_slider = wibox.widget(slider_properties)

    main_slider:connect_signal("property::value", function ()
        if not main_slider.pulseaudio_device then return end
        main_slider.pulseaudio_device:set_volume(main_slider.value)
    end)

    function main_slider:update_volume()
        pactl.get_devices(function (device_list)
            for _, device in ipairs(device_list) do
                if device.id == 0 and device.type == "Sink" then
                    self.value = device.volume
                    self.pulseaudio_device = device
                end
            end
        end)
    end
    -- update once at creation time
    main_slider:update_volume()



    local tooltip = nil
    main_slider:connect_signal("mouse::enter", function(other, geo)
        -- make sure only one instance of the wibox is created
        if tooltip and tooltip.visible then return end
        pactl.get_devices(function (device_list)
            local wibox_height = 0
            local slider_height = 20
            local slider_width = 100
            local n_w_max = 0
            local sliders = wibox.widget {
                forced_width = slider_width,
                layout  = wibox.layout.flex.vertical
            }
            for i, device in ipairs(device_list) do
                local textbox = wibox.widget.textbox()
                local slider
                if device.id == 0 and device.type == "Sink" then
                    slider = main_slider
                    slider.value = device.volume
                else
                    slider = wibox.widget(slider_properties)
                    slider.value = device.volume
                    slider:connect_signal("property::value", function ()
                        device:set_volume(slider.value)
                    end)
                end
                local device_widget = wibox.widget {
                    textbox,
                    wibox.widget.textbox(""),
                    slider,
                    layout = wibox.layout.align.horizontal,
                }
                textbox.text = device.active_port_description or
                    device.description or device.app_binary or ""
                local n_w = textbox:get_preferred_size(mouse.screen)
                n_w_max = (n_w > n_w_max) and n_w or n_w_max
                sliders:add(device_widget)
                wibox_height = wibox_height + slider_height
            end

            tooltip = tooltip_wibox({
                widget = sliders,
                parent_widget = main_slider,
                width = slider_width + n_w_max,
                height = wibox_height
            })
            tooltip:show(geo)
        end)
    end)

    -- Set up a timer to refresh main_slider every `timeout` seconds
    local mytimer = timer({ timeout = timeout })
    mytimer:connect_signal("timeout", function() main_slider:update_volume() end)
    mytimer:start()

    return wibox.widget {
        main_slider,
        layout = wibox.layout.fixed.horizontal,
    }
end
return factory
-- vim: filetype=lua:expandtab:fdm=marker:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80

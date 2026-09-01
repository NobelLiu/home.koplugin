--[[--
status_bar.lua — Home status display helpers.

Provides the status information and text shown next to the greeting/time
title (battery, Wi-Fi, frontlight). This module has no widget and no layout
code: it only returns the data and face, and the parent view (the Library
action bar) builds the label and lays it out itself.

Fonts match the TouchMenu footer's device_info (time_info):
  frontend/ui/widget/touchmenu.lua — self.fface = Font:getFace("ffont")
--]]

local BD = require("ui/bidi")
local Device = require("device")
local Font = require("ui/font")

-- Same glyph as ReaderFooter symbol_prefix.icons.wifi_status (nerdfonts/symbols.ttf).
local WIFI_ICON = "\u{ECA8}"
-- Frontlight (screen light) icon, shown while the light is on.
local FRONTLIGHT_ICON = "\u{ECA7}"

local StatusBar = {}

--- Face used by the status display area (same as the TouchMenu footer, so the
--- nerd-font glyphs resolve through the same fallback chain).
function StatusBar.face()
    return Font:getFace("ffont")
end

--- Collect the status information to display right now. No clock here — the
--- clock is the title's greeting → time label.
function StatusBar.collectInfo()
    local info = {}

    if Device:hasBattery() then
        pcall(function()
            local powerd = Device:getPowerDevice()
            if not powerd then return end
            local cap = powerd:getCapacity()
            if type(cap) ~= "number" then return end
            info.battery = cap
            info.is_charging = powerd:isCharging()
            info.is_charged = powerd:isCharged()
            info.battery_sym = powerd:getBatterySymbol(
                info.is_charged, info.is_charging, cap) or ""
            if Device:hasAuxBattery() and powerd:isAuxBatteryConnected() then
                local aux_cap = powerd:getAuxCapacity()
                if type(aux_cap) == "number" then
                    info.aux_battery = aux_cap
                    info.aux_battery_sym = powerd:getBatterySymbol(
                        powerd:isAuxCharged(), powerd:isAuxCharging(), aux_cap) or ""
                end
            end
        end)
    end

    if Device:hasFrontlight() then
        pcall(function()
            local powerd = Device:getPowerDevice()
            if not powerd then return end
            info.frontlight_on = powerd:isFrontlightOn()
        end)
    end

    if Device:hasWifiToggle() then
        pcall(function()
            local NetworkMgr = require("ui/network/manager")
            info.wifi_connected = NetworkMgr:isConnected()
        end)
    end

    return info
end

--- Menu-footer battery segment: while charging, prefix ⌁ + symbol +
--- percentage (with optional auxiliary battery).
--- @see TouchMenu:updateItems
function StatusBar.formatBatteryText(info)
    if not info.battery_sym or not info.battery then return "" end
    local txt = ""
    if info.is_charging then
        txt = BD.wrap("⌁")
    end
    txt = txt .. BD.wrap(info.battery_sym) .. BD.wrap(info.battery .. "%")
    if info.aux_battery_sym and info.aux_battery then
        txt = txt .. " " .. BD.wrap("+") .. BD.wrap(info.aux_battery_sym)
            .. BD.wrap(info.aux_battery .. "%")
    end
    return txt
end

--- The status display area text: the frontlight icon (when on), the Wi-Fi
--- icon (when connected) and the battery text, space-separated. Empty when
--- there is nothing to show (e.g. a device without battery/frontlight/Wi-Fi).
function StatusBar.statusText(info)
    local items = {}
    if info.frontlight_on then
        items[#items + 1] = BD.wrap(FRONTLIGHT_ICON)
    end
    if info.wifi_connected then
        items[#items + 1] = BD.wrap(WIFI_ICON)
    end
    local battery_txt = StatusBar.formatBatteryText(info)
    if battery_txt ~= "" then
        items[#items + 1] = battery_txt
    end
    return table.concat(items, " ")
end

return StatusBar

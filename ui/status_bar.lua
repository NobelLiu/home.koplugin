--[[--
status_bar.lua — Home top-bar helpers and kit StatusBar assembly.

Standard layout: time on the left, device status on the right. All glyphs and
text use HIG Headline; battery icon + percent are spaced 2pt, status items 10pt.
]]

local Device = require("device")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local TextWidget = require("ui/widget/textwidget")

local StatusBarWidget = require("ui/uikit/components/chrome/status_bar")
local Theme = require("ui/uikit/components/theme")

local StatusBar = {}

local STATUS_ROLE = "headline"
local BATTERY_INNER_GAP = Layout.gap.vstack
local STATUS_ITEM_GAP = Layout.gap.content

function StatusBar.face()
    return Theme.symbolFace(STATUS_ROLE)
end

function StatusBar.textFace()
    return Theme.face(STATUS_ROLE)
end

function StatusBar.currentTimeText()
    local now = os.time()
    if G_reader_settings:isTrue("twelve_hour_clock") then
        return os.date("%I:%M %p", now)
    end
    return os.date("%H:%M", now)
end

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
            info.battery_sym = Theme.batteryGlyph(
                info.is_charged, info.is_charging, cap)
            if Device:hasAuxBattery() and powerd:isAuxBatteryConnected() then
                local aux_cap = powerd:getAuxCapacity()
                if type(aux_cap) == "number" then
                    info.aux_battery = aux_cap
                    info.is_aux_charging = powerd:isAuxCharging()
                    info.is_aux_charged = powerd:isAuxCharged()
                    info.aux_battery_sym = Theme.batteryGlyph(
                        info.is_aux_charged, info.is_aux_charging, aux_cap)
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

--- Sun in day theme, moon in night theme. Empty when the frontlight is off.
function StatusBar.frontlightGlyph(info)
    if not (info and info.frontlight_on) then
        return ""
    end
    if G_reader_settings:isTrue("night_mode") then
        return Theme.icon.moon
    end
    return Theme.icon.sun
end

local function symbolText(text)
    return TextWidget:new{
        text = text or "",
        face = StatusBar.face(),
        fgcolor = Theme.color.black,
        padding = 0,
    }
end

local function percentText(text)
    return TextWidget:new{
        text = text or "",
        face = StatusBar.textFace(),
        fgcolor = Theme.color.black,
        padding = 0,
    }
end

local function appendGap(row, width)
    if #row > 0 and width > 0 then
        row[#row + 1] = HorizontalSpan:new{ width = width }
    end
end

local function buildBatterySegment(parts, is_charged, is_charging, capacity)
    local glyph = Theme.batteryGlyph(is_charged, is_charging, capacity)
    local percent = Theme.batteryPercentText(capacity)
    local glyph_widget = symbolText(glyph)
    local percent_widget = percentText(percent)
    local segment = HorizontalGroup:new{ align = "center" }
    segment[#segment + 1] = glyph_widget
    segment[#segment + 1] = HorizontalSpan:new{ width = pt(BATTERY_INNER_GAP) }
    segment[#segment + 1] = percent_widget
    parts.batteries[#parts.batteries + 1] = {
        glyph = glyph_widget,
        percent = percent_widget,
        _last_glyph = glyph,
        _last_percent = percent,
    }
    return segment
end

--- Right-side status cluster: Headline symbols + battery %, 10pt between items.
--- Frontlight keeps a dedicated slot so it can appear/hide without rebuilding.
function StatusBar.buildStatusCluster(info)
    info = info or StatusBar.collectInfo()
    local row = HorizontalGroup:new{ align = "center" }
    local parts = { batteries = {}, item_gap = pt(STATUS_ITEM_GAP) }
    local item_gap = parts.item_gap
    local has_wifi = info.wifi_connected
    local has_battery = info.battery ~= nil or info.aux_battery ~= nil

    if Device:hasFrontlight() then
        local glyph = StatusBar.frontlightGlyph(info)
        local glyph_widget = symbolText(glyph)
        row[#row + 1] = glyph_widget
        local gap_w = (glyph ~= "" and (has_wifi or has_battery)) and item_gap or 0
        local gap = HorizontalSpan:new{ width = gap_w }
        row[#row + 1] = gap
        parts.frontlight = {
            glyph = glyph_widget,
            gap = gap,
            _last_glyph = glyph,
            _last_gap = gap_w,
        }
        parts.has_trailing_after_frontlight = has_wifi or has_battery
    end
    if has_wifi then
        -- Frontlight's trailing gap already separates the next visible item.
        if not Device:hasFrontlight() then
            appendGap(row, item_gap)
        end
        row[#row + 1] = symbolText(Theme.icon.wifi)
        parts.wifi = row[#row]
    end
    if info.battery ~= nil then
        if not Device:hasFrontlight() or has_wifi then
            appendGap(row, item_gap)
        end
        row[#row + 1] = buildBatterySegment(parts, info.is_charged, info.is_charging, info.battery)
    end
    if info.aux_battery ~= nil then
        if info.battery ~= nil or has_wifi or not Device:hasFrontlight() then
            appendGap(row, item_gap)
        end
        row[#row + 1] = buildBatterySegment(parts, info.is_aux_charged, info.is_aux_charging, info.aux_battery)
    end

    row._status_parts = parts
    return row
end

function StatusBar.refreshStatusCluster(cluster, info)
    if not (cluster and cluster._status_parts) then
        return false
    end
    info = info or StatusBar.collectInfo()
    local parts = cluster._status_parts
    local dirty = false

    if parts.frontlight and parts.frontlight.glyph then
        local glyph = StatusBar.frontlightGlyph(info)
        local gap_w = 0
        if glyph ~= "" and parts.has_trailing_after_frontlight then
            gap_w = parts.item_gap or 0
        end
        if glyph ~= parts.frontlight._last_glyph then
            parts.frontlight.glyph:setText(glyph)
            parts.frontlight._last_glyph = glyph
            dirty = true
        end
        if parts.frontlight.gap and parts.frontlight._last_gap ~= gap_w then
            parts.frontlight.gap.width = gap_w
            parts.frontlight._last_gap = gap_w
            dirty = true
        end
    end

    local batteries = {
        {
            info.is_charged,
            info.is_charging,
            info.battery,
        },
        {
            info.is_aux_charged,
            info.is_aux_charging,
            info.aux_battery,
        },
    }

    for i, segment in ipairs(parts.batteries) do
        local charged, charging, capacity = batteries[i][1], batteries[i][2], batteries[i][3]
        if capacity ~= nil and segment.glyph and segment.percent then
            local glyph = Theme.batteryGlyph(charged, charging, capacity)
            local percent = Theme.batteryPercentText(capacity)
            if glyph ~= segment._last_glyph then
                segment.glyph:setText(glyph)
                segment._last_glyph = glyph
                dirty = true
            end
            if percent ~= segment._last_percent then
                segment.percent:setText(percent)
                segment._last_percent = percent
                dirty = true
            end
        end
    end
    if dirty and cluster.resetLayout then
        cluster:resetLayout()
    end
    return dirty
end

--- Legacy single-string status (all Material Symbols). Prefer buildStatusCluster.
function StatusBar.statusText(info)
    info = info or StatusBar.collectInfo()
    local items = {}
    if info.frontlight_on then
        items[#items + 1] = StatusBar.frontlightGlyph(info)
    end
    if info.wifi_connected then
        items[#items + 1] = Theme.icon.wifi
    end
    if info.battery ~= nil then
        items[#items + 1] = Theme.batteryText(
            info.is_charged, info.is_charging, info.battery)
    end
    if info.aux_battery ~= nil then
        items[#items + 1] = Theme.batteryText(
            info.is_aux_charged, info.is_aux_charging, info.aux_battery)
    end
    return table.concat(items, " ")
end

--- Fixed status bar chrome height (50pt) for layout; content is centered inside.
function StatusBar.metrics(width)
    return {
        width = width,
        height = pt(Layout.dim.status_bar),
        padding_horizontal = pt(Layout.pad.bar),
        border_height = pt(Layout.dim.border),
        time_text = StatusBar.currentTimeText(),
        cluster = StatusBar.buildStatusCluster(StatusBar.collectInfo()),
    }
end

--- Build the top StatusBar: time left, device status right.
function StatusBar.build(opts)
    opts = opts or {}
    local home = opts.home
    local width = opts.width
    local metrics = opts.metrics or StatusBar.metrics(width)
    local status_cluster = metrics.cluster or StatusBar.buildStatusCluster(StatusBar.collectInfo())
    local time_text = metrics.time_text or StatusBar.currentTimeText()

    local bar = StatusBarWidget:new{
        time_text = time_text,
        status_widget = status_cluster,
        width = width,
        height = metrics.height,
        title_role = STATUS_ROLE,
        time_role = STATUS_ROLE,
        on_status_tap = home and home.onShowStatusPanel and function()
            home:onShowStatusPanel()
        end,
        padding_horizontal = metrics.padding_horizontal,
        show_divider = true,
        divider_color = Layout.COLOR_COVER_BORDER,
        divider_size = metrics.border_height or pt(Layout.dim.border),
    }
    if home then
        home._status_label = bar.status_label
        home._status_cluster = status_cluster
        home._status_tap = bar.status_tap
        home._time_label = bar.time_label
        if home._time_label then
            home._time_label._tw_last_time_text = time_text
        end
    end
    return bar
end

return StatusBar

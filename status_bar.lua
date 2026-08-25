--[[--
status_bar.lua — Home top status bar.

Fonts match the TouchMenu footer's device_info (time_info):
  frontend/ui/widget/touchmenu.lua — self.fface = Font:getFace("ffont")
  Date (e.g. "Mon Aug 24") is left-aligned; time is centered; the frontlight
  icon (when the light is on) + Wi-Fi (when connected) + battery symbol +
  percentage are right-aligned.
  The periodic refresh repaints the whole bar (the centered time width can
  change and the date can roll over at midnight).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local datetime = require("datetime")
local Device = require("device")
local Font = require("ui/font")
local Size = require("ui/size")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Layout = require("layout")

-- Same glyph as ReaderFooter symbol_prefix.icons.wifi_status (nerdfonts/symbols.ttf).
local WIFI_ICON = "\u{ECA8}"
-- Frontlight (screen light) icon, shown left of the Wi-Fi icon while the light is on.
local FRONTLIGHT_ICON = "\u{ECA7}"

local REFRESH_INTERVAL = 60 -- seconds

local StatusBar = {}

--- Same face as TouchMenu.fface (menu footer time / page number / device info).
local function footerFace()
    return Font:getFace("ffont")
end

local function textWidget(text)
    return TextWidget:new{
        text = text,
        face = footerFace(),
        fgcolor = Blitbuffer.COLOR_BLACK,
        padding = 0,
        bold = false,
    }
end

--- Format the current date as e.g. "Mon Aug 24", localized via KOReader's
--- short day/month translation tables.
local function formatDate(seconds)
    local wday  = os.date("%a", seconds)
    local month = os.date("%b", seconds)
    local day   = os.date("%d", seconds)
    local wday_t  = datetime.shortDayOfWeekTranslation[wday] or wday
    local month_t = datetime.shortMonthTranslation[month] or month
    return wday_t .. " " .. month_t .. " " .. day
end

--- Collect the status information to display right now.
function StatusBar.collectInfo()
    local now = os.time()
    local info = {
        time = datetime.secondsToHour(now, G_reader_settings:isTrue("twelve_hour_clock")),
        date = formatDate(now),
    }

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

local function buildRightGroup(info)
    local items = {}
    local battery_widget
    if info.frontlight_on then
        items[#items + 1] = textWidget(BD.wrap(FRONTLIGHT_ICON))
        items[#items + 1] = HorizontalSpan:new{
            width = Size.span.horizontal_small + Size.padding.tiny,
        }
    end
    if info.wifi_connected then
        items[#items + 1] = textWidget(BD.wrap(WIFI_ICON))
        items[#items + 1] = HorizontalSpan:new{
            width = Size.span.horizontal_small + Size.padding.tiny,
        }
    end
    local battery_txt = StatusBar.formatBatteryText(info)
    if battery_txt ~= "" then
        battery_widget = textWidget(battery_txt)
        items[#items + 1] = battery_widget
    end
    if #items == 0 then
        return nil, nil
    end
    local group_args = { align = "center" }
    for i, item in ipairs(items) do
        group_args[i] = item
    end
    return HorizontalGroup:new(group_args), battery_widget
end

local StatusBarWidget = WidgetContainer:extend{
    name = "home_status_bar",
}

function StatusBarWidget:init()
    self.screen_w = Device.screen:getWidth()
    self.side_m = Layout.scaledSetting("status_side_padding")
    self.vert_m = Layout.scaledSetting("status_vert_padding")
    self._wifi_shown = false
    self._frontlight_shown = false
    self:build()
end

function StatusBarWidget:build()
    local info = StatusBar.collectInfo()
    self._wifi_shown = info.wifi_connected and true or false
    self._frontlight_shown = info.frontlight_on and true or false

    local inner_w = self.screen_w - self.side_m * 2
    self.date_widget = textWidget(info.date)
    self.time_widget = textWidget(info.time)
    self.right_group, self.battery_widget = buildRightGroup(info)

    local row_h = math.max(self.date_widget:getSize().h, self.time_widget:getSize().h)
    if self.right_group then
        row_h = math.max(row_h, self.right_group:getSize().h)
    end

    local row = OverlapGroup:new{
        dimen = Geom:new{ w = inner_w, h = row_h },
        LeftContainer:new{
            dimen = Geom:new{ w = inner_w, h = row_h },
            self.date_widget,
        },
        CenterContainer:new{
            dimen = Geom:new{ w = inner_w, h = row_h },
            self.time_widget,
        },
        RightContainer:new{
            dimen = Geom:new{ w = inner_w, h = row_h },
            self.right_group or TextWidget:new{
                text = "",
                face = footerFace(),
                padding = 0,
            },
        },
    }

    local content_frame = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = self.side_m,
        padding_right = self.side_m,
        padding_top = self.vert_m,
        padding_bottom = self.vert_m,
        row,
    }
    local total_h = content_frame:getSize().h

    self:clear(true)
    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        dimen = Geom:new{ w = self.screen_w, h = total_h },
        OverlapGroup:new{
            dimen = Geom:new{ w = self.screen_w, h = total_h },
            content_frame,
            BottomContainer:new{
                dimen = Geom:new{ w = self.screen_w, h = total_h },
                LineWidget:new{
                    dimen = Geom:new{ w = self.screen_w, h = Layout.dim.divider },
                    background = Blitbuffer.COLOR_GRAY_E,
                },
            },
        },
    }
    self.dimen = Geom:new{ w = self.screen_w, h = total_h }
    self:_computeRegions()
end

function StatusBarWidget:getHeight()
    return self.dimen and self.dimen.h or 0
end

function StatusBarWidget:_computeRegions()
    local bar_h = self.dimen.h
    local date_w = self.date_widget:getSize().w
    self.date_region = Geom:new{
        x = 0,
        y = 0,
        w = math.min(self.side_m + date_w + Size.padding.buttontable * 2, self.screen_w),
        h = bar_h,
    }
    local time_w = self.time_widget:getSize().w
    local time_half = math.floor(time_w / 2) + Size.padding.buttontable
    local center_x = math.floor(self.screen_w / 2)
    self.time_region = Geom:new{
        x = math.max(0, center_x - time_half),
        y = 0,
        w = math.min(self.screen_w, time_half * 2),
        h = bar_h,
    }
    local right_w = self.right_group and self.right_group:getSize().w or 0
    self.right_region = Geom:new{
        x = math.max(0, self.screen_w - self.side_m - right_w - Size.padding.buttontable * 2),
        y = 0,
        w = math.min(self.screen_w, self.side_m + right_w + Size.padding.buttontable * 2),
        h = bar_h,
    }
    self.bar_region = Geom:new{ x = 0, y = 0, w = self.screen_w, h = bar_h }
end

function StatusBarWidget:_refreshRegion(region)
    UIManager:widgetRepaint(self, 0, 0)
    UIManager:setDirty(nil, function()
        return "ui", region
    end)
end

function StatusBarWidget:updateTime()
    local info = StatusBar.collectInfo()
    self.time_widget:setText(info.time)
    self.date_widget:setText(info.date)
    self:_computeRegions()
    self:_refreshRegion(self.bar_region)
end

function StatusBarWidget:updateRight()
    local info = StatusBar.collectInfo()
    local wifi_shown = info.wifi_connected and true or false
    local frontlight_shown = info.frontlight_on and true or false
    local battery_txt = StatusBar.formatBatteryText(info)

    if wifi_shown ~= self._wifi_shown or frontlight_shown ~= self._frontlight_shown then
        self:build()
        self:_refreshRegion(self.bar_region)
        return
    end

    if self.battery_widget then
        self.battery_widget:setText(battery_txt)
        self:_computeRegions()
        self:_refreshRegion(self.right_region)
        return
    end

    self:build()
    self:_refreshRegion(self.bar_region)
end

function StatusBarWidget:updatePeriodic()
    local info = StatusBar.collectInfo()
    local wifi_shown = info.wifi_connected and true or false
    local frontlight_shown = info.frontlight_on and true or false

    if wifi_shown ~= self._wifi_shown or frontlight_shown ~= self._frontlight_shown then
        self:build()
        self:_refreshRegion(self.bar_region)
        return
    end

    self.time_widget:setText(info.time)
    self.date_widget:setText(info.date)
    if self.battery_widget then
        self.battery_widget:setText(StatusBar.formatBatteryText(info))
    end
    self:_computeRegions()
    self:_refreshRegion(self.bar_region)
end

function StatusBar.scheduleRefresh(widget, on_time_refresh)
    if widget._home_statusbar_timer then
        UIManager:unschedule(widget._home_statusbar_timer)
        widget._home_statusbar_timer = nil
    end
    if not on_time_refresh then return end

    local function tick()
        widget._home_statusbar_timer = tick
        UIManager:scheduleIn(REFRESH_INTERVAL, tick)
        -- Only repaint while Home is the frontmost (topmost visible) widget. If
        -- anything covers it — the top menu, the status panel, the lock screen,
        -- or the reader — skip this tick's repaint but keep the timer alive, so
        -- once Home is uncovered again the per-minute cadence resumes on its own
        -- (e.g. closing the top menu) without any extra event wiring. The three
        -- explicit re-entries (reader / lock screen / panel) additionally do an
        -- immediate refresh + greeting replay via Home:refreshOnReentry.
        if UIManager:getTopmostVisibleWidget() ~= widget then return end
        -- While the device is suspended / the screensaver (lock screen) is up,
        -- Home is still on the widget stack (just covered), so we must not
        -- repaint: doing so flashes the status bar region behind the lock
        -- screen.
        if Device.screen_saver_mode then return end
        on_time_refresh()
    end
    widget._home_statusbar_timer = tick
    UIManager:scheduleIn(REFRESH_INTERVAL, tick)
end

function StatusBar.unschedule(widget)
    if widget and widget._home_statusbar_timer then
        UIManager:unschedule(widget._home_statusbar_timer)
        widget._home_statusbar_timer = nil
    end
end

StatusBar.new = function(...)
    return StatusBarWidget:new(...)
end

return StatusBar

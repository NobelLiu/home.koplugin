--[[--
status_panel.lua — Right-anchored, full-height quick status / control panel.

Opened by tapping the icon cluster (right region) of the Home status bar.
Visual model (see design spec):
  * A vertical panel occupying the golden-ratio width (0.618 * screen width),
    anchored to the right edge, full screen height, with a left border matching
    the status bar bottom divider. The remaining left strip is a tap-to-close scrim.
  * Rows are stacked from the top. Each row height equals the Home status bar
    height, uses HIG Headline (same as the status bar), has a bottom divider
    matching the status bar hairline, and lays out a left content area (20px inset) vs a trailing
    row_height x row_height square icon/control box on the right.

Rows (top to bottom):
  1. Close (X) — right-aligned square box.
  2. Charge   — battery symbol + percentage (+ "charging"), read-only.
  3. Wi-Fi    — label/status tap opens network info; trailing icon toggles Wi-Fi.
  4. Brightness — a slider (0 = off, 1..max = on; far left turns the frontlight off);
     trailing icon toggles night mode.
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Event = require("ui/event")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Slider = require("ui/common/slider")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local Theme = require("ui/uikit/components/theme")

-- Golden-ratio panel width.
local PANEL_WIDTH_RATIO = 0.618
local PANEL_BORDER_COLOR = Layout.COLOR_COVER_BORDER
local PANEL_BORDER_SIZE = pt(Layout.dim.border)

local StatusPanel = InputContainer:extend{
    name = "home_status_panel",
    modal = true,
    covers_fullscreen = true,
    -- Row height (== Home status bar height); set by the caller, else derived.
    row_height = nil,
}

local STATUS_ROLE = "headline"

local function barFace()
    return Theme.face(STATUS_ROLE)
end

local function iconFace()
    return Theme.symbolFace(STATUS_ROLE)
end

local function barText(text)
    return TextWidget:new{
        text = text,
        face = barFace(),
        fgcolor = Blitbuffer.COLOR_BLACK,
        padding = 0,
        bold = false,
    }
end

function StatusPanel:init()
    self.screen_width = Screen:getWidth()
    self.screen_height = Screen:getHeight()
    self.powerd = Device:getPowerDevice()

    -- Row height matches the status bar; fall back to measured chrome height.
    if not self.row_height or self.row_height <= 0 then
        self.row_height = pt(Layout.dim.status_bar)
    end

    self.panel_width = math.floor(self.screen_width * PANEL_WIDTH_RATIO)
    self.panel_x = self.screen_width - self.panel_width
    self.left_padding = pt(Layout.pad.bar)
    self.icon_box = self.row_height             -- trailing square icon box (row_height x row_height)

    -- Ordered list of rows, so tap hit-testing can map y -> row without
    -- hardcoding indices (rows are added conditionally).
    self.row_kinds = {}

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{ x = 0, y = 0, w = self.screen_width, h = self.screen_height },
            },
        }
    end

    self:build()
end

--- A trailing square (row_height x row_height) box with a centered icon glyph widget.
--- Returns box, glyph_widget (same frame reference for glyph updates).
function StatusPanel:_iconBox(glyph, face)
    local glyph_widget = TextWidget:new{
        text = glyph,
        face = face or iconFace(),
        fgcolor = Blitbuffer.COLOR_BLACK,
        padding = 0,
        bold = false,
    }
    local frame = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = self.icon_box, h = self.row_height },
            glyph_widget,
        },
    }
    return frame, glyph_widget, frame
end

--- Assemble one row_height-tall row: `left_widget` in the left content area
--- (20px inset), `right_box` as the trailing square, plus a bottom divider
--- matching the status bar hairline. `kind` records the row for tap dispatch.
function StatusPanel:_makeRow(kind, left_widget, right_box)
    self.row_kinds[#self.row_kinds + 1] = kind
    local content_width = self.panel_width

    local left = LeftContainer:new{
        dimen = Geom:new{
            w = math.max(0, math.floor(content_width - self.icon_box)),
            h = self.row_height,
        },
        FrameContainer:new{
            bordersize = 0,
            padding = 0,
            padding_left = self.left_padding,
            left_widget,
        },
    }
    local right = RightContainer:new{
        dimen = Geom:new{ w = content_width, h = self.row_height },
        right_box,
    }
    -- Bottom hairline (same token as the status bar divider).
    local border = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = self.row_height - PANEL_BORDER_SIZE },
        LineWidget:new{
            dimen = Geom:new{ w = content_width, h = PANEL_BORDER_SIZE },
            background = PANEL_BORDER_COLOR,
        },
    }

    return OverlapGroup:new{
        dimen = Geom:new{ w = content_width, h = self.row_height },
        left,
        right,
        border,
    }
end

--- Charge row: battery symbol + percentage + optional "charging". Tapping the
--- whole row (label or icon) opens the battery statistics page.
function StatusPanel:_buildChargeRow()
    local text, sym = self:_chargeState()
    local label = barText(text)
    self.charge_label_glyph = label
    local icon, glyph, frame = self:_iconBox(BD.wrap(sym), iconFace())
    self.charge_icon_glyph = glyph
    self.charge_frame = frame
    return self:_makeRow("charge", label, icon)
end

--- Current charge display: returns (label_text, battery_symbol). Mirrors the
--- status bar's collectInfo battery segment.
function StatusPanel:_chargeState()
    local text = _("N/A")
    local sym = ""
    if Device:hasBattery() then
        local ok, cap = pcall(function() return self.powerd:getCapacity() end)
        if ok and type(cap) == "number" then
            local charging, charged = false, false
            pcall(function() charging = self.powerd:isCharging() end)
            pcall(function() charged = self.powerd:isCharged() end)
            sym = Theme.batteryGlyph(charged, charging, cap)
            text = string.format("%d%%", cap)
            if charging then
                text = text .. " " .. _("Charging")
            end
        end
    end
    return text, sym
end

--- Refresh the charge row from the current power state. Bound to a stable
--- method reference so it can be scheduled/unscheduled; guarded against the
--- panel being torn down before a scheduled tick fires.
function StatusPanel:_refreshChargeRow()
    if self._closed or not self.charge_label_glyph then return end
    local text, sym = self:_chargeState()
    self.charge_label_glyph:setText(text)
    if self.charge_icon_glyph then
        self.charge_icon_glyph:setText(BD.wrap(sym))
    end
    UIManager:setDirty(self, "ui", self:_panelRect())
end

-- Plugging/unplugging the charger broadcasts Charging / NotCharging. Refresh
-- the charge row so the symbol and the "Charging" suffix update immediately
-- instead of waiting for the panel to be reopened. The capacity reading can
-- lag the plug-in event by a moment, so also re-read shortly after.
function StatusPanel:onCharging()
    self:_refreshChargeRow()
    UIManager:scheduleIn(1, self._refreshChargeRow, self)
end
StatusPanel.onNotCharging = StatusPanel.onCharging

--- Wi-Fi row: label/status opens network info; trailing icon toggles Wi-Fi.
--- Current Wi-Fi state: returns (label_text, status), where status is one of:
---   "off"          -> radio off              ("Wi-Fi 已关闭"), wifi-off icon
---   "connecting"   -> a connection attempt is in flight ("正在连接…"), dots icon
---   "disconnected" -> on but unassociated    ("Wi-Fi 未连接"), wifi icon
---   "connected"    -> associated             (the SSID),        wifi icon
--- Note that "disconnected" and "connected" share the same wifi icon; only the
--- label differs.
function StatusPanel:_wifiState()
    local NetworkMgr = require("ui/network/manager")
    local on, connected, connecting = false, false, false
    pcall(function() on = NetworkMgr:isWifiOn() and true or false end)
    -- A connection attempt in progress (radio may be coming up and/or
    -- associating). Report this even if isWifiOn() is not yet true, so tapping
    -- "turn on" reflects immediately rather than briefly showing "off".
    pcall(function() connecting = NetworkMgr.pending_connection and true or false end)
    if not on and not connecting then
        return _("Wi-Fi off"), "off"
    end
    pcall(function() connected = NetworkMgr:isConnected() and true or false end)
    if connecting and not connected then
        -- Reuse KOReader core's existing string so we inherit its translations
        -- across all languages rather than shipping a plugin-specific one.
        return _("Connecting to Wi-Fi…"), "connecting"
    end
    if not connected then
        return _("Wi-Fi not connected"), "disconnected"
    end
    local ssid
    pcall(function()
        local nw = NetworkMgr:getCurrentNetwork()
        if nw and nw.ssid then
            ssid = require("util").fixUtf8(nw.ssid, "\u{FFFD}")
        end
    end)
    if ssid and ssid ~= "" then
        return ssid, "connected"
    end
    return _("Wi-Fi connected"), "connected"
end

--- Map a Wi-Fi status (see _wifiState) to its trailing icon glyph.
local function wifiStatusIcon(status)
    if status == "connecting" then
        return Theme.icon.ellipsis
    end
    if status == "off" then
        return Theme.icon.wifi_off
    end
    return Theme.icon.wifi
end

function StatusPanel:_buildWifiRow()
    local text, status = self:_wifiState()
    local label = barText(text)
    self.wifi_label_glyph = label
    local icon, glyph, frame = self:_iconBox(wifiStatusIcon(status))
    self.wifi_icon_glyph = glyph
    self.wifi_frame = frame
    return self:_makeRow("wifi", label, icon)
end

--- Brightness row: a slider (0 = off, 1..max = on) + trailing brightness icon.
function StatusPanel:_buildBrightnessRow()
    self.fl = {
        -- UI range uses 0 for "off", matching KOReader's FrontLightWidget and
        -- powerd:frontlightIntensity() (which reports 0 while off even when the
        -- native HW floor fl_min is > 0, e.g. on Android).
        min = 0,
        max = self.powerd.fl_max,
        cur = 0,
    }
    pcall(function()
        self.fl.cur = self.powerd:frontlightIntensity()
    end)

    -- _makeRow already insets the left widget by one left_padding and reserves the
    -- trailing icon box, so the slider spans exactly from left_padding to the icon
    -- box (aligning with the other rows' left content), with no extra wrapper.
    local track_width = math.max(0, math.floor(self.panel_width - self.icon_box - self.left_padding))
    self.fl_slider = Slider:new{
        -- Slider width/height are design pt; pass pre-scaled device px here.
        width_px = track_width,
        height_px = self.row_height,
        min = self.fl.min,
        max = self.fl.max,
        value = self.fl.cur,
        step = 1,
        -- If the device's native range is larger than 100 (e.g. reMarkable's
        -- 0..2047), label the handle as a 0..100 percentage for a consistent,
        -- readable value. Smaller native ranges (Kindle 0..24, Kobo 0..100)
        -- keep showing the native level number.
        display_max = self.fl.max > 100 and 100 or nil,
        show_parent = self,
        on_change = function(v) self:_setBrightness(v) end,
    }
    local icon, glyph, frame = self:_iconBox(self:_nightModeGlyph())
    self.night_mode_icon_glyph = glyph
    self.night_mode_frame = frame
    return self:_makeRow("brightness", self.fl_slider, icon)
end

--- The trailing icon glyph for the current night mode state.
function StatusPanel:_nightModeGlyph()
    local on = G_reader_settings:isTrue("night_mode")
    return on and Theme.icon.moon or Theme.icon.sun
end

function StatusPanel:build()
    local rows = VerticalGroup:new{ align = "left" }

    -- Row 1: close (right-aligned square box; empty left content).
    local close_box, _cg, close_frame = self:_iconBox(Theme.icon.close)
    self.close_frame = close_frame
    rows[#rows + 1] = self:_makeRow("close", barText(""), close_box)

    -- Row 2: charge.
    rows[#rows + 1] = self:_buildChargeRow()

    -- Row 3: Wi-Fi.
    if Device:hasWifiToggle() then
        rows[#rows + 1] = self:_buildWifiRow()
    end

    -- Row 4: brightness.
    if Device:hasFrontlight() then
        rows[#rows + 1] = self:_buildBrightnessRow()
    end

    -- Panel: golden-ratio width, full height, white, top-aligned rows, with a
    -- left border matching the status bar bottom divider.
    self.panel = OverlapGroup:new{
        dimen = Geom:new{ w = self.panel_width, h = self.screen_height },
        FrameContainer:new{
            bordersize = 0,
            padding = 0,
            margin = 0,
            background = Blitbuffer.COLOR_WHITE,
            width = self.panel_width,
            height = self.screen_height,
            rows,
        },
        LineWidget:new{
            dimen = Geom:new{ w = PANEL_BORDER_SIZE, h = self.screen_height },
            background = PANEL_BORDER_COLOR,
        },
    }

    self.frame = self.panel
    self[1] = RightContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = self.screen_width, h = self.screen_height },
        self.panel,
    }
end

--- Screen-space rect of the whole panel.
function StatusPanel:_panelRect()
    return Geom:new{ x = self.panel_x, y = 0, w = self.panel_width, h = self.screen_height }
end

--- Screen-space rect of the trailing square icon box for a given row index.
function StatusPanel:_iconBoxRect(row_index)
    return Geom:new{
        x = self.screen_width - self.icon_box,
        y = (row_index - 1) * self.row_height,
        w = self.icon_box,
        h = self.row_height,
    }
end

--- Screen-space rect of a full row for a given row index.
function StatusPanel:_rowRect(row_index)
    return Geom:new{
        x = self.panel_x,
        y = (row_index - 1) * self.row_height,
        w = self.panel_width,
        h = self.row_height,
    }
end

--- Index of the first row of the given kind, or nil.
function StatusPanel:_rowIndex(kind)
    for i, k in ipairs(self.row_kinds) do
        if k == kind then return i end
    end
    return nil
end

function StatusPanel:onShowWifiInfo()
    -- Close the panel first, then show the network-info dialog. Prefer the
    -- platform's dialog via the "ShowNetworkInfo" event, but some backends have
    -- a broken netinfo FFI (e.g. an out-of-sync base build) that raises when
    -- queried; guard it and fall back to a simple status message so a tap can
    -- never crash the app. Defer to nextTick so the panel finishes closing
    -- before the dialog is shown (otherwise it could be torn down with us).
    local text = self:_wifiState()
    self:onClose()
    UIManager:nextTick(function()
        local ok = pcall(function()
            UIManager:broadcastEvent(Event:new("ShowNetworkInfo"))
        end)
        if not ok then
            UIManager:show(require("ui/widget/infomessage"):new{
                text = text,
                timeout = 3,
            })
        end
    end)
    return true
end

function StatusPanel:onShowBatteryStats()
    -- Close the panel first, then open the battery statistics page (exactly like
    -- the menu entry, via the "ShowBatteryStatistics" event handled by the
    -- batterystat plugin's KeyValuePage). Guard it so a tap can never crash the
    -- app; if the plugin isn't loaded, nothing handles the event and we simply
    -- close.
    self:onClose()
    UIManager:nextTick(function()
        pcall(function()
            UIManager:broadcastEvent(Event:new("ShowBatteryStatistics"))
        end)
    end)
    return true
end

function StatusPanel:onToggleWifi()
    -- Drive NetworkMgr directly, exactly like the settings menu's Wi-Fi switch
    -- (NetworkMgr:getWifiToggleMenuTable), rather than broadcasting a ToggleWifi
    -- event: the event only works if a NetworkListener happens to be registered
    -- in the active widget stack, which is not guaranteed on the Home screen.
    -- Guard it the same way onShowWifiInfo guards network info: some backends
    -- have a broken netinfo/Wi-Fi FFI that raises when driven, and a tap must
    -- never crash the app.
    -- Turning Wi-Fi *on* (radio + association) is asynchronous and can take much
    -- longer than any fixed delay, so a lone scheduled refresh often runs before
    -- the connection settles and misses the final state. Pass a completion
    -- callback (fires once connectivity is established / the attempt ends) and
    -- also listen for the Network* broadcast events below, refreshing on each.
    local cb = function() self:_refreshWifiIcon() end
    pcall(function()
        local NetworkMgr = require("ui/network/manager")
        NetworkMgr:queryNetworkState()
        if NetworkMgr.is_wifi_on and NetworkMgr.is_connected then
            NetworkMgr:toggleWifiOff(cb, true)
        elseif NetworkMgr.is_wifi_on then
            -- On but not associated: ask whether to connect or turn off.
            NetworkMgr:promptWifi(cb, false, true)
        else
            NetworkMgr:toggleWifiOn(cb, false, true)
        end
    end)
    -- Fallback refresh in case neither the callback nor an event fires (e.g. a
    -- backend that toggles synchronously without emitting events). Bind to a
    -- stable method reference so it can be unscheduled if the panel is closed
    -- first (toggling Wi-Fi may background the app, e.g. Android opens the
    -- system Wi-Fi settings; the panel can be gone by the time this fires, and
    -- touching freed widgets crashes on-device).
    self._refresh_wifi_scheduled = true
    UIManager:scheduleIn(0.5, self._refreshWifiIcon, self)
    -- Reflect the new state immediately (e.g. "Connecting…" / "Wi-Fi not
    -- connected") instead of waiting for the async connection to settle. Some
    -- backends set pending_connection / broadcast NetworkConnecting during the
    -- call above, so this picks up "connecting" right away where available.
    self:_refreshWifiIcon()
    return true
end

-- Refresh the Wi-Fi row whenever the network state changes underneath us. These
-- broadcast events are the reliable signal for asynchronous connect/disconnect
-- (a fixed delay can't know when association actually completes).
function StatusPanel:onNetworkConnected()
    self:_refreshWifiIcon()
end
StatusPanel.onNetworkConnecting = StatusPanel.onNetworkConnected
StatusPanel.onNetworkDisconnected = StatusPanel.onNetworkConnected
StatusPanel.onNetworkDisconnecting = StatusPanel.onNetworkConnected

function StatusPanel:_refreshWifiIcon()
    -- Bail out if the panel was closed/torn down before this fired.
    if self._closed or not self.wifi_icon_glyph then return end
    local text, status = self:_wifiState()
    self.wifi_icon_glyph:setText(wifiStatusIcon(status))
    if self.wifi_label_glyph then
        self.wifi_label_glyph:setText(text)
    end
    UIManager:setDirty(self, "ui", self:_panelRect())
end

--- Toggle night mode (panel-local action): close the panel first, then flip
--- the screen colors. The panel has to be gone before the repaint, because it
--- covers the full screen while open, so _repaint skips the widgets underneath
--- and only the panel area would be repainted with the new colors, leaving the
--- rest of the screen stale.
--- NOTE: we must NOT do this via UIManager:broadcastEvent("ToggleNightMode")
--- (like the Settings menu does): this panel is itself in the widget stack and
--- defines onToggleNightMode, so the broadcast would be delivered back to us
--- and recurse forever. Instead, mirror DeviceListener:onToggleNightMode
--- directly (the CRe call-cache reset there only applies to an open document,
--- which never exists under this panel).
function StatusPanel:onToggleNightMode()
    local night_mode = G_reader_settings:isTrue("night_mode")
    -- Persist first so Home's status bar (resumed on close) paints sun/moon
    -- for the theme we are switching to.
    G_reader_settings:saveSetting("night_mode", not night_mode)
    self:onClose()
    Screen:toggleNightMode()
    UIManager:setDirty("all", "full")
    UIManager:ToggleNightMode(not night_mode)
    return true
end

--- Refresh the night mode icon glyph and slider from the current state.
function StatusPanel:_refreshBrightness()
    if self.night_mode_icon_glyph then
        self.night_mode_icon_glyph:setText(self:_nightModeGlyph())
    end
    if self.fl_slider then
        self.fl_slider:setValue(self.fl.cur)
    end
    UIManager:setDirty(self, "ui", self:_panelRect())
end

--- Apply a brightness from the slider. 0 is "off" (toggle off when on); any
--- other value sets the native intensity in [fl_min, fl_max], which also
--- turns the light back on if it was off.
function StatusPanel:_setBrightness(intensity)
    -- Guard against the slider callback re-entering while we sync it back below.
    if self._applying_brightness then return end
    self._applying_brightness = true

    if intensity == 0 then
        if self.powerd:isFrontlightOn() then
            pcall(function() self.powerd:toggleFrontlight() end)
        end
    else
        intensity = math.max(self.powerd.fl_min, math.min(self.fl.max, intensity))
        pcall(function() self.powerd:setIntensity(intensity) end)
    end
    pcall(function() self.powerd:updateResumeFrontlightState() end)
    pcall(function() self.fl.cur = self.powerd:frontlightIntensity() end)

    self:_refreshBrightness()
    self._applying_brightness = false
end

function StatusPanel:onTapClose(_, ges)
    if not (ges and ges.pos) then return true end

    -- Tap outside the panel -> close.
    if not ges.pos:intersectWith(self:_panelRect()) then
        self:onClose()
        return true
    end

    -- Close row: tapping its icon box (or anywhere on the row) closes.
    local close_i = self:_rowIndex("close")
    if close_i and ges.pos:intersectWith(self:_rowRect(close_i)) then
        self:onClose()
        return true
    end

    -- Charge row: tapping anywhere (label or icon) opens battery statistics.
    local charge_i = self:_rowIndex("charge")
    if charge_i and ges.pos:intersectWith(self:_rowRect(charge_i)) then
        self:onShowBatteryStats()
        return true
    end

    -- Wi-Fi row: icon box toggles Wi-Fi; the rest opens network info.
    local wifi_i = self:_rowIndex("wifi")
    if wifi_i and ges.pos:intersectWith(self:_rowRect(wifi_i)) then
        if ges.pos:intersectWith(self:_iconBoxRect(wifi_i)) then
            self:onToggleWifi()
        else
            self:onShowWifiInfo()
        end
        return true
    end

    -- Brightness row: tapping the trailing icon box toggles night mode.
    -- (The slider itself handles taps/drags over its own area.)
    local bright_i = self:_rowIndex("brightness")
    if bright_i and ges.pos:intersectWith(self:_iconBoxRect(bright_i)) then
        self:onToggleNightMode()
        return true
    end

    -- Any other tap inside the panel: swallow (don't close).
    return true
end

function StatusPanel:onShow()
    -- Pause the Home status bar's refreshes so it doesn't repaint under us.
    if self.home and self.home.pauseStatusBar then
        self.home:pauseStatusBar()
    end
    UIManager:setDirty(self, function()
        return "ui", self[1].dimen
    end)
    return true
end

function StatusPanel:onCloseWidget()
    -- Cancel any pending Wi-Fi refresh so it can't run against freed widgets.
    -- `_closed` also guards the event-driven refreshes (onNetworkConnected etc.)
    -- and the toggle completion callback, which may still fire after teardown.
    self._closed = true
    UIManager:unschedule(self._refreshWifiIcon)
    UIManager:unschedule(self._refreshChargeRow)
    self._refresh_wifi_scheduled = false
    -- Resume the Home status bar once the panel is gone.
    if self.home and self.home.resumeStatusBar then
        self.home:resumeStatusBar()
    end
end

function StatusPanel:onClose()
    -- Flash-refresh the full screen so the panel is fully cleared and the Home
    -- underneath is repainted (a region-limited refresh can leave the panel
    -- contents ghosting on e-ink).
    UIManager:close(self, "flashui")
    return true
end

return StatusPanel

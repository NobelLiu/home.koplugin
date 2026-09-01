--[[--
slider.lua — A horizontal value slider for the Home plugin.

Visual model (matches the SwiftUI reference):
  * A single full-width black track line (2px), vertically centered, spanning
    the whole widget.
  * A handle group (50px wide, full height, white background) that moves
    horizontally with the value. It holds three 2px-wide full-height black bars
    distributed as [bar | spacer | bar | spacer | bar] — i.e. at the group's
    left edge, center, and right edge.
  * A value box centered on the handle: the current value as text with 4px
    padding on a white background (sized to the text).

The widget is self-contained and reusable: give it a value range, an initial
value, and an `on_change` callback. It handles tap and pan/hold gestures over
its own area, snapping to integer values (optionally stepped). It is intended
for the Home screen now and to drive frontlight brightness later.

Usage:
    local Slider = require("ui/common/slider")
    local slider = Slider:new{
        width = 623,          -- design px (optional; scaled by screen DPI)
        min = 0,
        max = 100,
        value = 16,
        step = 1,             -- snap increment (optional)
        on_change = function(v) ... end,   -- fires while dragging / on tap
        on_change_done = function(v) ... end, -- fires when the gesture ends
    }
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Math = require("optmath")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local Screen = Device.screen

-- Design geometry (in design points; scaled by screen DPI at build time).
local DESIGN_WIDTH = 623
local DESIGN_HEIGHT = 50
local BAR_WIDTH = 2              -- Rectangle .frame(width: 2)
local TRACK_HEIGHT = 2           -- Rectangle .frame(height: 2)
local LABEL_PADDING = 4          -- Text .padding(4)
local VALUE_FONT_SIZE = 20       -- value label (two sizes below the 24 design)

local Slider = InputContainer:extend{
    name = "home_slider",
    width = DESIGN_WIDTH,        -- design px
    width_px = nil,              -- pre-scaled device px (overrides `width`)
    height = DESIGN_HEIGHT,      -- design px
    height_px = nil,             -- pre-scaled device px (overrides `height`)
    min = 0,
    max = 100,
    value = 0,
    step = 1,
    -- Optional display scale. When set, the value *label* (and only the label)
    -- is shown on a 0..display_max scale instead of the native [min, max] one.
    -- The slider still stores and emits native values via `on_change`; this only
    -- changes what the handle shows. Used so devices whose native range is huge
    -- (e.g. reMarkable's 0..2047) show a consistent 0..100 percentage, while
    -- small native ranges (Kindle 0..24, Kobo 0..100) keep showing the level.
    display_max = nil,
    on_change = nil,
    on_change_done = nil,
}

function Slider:init()
    -- Scale the design geometry to device pixels. `width_px`/`height_px` let a
    -- caller pass already-scaled (device-px) sizes instead of design px.
    self.w = self.width_px or Screen:scaleBySize(self.width)
    self.h = self.height_px or Screen:scaleBySize(self.height)
    -- Handle width is dynamic: three times the (scaled) value font size.
    self.handle_w = Screen:scaleBySize(VALUE_FONT_SIZE) * 3
    self.bar_w = math.max(1, Screen:scaleBySize(BAR_WIDTH))
    self.track_h = math.max(1, Screen:scaleBySize(TRACK_HEIGHT))
    self.label_pad = Screen:scaleBySize(LABEL_PADDING)

    -- The handle's left edge travels within [0, w - handle_w] so the whole
    -- group is always visible.
    self.travel = math.max(0, self.w - self.handle_w)

    self.dimen = Geom:new{ w = self.w, h = self.h }

    if Device:isTouchDevice() then
        -- Ranges are matched in screen coordinates, but a widget's on-screen
        -- position is only known at paintTo() time. Use a range *function* that
        -- returns the live self.dimen so the slider only claims gestures over
        -- its actual painted area (otherwise a static {x=0,y=0} range would sit
        -- at the screen's top-left and swallow taps meant for the status bar).
        local range = function() return self.dimen end
        self.ges_events.TapSlider = { GestureRange:new{ ges = "tap", range = range } }
        self.ges_events.PanSlider = { GestureRange:new{ ges = "pan", range = range } }
        self.ges_events.PanReleaseSlider = { GestureRange:new{ ges = "pan_release", range = range } }
        self.ges_events.HoldSlider = { GestureRange:new{ ges = "hold", range = range } }
        self.ges_events.HoldPanSlider = { GestureRange:new{ ges = "hold_pan", range = range } }
        self.ges_events.HoldReleaseSlider = { GestureRange:new{ ges = "hold_release", range = range } }
    end

    self:_build()
end

--- Clamp `v` into the range and snap it to the configured step.
function Slider:_normalize(v)
    v = math.max(self.min, math.min(self.max, v))
    local step = self.step or 1
    if step and step > 0 then
        v = self.min + Math.round((v - self.min) / step) * step
        v = math.max(self.min, math.min(self.max, v))
    end
    return v
end

--- Current value as a 0..1 fraction of the range.
function Slider:_fraction()
    local span = self.max - self.min
    if span <= 0 then return 0 end
    return (self.value - self.min) / span
end

--- Left edge (device px) of the handle group for the current value.
function Slider:_handleLeft()
    return Math.round(self:_fraction() * self.travel)
end

--- The label text for the current value. When `display_max` is set, the value
--- is shown on the 0..display_max scale (e.g. a percentage) rather than the
--- native [min, max] scale; otherwise the native value is shown as-is.
function Slider:_valueText()
    if self.display_max then
        return tostring(Math.round(self:_fraction() * self.display_max))
    end
    return tostring(math.floor(self.value + 0.5))
end

--- Build (or rebuild) the visual tree from the current value.
function Slider:_build()
    local handle_left = self:_handleLeft()

    -- Layer 1: a single full-width track line, vertically centered.
    local track_y = math.floor((self.h - self.track_h) / 2)
    local track = LineWidget:new{
        dimen = Geom:new{ w = self.w, h = self.track_h },
        background = Blitbuffer.COLOR_BLACK,
        overlap_offset = { 0, track_y },
    }

    -- Layer 2: the movable handle group, offset horizontally by the value.
    local handle = self:_buildHandle()
    handle.overlap_offset = { handle_left, 0 }

    self.frame = OverlapGroup:new{
        dimen = Geom:new{ w = self.w, h = self.h },
        track,
        handle,
    }
    self[1] = self.frame
end

--- The handle group (50px wide, full height). White background with three
--- full-height bars at left / center / right and a centered white-backed value
--- label on top. Positioning is done by the caller via overlap_offset.
function Slider:_buildHandle()
    -- Bars at the group's left edge, horizontal center, and right edge.
    local left_bar_x = 0
    local center_bar_x = math.floor((self.handle_w - self.bar_w) / 2)
    local right_bar_x = self.handle_w - self.bar_w

    local function bar(x)
        return LineWidget:new{
            dimen = Geom:new{ w = self.bar_w, h = self.h },
            background = Blitbuffer.COLOR_BLACK,
            overlap_offset = { x, 0 },
        }
    end

    -- White backing behind the bars (HStack .background(.white)).
    local backing = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        width = self.handle_w,
        height = self.h,
        OverlapGroup:new{
            dimen = Geom:new{ w = self.handle_w, h = self.h },
            bar(left_bar_x),
            bar(center_bar_x),
            bar(right_bar_x),
        },
    }
    backing.overlap_offset = { 0, 0 }

    -- Value label: text with 4px padding on a white background, sized to its
    -- content, centered over the handle.
    local label = TextWidget:new{
        text = self:_valueText(),
        face = Font:getFace("cfont", VALUE_FONT_SIZE),
        bold = true,
        fgcolor = Blitbuffer.COLOR_BLACK,
        padding = 0,
    }
    local label_size = label:getSize()
    local box_w = label_size.w + self.label_pad * 2
    local box_h = label_size.h + self.label_pad * 2
    local value_box = FrameContainer:new{
        bordersize = 0,
        padding = self.label_pad,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        label,
    }
    value_box.overlap_offset = {
        math.floor((self.handle_w - box_w) / 2),
        math.floor((self.h - box_h) / 2),
    }

    return OverlapGroup:new{
        dimen = Geom:new{ w = self.handle_w, h = self.h },
        backing,
        value_box,
    }
end

--- Map an absolute screen x to a value, using the handle-center travel model.
function Slider:_valueFromX(screen_x)
    if not self.dimen then return self.value end
    local half = math.floor(self.handle_w / 2)
    -- Position of the handle's left edge if its center were under the pointer.
    local left = (screen_x - self.dimen.x) - half
    local frac = self.travel > 0 and (left / self.travel) or 0
    frac = math.max(0, math.min(1, frac))
    return self:_normalize(self.min + frac * (self.max - self.min))
end

--- Set the value (clamped/snapped) and repaint if it changed. When `done` is
--- true the gesture has ended (fires `on_change_done`).
function Slider:setValue(v, done)
    local new_v = self:_normalize(v)
    local changed = new_v ~= self.value
    self.value = new_v
    if changed then
        self:_build()
        if self.dimen then
            UIManager:setDirty(self.show_parent or self, "ui", self.dimen)
        end
        if self.on_change then self.on_change(self.value) end
    end
    if done and self.on_change_done then
        self.on_change_done(self.value)
    end
    return changed
end

function Slider:_handleGesture(ges, done)
    if not (ges and ges.pos and ges.pos.x) then return false end
    self:setValue(self:_valueFromX(ges.pos.x), done)
    return true
end

function Slider:onTapSlider(_, ges)
    return self:_handleGesture(ges, true)
end

function Slider:onPanSlider(_, ges)
    return self:_handleGesture(ges, false)
end

function Slider:onPanReleaseSlider(_, ges)
    -- Position at release may be missing/stale; commit the current value.
    if ges and ges.pos and ges.pos.x then
        self:setValue(self:_valueFromX(ges.pos.x), true)
    elseif self.on_change_done then
        self.on_change_done(self.value)
    end
    return true
end

function Slider:onHoldSlider(_, ges)
    return self:_handleGesture(ges, false)
end

function Slider:onHoldPanSlider(_, ges)
    return self:_handleGesture(ges, false)
end

function Slider:onHoldReleaseSlider(_, ges)
    return self:onPanReleaseSlider(_, ges)
end

return Slider

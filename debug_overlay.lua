--[[--
debug_overlay.lua — Layout debugging: a 1px inner-border overlay + a name
label in the top-right corner (purely visual, does not affect layout).

Enable via: Settings → Display mode → Home display mode → Debug mode
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Layout = require("layout")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local Widget = require("ui/widget/widget")

local DebugOverlay = {}

local InnerBorder = Widget:extend{
    bordersize = Size.border.default,
    border_color = Blitbuffer.COLOR_BLACK,
}

function InnerBorder:init()
    self.dimen = self.border_dimen or Geom:new{ w = 1, h = 1 }
end

function InnerBorder:paintTo(bb, x, y)
    bb:paintInnerBorder(x, y, self.dimen.w, self.dimen.h,
        self.bordersize, self.border_color, 0)
end

local function colorForName(name)
    local h = 0
    for i = 1, #name do
        h = h + name:byte(i) * (i * 31)
    end
    local r = 64 + (h % 192)
    local g = 64 + ((h * 3) % 192)
    local b = 64 + ((h * 7) % 192)
    return Blitbuffer.ColorRGB32(r, g, b, 255)
end

local function labelFace()
    return Font:getFace("xx_smallinfofont")
end

local function makeBadge(name, color)
    return FrameContainer:new{
        bordersize = 0,
        background = color,
        padding = 0,
        margin = 0,
        TextWidget:new{
            text = name,
            face = labelFace(),
            bold = false,
            fgcolor = Blitbuffer.COLOR_WHITE,
            padding = 0,
        },
    }
end

local function resolveSize(widget, w, h)
    if w and h then return w, h end
    local s = widget:getSize()
    return w or s.w or 1, h or s.h or 1
end

local function overlayFrame(name, widget, w, h, color)
    local badge = makeBadge(name, color)
    local badge_size = badge:getSize()
    local label_h = math.min(h, badge_size.h)

    return OverlapGroup:new{
        dimen = Geom:new{ w = w, h = h },
        allow_mirroring = false,
        widget,
        InnerBorder:new{
            border_dimen = Geom:new{ w = w, h = h },
            border_color = color,
        },
        TopContainer:new{
            dimen = Geom:new{ w = w, h = label_h },
            RightContainer:new{
                dimen = Geom:new{ w = w, h = label_h },
                badge,
            },
        },
    }
end

--- Wrap a composite widget: inner border + name label in the top-right corner
--- (does not change w×h).
function DebugOverlay.wrap(name, widget, w, h, _)
    if not Layout.isDebugLayout() then return widget end
    w, h = resolveSize(widget, w, h)
    return overlayFrame(name, widget, w, h, colorForName(name))
end

return DebugOverlay

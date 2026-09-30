--[[--
1px structural rule. Solid only — no dashed or dotted lines.
]]

local Geom = require("ui/geometry")
local LineWidget = require("ui/widget/linewidget")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Divider = WidgetContainer:extend{
    width = nil,
    color = nil,
}

function Divider:init()
    local width = self.width or pt(Theme.dim.divider_width)
    self[1] = LineWidget:new{
        background = self.color or Theme.color.black,
        dimen = Geom:new{
            w = width,
            h = pt(Theme.dim.divider),
        },
    }
    self.dimen = Geom:new{
        w = width,
        h = pt(Theme.dim.divider),
    }
end

return Divider

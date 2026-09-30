--[[--
Horizontal and vertical gaps using KOReader span widgets.
]]

local HorizontalSpan = require("ui/widget/horizontalspan")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local VerticalSpan = require("ui/widget/verticalspan")

local Spacer = {}

function Spacer.horizontal(width)
    return HorizontalSpan:new{
        width = width or pt(Theme.gap.default),
    }
end

function Spacer.vertical(height)
    return VerticalSpan:new{
        width = height or pt(Theme.gap.stack),
    }
end

return Spacer

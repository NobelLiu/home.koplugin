--[[--
Horizontal or vertical stack with a fixed Swiss gap.
]]

local HorizontalGroup = require("ui/widget/horizontalgroup")
local Spacer = require("ui/uikit/components/layout/spacer")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Stack = WidgetContainer:extend{
    direction = "vertical",
    gap = nil,
    align = "left",
}

function Stack:init()
    local kids = self.children
    if not kids then
        kids = {}
        for i, child in ipairs(self) do
            kids[#kids + 1] = child
            self[i] = nil
        end
    end
    self.children = nil

    local gap = self.gap
    if gap == nil then
        gap = self.direction == "horizontal" and pt(Theme.gap.default) or pt(Theme.gap.stack)
    end

    local group
    if self.direction == "horizontal" then
        group = HorizontalGroup:new{
            align = self.align == "center" and "center" or "top",
        }
    else
        group = VerticalGroup:new{
            align = self.align,
        }
    end

    for i, child in ipairs(kids) do
        if i > 1 and gap > 0 then
            if self.direction == "horizontal" then
                table.insert(group, Spacer.horizontal(gap))
            else
                table.insert(group, Spacer.vertical(gap))
            end
        end
        table.insert(group, child)
    end
    self[1] = group
end

return Stack

--[[--
Hairline progress: gray well, black fill. No radius, no ticks.
]]

local Geom = require("ui/geometry")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local Widget = require("ui/widget/widget")

local Progress = Widget:extend{
    width = nil,
    height = nil,
    percentage = 0,
}

function Progress:init()
    local p = self.percentage or 0
    if p > 1 then
        p = p / 100
    end
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end
    self.percentage = p
    self.dimen = Geom:new{
        w = self.width or pt(Theme.dim.progress_width),
        h = self.height or pt(Theme.dim.progress),
    }
end

function Progress:getSize()
    return { w = self.dimen.w, h = self.dimen.h }
end

function Progress:setPercentage(percentage)
    local p = percentage or 0
    if p > 1 then p = p / 100 end
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end
    self.percentage = p
end

function Progress:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Theme.color.divider)
    local fill = math.floor(self.dimen.w * self.percentage)
    if fill > 0 then
        bb:paintRect(x, y, fill, self.dimen.h, Theme.color.black)
    end
end

return Progress

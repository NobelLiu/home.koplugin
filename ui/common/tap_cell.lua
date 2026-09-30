--[[--
tap_cell.lua — Tappable region wrapping an arbitrary child widget.

When width/height is larger than the child, content is centered in the tap
area (InputContainer defaults to top-left, which pins status-bar glyphs high).
]]

local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")

local TapCell = InputContainer:extend{
    enabled = true,
    callback = nil,
    on_tap = nil,
    align = "center",
    vertical_align = "center",
}

function TapCell:init()
    self[1] = self.content
    if self.cell_dimen then
        self.dimen = self.cell_dimen
    elseif self.width or self.height then
        self.dimen = Geom:new{
            w = math.floor((self.width or self[1]:getSize().w) + 0.5),
            h = math.floor((self.height or self[1]:getSize().h) + 0.5),
        }
    end
    self.ges_events = {
        TapCell = {
            GestureRange:new{
                ges = "tap",
                range = function()
                    if self.dimen then
                        return self.dimen
                    end
                    local size = self[1] and self[1]:getSize()
                    if size then
                        return Geom:new{
                            x = 0,
                            y = 0,
                            w = math.floor((size.w or 0) + 0.5),
                            h = math.floor((size.h or 0) + 0.5),
                        }
                    end
                end,
            },
        },
    }
end

function TapCell:onTapCell()
    if not self.enabled then
        return true
    end
    local fn = self.callback or self.on_tap
    if fn then
        fn()
    end
    return true
end

--- @param content table
--- @param dimen table Geom
--- @param on_tap function|nil
function TapCell.wrap(content, dimen, on_tap)
    return TapCell:new{
        content = content,
        cell_dimen = dimen,
        on_tap = on_tap,
    }
end

return TapCell

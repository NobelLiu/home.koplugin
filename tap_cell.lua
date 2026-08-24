--[[--
tap_cell.lua — A tappable cell wrapping an arbitrary child widget and
responding to taps.
--]]

local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")

local TapCell = InputContainer:extend{}

function TapCell:init()
    self.dimen = self.cell_dimen
    self[1] = self.content
    self.ges_events = {
        TapCell = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            },
        },
    }
end

function TapCell:onTapCell()
    if self.on_tap then self.on_tap() end
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

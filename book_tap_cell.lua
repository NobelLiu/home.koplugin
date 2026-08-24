--[[--
book_tap_cell.lua — A tappable cell wrapping an arbitrary content widget.
--]]

local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")

local BookTapCell = InputContainer:extend{}

function BookTapCell:init()
    self.dimen = self.cell_dimen
    self[1] = self.content
    self.ges_events = {
        TapBook = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            },
        },
    }
end

function BookTapCell:onTapBook()
    if self.on_tap then self.on_tap() end
    return true
end

local function makeTapCell(content, dimen, on_tap)
    return BookTapCell:new{
        content = content,
        cell_dimen = dimen,
        on_tap = on_tap,
    }
end

return {
    BookTapCell = BookTapCell,
    makeTapCell = makeTapCell,
}

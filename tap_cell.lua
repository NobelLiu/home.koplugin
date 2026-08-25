--[[--
tap_cell.lua — A tappable cell wrapping an arbitrary child widget and
responding to taps.

When `highlight` is set, the cell renders a short black inverted-rectangle
feedback on tap (the same visual language KOReader uses for buttons).
--]]

local FrameContainer = require("ui/widget/container/framecontainer")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")

local TapCell = InputContainer:extend{}

function TapCell:init()
    self.dimen = self.cell_dimen
    if self.highlight then
        -- Wrap the content so we have a paintable frame to invert on tap.
        self.frame = FrameContainer:new{
            bordersize = 0,
            padding = 0,
            margin = 0,
            dimen = self.cell_dimen,
            self.content,
        }
        self[1] = self.frame
    else
        self[1] = self.content
    end
    self.ges_events = {
        TapCell = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            },
        },
    }
end

function TapCell:_doFeedbackHighlight()
    self.frame.invert = true
    UIManager:widgetInvert(self.frame, self.frame.dimen.x, self.frame.dimen.y)
    UIManager:setDirty(nil, "fast", self.frame.dimen)
end

function TapCell:_undoFeedbackHighlight()
    self.frame.invert = false
    UIManager:widgetInvert(self.frame, self.frame.dimen.x, self.frame.dimen.y)
    UIManager:setDirty(nil, "fast", self.frame.dimen)
end

function TapCell:onTapCell()
    if not self.on_tap then return true end

    if self.highlight and self.frame and self.frame.dimen then
        self:_doFeedbackHighlight()
        UIManager:forceRePaint()
        self:_undoFeedbackHighlight()
    end

    self.on_tap()
    return true
end

--- @param content table
--- @param dimen table Geom
--- @param on_tap function|nil
--- @param opts table|nil { highlight = boolean }
function TapCell.wrap(content, dimen, on_tap, opts)
    opts = opts or {}
    return TapCell:new{
        content = content,
        cell_dimen = dimen,
        on_tap = on_tap,
        highlight = opts.highlight,
    }
end

return TapCell

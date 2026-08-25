--[[--
continue_center.lua — Outer container for the Continue book content. The book
content is pinned to the bottom of the slot (with a bottom padding matching the
screen edge padding); the greeting label occupies the top of the slot and is
overlapped separately by continue_section.lua.
--]]

local BottomContainer = require("ui/widget/container/bottomcontainer")
local DebugOverlay = require("debug_overlay")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")

local ContinueCenter = {}

--- @param content table inner Continue content widget
--- @param metrics table layout metrics (continue_slot_h, content_w, main_h_padding)
--- @return table
function ContinueCenter.wrap(content, metrics)
    -- Bottom padding matches the screen edge padding so the book content sits
    -- one screen-margin above the section divider.
    local bottom_pad = metrics.main_h_padding
    local inner_h = metrics.continue_slot_h - bottom_pad
    if inner_h < 0 then inner_h = 0 end
    local slot = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_bottom = bottom_pad,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
        BottomContainer:new{
            dimen = Geom:new{ w = metrics.content_w, h = inner_h },
            content,
        },
    }
    return DebugOverlay.wrap("continue_center_slot", slot,
        metrics.content_w, metrics.continue_slot_h, "continue_center")
end

return ContinueCenter

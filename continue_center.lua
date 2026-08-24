--[[--
continue_center.lua — Outer centering container for Continue (fixed at the
main content height × PHI).
--]]

local CenterContainer = require("ui/widget/container/centercontainer")
local DebugOverlay = require("debug_overlay")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")

local ContinueCenter = {}

--- @param content table inner Continue content widget
--- @param metrics table layout metrics (continue_slot_h, content_w)
--- @return table
function ContinueCenter.wrap(content, metrics)
    local center = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
        CenterContainer:new{
            dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
            content,
        },
    }
    return DebugOverlay.wrap("continue_center_slot", center,
        metrics.content_w, metrics.continue_slot_h, "continue_center")
end

return ContinueCenter

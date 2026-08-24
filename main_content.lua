--[[--
main_content.lua — The main content-area container.

The four-side padding is applied directly via the FrameContainer's padding
(absolute offsets) rather than Span placeholders. The inner content measures
content_w × inner_h, and the outer frame fills exactly screen_w × main_h.
--]]

local DebugOverlay = require("debug_overlay")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")

local MainContent = {}

--- @param screen_w number
--- @param metrics table layout metrics
--- @param sections table content (e.g. a VerticalGroup)
--- @return table
function MainContent.build(screen_w, metrics, sections)
    local inner = DebugOverlay.wrap("inner", FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.inner_h },
        sections,
    }, metrics.content_w, metrics.inner_h, "inner")

    return DebugOverlay.wrap("main_content", FrameContainer:new{
        bordersize = 0,
        margin = 0,
        padding = 0,
        padding_left = metrics.main_h_padding,
        padding_right = metrics.main_h_padding,
        padding_top = metrics.main_v_padding,
        padding_bottom = metrics.main_v_padding,
        width = screen_w,
        height = metrics.main_h,
        inner,
    }, screen_w, metrics.main_h, "main_content")
end

return MainContent

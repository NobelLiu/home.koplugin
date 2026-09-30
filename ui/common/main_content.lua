--[[--
main_content.lua — The main content-area container.

The four-side padding is applied directly via the FrameContainer's padding
(absolute offsets) rather than Span placeholders. The inner content measures
content_width × inner_height, and the outer frame fills exactly screen_width × main_height.
--]]

local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")

local MainContent = {}

--- @param screen_width number
--- @param metrics table layout metrics
--- @param sections table content (e.g. a VerticalGroup)
--- @return table
function MainContent.build(screen_width, metrics, sections)
    local inner = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_width, h = metrics.inner_height },
        sections,
    }

    return FrameContainer:new{
        bordersize = 0,
        margin = 0,
        padding = 0,
        padding_left = metrics.main_horizontal_padding,
        padding_right = metrics.main_horizontal_padding,
        padding_top = metrics.main_vertical_padding,
        padding_bottom = metrics.main_vertical_padding,
        width = screen_width,
        height = metrics.main_height,
        inner,
    }
end

return MainContent

--[[--
progress_bar.lua — A thin progress bar (shared by Continue / Library).
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Layout = require("ui/common/layout")
local ProgressWidget = require("ui/widget/progresswidget")

local ProgressBar = {}

--- @param w number width (already scaled)
--- @param percent number 0–1 (also accepts 0–100, converted automatically)
--- @param height number|nil optional height (already scaled); defaults to the system progress height
function ProgressBar.build(w, percent, height)
    local p = percent or 0
    if p > 1 then p = p / 100 end
    return ProgressWidget:new{
        width = w,
        height = height or Layout.dim.progress,
        percentage = p,
        margin_h = 0,
        margin_v = 0,
        bordersize = 0,
        radius = 0,
        bgcolor = Layout.COLOR_DIVIDER,
        fillcolor = Blitbuffer.COLOR_BLACK,
    }
end

return ProgressBar

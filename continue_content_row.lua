--[[--
continue_content_row.lua — Continue content row (cover column + info column,
equal height).
--]]

local BookCover = require("book_cover")
local CenterContainer = require("ui/widget/container/centercontainer")
local ContinueInfoColumn = require("continue_info_column")
local DebugOverlay = require("debug_overlay")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")

local ContinueContentRow = {}

--- @return table Content row widget
function ContinueContentRow.build(filepath, meta, metrics)
    local cover = BookCover.build(filepath, metrics.cover_w, metrics.cover_h, meta)

    local cover_col = DebugOverlay.wrap("cover_col", FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.cover_col_w, h = metrics.cover_h },
        CenterContainer:new{
            dimen = Geom:new{ w = metrics.cover_col_w, h = metrics.cover_h },
            cover,
        },
    }, metrics.cover_col_w, metrics.cover_h, "cover_col")

    local info_col = ContinueInfoColumn.build(meta, metrics)

    local row = HorizontalGroup:new{
        align = "top",
        cover_col,
        info_col,
    }

    return DebugOverlay.wrap("continue_content_row", row,
        metrics.content_w, metrics.cover_h, "continue_content_row")
end

return ContinueContentRow

--[[--
recent_cell.lua — A single book card in the Recent grid.
--]]

local BD = require("ui/bidi")
local BookCover = require("book_cover")
local BookRepository = require("book_repository")
local Geom = require("ui/geometry")
local Layout = require("layout")
local DebugOverlay = require("debug_overlay")
local ProgressBar = require("progress_bar")
local TapCell = require("tap_cell")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local RecentCell = {}

--- @return table TapCell
function RecentCell.build(filepath, cell_w, cover_h, on_open, cell_metrics)
    cell_metrics = cell_metrics or {}
    local meta = BookRepository.getBookMeta(filepath)
    local gap = cell_metrics.item_gap or Layout.scaledSetting("content_gap")
    local title_h = cell_metrics.title_h or Layout.captionLineHeight()
    local bar_h = cell_metrics.bar_h or Layout.dim.progress
    local cell_h = cover_h + gap + bar_h + gap + title_h

    local col = VerticalGroup:new{
        align = "left",
        BookCover.build(filepath, cell_w, cover_h, meta),
        VerticalSpan:new{ width = gap },
        ProgressBar.build(cell_w, meta.percent, bar_h),
        VerticalSpan:new{ width = gap },
        TextBoxWidget:new{
            text = BD.auto(meta.title),
            face = Layout.captionFace(),
            width = cell_w,
            height = title_h,
        },
    }

    local col_w = DebugOverlay.wrap("recent_cell", col, cell_w, cell_h, "recent_cell")

    return TapCell.wrap(col_w, Geom:new{ w = cell_w, h = cell_h }, function()
        on_open(filepath)
    end)
end

return RecentCell

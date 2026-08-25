--[[--
folder_cell.lua — A single folder card in the Recent grid. Mirrors the book
cell layout (cover, meta gap, title) but uses a 2x2 mosaic cover and has no
progress bar; tapping enters the folder.
--]]

local BD = require("ui/bidi")
local FolderCover = require("folder_cover")
local Geom = require("ui/geometry")
local Layout = require("layout")
local DebugOverlay = require("debug_overlay")
local TapCell = require("tap_cell")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local FolderCell = {}

--- @return table TapCell
function FolderCell.build(dir, name, cell_w, cover_h, on_enter, cell_metrics, sort_mode)
    cell_metrics = cell_metrics or {}
    local gap = cell_metrics.item_gap or Layout.scaledSetting("content_gap")
    local title_h = cell_metrics.title_h or Layout.captionLineHeight()
    local bar_h = cell_metrics.bar_h or Layout.dim.progress
    local cell_h = cover_h + gap + bar_h + gap + title_h

    -- No progress bar for a folder; keep the same total height as a book cell
    -- by reserving the bar row as blank space so the grid stays aligned.
    local col = VerticalGroup:new{
        align = "left",
        FolderCover.build(dir, cell_w, cover_h, sort_mode),
        VerticalSpan:new{ width = gap },
        VerticalSpan:new{ width = bar_h },
        VerticalSpan:new{ width = gap },
        TextBoxWidget:new{
            text = BD.auto(name or ""),
            face = Layout.captionFace(),
            width = cell_w,
            height = title_h,
        },
    }

    local col_w = DebugOverlay.wrap("folder_cell", col, cell_w, cell_h, "folder_cell")

    return TapCell.wrap(col_w, Geom:new{ w = cell_w, h = cell_h }, function()
        on_enter(dir)
    end)
end

return FolderCell

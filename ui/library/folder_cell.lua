--[[--
folder_cell.lua — A single folder card in the Library grid. Mirrors the book
cell layout (cover, meta gap, title) but uses a 2x2 mosaic cover and has no
progress bar; tapping enters the folder.
--]]

local BD = require("ui/bidi")
local FolderCover = require("ui/library/folder_cover")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local Spacer = require("ui/uikit/components/layout/spacer")
local TapCell = require("ui/common/tap_cell")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local FolderCell = {}

--- @return table TapCell
function FolderCell.build(dir, name, cell_width, cover_height, on_enter, cell_metrics, sort_mode)
    cell_metrics = cell_metrics or {}
    local cover_progress_gap = cell_metrics.cover_progress_gap or Layout.libraryCoverProgressGap()
    local progress_title_gap = cell_metrics.progress_title_gap or Layout.libraryProgressTitleGap()
    local title_height = cell_metrics.title_height or Layout.libraryTitleLineHeight()
    local progress_height = cell_metrics.progress_height or pt(4)
    local cell_height = math.floor(cover_height + cover_progress_gap
        + progress_height + progress_title_gap + title_height)

    -- No progress bar for a folder; reserve the bar row so the grid stays aligned.
    local col = VerticalGroup:new{
        align = "left",
        FolderCover.build(dir, cell_width, cover_height, sort_mode, name),
        Spacer.vertical(cover_progress_gap),
        Spacer.vertical(progress_height),
        Spacer.vertical(progress_title_gap),
        TextBoxWidget:new{
            text = BD.auto(name or ""),
            face = Layout.libraryTitleFace(),
            width = cell_width,
            height = title_height,
        },
    }

    return TapCell.wrap(col, Geom:new{ w = cell_width, h = cell_height }, function()
        on_enter(dir)
    end)
end

return FolderCell

--[[--
library_cell.lua — A single book card in the Library grid.
--]]

local BD = require("ui/bidi")
local BookCover = require("ui/library/book_cover")
local BookRepository = require("book_repository")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local Progress = require("ui/uikit/components/controls/progress")
local Spacer = require("ui/uikit/components/layout/spacer")
local TapCell = require("ui/common/tap_cell")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")

local LibraryCell = {}

--- @return table TapCell
function LibraryCell.build(filepath, cell_width, cover_height, on_open, cell_metrics)
    cell_metrics = cell_metrics or {}
    local meta = BookRepository.getBookMeta(filepath)
    local cover_progress_gap = cell_metrics.cover_progress_gap or Layout.libraryCoverProgressGap()
    local progress_title_gap = cell_metrics.progress_title_gap or Layout.libraryProgressTitleGap()
    local title_height = cell_metrics.title_height or Layout.libraryTitleLineHeight()
    local progress_height = cell_metrics.progress_height or pt(4)
    local cell_height = math.floor(cover_height + cover_progress_gap
        + progress_height + progress_title_gap + title_height)

    local col = VerticalGroup:new{
        align = "left",
        BookCover.build(filepath, cell_width, cover_height, meta, Layout.COLOR_COVER_BORDER),
        Spacer.vertical(cover_progress_gap),
        Progress:new{
            width = cell_width,
            height = progress_height,
            percentage = meta.percent,
        },
        Spacer.vertical(progress_title_gap),
        TextBoxWidget:new{
            text = BD.auto(meta.title),
            face = Layout.libraryTitleFace(),
            width = cell_width,
            height = title_height,
        },
    }

    return TapCell.wrap(col, Geom:new{ w = cell_width, h = cell_height }, function()
        on_open(filepath)
    end)
end

return LibraryCell

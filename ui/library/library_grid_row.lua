--[[--
library_grid_row.lua — The Library grid (row and column counts computed
dynamically by the layout). Items fill row-major (Z-order): left-to-right,
then top-to-bottom.

When there is more than one row, the first row is pinned to the top of the
grid area, the last row to the bottom, and the vertical space between rows is
split evenly (integer slack distributed across the gaps).
--]]

local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local FolderCell = require("ui/library/folder_cell")
local LibraryCell = require("ui/library/library_cell")

local LibraryGridRow = {}

local function appendGap(row, width)
    if width > 0 then
        row[#row + 1] = HorizontalSpan:new{ width = width }
    end
end

--- Evenly split `slack` px across `gap_count` vertical gaps; the first
--- `extra` gaps receive one additional pixel each.
local function distributeRowGaps(slack, gap_count)
    if gap_count <= 0 or slack <= 0 then
        return {}
    end
    local base = math.floor(slack / gap_count)
    local extra = slack - base * gap_count
    local gaps = {}
    for i = 1, gap_count do
        gaps[i] = base + (i <= extra and 1 or 0)
    end
    return gaps
end

--- @param entries table list of { type = "book"|"folder", path, name }
--- @return table Grid widget
function LibraryGridRow.build(entries, grid_metrics, on_open, on_enter)
    local content_w = grid_metrics.content_w
    local cell_w = grid_metrics.cell_w
    local cover_h = grid_metrics.cover_h
    local cell_gap = grid_metrics.cell_gap or 0
    local cell_gap_last = grid_metrics.cell_gap_last or cell_gap
    local library_cols = grid_metrics.library_cols
    local library_rows = grid_metrics.library_rows or 1
    local grid_h = grid_metrics.grid_h
    local row_h = grid_metrics.row_h
    if library_cols <= 0 or library_rows <= 0 then
        return VerticalGroup:new{ align = "left" }
    end
    local cell_metrics = {
        item_gap = grid_metrics.item_gap,
        title_h = grid_metrics.title_h,
        bar_h = grid_metrics.bar_h,
    }
    local sort_mode = grid_metrics.sort_mode

    local rows = {}
    for r = 0, library_rows - 1 do
        local row = HorizontalGroup:new{ align = "top" }
        for col = 1, library_cols do
            if col > 1 then
                appendGap(row, col == library_cols and cell_gap_last or cell_gap)
            end
            local entry = entries[r * library_cols + col]
            if entry and entry.type == "folder" then
                row[#row + 1] = FolderCell.build(entry.path, entry.name, cell_w, cover_h,
                    on_enter, cell_metrics, sort_mode)
            elseif entry then
                row[#row + 1] = LibraryCell.build(entry.path, cell_w, cover_h, on_open, cell_metrics)
            else
                row[#row + 1] = HorizontalSpan:new{ width = cell_w }
            end
        end
        rows[#rows + 1] = row
    end

    local grid = VerticalGroup:new{ align = "left" }
    if library_rows > 1 and grid_h and row_h and row_h > 0 then
        local slack = grid_h - library_rows * row_h
        if slack < 0 then slack = 0 end
        local row_gaps = distributeRowGaps(slack, library_rows - 1)
        for i, row in ipairs(rows) do
            if i > 1 then
                local gap_w = row_gaps[i - 1] or 0
                if gap_w > 0 then
                    grid[#grid + 1] = VerticalSpan:new{ width = gap_w }
                end
            end
            grid[#grid + 1] = row
        end
    else
        for i, row in ipairs(rows) do
            grid[#grid + 1] = row
        end
    end

    if grid_h and grid_h > 0 and content_w and content_w > 0 then
        return FrameContainer:new{
            bordersize = 0,
            padding = 0,
            dimen = Geom:new{ w = content_w, h = grid_h },
            TopContainer:new{
                dimen = Geom:new{ w = content_w, h = grid_h },
                grid,
            },
        }
    end

    return grid
end

return LibraryGridRow

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
    local content_width = grid_metrics.content_width
    local cell_width = grid_metrics.cell_width
    local cover_height = grid_metrics.cover_height
    local cell_gap = grid_metrics.cell_gap or 0
    local cell_gap_last = grid_metrics.cell_gap_last or cell_gap
    local library_cols = grid_metrics.library_cols
    local library_rows = grid_metrics.library_rows or 1
    local grid_height = grid_metrics.grid_height
    local row_height = grid_metrics.row_height
    if library_cols <= 0 or library_rows <= 0 then
        return VerticalGroup:new{ align = "left" }
    end
    local cell_metrics = {
        item_gap = grid_metrics.item_gap,
        title_height = grid_metrics.title_height,
        progress_height = grid_metrics.progress_height,
        cover_progress_gap = grid_metrics.cover_progress_gap,
        progress_title_gap = grid_metrics.progress_title_gap,
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
                row[#row + 1] = FolderCell.build(entry.path, entry.name, cell_width, cover_height,
                    on_enter, cell_metrics, sort_mode)
            elseif entry then
                row[#row + 1] = LibraryCell.build(entry.path, cell_width, cover_height, on_open, cell_metrics)
            else
                row[#row + 1] = HorizontalSpan:new{ width = cell_width }
            end
        end
        rows[#rows + 1] = row
    end

    local grid = VerticalGroup:new{ align = "left" }
    if library_rows > 1 and grid_height and row_height and row_height > 0 then
        local min_row_gap = grid_metrics.min_row_gap or 0
        local gap_count = library_rows - 1
        local fixed_gap = gap_count * min_row_gap
        local slack = grid_height - library_rows * row_height - fixed_gap
        if slack < 0 then slack = 0 end
        local extra_gaps = distributeRowGaps(slack, gap_count)
        local row_gaps = {}
        for i = 1, gap_count do
            row_gaps[i] = min_row_gap + (extra_gaps[i] or 0)
        end
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

    if grid_height and grid_height > 0 and content_width and content_width > 0 then
        return FrameContainer:new{
            bordersize = 0,
            padding = 0,
            dimen = Geom:new{ w = content_width, h = grid_height },
            TopContainer:new{
                dimen = Geom:new{ w = content_width, h = grid_height },
                grid,
            },
        }
    end

    return grid
end

return LibraryGridRow

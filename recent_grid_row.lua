--[[--
recent_grid_row.lua — A single Recent grid row (column count computed
dynamically by the layout).
--]]

local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local DebugOverlay = require("debug_overlay")
local FolderCell = require("folder_cell")
local RecentCell = require("recent_cell")

local RecentGridRow = {}

local function appendGap(row, width)
    if width > 0 then
        row[#row + 1] = HorizontalSpan:new{ width = width }
    end
end

--- @param entries table list of { type = "book"|"folder", path, name }
--- @return table Grid row widget
function RecentGridRow.build(entries, grid_metrics, on_open, on_enter)
    local cell_w = grid_metrics.cell_w
    local cover_h = grid_metrics.cover_h
    local cell_gap = grid_metrics.cell_gap or 0
    local cell_gap_last = grid_metrics.cell_gap_last or cell_gap
    local recent_cols = grid_metrics.recent_cols
    local content_w = grid_metrics.content_w
    if recent_cols <= 0 then
        return HorizontalGroup:new{ align = "top" }
    end
    local cell_metrics = {
        item_gap = grid_metrics.item_gap,
        title_h = grid_metrics.title_h,
        bar_h = grid_metrics.bar_h,
    }
    local sort_mode = grid_metrics.sort_mode

    local row = HorizontalGroup:new{ align = "top" }
    for col = 1, recent_cols do
        if col > 1 then
            appendGap(row, col == recent_cols and cell_gap_last or cell_gap)
        end
        local entry = entries[col]
        if entry and entry.type == "folder" then
            row[#row + 1] = FolderCell.build(entry.path, entry.name, cell_w, cover_h,
                on_enter, cell_metrics, sort_mode)
        elseif entry then
            row[#row + 1] = RecentCell.build(entry.path, cell_w, cover_h, on_open, cell_metrics)
        else
            row[#row + 1] = HorizontalSpan:new{ width = cell_w }
        end
    end

    local row_h = cover_h + cell_metrics.item_gap + cell_metrics.bar_h
        + cell_metrics.item_gap + cell_metrics.title_h
    return DebugOverlay.wrap("recent_grid_row", row, content_w, row_h, "recent_grid_row")
end

return RecentGridRow

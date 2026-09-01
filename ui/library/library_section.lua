--[[--
library_section.lua — Assembles the Library section.
--]]

local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local LibraryActionBar = require("ui/library/library_action_bar")
local LibraryGridRow = require("ui/library/library_grid_row")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local LibrarySection = {}

--- @return table Library section widget
function LibrarySection.build(entries, metrics, on_open, opts)
    opts = opts or {}
    -- 32px padding around the whole Library section. The section's outer
    -- footprint stays content_w x library_h; the inner content area (action bar
    -- + grid) is inset on all four sides, with the top inset 4 (design px)
    -- smaller so the action bar sits closer to the Continue section above.
    local pad = Layout.pad.cover
    local pad_top = Layout.pad.library_top
    local inner_w = metrics.content_w - 2 * pad
    if inner_w < 0 then inner_w = 0 end
    local inner_content_h = metrics.library_h - pad_top - pad
    if inner_content_h < 0 then inner_content_h = 0 end
    -- Downstream sizing (grid columns/rows, action bar width) works against the
    -- padded content width/height.
    local inner_metrics = {}
    for k, v in pairs(metrics) do inner_metrics[k] = v end
    inner_metrics.content_w = inner_w
    inner_metrics.library_h = inner_content_h

    local grid_metrics = Layout.libraryGridMetrics(inner_w, inner_content_h)
    grid_metrics.sort_mode = opts.sort_mode
    local page = opts.page or 0
    local page_size = grid_metrics.library_cols * grid_metrics.library_rows
    local page_count = 1
    local page_entries = {}

    if page_size > 0 then
        page_count = math.max(1, math.ceil(#entries / page_size))
        if page >= page_count then page = page_count - 1 end
        if page < 0 then page = 0 end

        local start_idx = page * page_size + 1
        for i = start_idx, math.min(start_idx + page_size - 1, #entries) do
            page_entries[#page_entries + 1] = entries[i]
        end
    end

    local action_bar = LibraryActionBar.build({
        sort_mode = opts.sort_mode,
        page = page,
        metrics = inner_metrics,
        show_parent = opts.show_parent,
        current_title = opts.current_title,
        home = opts.home,
        title_region = opts.title_region,
        animate_title = opts.animate_title,
        on_sort_menu = opts.on_sort_menu,
        on_page_change = opts.on_page_change,
        on_go_up = opts.on_go_up,
    }, page_count)

    local grid_row
    if page_size > 0 then
        grid_row = LibraryGridRow.build(page_entries, grid_metrics, on_open, opts.on_enter)
    else
        grid_row = VerticalGroup:new{ align = "left" }
    end

    local inner = VerticalGroup:new{ align = "left", action_bar }
    if grid_metrics.header_gap > 0 then
        inner[#inner + 1] = VerticalSpan:new{ width = grid_metrics.header_gap }
    end
    inner[#inner + 1] = grid_row

    local section = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = pad,
        padding_right = pad,
        padding_top = pad_top,
        padding_bottom = pad,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.library_h },
        TopContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_content_h },
            inner,
        },
    }

    return section
end

return LibrarySection

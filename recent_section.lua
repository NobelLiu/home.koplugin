--[[--
recent_section.lua — Assembles the Recent section.
--]]

local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local DebugOverlay = require("debug_overlay")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Layout = require("layout")
local RecentActionBar = require("recent_action_bar")
local RecentGridRow = require("recent_grid_row")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local RecentSection = {}

--- @return table Recent section widget
function RecentSection.build(entries, metrics, on_open, opts)
    opts = opts or {}
    local grid_metrics = Layout.recentGridMetrics(metrics.content_w, metrics.recent_h)
    grid_metrics.sort_mode = opts.sort_mode
    local page = opts.page or 0
    local page_size = grid_metrics.recent_cols
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

    local action_bar = RecentActionBar.build({
        sort_mode = opts.sort_mode,
        page = page,
        metrics = metrics,
        show_parent = opts.show_parent,
        current_title = opts.current_title,
        on_sort_menu = opts.on_sort_menu,
        on_page_change = opts.on_page_change,
        on_go_up = opts.on_go_up,
    }, page_count)

    local grid_row
    if page_size > 0 then
        grid_row = RecentGridRow.build(page_entries, grid_metrics, on_open, opts.on_enter)
    else
        grid_row = HorizontalGroup:new{ align = "top" }
    end

    local inner = VerticalGroup:new{ align = "left", action_bar }
    if grid_metrics.header_gap > 0 then
        inner[#inner + 1] = VerticalSpan:new{ width = grid_metrics.header_gap }
    end
    inner[#inner + 1] = grid_row

    local section = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.recent_h },
        TopContainer:new{
            dimen = Geom:new{ w = metrics.content_w, h = metrics.recent_h },
            inner,
        },
    }

    return DebugOverlay.wrap("recent_section", section,
        metrics.content_w, metrics.recent_h, "recent_section")
end

return RecentSection

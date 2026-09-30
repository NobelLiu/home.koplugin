--[[--
library_section.lua — Library chrome: action bar, cover grid, page footer.

Three-layer VStack (spacing 0), matching SwiftUI:
  Action Bar — full width
  Books      — horizontal padding only (Layout.pad.bar, 20pt)
  Page Indicator — screen width, height Layout.pad.bar; hidden when one page
]]

local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local LibraryActionBar = require("ui/library/library_action_bar")
local LibraryGridRow = require("ui/library/library_grid_row")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local PageIndicator = require("ui/uikit/components/chrome/page_indicator")
local Theme = require("ui/uikit/components/theme")

local LibrarySection = {}

local function slicePage(entries, page, page_size)
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
    return page, page_count, page_entries
end

--- @return table Library section widget
function LibrarySection.build(entries, metrics, on_open, opts)
    opts = opts or {}
    local inset = Layout.libraryInnerSize(metrics.content_width, metrics.library_height)

    local grid_metrics = Layout.libraryGridMetrics(inset.inner_width, inset.inner_height)
    grid_metrics.sort_mode = opts.sort_mode
    local page, page_count, page_entries = slicePage(
        entries, opts.page or 0,
        grid_metrics.library_cols * grid_metrics.library_rows
    )
    local action_bar = LibraryActionBar.build({
        metrics = metrics,
        current_title = opts.current_title,
        can_back = opts.can_back,
        can_forward = opts.can_forward,
        on_back = opts.on_back,
        on_forward = opts.on_forward,
        on_sort_menu = opts.on_sort_menu,
    })

    local grid_row
    if grid_metrics.library_cols > 0 and grid_metrics.library_rows > 0 then
        grid_row = LibraryGridRow.build(page_entries, grid_metrics, on_open, opts.on_enter)
    else
        grid_row = VerticalGroup:new{ align = "left" }
    end

    local footer = PageIndicator:new{
        page = page,
        page_count = page_count,
        on_page = opts.on_page_change,
        width = metrics.screen_width,
        height = grid_metrics.footer_height or pt(Layout.pad.bar),
    }

    local books = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = inset.pad,
        padding_right = inset.pad,
        width = metrics.content_width,
        background = Theme.color.white,
        grid_row,
    }

    local col = VerticalGroup:new{ align = "left", action_bar }
    if grid_metrics.header_gap > 0 then
        col[#col + 1] = VerticalSpan:new{ width = grid_metrics.header_gap }
    end
    col[#col + 1] = books
    col[#col + 1] = footer

    return FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_width, h = metrics.library_height },
        background = Theme.color.white,
        TopContainer:new{
            dimen = Geom:new{ w = metrics.content_width, h = metrics.library_height },
            col,
        },
    }
end

return LibrarySection

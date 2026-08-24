--[[--
recent_action_bar.lua — Recent action bar (sort toggle + pagination).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Layout = require("layout")
local DebugOverlay = require("debug_overlay")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local TapCell = require("tap_cell")
local TextWidget = require("ui/widget/textwidget")
local _ = require("gettext")

local RecentActionBar = {}

-- nerdfonts/symbols.ttf
local ICON_DOWN = "\u{E83F}"
local ICON_LEFT = "\u{E840}"
local ICON_RIGHT = "\u{E841}"

local function symbolFace()
    return Font:getFace("cfont")
end

local function symbolWidget(glyph, enabled)
    return TextWidget:new{
        text = BD.wrap(glyph),
        face = symbolFace(),
        fgcolor = enabled and Blitbuffer.COLOR_BLACK or Layout.COLOR_MUTED,
        padding = 0,
        bold = false,
    }
end

local function sortLabel(sort_mode)
    if sort_mode == "name" then
        return _("Name")
    end
    return _("Recent")
end

local function buildSortButton(sort_mode, on_sort_toggle)
    local chevron = symbolWidget(ICON_DOWN, true)
    local label = TextWidget:new{
        text = sortLabel(sort_mode),
        face = Layout.sectionFace(),
        bold = true,
        fgcolor = Blitbuffer.COLOR_BLACK,
    }
    local row = HorizontalGroup:new{
        align = "center",
        label,
        HorizontalSpan:new{ width = Size.padding.buttontable },
        chevron,
    }
    local size = row:getSize()
    return TapCell.wrap(row, Geom:new{ w = size.w, h = size.h }, on_sort_toggle)
end

local function buildPagerButton(glyph, enabled, callback)
    local wg = symbolWidget(glyph, enabled)
    local size = wg:getSize()
    return TapCell.wrap(wg, Geom:new{ w = size.w, h = size.h }, enabled and callback or nil)
end

--- Return pagination controls only when there are multiple pages; returns nil
--- (hidden) for a single page.
local function buildPagerButtons(page, page_count, on_page_change)
    if page_count <= 1 then return nil end

    local left_glyph = ICON_LEFT
    local right_glyph = ICON_RIGHT
    if BD.mirroredUILayout() then
        left_glyph, right_glyph = right_glyph, left_glyph
    end

    local prev_enabled = page > 0
    local next_enabled = page < page_count - 1

    local prev_btn = buildPagerButton(left_glyph, prev_enabled, function()
        on_page_change(page - 1)
    end)
    local next_btn = buildPagerButton(right_glyph, next_enabled, function()
        on_page_change(page + 1)
    end)

    return HorizontalGroup:new{
        align = "center",
        prev_btn,
        HorizontalSpan:new{ width = Size.padding.buttontable * 2 },
        next_btn,
    }
end

--- @return table action bar widget, number action_bar_h
function RecentActionBar.build(opts, page_count)
    local action_bar_h = Layout.dim.action_bar
    local sort_btn = buildSortButton(opts.sort_mode, opts.on_sort_toggle)
    local pager = buildPagerButtons(opts.page, page_count, opts.on_page_change)

    local row = OverlapGroup:new{
        dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
        LeftContainer:new{
            dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
            sort_btn,
        },
    }
    -- Show pagination controls only when there are multiple pages.
    if pager then
        row[#row + 1] = RightContainer:new{
            dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
            pager,
        }
    end

    return DebugOverlay.wrap("recent_action_bar", row,
        opts.metrics.content_w, action_bar_h, "recent_action_bar"), action_bar_h
end

return RecentActionBar

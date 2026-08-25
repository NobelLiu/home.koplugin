--[[--
recent_action_bar.lua — Recent action bar (sort toggle + pagination).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
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
local ICON_LEFT = "\u{F47D}"
local ICON_RIGHT = "\u{F460}"
local ICON_BACK = "\u{E74C}"
local ICON_SORT_NAME = "\u{F15D}"
local ICON_SORT_RECENT = "\u{F161}"

local function symbolFace(size)
    return Font:getFace("cfont", size)
end

local function symbolWidget(glyph, enabled, size)
    return TextWidget:new{
        text = BD.wrap(glyph),
        face = symbolFace(size),
        fgcolor = enabled and Blitbuffer.COLOR_BLACK or Layout.COLOR_MUTED,
        padding = 0,
        bold = false,
    }
end

-- Icon sizes anchored to Font sizemap presets (orig/unscaled px):
--   pager  -> "tfont" (26)
--   sort   -> "x_smallinfofont" (20), matching the section face
local PAGER_ICON_SIZE = Font:getFace("tfont").orig_size
local SORT_ICON_SIZE = Font:getFace("x_smallinfofont").orig_size

--- Square, icon-centered tappable button. Side length matches the action bar
--- height, so tapping inverts the whole square (black) as feedback.
local function buildSquareIconButton(glyph, enabled, callback, icon_font_size)
    local side = Layout.dim.action_bar
    local icon = symbolWidget(glyph, enabled, icon_font_size)
    local icon_size = icon:getSize()
    icon.overlap_offset = {
        math.floor((side - icon_size.w) / 2),
        math.floor((side - icon_size.h) / 2),
    }
    local cell = OverlapGroup:new{
        dimen = Geom:new{ w = side, h = side },
        allow_mirroring = false,
        icon,
    }
    local content = FrameContainer:new{
        bordersize = 0,
        color = enabled and Blitbuffer.COLOR_BLACK or Layout.COLOR_MUTED,
        padding = 0,
        margin = 0,
        radius = 0,
        width = side,
        height = side,
        cell,
    }
    return TapCell.wrap(content, Geom:new{ w = side, h = side },
        enabled and callback or nil, { highlight = enabled })
end

local function buildSortButton(sort_mode, on_sort_menu)
    local glyph = sort_mode == "name" and ICON_SORT_NAME or ICON_SORT_RECENT
    return buildSquareIconButton(glyph, true, on_sort_menu, SORT_ICON_SIZE)
end

local function buildPagerButton(glyph, enabled, callback)
    return buildSquareIconButton(glyph, enabled, callback, PAGER_ICON_SIZE)
end

--- Pagination controls; both arrows are shown always and rendered as disabled
--- (muted, non-tappable) when there is no previous/next page.
local function buildPagerButtons(page, page_count, on_page_change)
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
        next_btn,
    }
end

--- Left segment: a back icon + label. At the root the label is "Recent" with
--- no icon (not tappable); inside a subfolder the label is the folder name
--- preceded by a back icon, and tapping returns to the parent folder.
local function buildTitle(current_title, content_w, on_go_up)
    local at_root = not current_title or current_title == ""
    local label_text = at_root and _("Recent") or current_title
    local max_label_w = math.floor(content_w * 0.5)
    local label = TextWidget:new{
        text = label_text,
        face = Layout.sectionFace(),
        bold = true,
        fgcolor = Blitbuffer.COLOR_BLACK,
        max_width = max_label_w,
    }

    if at_root then
        local size = label:getSize()
        return TapCell.wrap(label, Geom:new{ w = size.w, h = size.h })
    end

    local icon = symbolWidget(ICON_BACK, true)
    local row = HorizontalGroup:new{
        align = "center",
        icon,
        HorizontalSpan:new{ width = Size.padding.buttontable },
        label,
    }
    local size = row:getSize()
    return TapCell.wrap(row, Geom:new{ w = size.w, h = size.h }, on_go_up,
        { highlight = true })
end

--- @return table action bar widget, number action_bar_h
function RecentActionBar.build(opts, page_count)
    local action_bar_h = Layout.dim.action_bar
    local title = buildTitle(opts.current_title, opts.metrics.content_w, opts.on_go_up)
    local sort_btn = buildSortButton(opts.sort_mode, opts.on_sort_menu)
    local pager = buildPagerButtons(opts.page, page_count, opts.on_page_change)

    -- Right cluster: sort button, then pager. The pager is always shown; its
    -- arrows appear disabled (muted, non-tappable) when there is no prev/next
    -- page.
    local right_group = HorizontalGroup:new{
        align = "center",
        sort_btn,
        HorizontalSpan:new{ width = Size.padding.large },
        pager,
    }

    local row = OverlapGroup:new{
        dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
        LeftContainer:new{
            dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
            title,
        },
        RightContainer:new{
            dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
            right_group,
        },
    }

    return DebugOverlay.wrap("recent_action_bar", row,
        opts.metrics.content_w, action_bar_h, "recent_action_bar"), action_bar_h
end

return RecentActionBar

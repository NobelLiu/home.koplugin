--[[--
layout.lua — Home layout constants and sizing helpers.

Module structure is split across the individual section files; all sizes are
computed centrally by mainContentMetrics(). Spacing prefers ui/size tokens;
user-adjustable values are stored in settings as design px and converted
through scale().
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Size = require("ui/size")
local Screen = Device.screen

local Layout = {}

Layout.PHI = 0.618
Layout.COVER_ASPECT = 1.4 -- height / width (width : height = 1 : 1.4)

-- Spacing helpers (already scaled via Size)
Layout.pad = {
    main     = 2 * Size.padding.large,           -- design 20
    info     = 2 * Size.padding.large,
    status_v = Size.padding.large + Size.padding.small, -- design 12
}
Layout.gap = {
    content = Size.span.horizontal_default,      -- design 10
    section = 2 * Size.span.horizontal_default,  -- design 20
    vstack  = Size.span.vertical_default,        -- design 2
}
Layout.dim = {
    action_bar = Size.item.height_big,           -- design 40
    progress   = Size.span.vertical_default,     -- design 2
    border     = Size.border.default,
    divider    = Size.line.thick,
    empty_extra = 2 * Size.item.height_large,    -- design 100, vertical centering room
}

-- Design px defaults aligned with Size tokens (user settings 0–60)
Layout.DEFAULTS = {
    vstack_padding = 20,
    section_title_v_pad = 10,
    content_gap = 10,
    section_gap = 20,
    status_side_padding = 20,
    status_vert_padding = 12,
    continue_row_gap = 10,
}

Layout.SETTING_KEYS = {
    vstack_padding = "home_vstack_padding",
    section_title_v_pad = "home_section_title_v_pad",
    content_gap = "home_content_gap",
    section_gap = "home_section_gap",
    status_side_padding = "home_status_side_padding",
    status_vert_padding = "home_status_vert_padding",
    continue_row_gap = "home_continue_row_gap",
    debug_layout = "home_debug_layout",
}

Layout.COLOR_DIVIDER = Blitbuffer.COLOR_GRAY
Layout.COLOR_PLACEHOLDER = Blitbuffer.COLOR_LIGHT_GRAY
Layout.COLOR_MUTED = Blitbuffer.COLOR_DARK_GRAY
Layout.COLOR_COVER_BORDER = Blitbuffer.COLOR_GRAY_D

local function readSetting(key)
    if not G_reader_settings then return nil end
    local val = G_reader_settings:readSetting(Layout.SETTING_KEYS[key])
    if type(val) == "number" then return val end
    return Layout.DEFAULTS[key]
end

function Layout.getVstackPadding() return readSetting("vstack_padding") end
function Layout.getSectionTitleVPad() return readSetting("section_title_v_pad") end
function Layout.getContentGap() return readSetting("content_gap") end
function Layout.getSectionGap() return readSetting("section_gap") end
function Layout.getStatusSidePadding() return readSetting("status_side_padding") end
function Layout.getStatusVertPadding() return readSetting("status_vert_padding") end
function Layout.getContinueRowGap() return readSetting("continue_row_gap") end

function Layout.isDebugLayout()
    if not G_reader_settings then return false end
    return G_reader_settings:isTrue(Layout.SETTING_KEYS.debug_layout)
end

function Layout.scale(n)
    return Screen:scaleBySize(n)
end

--- User setting in design px → scaled pixels.
function Layout.scaledSetting(key)
    return Layout.scale(readSetting(key))
end

function Layout.lineHeight(face, em)
    return math.ceil(face.size * (1 + (em or 0.3)))
end

function Layout.captionLineHeight()
    return Layout.lineHeight(Layout.captionFace())
end

function Layout.contentWidth(screen_w, main_h_padding)
    local pad = main_h_padding or Layout.pad.main
    return screen_w - 2 * pad
end

--- Compute the cover size from the cover column width (1:1.4); shrinks while
--- keeping the aspect ratio when it would exceed max_h.
function Layout.continueCoverSize(cover_col_w, max_h)
    local cover_w = cover_col_w
    local cover_h = math.floor(cover_w * Layout.COVER_ASPECT)
    if max_h and cover_h > max_h then
        cover_h = max_h
        cover_w = math.floor(cover_h / Layout.COVER_ASPECT)
    end
    return cover_w, cover_h
end

--- All sizing metrics for the main content area.
function Layout.mainContentMetrics(screen_w, screen_h, status_bar_h)
    local main_h = screen_h - status_bar_h
    local main_h_padding = Layout.pad.main
    local main_v_padding = Layout.scaledSetting("vstack_padding")
    local main_padding = main_h_padding
    local inner_h = main_h - 2 * main_v_padding
    local content_w = Layout.contentWidth(screen_w, main_h_padding)
    local continue_slot_h = math.floor(inner_h * Layout.PHI) - Layout.gap.section
    if continue_slot_h < 0 then continue_slot_h = 0 end
    local section_gap = Layout.scaledSetting("section_gap")
    local recent_h = inner_h - continue_slot_h - section_gap
    if recent_h < 0 then recent_h = 0 end
    local info_w = math.floor(content_w * Layout.PHI)
    local cover_col_w = content_w - info_w
    local info_pad = Layout.pad.info
    local progress_bar_h = Layout.dim.progress
    local progress_row_h = math.max(progress_bar_h, Layout.lineHeight(Layout.bodyFace()))
    local continue_row_gap = Layout.scaledSetting("continue_row_gap")
    local max_info_row_h = continue_slot_h - progress_row_h - continue_row_gap
    local cover_w, cover_h = Layout.continueCoverSize(cover_col_w, max_info_row_h)
    local continue_info_row_h = cover_h
    local continue_h = cover_h + continue_row_gap + progress_row_h
    local item_gap = Layout.scaledSetting("content_gap")
    local section_title_v_pad = Layout.scaledSetting("section_title_v_pad")

    return {
        screen_w = screen_w,
        screen_h = screen_h,
        main_h = main_h,
        inner_h = inner_h,
        content_w = content_w,
        main_h_padding = main_h_padding,
        main_v_padding = main_v_padding,
        main_padding = main_padding,
        continue_slot_h = continue_slot_h,
        continue_h = continue_h,
        recent_h = recent_h,
        section_gap = section_gap,
        info_w = info_w,
        cover_col_w = cover_col_w,
        cover_w = cover_w,
        cover_h = cover_h,
        info_pad = info_pad,
        progress_row_h = progress_row_h,
        continue_row_gap = continue_row_gap,
        progress_bar_h = progress_bar_h,
        continue_info_row_h = continue_info_row_h,
        info_text_w = info_w - 2 * info_pad,
        item_gap = item_gap,
        section_title_v_pad = section_title_v_pad,
    }
end

--- Recent grid metrics: cover_h is derived from the remaining height, cell_w
--- follows the 1:1.4 aspect ratio, and the column count and gaps are chosen to
--- fill content_w.
function Layout.recentGridMetrics(content_w, recent_h)
    local title_h = Layout.captionLineHeight()
    local bar_h = Layout.dim.progress
    local item_gap = Layout.scaledSetting("content_gap")
    local action_bar_h = Layout.dim.action_bar
    local header_gap = item_gap
    local meta_row_h = item_gap + bar_h + item_gap + title_h
    local min_cover_h = Layout.scale(40)
    local min_cell_w = Layout.scale(72)
    local min_cell_gap = Size.margin.default
    local grid_h = recent_h - action_bar_h - header_gap

    local base = {
        content_w = content_w,
        title_h = title_h,
        bar_h = bar_h,
        item_gap = item_gap,
        action_bar_h = action_bar_h,
        header_gap = header_gap,
        cell_gap = 0,
        cell_gap_last = 0,
    }

    if grid_h < meta_row_h + min_cover_h or content_w <= 0 then
        return {
            content_w = content_w,
            cell_w = min_cell_w,
            cover_h = min_cover_h,
            recent_cols = 0,
            title_h = title_h,
            bar_h = bar_h,
            item_gap = item_gap,
            action_bar_h = action_bar_h,
            header_gap = header_gap,
            cell_gap = 0,
            cell_gap_last = 0,
        }
    end

    local cover_h = grid_h - meta_row_h
    if cover_h < min_cover_h then cover_h = min_cover_h end

    local cell_w = math.floor(cover_h / Layout.COVER_ASPECT)
    cell_w = math.max(min_cell_w, cell_w)
    cover_h = math.floor(cell_w * Layout.COVER_ASPECT)

    local recent_cols = math.max(1, math.floor((content_w + min_cell_gap) / (cell_w + min_cell_gap)))
    while recent_cols > 1 and recent_cols * cell_w + (recent_cols - 1) * min_cell_gap > content_w do
        recent_cols = recent_cols - 1
    end

    local cell_gap, cell_gap_last = 0, 0
    if recent_cols > 1 then
        local total_gap = content_w - recent_cols * cell_w
        cell_gap = math.floor(total_gap / (recent_cols - 1))
        cell_gap_last = total_gap - cell_gap * (recent_cols - 2)
    end

    base.cell_w = cell_w
    base.cover_h = cover_h
    base.recent_cols = recent_cols
    base.cell_gap = cell_gap
    base.cell_gap_last = cell_gap_last
    return base
end

function Layout.sectionFace()
    return Font:getFace("x_smallinfofont")
end

function Layout.titleFace()
    return Font:getFace("cfont")
end

function Layout.bodyFace()
    return Font:getFace("x_smallinfofont")
end

function Layout.bodyItalicFace()
    local body = Layout.bodyFace()
    return Font:getFace("NotoSans-Italic.ttf", body.orig_size)
end

function Layout.captionFace()
    return Font:getFace("rifont")
end

return Layout

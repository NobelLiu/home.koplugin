--[[--
layout.lua — Home layout constants and sizing helpers.

Module structure is split across the individual section files; all sizes are
computed centrally by mainContentMetrics(). Spacing prefers ui/size tokens;
spacing/padding values are fixed design px (see DEFAULTS) converted through
scale().
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Size = require("ui/size")
local _ = require("gettext")
local Screen = Device.screen

local Layout = {}

Layout.PHI = 0.618
Layout.COVER_ASPECT = 1.4 -- height / width (width : height = 1 : 1.4)

-- Spacing helpers (already scaled via Size)
Layout.pad = {
    main     = 2 * Size.padding.large,           -- design 20
    info     = 2 * Size.padding.large,
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

-- Fixed design px values. Spacing/padding are anchored to ui/size presets;
-- the greeting font size is the only genuinely custom (user-adjustable) value.
Layout.DEFAULTS = {
    greeting_font_size = 26, -- nearest Font sizemap face: "tfont"
    -- Empty by default: an unset greeting (or one reset to default) falls back
    -- to the localized greeting in getGreetingText().
    greeting_text = "",
    -- Per-character reveal interval for the greeting typewriter animation, in
    -- milliseconds.
    greeting_anim_ms = 100,
}

-- Untranslated msgid for the fallback greeting shown when no custom greeting is
-- set. Wrapped through _() at read time so it follows the UI language.
Layout.DEFAULT_GREETING_TEXT = "Hi KOReader"

Layout.SETTING_KEYS = {
    greeting_font = "home_greeting_font",
    greeting_font_size = "home_greeting_font_size",
    greeting_text = "home_greeting_text",
    greeting_anim_ms = "home_greeting_anim_ms",
    debug_layout = "home_debug_layout",
}

Layout.COLOR_DIVIDER = Blitbuffer.COLOR_GRAY
Layout.COLOR_PLACEHOLDER = Blitbuffer.COLOR_LIGHT_GRAY
Layout.COLOR_MUTED = Blitbuffer.COLOR_DARK_GRAY
Layout.COLOR_COVER_BORDER = Blitbuffer.COLOR_GRAY_D

-- Spacing tokens (already scaled), anchored to ui/size presets. These replace
-- the previous raw design-px constants so downstream sizing uses presets.
Layout.space = {
    content_gap          = Size.padding.large,            -- design 10
    section_title_v_pad  = Size.padding.large,            -- design 10
    continue_row_gap     = Size.padding.large,            -- design 10
    vstack_padding       = 2 * Size.padding.large,        -- design 20
    section_gap          = 2 * Size.span.horizontal_default, -- design 20
    status_side_padding  = 2 * Size.padding.large,        -- design 20
    status_vert_padding  = Size.padding.large,            -- design 10 (nearest preset)
}

--- The greeting label text. Users may set a custom string; when it is empty
--- (unset, or reset to default), fall back to the localized default greeting
--- ("Hi KOReader"). Callers can hide the greeting by checking for an empty
--- return value, but by design this only happens when there is no translation
--- and no custom text.
function Layout.getGreetingText()
    local val = nil
    if G_reader_settings then
        val = G_reader_settings:readSetting(Layout.SETTING_KEYS.greeting_text)
    end
    if type(val) == "string" and val ~= "" then return val end
    return _(Layout.DEFAULT_GREETING_TEXT)
end

--- Greeting font file path (nil = use the default title face font "cfont").
function Layout.getGreetingFont()
    if not G_reader_settings then return nil end
    local val = G_reader_settings:readSetting(Layout.SETTING_KEYS.greeting_font)
    if type(val) == "string" and val ~= "" then return val end
    return nil
end

Layout.GREETING_FONT_SIZE_MIN = 12
Layout.GREETING_FONT_SIZE_MAX = 60

--- Greeting font size (orig/unscaled px; Font:getFace applies DPI scaling).
function Layout.getGreetingFontSize()
    local size = Layout.DEFAULTS.greeting_font_size
    if G_reader_settings then
        local val = G_reader_settings:readSetting(Layout.SETTING_KEYS.greeting_font_size)
        if type(val) == "number" then size = val end
    end
    if size < Layout.GREETING_FONT_SIZE_MIN then size = Layout.GREETING_FONT_SIZE_MIN end
    if size > Layout.GREETING_FONT_SIZE_MAX then size = Layout.GREETING_FONT_SIZE_MAX end
    return size
end

--- Face used to render the greeting label: the chosen font file (or the
--- default "cfont" title font) at the configured size.
function Layout.greetingFace()
    return Font:getFace(Layout.getGreetingFont() or "cfont", Layout.getGreetingFontSize())
end

Layout.GREETING_ANIM_MS_MIN = 0
Layout.GREETING_ANIM_MS_MAX = 1000

--- Per-character reveal interval for the greeting typewriter animation, in
--- milliseconds (as stored/displayed). Clamped to [MIN, MAX].
function Layout.getGreetingAnimMs()
    local ms = Layout.DEFAULTS.greeting_anim_ms
    if G_reader_settings then
        local val = G_reader_settings:readSetting(Layout.SETTING_KEYS.greeting_anim_ms)
        if type(val) == "number" then ms = val end
    end
    if ms < Layout.GREETING_ANIM_MS_MIN then ms = Layout.GREETING_ANIM_MS_MIN end
    if ms > Layout.GREETING_ANIM_MS_MAX then ms = Layout.GREETING_ANIM_MS_MAX end
    return ms
end

--- Same value as getGreetingAnimMs(), but in seconds for UIManager:scheduleIn.
--- A value of 0 reveals the whole greeting at once (no animation).
function Layout.getGreetingAnimInterval()
    return Layout.getGreetingAnimMs() / 1000
end

function Layout.isDebugLayout()
    if not G_reader_settings then return false end
    return G_reader_settings:isTrue(Layout.SETTING_KEYS.debug_layout)
end

function Layout.scale(n)
    return Screen:scaleBySize(n)
end

--- Preset-anchored spacing token (already scaled) for the given key.
function Layout.scaledSetting(key)
    return Layout.space[key]
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
    -- The gap between Continue and Recent is built around a 1px divider that must
    -- land exactly on the golden-ratio point of the full screen height. The
    -- divider is flanked by equal breathing room on both sides, each equal to the
    -- Recent header->books gap (content_gap), so the divider->header distance
    -- matches the header title->book distance.
    local divider_line_h = Size.line.medium
    local section_edge_gap = Layout.scaledSetting("content_gap")
    local section_gap = 2 * section_edge_gap + divider_line_h
    -- Vertical stack above the divider center is: status bar + main top padding +
    -- continue slot + top edge gap + half the divider line. Solve for the slot so
    -- that center sits on screen_h * PHI.
    local golden_y = math.floor(screen_h * Layout.PHI)
    local continue_slot_h = golden_y - status_bar_h - main_v_padding
        - section_edge_gap - math.floor(divider_line_h / 2)
    if continue_slot_h < 0 then continue_slot_h = 0 end
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
        divider_line_h = divider_line_h,
        section_edge_gap = section_edge_gap,
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

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
-- Default minimum book width in raw px (responsive to window width);
-- user-adjustable via the Library settings menu (see getLibraryCellWidthMin).
-- The maximum is auto-derived as 1.2x the minimum (see getLibraryCellWidthMax).
-- 110 keeps a 540x720 screen at 4 columns x 2 rows (8 books) with
-- padding-equal gaps.
Layout.CELL_W_MIN = 180
-- Absolute bounds the user may choose within.
Layout.CELL_W_LIMIT_MIN = 60
Layout.CELL_W_LIMIT_MAX = 600

-- Spacing helpers (already scaled via Size)
Layout.pad = {
    main     = 2 * Size.padding.large,           -- design 20
    info     = 2 * Size.padding.large,
    cover    = Screen:scaleBySize(20),           -- section/cover/info padding (was 32)
    -- The Library section's top padding is deliberately 4 (design px) smaller
    -- than the others (Layout.pad.cover), pulling the action bar closer to the
    -- Continue section above it.
    library_top = Screen:scaleBySize(20) - Screen:scaleBySize(12),
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

-- Fixed design px values. Spacing/padding are anchored to ui/size presets. The
-- greeting/title font size is fixed to the section face; only the greeting text,
-- font, and animation speed are user-adjustable.
Layout.DEFAULTS = {
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
    greeting_text = "home_greeting_text",
    greeting_anim_ms = "home_greeting_anim_ms",
    library_cell_w_min = "home_library_cell_w_min",
}

Layout.COLOR_DIVIDER = Blitbuffer.COLOR_GRAY
Layout.COLOR_PLACEHOLDER = Blitbuffer.COLOR_LIGHT_GRAY
Layout.COLOR_MUTED = Blitbuffer.COLOR_DARK_GRAY
Layout.COLOR_COVER_BORDER = Blitbuffer.COLOR_LIGHT_GRAY
Layout.COLOR_COVER_BG = Blitbuffer.COLOR_WHITE
Layout.COLOR_COVER_SHADOW_1 = Blitbuffer.COLOR_WHITE
Layout.COLOR_COVER_SHADOW_2 = Blitbuffer.COLOR_WHITE
Layout.COLOR_INFO_BG = Blitbuffer.COLOR_GRAY_F

-- Spacing tokens (already scaled), anchored to ui/size presets. These replace
-- the previous raw design-px constants so downstream sizing uses presets.
Layout.space = {
    content_gap          = Size.padding.small,            -- design 10
    section_title_v_pad  = Size.padding.large,            -- design 10
    vstack_padding       = 2 * Size.padding.large,        -- design 20
    section_gap          = 2 * Size.span.horizontal_default, -- design 20
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

--- Greeting font file path (nil = use the default section face font).
function Layout.getGreetingFont()
    if not G_reader_settings then return nil end
    local val = G_reader_settings:readSetting(Layout.SETTING_KEYS.greeting_font)
    if type(val) == "string" and val ~= "" then return val end
    return nil
end

--- Face used to render the greeting/title label: the chosen greeting font file
--- (or the default section face font) at the fixed section face size. The size
--- is not user-adjustable; only the font can be changed.
function Layout.greetingFace()
    local section = Layout.sectionFace()
    local font = Layout.getGreetingFont()
    if not font then return section end
    return Font:getFace(font, section.orig_size)
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

--- User-configured minimum book width (raw px), clamped to the allowed limits.
function Layout.getLibraryCellWidthMin()
    local w = Layout.CELL_W_MIN
    if G_reader_settings then
        local val = G_reader_settings:readSetting(Layout.SETTING_KEYS.library_cell_w_min)
        if type(val) == "number" then w = val end
    end
    if w < Layout.CELL_W_LIMIT_MIN then w = Layout.CELL_W_LIMIT_MIN end
    if w > Layout.CELL_W_LIMIT_MAX then w = Layout.CELL_W_LIMIT_MAX end
    return w
end

--- Maximum book width (raw px), auto-computed as 1.2x the current minimum and
--- clamped to the allowed upper limit.
function Layout.getLibraryCellWidthMax()
    local w = math.floor(Layout.getLibraryCellWidthMin() * 1.2)
    if w > Layout.CELL_W_LIMIT_MAX then w = Layout.CELL_W_LIMIT_MAX end
    return w
end

--- Largest minimum book width that still renders at least one full book card
--- (1 column x 1 row) on the current screen. Wider minimums are meant for
--- higher-resolution, larger screens; the pinch-zoom cap follows this so a
--- book always stays visible no matter how far the user spreads.
function Layout.getLibraryCellWidthMaxForScreen()
    local w, h = Screen:getWidth(), Screen:getHeight()
    if not w or not h or w <= 0 or h <= 0 then
        return Layout.CELL_W_LIMIT_MAX
    end
    local m = Layout.mainContentMetrics(w, h, 0)
    local pad = Layout.pad.cover
    local inner_w = math.max(0, m.content_w - 2 * pad)
    local inner_h = math.max(0, m.library_h - Layout.pad.library_top - pad)
    local title_h = Layout.captionLineHeight()
    local item_gap = Layout.scaledSetting("content_gap")
    local bar_h = Layout.dim.progress
    local action_bar_h = Layout.dim.action_bar
    local meta_row_h = item_gap + bar_h + item_gap + title_h
    local grid_h = inner_h - action_bar_h - item_gap
    -- Cell width that still fits a single row: cover_h + meta_row_h <= grid_h.
    local row_fit_w = math.floor(math.max(0, grid_h - meta_row_h) / Layout.COVER_ASPECT)
    -- The rendered cell width is clamped up to 1.2x the minimum, so the
    -- minimum itself must stay below the fit width by that same factor.
    local max_min_w = math.floor(math.min(inner_w, row_fit_w) / 1.2)
    if max_min_w < Layout.CELL_W_LIMIT_MIN then max_min_w = Layout.CELL_W_LIMIT_MIN end
    if max_min_w > Layout.CELL_W_LIMIT_MAX then max_min_w = Layout.CELL_W_LIMIT_MAX end
    return max_min_w
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

--- Compute the cover size with aspect-fit (1:1.4) into the box
--- max_w × max_h; the ratio is preserved, no distortion.
function Layout.continueCoverSize(max_w, max_h)
    local cover_w = max_w
    local cover_h = math.floor(cover_w * Layout.COVER_ASPECT)
    if max_h and cover_h > max_h then
        cover_h = max_h
        cover_w = math.floor(cover_h / Layout.COVER_ASPECT)
    end
    return cover_w, cover_h
end

--- All sizing metrics for the main content area.
--- Vertical model mirrors the SwiftUI layout: the whole screen is the container,
--- Library takes exactly screen_h * PHI and Continue takes the remainder, so
--- the full Continue slot is usable content. No divider or inter-section gap;
--- Home is a clean vertical stack.
function Layout.mainContentMetrics(screen_w, screen_h, status_bar_h)
    local main_h = screen_h
    local main_h_padding = 0
    local main_v_padding = 0
    local main_padding = main_h_padding
    local inner_h = main_h - 2 * main_v_padding
    local content_w = Layout.contentWidth(screen_w, main_h_padding)
    -- No divider / no inter-section gap (VStack spacing 0).
    local section_gap = 0
    -- Library gets the golden-ratio share of the full screen; Continue takes the
    -- rest. The whole Continue slot is content.
    local library_h = math.floor(screen_h * Layout.PHI)
    local continue_slot_h = inner_h - library_h
    if continue_slot_h < 0 then continue_slot_h = 0 end
    local continue_content_h = continue_slot_h
    local info_w = math.floor(content_w * Layout.PHI)
    local cover_col_w = content_w - info_w
    local cover_col_h = continue_content_h
    local info_pad = Layout.pad.info
    -- Padding around the cover inside its (gray) column, on all four sides.
    local cover_h_pad = Layout.pad.cover
    -- The Continue section is a single row (cover + info column). The cover
    -- aspect-fits inside the column minus padding on both sides:
    --   max_w = cover_col_w - 2*pad, max_h = cover_col_h - 2*pad.
    local cover_avail_w = cover_col_w - 2 * cover_h_pad
    if cover_avail_w < 0 then cover_avail_w = 0 end
    local cover_avail_h = cover_col_h - 2 * cover_h_pad
    if cover_avail_h < 0 then cover_avail_h = 0 end
    local cover_w, cover_h = Layout.continueCoverSize(cover_avail_w, cover_avail_h)
    local continue_h = cover_h
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
        status_bar_h = status_bar_h,
        continue_slot_h = continue_slot_h,
        continue_content_h = continue_content_h,
        continue_h = continue_h,
        library_h = library_h,
        section_gap = section_gap,
        info_w = info_w,
        cover_col_w = cover_col_w,
        cover_col_h = cover_col_h,
        cover_w = cover_w,
        cover_h = cover_h,
        cover_h_pad = cover_h_pad,
        info_pad = info_pad,
        info_text_w = info_w - 2 * info_pad,
        item_gap = item_gap,
        section_title_v_pad = section_title_v_pad,
    }
end

--- Library grid metrics: cell_w is driven by book width, clamped to the
--- user-configured raw px range [getLibraryCellWidthMin, getLibraryCellWidthMax]
--- so the column count stays fully responsive to the actual window width (min 1
--- column). cover_h follows the 1:1.4 aspect ratio, gaps fill content_w, and the
--- row count is how many such rows fit into the remaining height (min 1 row).
--- Items fill row-major (Z-order).
function Layout.libraryGridMetrics(content_w, library_h)
    local title_h = Layout.captionLineHeight()
    local bar_h = Layout.dim.progress
    local item_gap = Layout.scaledSetting("content_gap")
    local action_bar_h = Layout.dim.action_bar
    local header_gap = item_gap
    local row_gap = item_gap
    local meta_row_h = item_gap + bar_h + item_gap + title_h
    local min_cell_w = Layout.getLibraryCellWidthMin()
    local max_cell_w = Layout.getLibraryCellWidthMax()
    -- Spacing between books equals the Library section's outer padding.
    local min_cell_gap = Layout.pad.cover
    local grid_h = library_h - action_bar_h - header_gap

    local empty = {
        content_w = content_w,
        cell_w = min_cell_w,
        cover_h = math.floor(min_cell_w * Layout.COVER_ASPECT),
        library_cols = 0,
        library_rows = 0,
        grid_h = grid_h,
        row_h = 0,
        title_h = title_h,
        bar_h = bar_h,
        item_gap = item_gap,
        row_gap = row_gap,
        action_bar_h = action_bar_h,
        header_gap = header_gap,
        cell_gap = 0,
        cell_gap_last = 0,
    }

    if content_w <= 0 then return empty end

    -- Column count: as many min-width cells (plus gaps) as fit into content_w.
    local library_cols = math.max(1, math.floor((content_w + min_cell_gap) / (min_cell_w + min_cell_gap)))
    while library_cols > 1 and library_cols * min_cell_w + (library_cols - 1) * min_cell_gap > content_w do
        library_cols = library_cols - 1
    end

    -- Justified cell width for that column count, clamped to the design range.
    local total_min_gap = (library_cols - 1) * min_cell_gap
    local cell_w = math.floor((content_w - total_min_gap) / library_cols)
    cell_w = math.max(min_cell_w, math.min(max_cell_w, cell_w))

    local cover_h = math.floor(cell_w * Layout.COVER_ASPECT)
    local row_h = cover_h + meta_row_h

    -- Row count: as many full rows as fit; vertical gaps between rows are
    -- distributed dynamically in library_grid_row (first row top, last bottom).
    -- If even one row doesn't fit (e.g. a minimum width manually set beyond
    -- what this screen can show), shrink the cell so at least one book always
    -- stays visible.
    local library_rows = math.floor(grid_h / row_h)
    if library_rows < 1 then
        if grid_h < 1 then return empty end
        library_cols = 1
        cell_w = math.max(Layout.CELL_W_LIMIT_MIN,
            math.floor((grid_h - meta_row_h) / Layout.COVER_ASPECT))
        cover_h = math.floor(cell_w * Layout.COVER_ASPECT)
        row_h = cover_h + meta_row_h
        library_rows = 1
    end

    -- Distribute leftover horizontal space between cells to justify the row.
    local cell_gap, cell_gap_last = 0, 0
    if library_cols > 1 then
        local total_gap = content_w - library_cols * cell_w
        cell_gap = math.floor(total_gap / (library_cols - 1))
        cell_gap_last = total_gap - cell_gap * (library_cols - 2)
    end

    return {
        content_w = content_w,
        title_h = title_h,
        bar_h = bar_h,
        item_gap = item_gap,
        row_gap = row_gap,
        action_bar_h = action_bar_h,
        header_gap = header_gap,
        grid_h = grid_h,
        row_h = row_h,
        cell_w = cell_w,
        cover_h = cover_h,
        library_cols = library_cols,
        library_rows = library_rows,
        cell_gap = cell_gap,
        cell_gap_last = cell_gap_last,
    }
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

--- Smaller body face for the Continue description (one preset step below the
--- body/author face). Same NotoSans-Regular family, smaller size.
function Layout.descriptionFace()
    return Font:getFace("xx_smallinfofont")
end

function Layout.captionFace()
    return Font:getFace("rifont")
end

return Layout

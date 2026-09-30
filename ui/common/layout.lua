--[[--
layout.lua — Home layout constants and sizing helpers.

Module structure is split across the individual section files; all sizes are
computed centrally by mainContentMetrics(). Chrome and spacing are design pt
× Theme.screenScale() (same as ui/uikit). Set pt via Layout.pt
or Theme.pt; Layout.pad / dim / gap are pt. Wrap with Layout.pt() at layout.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local _ = require("gettext")
local Screen = Device.screen

local Layout = {}

Layout.PHI = 0.618
-- height / width; see Theme.coverAspect (Layout.COVER_ASPECT mirrors it).
Layout.COVER_ASPECT = nil -- set lazily from Theme.coverAspect
-- Book width clamp limits in design pt (shelf-row layout derives width from rows).
Layout.CELL_WIDTH_MIN = nil
Layout.CELL_WIDTH_LIMIT_MIN = nil
Layout.CELL_WIDTH_LIMIT_MAX = nil

-- Home-only design pt. Chrome (bar height / bar padding) lives on Theme.pt.
local PAD_PT = {
    main     = 20,
    info     = 20,
    cover    = 20,
    library_top = 0,
    library_bottom = 0,
}
local GAP_PT = {
    content = 10,
    section = 20,
    vstack  = 2,
    page    = 10,
}
local DIM_PT = {
    empty_extra = 100,
}
local SPACE_PT = {
    content_gap          = 2,
    section_title_vertical_padding = 10,
    vstack_padding       = 20,
    section_gap          = 20,
    continue_gap         = 8,
    continue_title_gap   = 4,
    library_cover_progress_gap = 4,
    library_progress_title_gap = 2,
    library_cell_gap = 20,
}

local DIM_THEME = {
    status_bar = "status_height",
    action_bar = "action_bar_height",
    footer     = "footer_height",
    icon       = "icon",
    page_dot   = "page_dot",
    progress   = "progress",
    divider    = "divider",
}

-- Fixed defaults. Spacing/padding are design pt tokens. The continue header
-- (greeting and "Continue reading") uses Headline; only the greeting text,
-- font file, and animation speed are user-adjustable.
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
    library_shelf_rows = "home_library_shelf_rows",
}

Layout.COLOR_DIVIDER = Blitbuffer.COLOR_GRAY
Layout.COLOR_PLACEHOLDER = Blitbuffer.COLOR_LIGHT_GRAY
Layout.COLOR_MUTED = Blitbuffer.COLOR_DARK_GRAY
Layout.COLOR_COVER_BORDER = Blitbuffer.COLOR_LIGHT_GRAY
Layout.COLOR_COVER_BG = Blitbuffer.COLOR_WHITE
Layout.COLOR_COVER_SHADOW_1 = Blitbuffer.COLOR_WHITE
Layout.COLOR_COVER_SHADOW_2 = Blitbuffer.COLOR_WHITE
Layout.COLOR_INFO_BG = Blitbuffer.COLOR_GRAY_F

--- iOS system gray (#8E8E93), used for Continue author.
function Layout.secondaryColor()
    if Device:hasColorScreen() then
        return Blitbuffer.ColorRGB32(0x8E, 0x8E, 0x93, 0xFF)
    end
    return Blitbuffer.Color8(0x8E)
end

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

function Layout.theme()
    if Layout._theme then
        return Layout._theme
    end
    Layout._theme = require("ui/uikit/components/theme")
    Layout.COVER_ASPECT = Layout._theme.coverAspect
    Layout.CELL_WIDTH_MIN = Layout._theme.dim.library_cell_min
    Layout.CELL_WIDTH_LIMIT_MIN = Layout._theme.dim.library_cell_limit_min
    Layout.CELL_WIDTH_LIMIT_MAX = Layout._theme.dim.library_cell_limit_max
    return Layout._theme
end

--- Design pt → device px. `local pt, px = Layout.pt, Layout.px`
function Layout.pt(n)
    return Layout.theme().pt(n)
end

--- Device px → design pt (inverse of Layout.pt).
function Layout.unpt(px)
    return Layout.theme().unpt(px)
end

--- Raw device pixels. `px(1)` is always 1px.
function Layout.px(n)
    return Layout.theme().px(n)
end

function Layout.scale(n)
    return Layout.pt(n)
end

function Layout.coverAspect()
    if not Layout.COVER_ASPECT then
        Layout.theme()
    end
    return Layout.COVER_ASPECT
end

-- Token tables are pt. Chrome keys read Theme.pad / Theme.dim.
Layout.pad = setmetatable({}, {
    __index = function(_, key)
        if key == "bar" then
            return Layout.theme().pad.page_horizontal
        end
        return PAD_PT[key]
    end,
    __newindex = function(_, key, value)
        if key == "bar" then
            Layout.theme().pt.pad.page_horizontal = value
            return
        end
        PAD_PT[key] = value
    end,
})

Layout.gap = setmetatable({}, {
    __index = function(_, key)
        return GAP_PT[key]
    end,
    __newindex = function(_, key, value)
        GAP_PT[key] = value
    end,
})

Layout.dim = setmetatable({}, {
    __index = function(_, key)
        local theme_key = DIM_THEME[key]
        if theme_key then
            return Layout.theme().dim[theme_key]
        end
        if key == "border" then
            return Layout.theme().border.default
        end
        return DIM_PT[key]
    end,
    __newindex = function(_, key, value)
        local theme_key = DIM_THEME[key]
        if theme_key then
            Layout.theme().pt.dim[theme_key] = value
            return
        end
        if key == "border" then
            Layout.theme().pt.border.default = value
            return
        end
        DIM_PT[key] = value
    end,
})

Layout.space = setmetatable({}, {
    __index = function(_, key)
        return SPACE_PT[key]
    end,
    __newindex = function(_, key, value)
        SPACE_PT[key] = value
    end,
})

function Layout.face(role, opts)
    return Layout.theme().face(role, opts)
end

--- Face at HIG pt (Font:getFace is undone so glyphs match Theme.pt).
function Layout.deviceFace(font, pixel_size)
    local theme = Layout.theme()
    local size = pixel_size
    if not size then
        size = Font.sizemap and Font.sizemap[font] or 20
    end
    return theme.getFace(font, theme.devicePixels(size))
end

--- Continue header line (greeting and "Continue reading"): Subheadline Emphasized.
function Layout.greetingFace()
    local theme = Layout.theme()
    local spec = theme.type.spec("subhead", { emphasized = true })
    local font = Layout.getGreetingFont()
    if font then
        return Layout.deviceFace(font, spec.size)
    end
    return theme.face("subhead", { emphasized = true })
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

--- Grid height and meta row height for shelf-row calculations.
function Layout._libraryShelfGridContext(content_width, library_height, opts)
    opts = opts or {}
    if not content_width or not library_height then
        local w, h = Screen:getWidth(), Screen:getHeight()
        if not w or not h or w <= 0 or h <= 0 then
            return 0, 0
        end
        local m = Layout.mainContentMetrics(w, h, Layout.pt(Layout.dim.status_bar))
        local inner = Layout.libraryInnerSize(m.content_width, m.library_height)
        content_width = inner.inner_width
        library_height = inner.inner_height
    end
    local title_height = Layout.libraryTitleLineHeight()
    local progress_height = Layout.pt(4)
    local item_gap = Layout.pt(Layout.scaledSetting("content_gap"))
    local action_bar_height = Layout.pt(Layout.dim.action_bar)
    local footer_height = opts.include_footer == false and 0 or Layout.pt(Layout.pad.bar)
    local meta_row_height = Layout.libraryMetaRowHeight(title_height, progress_height)
    local grid_height = math.floor((library_height or 0) - action_bar_height - item_gap - footer_height)
    return grid_height, meta_row_height
end

--- Minimum horizontal/vertical gap between library book cards (design pt).
function Layout.libraryCellGapPt()
    return Layout.space.library_cell_gap or Layout.pad.cover
end

--- Minimum book-to-book gap in device px.
function Layout.libraryCellGap()
    return Layout.pt(Layout.libraryCellGapPt())
end

--- Row height at the smallest allowed book width (design pt limit_min).
function Layout._libraryMinRowHeight(meta_row_height)
    local lo = Layout.CELL_WIDTH_LIMIT_MIN or Layout.theme().dim.library_cell_limit_min
    local min_cell_width = Layout.pt(lo)
    return math.floor(min_cell_width * Layout.coverAspect()) + meta_row_height
end

--- Maximum shelf rows that fit at the minimum book display size.
function Layout.getLibraryShelfRowsMax(content_width, library_height, opts)
    local grid_height, meta_row_height = Layout._libraryShelfGridContext(content_width, library_height, opts)
    if grid_height < 1 then return 1 end
    local min_row_height = Layout._libraryMinRowHeight(meta_row_height)
    if min_row_height < 1 then return 1 end
    local min_row_gap = Layout.libraryCellGap()
    -- n rows need n * row_height + (n - 1) * min_row_gap <= grid_height
    return math.max(1, math.floor((grid_height + min_row_gap) / (min_row_height + min_row_gap)))
end

--- Default shelf rows when the user has not set a preference: as many rows as
--- fit at the minimum cover display size on the current screen.
function Layout.inferDefaultLibraryShelfRows(content_width, library_height, opts)
    return Layout.getLibraryShelfRowsMax(content_width, library_height, opts)
end

--- User-configured shelf row count, clamped to the current screen maximum.
function Layout.getLibraryShelfRows(content_width, library_height, opts)
    local max_rows = Layout.getLibraryShelfRowsMax(content_width, library_height, opts)
    local rows
    if G_reader_settings then
        local val = G_reader_settings:readSetting(Layout.SETTING_KEYS.library_shelf_rows)
        if type(val) == "number" then rows = math.floor(val) end
    end
    if not rows then
        rows = Layout.inferDefaultLibraryShelfRows(content_width, library_height, opts)
    end
    if rows < 1 then rows = 1 end
    if rows > max_rows then rows = max_rows end
    return rows
end

--- Persist shelf row count, clamped to [1, max_rows].
function Layout.setLibraryShelfRows(rows, content_width, library_height, opts)
    rows = math.floor(rows or 1)
    local max_rows = Layout.getLibraryShelfRowsMax(content_width, library_height, opts)
    if rows < 1 then rows = 1 end
    if rows > max_rows then rows = max_rows end
    if G_reader_settings then
        G_reader_settings:saveSetting(Layout.SETTING_KEYS.library_shelf_rows, rows)
    end
    return rows
end

function Layout.scaledSetting(key)
    return Layout.space[key]
end

function Layout.lineHeight(face, em)
    return math.ceil(face.size * (1 + (em or 0.3)))
end

function Layout.captionLineHeight()
    return Layout.theme().type.leading("caption")
end

function Layout.calloutLineHeight()
    return Layout.theme().type.leading("callout")
end

function Layout.libraryTitleLineHeight()
    return Layout.theme().type.leading("subhead")
end

function Layout.contentWidth(screen_width, main_horizontal_padding)
    local pad = main_horizontal_padding or Layout.pt(Layout.pad.main)
    return math.max(0, math.floor((screen_width or 0) - 2 * pad))
end

--- Compute the cover size with aspect-fit (coverAspect) into the box
--- max_width × max_height; the ratio is preserved, no distortion.
--- Inset horizontal padding for the Library books grid only (Action Bar and
--- Page Indicator stay edge-to-edge). Grid metrics use inner_width/inner_height.
function Layout.libraryInnerSize(content_width, library_height)
    local pad = Layout.pt(Layout.pad.bar)
    local padding_top = Layout.pt(Layout.pad.library_top)
    local padding_bottom = Layout.pt(Layout.pad.library_bottom)
    return {
        pad = pad,
        padding_top = padding_top,
        padding_bottom = padding_bottom,
        inner_width = math.max(0, math.floor((content_width or 0) - 2 * pad)),
        inner_height = math.max(0, math.floor((library_height or 0) - padding_top - padding_bottom)),
    }
end

function Layout.continueCoverSize(max_width, max_height)
    local cover_width = math.floor(max_width or 0)
    local cover_height = math.floor(cover_width * Layout.coverAspect())
    if max_height then
        max_height = math.floor(max_height)
        if cover_height > max_height then
            cover_height = max_height
            cover_width = math.floor(cover_height / Layout.coverAspect())
        end
    end
    return cover_width, cover_height
end

--- All sizing metrics for the main content area.
--- Vertical stack: Status Bar, Continue, Library. Library is screen_height * PHI;
--- Continue is whatever remains under the status bar.
function Layout.mainContentMetrics(screen_width, screen_height, status_bar_height)
    local main_height = screen_height
    local main_horizontal_padding = 0
    local main_vertical_padding = 0
    local main_padding = main_horizontal_padding
    local inner_height = math.floor((main_height or 0) - 2 * main_vertical_padding)
    local content_width = Layout.contentWidth(screen_width, main_horizontal_padding)
    local section_gap = 0
    status_bar_height = status_bar_height or 0
    -- Library keeps the golden-ratio share of the full screen (494 on 800).
    -- Continue is the remainder after the status bar.
    local library_height = math.floor(screen_height * Layout.PHI)
    local continue_slot_height = math.max(0, math.floor(inner_height - status_bar_height - library_height))
    local continue_content_height = continue_slot_height
    local info_width = math.floor(content_width * Layout.PHI)
    local cover_column_width = content_width - info_width
    local cover_column_height = continue_content_height
    local info_padding = Layout.pt(Layout.pad.info)
    local info_top_padding = Layout.pt(Layout.pad.info)
    local cover_horizontal_padding = Layout.pt(Layout.pad.cover)
    local cover_top_padding = Layout.pt(Layout.pad.cover)
    local cover_bottom_padding = Layout.pt(Layout.pad.cover)
    -- The Continue section is a single row (cover + info column). The cover
    -- aspect-fits inside the column minus side and vertical padding.
    local cover_available_width = math.max(0, math.floor(cover_column_width - 2 * cover_horizontal_padding))
    local cover_available_height = math.max(0, math.floor(
        cover_column_height - cover_top_padding - cover_bottom_padding))
    local cover_width, cover_height = Layout.continueCoverSize(cover_available_width, cover_available_height)
    local continue_height = cover_height
    local item_gap = Layout.pt(Layout.scaledSetting("content_gap"))
    local section_title_vertical_padding = Layout.pt(Layout.scaledSetting("section_title_vertical_padding"))

    return {
        screen_width = screen_width,
        screen_height = screen_height,
        main_height = main_height,
        inner_height = inner_height,
        content_width = content_width,
        main_horizontal_padding = main_horizontal_padding,
        main_vertical_padding = main_vertical_padding,
        main_padding = main_padding,
        status_bar_height = status_bar_height,
        continue_slot_height = continue_slot_height,
        continue_content_height = continue_content_height,
        continue_height = continue_height,
        library_height = library_height,
        section_gap = section_gap,
        info_width = info_width,
        cover_column_width = cover_column_width,
        cover_column_height = cover_column_height,
        cover_width = cover_width,
        cover_height = cover_height,
        cover_horizontal_padding = cover_horizontal_padding,
        cover_top_padding = cover_top_padding,
        cover_bottom_padding = cover_bottom_padding,
        info_padding = info_padding,
        info_top_padding = info_top_padding,
        info_text_width = math.max(0, math.floor(info_width - info_padding)),
        item_gap = item_gap,
        section_title_vertical_padding = section_title_vertical_padding,
    }
end

--- Cover → progress 4pt, progress → title 2pt.
function Layout.libraryCoverProgressGap()
    return Layout.pt(Layout.space.library_cover_progress_gap)
end

function Layout.libraryProgressTitleGap()
    return Layout.pt(Layout.space.library_progress_title_gap)
end

function Layout.libraryMetaRowHeight(title_height, progress_height)
    title_height = title_height or Layout.libraryTitleLineHeight()
    progress_height = progress_height or Layout.pt(4)
    return Layout.libraryCoverProgressGap() + progress_height
        + Layout.libraryProgressTitleGap() + title_height
end

--- Library grid metrics: shelf row count is user-controlled; cell_width and
--- cover_height are derived from the per-row vertical budget. Column count and
--- horizontal gaps follow content_width (min 1 column). cover_height follows
--- coverAspect. Items fill row-major (Z-order).
function Layout.libraryGridMetrics(content_width, library_height, opts)
    opts = opts or {}
    local title_height = Layout.libraryTitleLineHeight()
    local progress_height = Layout.pt(4)
    local item_gap = Layout.pt(Layout.scaledSetting("content_gap"))
    local action_bar_height = Layout.pt(Layout.dim.action_bar)
    local footer_height = opts.include_footer == false and 0 or Layout.pt(Layout.pad.bar)
    local header_gap = item_gap
    local row_gap = item_gap
    local cover_progress_gap = Layout.libraryCoverProgressGap()
    local progress_title_gap = Layout.libraryProgressTitleGap()
    local meta_row_height = Layout.libraryMetaRowHeight(title_height, progress_height)
    local lo_px = Layout.pt(Layout.CELL_WIDTH_LIMIT_MIN or Layout.theme().dim.library_cell_limit_min)
    local hi_px = Layout.pt(Layout.CELL_WIDTH_LIMIT_MAX or Layout.theme().dim.library_cell_limit_max)
    local min_cell_gap = Layout.libraryCellGap()
    local min_row_gap = min_cell_gap
    local grid_height, _ = Layout._libraryShelfGridContext(content_width, library_height, opts)

    local empty = {
        content_width = content_width,
        cell_width = lo_px,
        cover_height = math.floor(lo_px * Layout.coverAspect()),
        library_cols = 0,
        library_rows = 0,
        grid_height = grid_height,
        row_height = 0,
        title_height = title_height,
        progress_height = progress_height,
        cover_progress_gap = cover_progress_gap,
        progress_title_gap = progress_title_gap,
        item_gap = item_gap,
        row_gap = row_gap,
        action_bar_height = action_bar_height,
        footer_height = footer_height,
        header_gap = header_gap,
        cell_gap = 0,
        cell_gap_last = 0,
        min_row_gap = min_row_gap,
    }

    if content_width <= 0 or grid_height < 1 then return empty end

    local max_rows = Layout.getLibraryShelfRowsMax(content_width, library_height, opts)
    local library_rows = Layout.getLibraryShelfRows(content_width, library_height, opts)
    if library_rows > max_rows then library_rows = max_rows end
    if library_rows < 1 then library_rows = 1 end

    local cell_width, cover_height, row_height
    repeat
        local row_area_height = grid_height
        if library_rows > 1 then
            row_area_height = grid_height - (library_rows - 1) * min_row_gap
        end
        local per_row_budget = math.floor(row_area_height / library_rows)
        cover_height = per_row_budget - meta_row_height
        cell_width = math.floor(cover_height / Layout.coverAspect())
        if cover_height < 1 or cell_width < 1 or row_area_height < 1 then
            library_rows = 1
            per_row_budget = grid_height
            cover_height = math.max(1, per_row_budget - meta_row_height)
            cell_width = math.max(lo_px, math.floor(cover_height / Layout.coverAspect()))
        end
        cell_width = math.max(lo_px, math.min(hi_px, cell_width))
        cover_height = math.floor(cell_width * Layout.coverAspect())
        row_height = cover_height + meta_row_height
        local total_row_block = library_rows * row_height
        if library_rows > 1 then
            total_row_block = total_row_block + (library_rows - 1) * min_row_gap
        end
        if library_rows > 1 and total_row_block > grid_height then
            library_rows = library_rows - 1
            cell_width = nil
        end
    until cell_width ~= nil

    local library_cols = math.max(1, math.floor((content_width + min_cell_gap) / (cell_width + min_cell_gap)))
    while library_cols > 1 and library_cols * cell_width + (library_cols - 1) * min_cell_gap > content_width do
        library_cols = library_cols - 1
    end

    local cell_gap, cell_gap_last = 0, 0
    if library_cols > 1 then
        local total_gap = content_width - library_cols * cell_width
        local gap_count = library_cols - 1
        cell_gap = math.max(min_cell_gap, math.floor(total_gap / gap_count))
        cell_gap_last = math.max(min_cell_gap, math.floor(total_gap - cell_gap * (gap_count - 1)))
        while library_cols > 1
            and library_cols * cell_width + (library_cols - 1) * min_cell_gap > content_width do
            library_cols = library_cols - 1
            gap_count = library_cols - 1
            if gap_count < 1 then
                cell_gap = 0
                cell_gap_last = 0
                break
            end
            total_gap = content_width - library_cols * cell_width
            cell_gap = math.max(min_cell_gap, math.floor(total_gap / gap_count))
            cell_gap_last = math.max(min_cell_gap, math.floor(total_gap - cell_gap * (gap_count - 1)))
        end
    end

    return {
        content_width = content_width,
        title_height = title_height,
        progress_height = progress_height,
        cover_progress_gap = cover_progress_gap,
        progress_title_gap = progress_title_gap,
        item_gap = item_gap,
        row_gap = row_gap,
        action_bar_height = action_bar_height,
        footer_height = footer_height,
        header_gap = header_gap,
        grid_height = grid_height,
        row_height = row_height,
        cell_width = cell_width,
        cover_height = cover_height,
        library_cols = library_cols,
        library_rows = library_rows,
        cell_gap = cell_gap,
        cell_gap_last = cell_gap_last,
        min_row_gap = min_row_gap,
    }
end

function Layout.sectionFace()
    return Layout.face("h3")
end

function Layout.titleFace()
    return Layout.face("title")
end

function Layout.bodyFace()
    return Layout.face("body")
end

--- Noto Sans SC has no italic; Medium is the HIG-adjacent substitute.
function Layout.bodyItalicFace()
    return Layout.face("body", { weight = "medium" })
end

function Layout.descriptionFace()
    return Layout.face("callout")
end

function Layout.libraryTitleFace()
    return Layout.face("subhead")
end

function Layout.captionFace()
    return Layout.face("caption")
end

return Layout

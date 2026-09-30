--[[--
Swiss International Style tokens for the Home component library.

Maps STYLE.md to KOReader Font / Size / Blitbuffer. Layout is iOS-style
pt × screen scale (1 / 1.5 / 2 / 3 from DPI). Type follows Apple HIG
iOS Dynamic Type (see components/type.lua). Interactive controls invoke
callbacks directly (no translate, scale, shadow, or invert flash).
]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FontList = require("fontlist")
local Geom = require("ui/geometry")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local Screen = Device.screen

local function pluginFontsDir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1, 1) == "@" then
        src = src:sub(2)
    end
    local root = src:match("(.+)[/\\]components[/\\]theme%.lua$")
    if not root or root == "" then
        root = "./plugins/home.koplugin/ui/uikit"
    end
    if root:sub(1, 1) ~= "/" and root:sub(1, 2) ~= "./" then
        root = "./" .. root
    end
    return root .. "/fonts"
end

local FONT_SUBDIRS = {
    "Noto_Sans_SC",
    "Material_Icons",
    "static",
    "",
}

local function absolutePath(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    if path:sub(1, 1) == "/" then
        return path
    end
    local cwd = lfs.currentdir()
    if path:sub(1, 2) == "./" then
        return cwd .. "/" .. path:sub(3)
    end
    return cwd .. "/" .. path
end

local function fontFileName(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local _, name = util.splitFilePathName(path)
    if name and name ~= "" then
        return name
    end
    return path
end

-- KOReader before #15873 (2026-08) only opens files under ./fonts, then
-- searches FontList by basename. Register plugin TTFs so that search works
-- on Kindle builds that do not yet accept a full path in Font:getFace.
local function registerPluginFont(path)
    path = absolutePath(path)
    if not path then
        return nil
    end
    FontList:getFontList()
    for _, known in ipairs(FontList.fontlist) do
        if known == path then
            return path
        end
    end
    table.insert(FontList.fontlist, path)
    return path
end

local function fontPath(filename)
    local root = pluginFontsDir()
    for _, sub in ipairs(FONT_SUBDIRS) do
        local path = sub == ""
            and (root .. "/" .. filename)
            or (root .. "/" .. sub .. "/" .. filename)
        if lfs.attributes(path, "mode") == "file" then
            return registerPluginFont(path)
        end
    end
end

local Theme = {}

Theme.arrow = "→"
Theme.radius = 0

--- Cover height / width (width : height = 1 : coverAspect).
Theme.coverAspect = 1.4

function Theme.coverHeight(width)
    return math.floor((width or 0) * Theme.coverAspect)
end

Theme.color = {
    black = Blitbuffer.COLOR_BLACK,
    white = Blitbuffer.COLOR_WHITE,
    gray_e = Blitbuffer.ColorRGB32(0xEE, 0xEE, 0xEE, 0xFF),
    muted = Blitbuffer.COLOR_DARK_GRAY,
    placeholder = Blitbuffer.COLOR_LIGHT_GRAY,
    divider = Blitbuffer.COLOR_GRAY,
}

--- White veil over content behind popups (0 = invisible, 1 = opaque).
Theme.scrim_alpha = 0.5

--- Design tokens in pt. Convert at layout time: `pt(Theme.pad.card)`, `px(1)`.
local BORDER_PT = {
    thin = 1,
    default = 1,
    thick = 2,
}

local PAD_PT = {
    tiny = 1,
    small = 2,
    default = 5,
    large = 10,
    card = 10,
    page_horizontal = 20,
    page_vertical = 20,
    button = 10,
}

local GAP_PT = {
    small = 5,
    default = 10,
    section = 20,
    stack = 5,
    page = 10,
}

--- Filled by Type.attach() from the HIG scale (callout / title3). Stays in pt.
Theme.size = {
    status_icon = 16,
    page = 20,
}

local DIM_PT = {
    progress = 1,
    divider = 1,
    track = 2,
    button_height = 20,
    title_height = 50,
    handle = 30,
    icon = 20,
    status_height = 50,
    action_bar_height = 50,
    footer_height = 50,
    page_dot = 5,
    page_dot_gap = 4,
    page_underline = 2,
    status_icon = 16,
    check_box = 18,
    check_symbol = 14,
    check_fill_inset = 6,
    tab_indicator = 3,
    cover_width = 80,
    cover_height = 112,
    card_width = 100,
    hero_width = 300,
    toggle_width = 200,
    divider_width = 200,
    input_width = 240,
    slider_width = 240,
    progress_width = 120,
    scroll_min_height = 80,
    showcase_min_width = 120,
    showcase_hero_width = 160,
    showcase_cover_width = 72,
    showcase_cover_height = 100,
    slider_track_width = 623,
    slider_row_height = 50,
    slider_label_padding = 4,
    library_cell_min = 110,
    library_cell_limit_min = 60,
    library_cell_limit_max = 600,
}

--- Emphasized red on color screens; black on grayscale e-ink.
function Theme.accent()
    if Device:hasColorScreen() then
        return Blitbuffer.ColorRGB32(0xFF, 0x00, 0x00, 0xFF)
    end
    return Blitbuffer.COLOR_BLACK
end

--- Discrete display scale from DPI (1 / 1.5 / 2 / 3).
function Theme.screenScale()
    local dpi = Screen:getDPI() or 160
    if dpi < 200 then
        return 1
    elseif dpi < 280 then
        return 1.5
    elseif dpi < 400 then
        return 2
    end
    return 3
end

--- Design pt → integer device px (ceil so 1.5× never yields a fraction or 0).
function Theme.scale(pt)
    pt = pt or 0
    if pt == 0 then
        return 0
    end
    return math.ceil(pt * Theme.screenScale())
end

--- Face size for Font:getFace so glyphs render at Theme.scale(pt).
--- This is Font orig_size (pre-scaleBySize), not a layout dimension.
function Theme.devicePixels(pt)
    local target = Theme.scale(pt)
    local sample = Screen:scaleBySize(100)
    if not sample or sample <= 0 then
        return target
    end
    return target * 100 / sample
end

Theme.border = BORDER_PT
Theme.pad = PAD_PT
Theme.gap = GAP_PT
Theme.dim = DIM_PT

--- `pt(50)` → px. `Theme.pt.dim.status_height = 50` writes the token.
Theme.pt = setmetatable({
    border = BORDER_PT,
    pad = PAD_PT,
    gap = GAP_PT,
    dim = DIM_PT,
    size = Theme.size,
}, {
    __call = function(_, n)
        return Theme.scale(n)
    end,
})

--- Raw device pixels, snapped to an integer. `px(1)` is always 1px.
function Theme.px(n)
    n = n or 0
    if n == 0 then
        return 0
    end
    return math.floor(n + 0.5)
end

--- Device px → design pt (inverse of Theme.scale).
function Theme.unpt(px)
    px = px or 0
    if px == 0 then
        return 0
    end
    local scale = Theme.screenScale()
    if not scale or scale <= 0 then
        return px
    end
    return math.floor(px / scale + 0.5)
end

function Theme.getPt(group, key)
    local tokens = Theme.pt[group]
    if not tokens then
        return nil
    end
    return tokens[key]
end

function Theme.setPt(group, key, value)
    local tokens = Theme.pt[group]
    if not tokens then
        return
    end
    tokens[key] = value
end

--- HorizontalGroup/VerticalGroup:getSize() returns a bare {w,h} table.
--- GestureRange:match needs a Geom with :contains().
function Theme.asGeom(size)
    if not size then
        return Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    end
    if size.contains then
        return size
    end
    return Geom:new{
        x = math.floor((size.x or 0) + 0.5),
        y = math.floor((size.y or 0) + 0.5),
        w = math.floor((size.w or 0) + 0.5),
        h = math.floor((size.h or 0) + 0.5),
    }
end

Theme.font = {
    thin = fontPath("NotoSansSC-Thin.ttf"),
    extra_light = fontPath("NotoSansSC-ExtraLight.ttf"),
    light = fontPath("NotoSansSC-Light.ttf"),
    regular = fontPath("NotoSansSC-Regular.ttf"),
    medium = fontPath("NotoSansSC-Medium.ttf"),
    semibold = fontPath("NotoSansSC-SemiBold.ttf"),
    bold = fontPath("NotoSansSC-Bold.ttf"),
    extra_bold = fontPath("NotoSansSC-ExtraBold.ttf"),
    black = fontPath("NotoSansSC-Black.ttf"),
    symbols_extra_light = fontPath("MaterialSymbolsOutlined-ExtraLight.ttf"),
    symbols_light = fontPath("MaterialSymbolsOutlined-Light.ttf"),
    symbols = fontPath("MaterialSymbolsOutlined-Regular.ttf"),
    symbols_medium = fontPath("MaterialSymbolsOutlined-Medium.ttf"),
    symbols_semibold = fontPath("MaterialSymbolsOutlined-SemiBold.ttf"),
    symbols_bold = fontPath("MaterialSymbolsOutlined-Bold.ttf"),
    symbols_extra_bold = fontPath("MaterialSymbolsOutlined-Bold.ttf"),
    symbols_black = fontPath("MaterialSymbolsOutlined-Bold.ttf"),
}

local function registerBoldPair(regular, bold)
    regular = fontFileName(regular)
    bold = fontFileName(bold)
    if regular and bold and regular ~= bold then
        Font.bold_font_variant[regular] = bold
        Font.regular_font_variant[bold] = regular
    end
end

registerBoldPair(Theme.font.thin, Theme.font.regular)
registerBoldPair(Theme.font.extra_light, Theme.font.regular)
registerBoldPair(Theme.font.light, Theme.font.regular)
registerBoldPair(Theme.font.regular, Theme.font.bold)
registerBoldPair(Theme.font.medium, Theme.font.bold)
registerBoldPair(Theme.font.semibold, Theme.font.bold)
registerBoldPair(Theme.font.bold, Theme.font.extra_bold)
registerBoldPair(Theme.font.extra_bold, Theme.font.black)
if Theme.font.regular and Theme.font.black then
    local regular_name = fontFileName(Theme.font.regular)
    local black_name = fontFileName(Theme.font.black)
    if regular_name and black_name then
        Font.regular_font_variant[black_name] = regular_name
    end
end
registerBoldPair(Theme.font.symbols_extra_light, Theme.font.symbols)
registerBoldPair(Theme.font.symbols_light, Theme.font.symbols)
registerBoldPair(Theme.font.symbols, Theme.font.symbols_bold)
registerBoldPair(Theme.font.symbols_medium, Theme.font.symbols_bold)
registerBoldPair(Theme.font.symbols_semibold, Theme.font.symbols_bold)

--- Named icons → Material Symbols Outlined glyphs. Prefer these over SVG.
Theme.icon = {
    close = "\u{E5CD}",
    cancel = "\u{E5CD}",
    check = "\u{E668}",
    plus = "\u{E145}",
    home = "\u{E9B2}",
    info = "\u{E88E}",
    edit = "\u{F097}",
    exit = "\u{E9BA}",
    wifi = "\u{E63E}",
    wifi_off = "\u{E648}",
    frontlight = "\u{E518}",
    sun = "\u{E518}",
    moon = "\u{E51C}",
    ellipsis = "\u{E5D3}",
    sort = "\u{E164}",
    battery_1_bar = "\u{F09C}",
    battery_2_bar = "\u{F09D}",
    battery_3_bar = "\u{F09E}",
    battery_4_bar = "\u{F09F}",
    battery_5_bar = "\u{F0A0}",
    battery_full = "\u{E1A5}",
    battery_charging_20 = "\u{F0A2}",
    battery_charging_30 = "\u{F0A3}",
    battery_charging_50 = "\u{F0A4}",
    battery_charging_60 = "\u{F0A5}",
    battery_charging_80 = "\u{F0A6}",
    battery_charging_90 = "\u{F0A7}",
    battery_charging_full = "\u{E1A3}",
    battery = "\u{E1A5}",
    battery_charging = "\u{E1A3}",
    bookmark = "\u{E8E7}",
    triangle = "\u{E5C7}",
    ["appbar.menu"] = "\u{E5D2}",
    ["appbar.settings"] = "\u{E8B8}",
    ["appbar.search"] = "\u{EF7A}",
    ["appbar.tools"] = "\u{F8CD}",
    ["appbar.filebrowser"] = "\u{E2C7}",
    ["appbar.home"] = "\u{E9B2}",
    ["appbar.navigation"] = "\u{E8D4}",
    ["appbar.typeset"] = "\u{F097}",
    ["appbar.contrast"] = "\u{EB37}",
    ["appbar.crop"] = "\u{E3BE}",
    ["appbar.pageview"] = "\u{E8ED}",
    ["appbar.pagefit"] = "\u{EA10}",
    ["appbar.rotation"] = "\u{E41A}",
    ["appbar.textsize"] = "\u{E262}",
    ["appbar.pokeball"] = "\u{EF4A}",
    ["chevron.left"] = "\u{E5CB}",
    ["chevron.right"] = "\u{E5CC}",
    ["chevron.up"] = "\u{E316}",
    ["chevron.down"] = "\u{E313}",
    ["chevron.first"] = "\u{E5DC}",
    ["chevron.last"] = "\u{E5DD}",
    ["star.full"] = "\u{F09A}",
    ["star.empty"] = "\u{F0EC}",
    ["star.white"] = "\u{F0EC}",
    ["notice-info"] = "\u{E88E}",
    ["notice-warning"] = "\u{F083}",
    ["notice-question"] = "\u{E8FD}",
    ["book.opened"] = "\u{EA19}",
    ["align.left"] = "\u{E236}",
    ["align.center"] = "\u{E234}",
    ["align.right"] = "\u{E237}",
    ["align.justify"] = "\u{E235}",
    ["align.auto"] = "\u{E236}",
    ["column.one"] = "\u{E8EC}",
    ["column.two"] = "\u{E8F3}",
    ["column.three"] = "\u{E8F0}",
    ["move.up"] = "\u{F1E0}",
    ["move.down"] = "\u{F1E3}",
    ["back.top"] = "\u{F1E0}",
    ["back.top.rtl"] = "\u{F1E0}",
}

local function clampBatteryCapacity(capacity)
    if type(capacity) ~= "number" then
        return 0
    end
    if capacity < 0 then
        return 0
    end
    if capacity > 100 then
        return 100
    end
    return math.floor(capacity + 0.5)
end

--- Material battery glyph for the current charge level and plug state.
function Theme.batteryGlyph(is_charged, is_charging, capacity)
    local cap = clampBatteryCapacity(capacity)
    if is_charging and not is_charged then
        if cap >= 100 then
            return Theme.icon.battery_charging_full
        end
        if cap > 90 then
            return Theme.icon.battery_charging_90
        end
        if cap > 80 then
            return Theme.icon.battery_charging_80
        end
        if cap > 60 then
            return Theme.icon.battery_charging_60
        end
        if cap > 50 then
            return Theme.icon.battery_charging_50
        end
        if cap > 30 then
            return Theme.icon.battery_charging_30
        end
        return Theme.icon.battery_charging_20
    end
    if is_charged or cap >= 100 then
        return Theme.icon.battery_full
    end
    if cap > 80 then
        return Theme.icon.battery_5_bar
    end
    if cap > 60 then
        return Theme.icon.battery_4_bar
    end
    if cap > 40 then
        return Theme.icon.battery_3_bar
    end
    if cap > 20 then
        return Theme.icon.battery_2_bar
    end
    return Theme.icon.battery_1_bar
end

--- Battery percentage label in Noto Sans SC (not Material Symbols).
function Theme.batteryPercentText(capacity)
    if type(capacity) ~= "number" then
        return ""
    end
    return string.format("%d%%", clampBatteryCapacity(capacity))
end

--- Battery icon plus percent. Prefer separate glyph/percent widgets in UI.
function Theme.batteryText(is_charged, is_charging, capacity)
    local glyph = Theme.batteryGlyph(is_charged, is_charging, capacity)
    local percent = Theme.batteryPercentText(capacity)
    if percent == "" then
        return glyph
    end
    return glyph .. percent
end

function Theme.iconGlyph(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if Theme.icon[name] then
        return Theme.icon[name]
    end
    if not name:find("[%a]") then
        return name
    end
    return nil
end

local Type = require("ui/uikit/components/type")
Type.attach(Theme)

--- @param role_or_size string|number HIG role or unscaled px
--- @param opts table|nil { emphasized, weight, content_size }
function Theme.symbolFace(role_or_size, opts)
    return Type.symbolFace(role_or_size, opts)
end

--- Role → { weight_key, unscaled_px }. Rebuilt from Type; override to restyle.
Theme.face_spec = Type.snapshotFaceSpec()

--- @param role string HIG style (body, title1, …) or Swiss alias (h1, caption, …)
--- @param opts table|nil { emphasized, weight, content_size, size, leading }
function Theme.face(role, opts)
    return Type.face(role, opts)
end

--- Load a plugin or system font without passing a nil face to TextWidget.
--- @param font string|nil full path or basename
--- @param size number|nil
--- @param fallback string|nil Font.fontmap name (default cfont)
function Theme.getFace(font, size, fallback)
    return Type.getFace(font, size, fallback)
end

function Theme.withArrow(text)
    if type(text) ~= "string" or text == "" then
        return Theme.arrow
    end
    if text:find(Theme.arrow, 1, true) then
        return text
    end
    return text .. " " .. Theme.arrow
end

--- Defaults for a Swiss FrameContainer (callers pass this into FrameContainer:new).
function Theme.frameProps(extra)
    local pt = Theme.pt
    local props = {
        radius = Theme.radius,
        bordersize = pt(Theme.border.default),
        padding = pt(Theme.pad.card),
        margin = 0,
        background = Theme.color.white,
        color = Theme.color.black,
    }
    if extra then
        for key, value in pairs(extra) do
            props[key] = value
        end
    end
    return props
end

return Theme

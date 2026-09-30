--[[--
Apple HIG typography for home.koplugin ui/uikit.

Face files are Noto Sans SC / Material Symbols Outlined (not SF). Metrics follow the
iOS / iPadOS Dynamic Type tables in Human Interface Guidelines > Typography:
https://developer.apple.com/design/human-interface-guidelines/typography

1pt × Theme.screenScale() (1 / 1.5 / 2 / 3 from DPI). Font:getFace still
applies scaleBySize; Theme.devicePixels undoes that so glyphs match pt × scale.
Default content size is Apple's Large. Type.attach(Theme) binds faces.
]]

local Font = require("ui/font")
local logger = require("logger")
local util = require("util")

local Type = {}

Type.platform = "ios"
Type.content_size = "large"
Type.bold_text = false
Type.minimum_size = 11

Type.CONTENT_SIZES = {
    "xSmall", "small", "medium", "large", "xLarge", "xxLarge", "xxxLarge",
    "AX1", "AX2", "AX3", "AX4", "AX5",
}

Type.STYLE_ORDER = {
    "extra_large_title",
    "extra_large_title_2",
    "large_title",
    "title1",
    "title2",
    "title3",
    "headline",
    "body",
    "callout",
    "subhead",
    "footnote",
    "caption1",
    "caption2",
}

--- Noto Sans SC files, thin → black.
Type.WEIGHT_ORDER = {
    "thin",
    "extra_light",
    "light",
    "regular",
    "medium",
    "semibold",
    "bold",
    "extra_bold",
    "black",
}

Type.WEIGHT_DISPLAY_NAME = {
    thin = "Thin",
    extra_light = "Extra Light",
    light = "Light",
    regular = "Regular",
    medium = "Medium",
    semibold = "SemiBold",
    bold = "Bold",
    extra_bold = "Extra Bold",
    black = "Black",
}

Type.DISPLAY_NAME = {
    extra_large_title = "Extra Large Title",
    extra_large_title_2 = "Extra Large Title 2",
    large_title = "Large Title",
    title1 = "Title 1",
    title2 = "Title 2",
    title3 = "Title 3",
    headline = "Headline",
    body = "Body",
    callout = "Callout",
    subhead = "Subhead",
    footnote = "Footnote",
    caption1 = "Caption 1",
    caption2 = "Caption 2",
}

--- Swiss / kit roles → HIG style. Titles use the emphasized weight.
Type.alias = {
    hero = { style = "large_title", emphasized = true },
    h1 = { style = "title1", emphasized = true },
    h2 = { style = "title2", emphasized = true },
    h3 = { style = "title3", emphasized = true },
    title = { style = "title2", emphasized = true },
    body = { style = "body" },
    caption = { style = "caption1" },
    label = { style = "footnote", weight = "medium" },
    button = { style = "headline" },
    page = { style = "title3", emphasized = true },
}

local R, SB, B, K = "regular", "semibold", "bold", "black"

local function row(weight, size, leading, emphasized)
    return {
        weight = weight,
        size = size,
        leading = leading,
        emphasized = emphasized,
    }
end

--- iOS 17+ editorial styles at Large. Other sizes scale with Large Title.
local EXTRA_LARGE_AT_LARGE = {
    extra_large_title = row(B, 36, 41, K),
    extra_large_title_2 = row(B, 28, 34, K),
}

-- { weight, size, leading, emphasized } per HIG iOS / iPadOS tables.
Type.ios = {
    xSmall = {
        large_title = row(R, 31, 38, B),
        title1 = row(R, 25, 31, B),
        title2 = row(R, 19, 24, B),
        title3 = row(R, 17, 22, SB),
        headline = row(SB, 14, 19, SB),
        body = row(R, 14, 19, SB),
        callout = row(R, 13, 18, SB),
        subhead = row(R, 12, 16, SB),
        footnote = row(R, 12, 16, SB),
        caption1 = row(R, 11, 13, SB),
        caption2 = row(R, 11, 13, SB),
    },
    small = {
        large_title = row(R, 32, 39, B),
        title1 = row(R, 26, 32, B),
        title2 = row(R, 20, 25, B),
        title3 = row(R, 18, 23, SB),
        headline = row(SB, 15, 20, SB),
        body = row(R, 15, 20, SB),
        callout = row(R, 14, 19, SB),
        subhead = row(R, 13, 18, SB),
        footnote = row(R, 12, 16, SB),
        caption1 = row(R, 11, 13, SB),
        caption2 = row(R, 11, 13, SB),
    },
    medium = {
        large_title = row(R, 33, 40, B),
        title1 = row(R, 27, 33, B),
        title2 = row(R, 21, 26, B),
        title3 = row(R, 19, 24, SB),
        headline = row(SB, 16, 21, SB),
        body = row(R, 16, 21, SB),
        callout = row(R, 15, 20, SB),
        subhead = row(R, 14, 19, SB),
        footnote = row(R, 12, 16, SB),
        caption1 = row(R, 11, 13, SB),
        caption2 = row(R, 11, 13, SB),
    },
    large = {
        large_title = row(R, 34, 41, B),
        title1 = row(R, 28, 34, B),
        title2 = row(R, 22, 28, B),
        title3 = row(R, 20, 25, SB),
        headline = row(SB, 17, 22, SB),
        body = row(R, 17, 22, SB),
        callout = row(R, 16, 21, SB),
        subhead = row(R, 15, 20, SB),
        footnote = row(R, 13, 18, SB),
        caption1 = row(R, 12, 16, SB),
        caption2 = row(R, 11, 13, SB),
    },
    xLarge = {
        large_title = row(R, 36, 43, B),
        title1 = row(R, 30, 37, B),
        title2 = row(R, 24, 30, B),
        title3 = row(R, 22, 28, SB),
        headline = row(SB, 19, 24, SB),
        body = row(R, 19, 24, SB),
        callout = row(R, 18, 23, SB),
        subhead = row(R, 17, 22, SB),
        footnote = row(R, 15, 20, SB),
        caption1 = row(R, 14, 19, SB),
        caption2 = row(R, 13, 18, SB),
    },
    xxLarge = {
        large_title = row(R, 38, 46, B),
        title1 = row(R, 32, 39, B),
        title2 = row(R, 26, 32, B),
        title3 = row(R, 24, 30, SB),
        headline = row(SB, 21, 26, SB),
        body = row(R, 21, 26, SB),
        callout = row(R, 20, 25, SB),
        subhead = row(R, 19, 24, SB),
        footnote = row(R, 17, 22, SB),
        caption1 = row(R, 16, 21, SB),
        caption2 = row(R, 15, 20, SB),
    },
    xxxLarge = {
        large_title = row(R, 40, 48, B),
        title1 = row(R, 34, 41, B),
        title2 = row(R, 28, 34, B),
        title3 = row(R, 26, 32, SB),
        headline = row(SB, 23, 29, SB),
        body = row(R, 23, 29, SB),
        callout = row(R, 22, 28, SB),
        subhead = row(R, 21, 28, SB),
        footnote = row(R, 19, 24, SB),
        caption1 = row(R, 18, 23, SB),
        caption2 = row(R, 17, 22, SB),
    },
    AX1 = {
        large_title = row(R, 44, 52, B),
        title1 = row(R, 38, 46, B),
        title2 = row(R, 34, 41, B),
        title3 = row(R, 31, 38, SB),
        headline = row(SB, 28, 34, SB),
        body = row(R, 28, 34, SB),
        callout = row(R, 26, 32, SB),
        subhead = row(R, 25, 31, SB),
        footnote = row(R, 23, 29, SB),
        caption1 = row(R, 22, 28, SB),
        caption2 = row(R, 20, 25, SB),
    },
    AX2 = {
        large_title = row(R, 48, 57, B),
        title1 = row(R, 43, 51, B),
        title2 = row(R, 39, 47, B),
        title3 = row(R, 37, 44, SB),
        headline = row(SB, 33, 40, SB),
        body = row(R, 33, 40, SB),
        callout = row(R, 32, 39, SB),
        subhead = row(R, 30, 37, SB),
        footnote = row(R, 27, 33, SB),
        caption1 = row(R, 26, 32, SB),
        caption2 = row(R, 24, 30, SB),
    },
    AX3 = {
        large_title = row(R, 52, 61, B),
        title1 = row(R, 48, 57, B),
        title2 = row(R, 44, 52, B),
        title3 = row(R, 43, 51, SB),
        headline = row(SB, 40, 48, SB),
        body = row(R, 40, 48, SB),
        callout = row(R, 38, 46, SB),
        subhead = row(R, 36, 43, SB),
        footnote = row(R, 33, 40, SB),
        caption1 = row(R, 32, 39, SB),
        caption2 = row(R, 29, 35, SB),
    },
    AX4 = {
        large_title = row(R, 56, 66, B),
        title1 = row(R, 53, 62, B),
        title2 = row(R, 50, 59, B),
        title3 = row(R, 49, 58, SB),
        headline = row(SB, 47, 56, SB),
        body = row(R, 47, 56, SB),
        callout = row(R, 44, 52, SB),
        subhead = row(R, 42, 50, SB),
        footnote = row(R, 38, 46, SB),
        caption1 = row(R, 37, 44, SB),
        caption2 = row(R, 34, 41, SB),
    },
    AX5 = {
        large_title = row(R, 60, 70, B),
        title1 = row(R, 58, 68, B),
        title2 = row(R, 56, 66, B),
        title3 = row(R, 55, 65, SB),
        headline = row(SB, 53, 62, SB),
        body = row(R, 53, 62, SB),
        callout = row(R, 51, 60, SB),
        subhead = row(R, 49, 58, SB),
        footnote = row(R, 44, 52, SB),
        caption1 = row(R, 43, 51, SB),
        caption2 = row(R, 40, 48, SB),
    },
}

--- SF Pro tracking (1/1000 em) at integer point sizes. Noto is not SF; stored
--- for mockups. KOReader text widgets do not apply tracking.
Type.SF_PRO_TRACKING_EM = {
    [6] = 41, [7] = 34, [8] = 26, [9] = 19, [10] = 12, [11] = 6, [12] = 0,
    [13] = -6, [14] = -11, [15] = -16, [16] = -20, [17] = -26, [18] = -25,
    [19] = -24, [20] = -23, [21] = -18, [22] = -12, [23] = -4, [24] = 3,
    [25] = 6, [26] = 8, [27] = 11, [28] = 14, [29] = 14, [30] = 14, [31] = 13,
    [32] = 13, [33] = 12, [34] = 12, [35] = 11, [36] = 10, [37] = 10, [38] = 10,
    [39] = 10, [40] = 10, [41] = 9, [42] = 9, [43] = 9, [44] = 8, [45] = 8,
    [46] = 8, [47] = 8, [48] = 8, [49] = 7, [50] = 7, [51] = 7, [52] = 6,
    [53] = 6, [54] = 6, [56] = 6, [58] = 5, [60] = 4, [62] = 4, [64] = 4,
    [66] = 3, [68] = 2, [70] = 2, [72] = 2, [76] = 1, [80] = 0, [84] = 0,
    [88] = 0, [92] = 0, [96] = 0,
}

local SIZE_KEY = {
    xsmall = "xSmall",
    ["x-small"] = "xSmall",
    small = "small",
    medium = "medium",
    large = "large",
    xlarge = "xLarge",
    ["x-large"] = "xLarge",
    xxlarge = "xxLarge",
    ["xx-large"] = "xxLarge",
    xxxlarge = "xxxLarge",
    ["xxx-large"] = "xxxLarge",
    ax1 = "AX1",
    ax2 = "AX2",
    ax3 = "AX3",
    ax4 = "AX4",
    ax5 = "AX5",
    accessibility1 = "AX1",
    accessibility2 = "AX2",
    accessibility3 = "AX3",
    accessibility4 = "AX4",
    accessibility5 = "AX5",
}

local STYLE_KEY = {
    extraLargeTitle = "extra_large_title",
    extra_large_title = "extra_large_title",
    ["extra large title"] = "extra_large_title",
    extraLargeTitle2 = "extra_large_title_2",
    extra_large_title_2 = "extra_large_title_2",
    ["extra large title 2"] = "extra_large_title_2",
    largeTitle = "large_title",
    large_title = "large_title",
    ["large title"] = "large_title",
    title1 = "title1",
    title_1 = "title1",
    ["title 1"] = "title1",
    title2 = "title2",
    title_2 = "title2",
    ["title 2"] = "title2",
    title3 = "title3",
    title_3 = "title3",
    ["title 3"] = "title3",
    headline = "headline",
    body = "body",
    callout = "callout",
    subhead = "subhead",
    subheadline = "subhead",
    footnote = "footnote",
    caption = "caption1",
    caption1 = "caption1",
    caption_1 = "caption1",
    ["caption 1"] = "caption1",
    caption2 = "caption2",
    caption_2 = "caption2",
    ["caption 2"] = "caption2",
}

local WEIGHT_KEY = {
    ultralight = "thin",
    ultra_light = "thin",
    thin = "thin",
    extraLight = "extra_light",
    extra_light = "extra_light",
    light = "light",
    regular = "regular",
    medium = "medium",
    semibold = "semibold",
    semi_bold = "semibold",
    bold = "bold",
    heavy = "extra_bold",
    extraBold = "extra_bold",
    extra_bold = "extra_bold",
    black = "black",
}

local WEIGHT_FALLBACK = {
    thin = { "thin", "extra_light", "light", "regular" },
    extra_light = { "extra_light", "light", "regular" },
    light = { "light", "regular" },
    regular = { "regular", "medium" },
    medium = { "medium", "semibold", "regular" },
    semibold = { "semibold", "bold", "medium" },
    bold = { "bold", "extra_bold", "semibold", "black" },
    extra_bold = { "extra_bold", "black", "bold" },
    black = { "black", "extra_bold", "bold" },
}

local SYMBOL_WEIGHT = {
    thin = "symbols_extra_light",
    extra_light = "symbols_extra_light",
    light = "symbols_light",
    regular = "symbols",
    medium = "symbols_medium",
    semibold = "symbols_semibold",
    bold = "symbols_bold",
    extra_bold = "symbols_extra_bold",
    black = "symbols_black",
}

local TITLE_STYLES = {
    extra_large_title = true,
    extra_large_title_2 = true,
    large_title = true,
    title1 = true,
    title2 = true,
    title3 = true,
    headline = true,
}

function Type.normalizeContentSize(name)
    if name == nil or name == "" then
        return Type.content_size
    end
    if Type.ios[name] then
        return name
    end
    return SIZE_KEY[tostring(name):lower()] or Type.content_size
end

function Type.normalizeStyle(name)
    if type(name) ~= "string" or name == "" then
        return "body"
    end
    if Type.alias[name] then
        return Type.alias[name].style
    end
    if STYLE_KEY[name] then
        return STYLE_KEY[name]
    end
    return STYLE_KEY[name:lower()] or "body"
end

function Type.normalizeWeight(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return WEIGHT_KEY[name] or WEIGHT_KEY[name:lower()]
end

function Type.displayName(role)
    local style = Type.normalizeStyle(role)
    return Type.DISPLAY_NAME[style] or role
end

function Type.isAccessibilityCategory(size)
    size = Type.normalizeContentSize(size or Type.content_size)
    return size:sub(1, 2) == "AX"
end

function Type.setContentSize(name)
    Type.content_size = Type.normalizeContentSize(name)
    return Type.content_size
end

function Type.setBoldText(on)
    Type.bold_text = on and true or false
    return Type.bold_text
end

local function copyRow(src)
    return {
        weight = src.weight,
        size = src.size,
        leading = src.leading,
        emphasized = src.emphasized,
    }
end

local function extraLargeRow(style, category)
    local base = EXTRA_LARGE_AT_LARGE[style]
    local large = Type.ios.large.large_title
    local current = category and category.large_title
    if not base or not current then
        return base and copyRow(base) or nil
    end
    local size_ratio = current.size / large.size
    local lead_ratio = current.leading / large.leading
    return {
        weight = base.weight,
        size = math.floor(base.size * size_ratio + 0.5),
        leading = math.floor(base.leading * lead_ratio + 0.5),
        emphasized = base.emphasized,
    }
end

local function categoryFor(size)
    return Type.ios[Type.normalizeContentSize(size)] or Type.ios.large
end

--- Resolve a role to { style, weight, size, leading, emphasized }.
function Type.spec(role, opts)
    opts = opts or {}
    local alias = Type.alias[role]
    local style
    local emphasized = opts.emphasized
    local weight_override = Type.normalizeWeight(opts.weight)
    if alias then
        style = alias.style
        if emphasized == nil then
            emphasized = alias.emphasized
        end
        if not weight_override then
            weight_override = Type.normalizeWeight(alias.weight)
        end
    else
        style = Type.normalizeStyle(role)
    end
    if Type.bold_text and emphasized == nil then
        emphasized = true
    end

    local category = categoryFor(opts.content_size or Type.content_size)
    local base = category[style]
    if not base then
        base = extraLargeRow(style, category)
    end
    if not base then
        base = category.body
        style = "body"
    end

    local weight = weight_override or base.weight
    if emphasized then
        weight = base.emphasized or weight
    end

    local size = opts.size or base.size
    if size < Type.minimum_size then
        size = Type.minimum_size
    end
    local leading = opts.leading or base.leading
    if leading < size then
        leading = size
    end

    return {
        style = style,
        weight = weight,
        size = size,
        leading = leading,
        emphasized = emphasized and true or false,
        default_weight = base.weight,
        emphasized_weight = base.emphasized,
    }
end

function Type.size(role, opts)
    return Type.spec(role, opts).size
end

function Type.leading(role, opts)
    local leading = Type.spec(role, opts).leading
    local theme = Type.theme
    if theme and theme.scale then
        return theme.scale(leading)
    end
    return leading
end

--- TextBoxWidget line_height is extra em above 1. Body 17/22 → ~0.29.
function Type.lineHeightEm(role, opts)
    local spec = Type.spec(role, opts)
    if spec.size <= 0 then
        return 0.3
    end
    return (spec.leading / spec.size) - 1
end

function Type.weight(role, opts)
    return Type.spec(role, opts).weight
end

function Type.isTitleStyle(role)
    local style = Type.alias[role] and Type.alias[role].style or Type.normalizeStyle(role)
    return TITLE_STYLES[style] == true
        or role == "hero" or role == "h1" or role == "h2"
        or role == "h3" or role == "title" or role == "button"
end

function Type.isMultilineStyle(role)
    local style = Type.alias[role] and Type.alias[role].style or Type.normalizeStyle(role)
    return style == "body" or style == "callout" or style == "subhead"
        or style == "footnote" or style == "caption1" or style == "caption2"
end

function Type.trackingEm(size)
    size = math.floor((size or 17) + 0.5)
    local table_ = Type.SF_PRO_TRACKING_EM
    if table_[size] then
        return table_[size]
    end
    local closest, delta
    for pt, em in pairs(table_) do
        local d = math.abs(pt - size)
        if not delta or d < delta then
            closest, delta = em, d
        end
    end
    return closest or 0
end

local function fontPath(theme, weight, symbols)
    local fonts = theme and theme.font
    if not fonts then
        return nil
    end
    local keys = WEIGHT_FALLBACK[weight] or { weight, "regular" }
    if symbols then
        for _, key in ipairs(keys) do
            local path = fonts[SYMBOL_WEIGHT[key] or "symbols"]
            if path then
                return path
            end
        end
        return fonts.symbols or fonts.symbols_bold
    end
    for _, key in ipairs(keys) do
        if fonts[key] then
            return fonts[key]
        end
    end
    return fonts.regular or fonts.bold
end

-- Prefer the file basename. Full plugin paths only work on KOReader with
-- Font:getFace() path support (#15873); older Kindle builds look up
-- ./fonts/<name> and then FontList. Theme registers plugin TTFs there.
function Type.getFace(path, pixels, fallback_name)
    fallback_name = fallback_name or "cfont"
    local name = path
    if type(path) == "string" then
        local _, base = util.splitFilePathName(path)
        if base and base ~= "" then
            name = base
        end
    elseif path then
        name = path
    else
        name = nil
    end
    local face = name and Font:getFace(name, pixels) or nil
    if not face and fallback_name and fallback_name ~= name then
        logger.warn("home type: failed to load font", name or path, "→", fallback_name)
        face = Font:getFace(fallback_name, pixels)
    end
    return face
end

local function getFace(path, pixels, fallback_name)
    return Type.getFace(path, pixels, fallback_name)
end

function Type.face(role, opts)
    local theme = Type.theme
    local spec = Type.spec(role, opts)
    local pixels = theme and theme.devicePixels(spec.size) or spec.size
    local path = fontPath(theme, spec.weight, false)
    local fallback = (spec.weight == "bold" or spec.weight == "black"
        or spec.weight == "extra_bold" or spec.weight == "semibold")
        and "tfont" or "cfont"
    return getFace(path, pixels, fallback)
end

function Type.symbolFace(role_or_size, opts)
    opts = opts or {}
    local theme = Type.theme
    local size, weight
    if type(role_or_size) == "string" then
        local spec = Type.spec(role_or_size, opts)
        size = spec.size
        weight = spec.weight
    else
        size = role_or_size or Type.size("body")
        weight = Type.normalizeWeight(opts.weight) or "regular"
    end
    local pixels = theme and theme.devicePixels(size) or size
    local path = fontPath(theme, weight, true)
    return getFace(path, pixels, "cfont")
end

function Type.snapshotFaceSpec()
    local spec = {}
    for role, _ in pairs(Type.alias) do
        local row_spec = Type.spec(role)
        spec[role] = { row_spec.weight, row_spec.size }
    end
    return spec
end

function Type.attach(theme)
    Type.theme = theme
    theme.type = Type
    theme.face_spec = Type.snapshotFaceSpec()
    theme.size = theme.size or {}
    theme.size.status_icon = Type.size("callout")
    theme.size.page = Type.size("page")
    if theme.dim then
        theme.dim.status_icon = Type.size("callout")
    end
end

return Type

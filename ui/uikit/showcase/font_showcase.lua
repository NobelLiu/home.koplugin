--[[--
Noto Sans SC specimen: HIG sizes small → large, then weights thin → black.
]]

local Divider = require("ui/uikit/components/layout/divider")
local Label = require("ui/uikit/components/controls/label")
local ShowcasePage = require("ui/uikit/showcase/page")
local Spacer = require("ui/uikit/components/layout/spacer")
local Theme = require("ui/uikit/components/theme")
local VerticalGroup = require("ui/widget/verticalgroup")
local pt = Theme.pt
local _ = require("gettext")

local FontShowcase = {}

local SAMPLE = "Noto Sans SC 瑞士国际 ABC"

local function metaLine(spec)
    local weight = Theme.type.WEIGHT_DISPLAY_NAME[spec.weight] or spec.weight
    return string.format("%d / %d · %s", spec.size, spec.leading, weight)
end

local function sectionHeader(text, width)
    local col = VerticalGroup:new{ align = "left" }
    table.insert(col, Label:new{
        text = text,
        role = "label",
        width = width,
    })
    table.insert(col, Spacer.vertical(pt(Theme.gap.small)))
    table.insert(col, Divider:new{
        width = width,
        color = Theme.color.black,
    })
    return col
end

local function specimen(role, opts, width)
    opts = opts or {}
    local spec = Theme.type.spec(role, opts)
    local name = opts.weight
        and (Theme.type.WEIGHT_DISPLAY_NAME[spec.weight] or spec.weight)
        or Theme.type.displayName(role)
    local col = VerticalGroup:new{ align = "left" }
    table.insert(col, Label:new{
        text = name,
        role = "label",
        width = width,
    })
    table.insert(col, Spacer.vertical(pt(Theme.gap.small)))
    table.insert(col, Label:new{
        text = SAMPLE,
        role = role,
        weight = opts.weight,
        width = width,
        max_width = width,
    })
    table.insert(col, Spacer.vertical(pt(Theme.gap.small)))
    table.insert(col, Label:new{
        text = metaLine(spec),
        role = "caption2",
        color = Theme.color.muted,
        width = width,
    })
    return col
end

local function buildContent(width)
    local col = VerticalGroup:new{ align = "left" }
    local gap = pt(Theme.gap.section)

    table.insert(col, sectionHeader(_("Size"), width))
    table.insert(col, Spacer.vertical(pt(Theme.gap.default)))
    local styles = Theme.type.STYLE_ORDER
    for i = #styles, 1, -1 do
        if i < #styles then
            table.insert(col, Spacer.vertical(gap))
        end
        table.insert(col, specimen(styles[i], nil, width))
    end

    table.insert(col, Spacer.vertical(gap))
    table.insert(col, sectionHeader(_("Weight"), width))
    table.insert(col, Spacer.vertical(pt(Theme.gap.default)))
    local weights = Theme.type.WEIGHT_ORDER
    for i, weight in ipairs(weights) do
        if i > 1 then
            table.insert(col, Spacer.vertical(gap))
        end
        table.insert(col, specimen("title3", { weight = weight }, width))
    end
    return col
end

function FontShowcase.show()
    ShowcasePage.show{
        name = "home_font_showcase",
        title = _("Font"),
        build_content = buildContent,
    }
end

return FontShowcase

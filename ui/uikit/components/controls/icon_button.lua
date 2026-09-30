--[[--
Icon tap target matching SwiftUI ActionBar IconButton:
horizontal padding, full bar height, typographic icon at action-bar size.
]]

local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local Icon = require("ui/uikit/components/icon")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local TapCell = require("ui/common/tap_cell")
local TextWidget = require("ui/widget/textwidget")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local ALIGN_CONTAINERS = {
    left = LeftContainer,
    center = CenterContainer,
    right = RightContainer,
}

local IconButton = WidgetContainer:extend{
    icon = "close",
    enabled = true,
    callback = nil,
    width = nil,
    height = nil,
    icon_size = nil,
    icon_role = nil,
    icon_weight = nil,
    icon_emphasized = nil,
    padding_horizontal = nil,
    alignment = "center",
}

local function iconTypeOpts(opts)
    return {
        weight = opts.icon_weight,
        emphasized = opts.icon_emphasized,
    }
end

local function iconSizePt(opts)
    if opts.icon_size then
        return opts.icon_size
    end
    if opts.icon_role then
        return Theme.type.size(opts.icon_role, iconTypeOpts(opts))
    end
    return Theme.dim.icon
end

local function iconFace(opts)
    local type_opts = iconTypeOpts(opts)
    if opts.icon_role then
        return Theme.symbolFace(opts.icon_role, type_opts)
    end
    return Theme.symbolFace(iconSizePt(opts), type_opts)
end

function IconButton.naturalWidth(opts)
    opts = opts or {}
    local pad_h = opts.padding_horizontal
    if pad_h == nil then
        pad_h = pt(Theme.pad.page_horizontal)
    end
    local icon_pt = iconSizePt(opts)
    local glyph = Theme.iconGlyph(opts.icon)
    if glyph then
        local probe = TextWidget:new{
            text = glyph,
            face = iconFace(opts),
            bold = false,
            padding = 0,
        }
        local w = probe:getSize().w + 2 * pad_h
        probe:free()
        return math.ceil(w)
    end
    return math.ceil(pt(icon_pt) + 2 * pad_h)
end

function IconButton:init()
    local pad_h = self.padding_horizontal
    if pad_h == nil then
        pad_h = pt(Theme.pad.page_horizontal)
    end
    local bar_h = self.height or pt(Theme.dim.action_bar_height)
    local icon_opts = {
        icon = self.icon,
        icon_size = self.icon_size,
        icon_role = self.icon_role,
        icon_weight = self.icon_weight,
        icon_emphasized = self.icon_emphasized,
        padding_horizontal = pad_h,
    }
    local icon_pt = iconSizePt(icon_opts)

    local btn_w = self.width
    if not btn_w then
        btn_w = IconButton.naturalWidth(icon_opts)
    end

    local align = self.alignment or "center"
    local AlignContainer = ALIGN_CONTAINERS[align] or CenterContainer
    self[1] = TapCell:new{
        width = btn_w,
        height = bar_h,
        enabled = self.enabled,
        callback = self.callback,
        content = AlignContainer:new{
            dimen = Geom:new{ w = btn_w, h = bar_h },
            Icon:new{
                icon = self.icon,
                role = self.icon_role,
                weight = self.icon_weight,
                emphasized = self.icon_emphasized,
                width = pt(icon_pt),
                height = pt(icon_pt),
                dim = not self.enabled,
            },
        },
    }
end

return IconButton

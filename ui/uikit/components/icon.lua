--[[--
Typographic icon. Uses Material Symbols when a glyph exists.
]]

local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local TextWidget = require("ui/widget/textwidget")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Icon = WidgetContainer:extend{
    icon = "appbar.menu",
    width = nil,
    height = nil,
    dim = false,
    role = nil,
    weight = nil,
    emphasized = nil,
}

function Icon:init()
    local type_opts = {
        weight = self.weight,
        emphasized = self.emphasized,
    }
    local face
    local side
    if self.role then
        local spec = Theme.type.spec(self.role, type_opts)
        face = Theme.symbolFace(self.role, type_opts)
        side = math.floor((self.width or self.height or pt(spec.size)) + 0.5)
    else
        side = math.floor((self.width or self.height or pt(Theme.dim.icon)) + 0.5)
        face = Theme.symbolFace(math.floor(side * 0.78 + 0.5), type_opts)
    end
    local glyph = Theme.iconGlyph(self.icon)
    local inner
    if glyph then
        inner = TextWidget:new{
            text = glyph,
            face = face,
            bold = false,
            fgcolor = self.dim and Theme.color.muted or Theme.color.black,
            padding = 0,
        }
    else
        local IconWidget = require("ui/widget/iconwidget")
        inner = IconWidget:new{
            icon = self.icon,
            width = side,
            height = side,
            alpha = true,
            dim = self.dim,
        }
    end
    self[1] = CenterContainer:new{
        dimen = Geom:new{ w = side, h = side },
        inner,
    }
end

return Icon

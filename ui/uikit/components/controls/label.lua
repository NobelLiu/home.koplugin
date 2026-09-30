--[[--
Typographic roles from Apple HIG (Theme.face). Eyebrow (label) is uppercase.
Always left-aligned. Weight lives in the face file — do not synth-bold titles.
]]

local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local Theme = require("ui/uikit/components/theme")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local Label = WidgetContainer:extend{
    text = "",
    role = "body",
    width = nil,
    max_width = nil,
    -- When set, single-line labels use this as the HIG line box (px) and
    -- optically center the glyphs in it (Noto CJK metrics sit low in the
    -- FreeType face_height box).
    height = nil,
    bold = nil,
    emphasized = nil,
    weight = nil,
    color = nil,
    multiline = nil,
}

-- Half of a typical cap-height (~0.73em). Also near Noto's CJK typo-em center.
local OPTICAL_CENTER_EM = 0.37

function Label:init()
    local role = self.role or "body"
    local text = self.text or ""
    if role == "label" then
        text = text:upper()
    end
    local emphasized = self.emphasized
    if emphasized == nil and self.bold == true then
        emphasized = true
    end
    local type_opts = {
        emphasized = emphasized,
        weight = self.weight,
    }
    if self.size then
        type_opts.size = self.size
    end
    local face = Theme.face(role, type_opts)
    local color = self.color or Theme.color.black
    local multiline = self.multiline
    if multiline == nil then
        multiline = self.width ~= nil and Theme.type.isMultilineStyle(role)
    end
    if multiline and self.width then
        self[1] = TextBoxWidget:new{
            text = text,
            face = face,
            bold = false,
            fgcolor = color,
            width = self.width,
            alignment = "left",
            line_height = Theme.type.lineHeightEm(role, type_opts),
        }
    else
        local widget = TextWidget:new{
            text = text,
            face = face,
            bold = false,
            fgcolor = color,
            max_width = self.max_width or self.width,
            padding = 0,
        }
        local line_h = self.height
        if line_h then
            -- Place the optical center (mid-cap / mid-CJK em) on the line-box
            -- midline so the title lines up with centered icon buttons.
            widget:updateSize()
            widget.forced_height = line_h
            widget.forced_baseline = math.floor(
                line_h / 2 + Theme.scale(Theme.type.spec(role, type_opts).size) * OPTICAL_CENTER_EM + 0.5)
        end
        self[1] = widget
    end
end

return Label

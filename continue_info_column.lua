--[[--
continue_info_column.lua — Continue right-hand info column (title / author /
description).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local DebugOverlay = require("debug_overlay")
local Layout = require("layout")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local ContinueInfoColumn = {}

local TITLE_MAX_LINES = 2

--- @return table Info column widget
function ContinueInfoColumn.build(meta, metrics)
    local text_w = metrics.info_text_w
    local item_gap = metrics.item_gap
    local info_pad = metrics.info_pad
    local col_h = metrics.cover_h

    local title_face = Layout.titleFace()
    local body_face = Layout.bodyFace()
    local author_face = Layout.bodyItalicFace()
    local title_line_h = Layout.lineHeight(title_face)
    local title_h = title_line_h * TITLE_MAX_LINES

    local items = VerticalGroup:new{ align = "left" }

    items[#items + 1] = TextWidget:new{
        text = _("Continue"),
        face = Layout.sectionFace(),
        bold = true,
        fgcolor = Blitbuffer.COLOR_BLACK,
    }
    items[#items + 1] = VerticalSpan:new{ width = item_gap }
    items[#items + 1] = TextBoxWidget:new{
        text = BD.auto(meta.title),
        face = title_face,
        width = text_w,
        height = title_h,
        bold = true,
        height_adjust = true,
        height_overflow_show_ellipsis = true,
    }

    if meta.authors and meta.authors ~= "" then
        items[#items + 1] = VerticalSpan:new{ width = item_gap }
        items[#items + 1] = TextBoxWidget:new{
            text = BD.auto(meta.authors),
            face = author_face,
            width = text_w,
            height = Layout.lineHeight(author_face),
            fgcolor = Layout.COLOR_MUTED,
            height_overflow_show_ellipsis = true,
        }
    end

    items:resetLayout()
    local used_h = items:getSize().h
    local desc_h = col_h - used_h - item_gap
    if desc_h > Layout.lineHeight(body_face) and meta.description and meta.description ~= "" then
        items[#items + 1] = VerticalSpan:new{ width = item_gap }
        items[#items + 1] = TextBoxWidget:new{
            text = BD.auto(meta.description),
            face = body_face,
            width = text_w,
            height = desc_h,
            fgcolor = Layout.COLOR_MUTED,
            height_overflow_show_ellipsis = true,
        }
    end

    items:resetLayout()

    local col = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = info_pad,
        padding_right = info_pad,
        dimen = Geom:new{ w = metrics.info_w, h = col_h },
        TopContainer:new{
            dimen = Geom:new{ w = text_w, h = col_h },
            items,
        },
    }

    return DebugOverlay.wrap("continue_info_column", col, metrics.info_w, col_h, "continue_info_column")
end

return ContinueInfoColumn

--[[--
continue_info_column.lua — Continue right-hand info column (section header /
title / author / description / read-status).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local datetime = require("datetime")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local T = require("ffi/util").template
local _ = require("gettext")

local ContinueInfoColumn = {}

local TITLE_MAX_LINES = 2

local function formatPercent(percent)
    local p = percent or 0
    if p <= 1 then
        return math.floor(p * 100 + 0.5)
    end
    return math.floor(p + 0.5)
end

local function formatReadTime(seconds)
    if not seconds or seconds <= 0 then
        return nil
    end
    local user_duration_format = G_reader_settings:readSetting("duration_format", "classic")
    return datetime.secondsToClockDuration(user_duration_format, seconds, true)
end

local function buildProgressText(meta)
    local percent = formatPercent(meta.percent)
    local duration = formatReadTime(meta.read_time)
    if duration then
        return T(_("Read %1% · %2"), percent, duration)
    end
    return T(_("Read %1%"), percent)
end

--- @return table Info column widget
function ContinueInfoColumn.build(meta, metrics)
    local pad = metrics.cover_h_pad
    local text_w = metrics.info_w - 2 * pad
    if text_w < 0 then text_w = 0 end
    local item_gap = metrics.item_gap
    local col_h = metrics.continue_content_h
    local bg = Layout.COLOR_INFO_BG
    -- Left/right/top/bottom padding: the read-status line pinned at the bottom
    -- of the content area stays one pad above the column's bottom edge.
    local inner_h = col_h - 2 * pad
    if inner_h < 0 then inner_h = 0 end

    local title_face = Layout.titleFace()
    local body_face = Layout.bodyFace()
    local author_face = Layout.bodyItalicFace()
    local desc_face = Layout.descriptionFace()
    local title_line_h = Layout.lineHeight(title_face)
    local title_h = title_line_h * TITLE_MAX_LINES

    local items = VerticalGroup:new{ align = "left" }

    items[#items + 1] = TextWidget:new{
        text = _("Continue reading"),
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
        bgcolor = bg,
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
            bgcolor = bg,
            height_overflow_show_ellipsis = true,
        }
    end

    -- The read-status line is always pinned to the bottom of the column. Build
    -- it up front so its height can be reserved when sizing the description and
    -- the flexible spacer.
    local status_widget = TextWidget:new{
        text = buildProgressText(meta),
        face = body_face,
        fgcolor = Layout.COLOR_MUTED,
    }
    local status_h = Layout.lineHeight(body_face)

    items:resetLayout()
    local used_h = items:getSize().h
    -- Space left for the bottom row (the item gap above it + the status line).
    local free_h = inner_h - used_h - item_gap - status_h
    if free_h > 0 then
        local desc_line_h = Layout.lineHeight(desc_face)
        if meta.description and meta.description ~= ""
            and free_h >= item_gap + desc_line_h then
            items[#items + 1] = VerticalSpan:new{ width = item_gap }
            items[#items + 1] = TextBoxWidget:new{
                text = BD.auto(meta.description),
                face = desc_face,
                width = text_w,
                height = free_h - item_gap,
                fgcolor = Layout.COLOR_MUTED,
                bgcolor = bg,
                height_overflow_show_ellipsis = true,
            }
        else
            -- No description (or not enough room for one): the spacer fills the
            -- remaining column height so the read-status line stays at bottom.
            items[#items + 1] = VerticalSpan:new{ width = free_h }
        end
    end

    items[#items + 1] = VerticalSpan:new{ width = item_gap }
    items[#items + 1] = status_widget

    items:resetLayout()

    local col = FrameContainer:new{
        background = Layout.COLOR_INFO_BG,
        bordersize = 0,
        padding = 0,
        padding_left = pad,
        padding_right = pad,
        padding_top = pad,
        padding_bottom = pad,
        dimen = Geom:new{ w = metrics.info_w, h = col_h },
        TopContainer:new{
            dimen = Geom:new{ w = text_w, h = inner_h },
            items,
        },
    }

    -- 1px light-gray left border (divider between the cover column and this
    -- info column), drawn over the column's left edge pixels.
    local left_border = LineWidget:new{
        dimen = Geom:new{ w = Layout.dim.border, h = col_h },
        background = Layout.COLOR_COVER_BORDER,
        overlap_offset = { 0, 0 },
    }
    return OverlapGroup:new{
        dimen = Geom:new{ w = metrics.info_w, h = col_h },
        allow_mirroring = false,
        col,
        left_border,
    }
end

return ContinueInfoColumn

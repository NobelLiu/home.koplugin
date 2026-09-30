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
local pt = Layout.pt
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local T = require("ffi/util").template
local _ = require("gettext")

local ContinueInfoColumn = {}

local TypewriterLabel = require("ui/common/typewriter_label")
local UIManager = require("ui/uimanager")

local HEADER_PAUSE_S = 2
local HEADER_ROLE = "subhead"
local HEADER_OPTS = { emphasized = true }
local TITLE_ROLE = "headline"
local AUTHOR_ROLE = "subhead"
-- Noto Sans SC has no italic; Medium stands in for Subheadline/Italic.
local AUTHOR_OPTS = { weight = "medium" }
local DESC_ROLE = "footnote"
local STATUS_ROLE = "footnote"
local STATUS_OPTS = { emphasized = true }

local function scheduleContinueHeaderReveal(home)
    if not home then return end
    if home._unscheduleContinueHeaderReveal then
        home:_unscheduleContinueHeaderReveal()
    end
    home._continue_header_reveal_task = function()
        home._continue_header_reveal_task = nil
        local label = home._continue_header_label
        local region = home._continue_header_region
        if label and region and label.reveal then
            label:reveal(home, region, _("Continue reading"), 0)
        end
    end
    UIManager:scheduleIn(HEADER_PAUSE_S, home._continue_header_reveal_task)
end

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

local function typeLineEm(role, opts)
    return Layout.theme().type.lineHeightEm(role, opts)
end

local function wrappingLabel(text, width, role, opts, extra)
    extra = extra or {}
    return TextBoxWidget:new{
        text = text or "",
        face = Layout.face(role, opts),
        width = width,
        bold = false,
        fgcolor = extra.fgcolor or Blitbuffer.COLOR_BLACK,
        bgcolor = extra.bgcolor,
        line_height = typeLineEm(role, opts),
        alignment = "left",
    }
end

local function measureWrapHeight(text, width, role, opts)
    local box = wrappingLabel(text, width, role, opts)
    local h = box:getSize().h
    box:free()
    return h
end

--- Screen region for the Continue section header line (greeting / title).
function ContinueInfoColumn.headerRegion(metrics, height)
    local pad_left = metrics.info_padding
    local pad_right = metrics.info_padding
    local pad_top = metrics.info_top_padding or metrics.info_padding
    local text_width = math.max(0, math.floor((metrics.info_width or 0) - pad_left - pad_right))
    return Geom:new{
        x = metrics.main_horizontal_padding + metrics.cover_column_width + pad_left,
        y = metrics.main_vertical_padding + metrics.status_bar_height + pad_top,
        w = text_width,
        h = height or measureWrapHeight(_("Continue reading"),
            text_width, HEADER_ROLE, HEADER_OPTS),
    }
end

--- Header label: typewriter greeting, pause, then typewriter "Continue reading".
function ContinueInfoColumn.buildHeader(home, metrics, animate)
    local continue_text = _("Continue reading")
    local header_face = Layout.greetingFace()
    local pad_left = metrics.info_padding
    local pad_right = metrics.info_padding
    local text_width = math.max(0, math.floor((metrics.info_width or 0) - pad_left - pad_right))
    local header_height = math.max(
        measureWrapHeight(Layout.getGreetingText(), text_width, HEADER_ROLE, HEADER_OPTS),
        measureWrapHeight(continue_text, text_width, HEADER_ROLE, HEADER_OPTS))
    local region = ContinueInfoColumn.headerRegion(metrics, header_height)

    if not animate then
        return wrappingLabel(continue_text, text_width, HEADER_ROLE, HEADER_OPTS, {
            bgcolor = Layout.COLOR_INFO_BG,
        }), region
    end

    local label = TypewriterLabel.build{
        text = Layout.getGreetingText(),
        face = header_face,
        bold = false,
        width = text_width,
        height = header_height,
        line_height = typeLineEm(HEADER_ROLE, HEADER_OPTS),
        bgcolor = Layout.COLOR_INFO_BG,
        animate = true,
        guard_key = "_continue_header_label",
        on_finish = function()
            scheduleContinueHeaderReveal(home)
        end,
    }
    return label, region
end

--- @return table Info column widget
function ContinueInfoColumn.build(meta, metrics, opts)
    opts = opts or {}
    local pad_left = metrics.info_padding
    local pad_right = metrics.info_padding
    local pad_top = metrics.info_top_padding or metrics.info_padding
    local pad_bottom = metrics.info_padding
    local text_width = math.max(0, math.floor(metrics.info_width - pad_left - pad_right))
    local stack_gap = pt(Layout.space.continue_gap)
    local title_gap = pt(Layout.space.continue_title_gap)
    local column_height = metrics.continue_content_height
    local bg = Layout.COLOR_INFO_BG
    local inner_height = math.max(0, math.floor(column_height - pad_top - pad_bottom))

    local items = VerticalGroup:new{ align = "left" }

    if opts.header_label then
        items[#items + 1] = opts.header_label
    else
        items[#items + 1] = wrappingLabel(_("Continue reading"), text_width,
            HEADER_ROLE, HEADER_OPTS, { bgcolor = bg })
    end

    local title_block = VerticalGroup:new{ align = "left" }
    title_block[#title_block + 1] = wrappingLabel(BD.auto(meta.title), text_width,
        TITLE_ROLE, nil, { bgcolor = bg })
    if meta.authors and meta.authors ~= "" then
        title_block[#title_block + 1] = VerticalSpan:new{ width = title_gap }
        title_block[#title_block + 1] = wrappingLabel(BD.auto(meta.authors), text_width,
            AUTHOR_ROLE, AUTHOR_OPTS, {
                fgcolor = Layout.secondaryColor(),
                bgcolor = bg,
            })
    end
    items[#items + 1] = VerticalSpan:new{ width = stack_gap }
    items[#items + 1] = title_block

    -- The read-status line is always pinned to the bottom of the column. Build
    -- it up front so its height can be reserved when sizing the description and
    -- the flexible spacer.
    local status_widget = wrappingLabel(buildProgressText(meta), text_width,
        STATUS_ROLE, STATUS_OPTS, {
            bgcolor = bg,
            fgcolor = Layout.secondaryColor(),
        })
    local status_height = status_widget:getSize().h

    items:resetLayout()
    local used_height = math.floor((items:getSize().h or 0) + 0.5)
    -- Space left for the bottom row (the stack gap above it + the status line).
    local free_height = math.floor(inner_height - used_height - stack_gap - status_height)
    if free_height > 0 then
        local description_line_height = Layout.theme().type.leading(DESC_ROLE)
        if meta.description and meta.description ~= ""
            and free_height >= stack_gap + description_line_height then
            items[#items + 1] = VerticalSpan:new{ width = stack_gap }
            local desc_height = math.max(0, math.floor(free_height - stack_gap))
            local desc = wrappingLabel(BD.auto(meta.description), text_width,
                DESC_ROLE, nil, { bgcolor = bg })
            local desc_h = desc:getSize().h
            -- Wrap with no line cap. If the text is taller than the remaining
            -- slot, clip that slot only so status stays on-screen.
            if desc_h > desc_height then
                desc:free()
                desc = TextBoxWidget:new{
                    text = BD.auto(meta.description),
                    face = Layout.face(DESC_ROLE),
                    width = text_width,
                    height = desc_height,
                    bold = false,
                    fgcolor = Blitbuffer.COLOR_BLACK,
                    bgcolor = bg,
                    line_height = typeLineEm(DESC_ROLE),
                    alignment = "left",
                    height_overflow_show_ellipsis = true,
                }
            end
            items[#items + 1] = desc
            if desc_h < desc_height then
                items[#items + 1] = VerticalSpan:new{ width = desc_height - desc_h }
            end
        else
            -- No description (or not enough room for one): the spacer fills the
            -- remaining column height so the read-status line stays at bottom.
            items[#items + 1] = VerticalSpan:new{ width = free_height }
        end
    end

    items[#items + 1] = VerticalSpan:new{ width = stack_gap }
    items[#items + 1] = status_widget

    items:resetLayout()

    local col = FrameContainer:new{
        background = Layout.COLOR_INFO_BG,
        bordersize = 0,
        padding = 0,
        padding_left = pad_left,
        padding_right = pad_right,
        padding_top = pad_top,
        padding_bottom = pad_bottom,
        dimen = Geom:new{ w = metrics.info_width, h = column_height },
        TopContainer:new{
            dimen = Geom:new{ w = text_width, h = inner_height },
            items,
        },
    }

    -- 1px light-gray left border (divider between the cover column and this
    -- info column), drawn over the column's left edge pixels.
    local left_border = LineWidget:new{
        dimen = Geom:new{ w = pt(Layout.dim.border), h = column_height },
        background = Blitbuffer.COLOR_WHITE,
        overlap_offset = { 0, 0 },
    }
    return OverlapGroup:new{
        dimen = Geom:new{ w = metrics.info_width, h = column_height },
        allow_mirroring = false,
        col,
        left_border,
    }
end

return ContinueInfoColumn

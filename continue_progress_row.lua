--[[--
continue_progress_row.lua — Continue progress row (progress bar under the
cover + "Read %" in the info area).
--]]

local Blitbuffer = require("ffi/blitbuffer")
local datetime = require("datetime")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Layout = require("layout")
local LeftContainer = require("ui/widget/container/leftcontainer")
local ProgressBar = require("progress_bar")
local TextWidget = require("ui/widget/textwidget")
local T = require("ffi/util").template
local _ = require("gettext")

local ContinueProgressRow = {}

local DebugOverlay = require("debug_overlay")

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

--- @return table Progress row widget
function ContinueProgressRow.build(meta, metrics)
    local percent_text = buildProgressText(meta)
    local bar = CenterContainer:new{
        dimen = Geom:new{ w = metrics.cover_col_w, h = metrics.progress_row_h },
        ProgressBar.build(metrics.cover_col_w, meta.percent, metrics.progress_bar_h),
    }
    local label = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = metrics.info_pad,
        padding_right = metrics.info_pad,
        dimen = Geom:new{ w = metrics.info_w, h = metrics.progress_row_h },
        LeftContainer:new{
            dimen = Geom:new{ w = metrics.info_w - 2 * metrics.info_pad, h = metrics.progress_row_h },
            TextWidget:new{
                text = percent_text,
                face = Layout.bodyFace(),
                fgcolor = Layout.COLOR_MUTED,
            },
        },
    }

    local row = HorizontalGroup:new{
        align = "center",
        bar,
        label,
    }

    return DebugOverlay.wrap("continue_progress_row", row,
        metrics.content_w, metrics.progress_row_h, "continue_progress_row")
end

return ContinueProgressRow

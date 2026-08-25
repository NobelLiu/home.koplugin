--[[--
continue_section.lua — Assembles the Continue section.
--]]

local BookRepository = require("book_repository")
local ContinueCenter = require("continue_center")
local ContinueContentRow = require("continue_content_row")
local ContinueProgressRow = require("continue_progress_row")
local DebugOverlay = require("debug_overlay")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local TapCell = require("tap_cell")
local TextWidget = require("ui/widget/textwidget")
local TopContainer = require("ui/widget/container/topcontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local util = require("util")

local Blitbuffer = require("ffi/blitbuffer")
local Layout = require("layout")

local ContinueSection = {}

--- Build the greeting label pinned to the top-left corner of the Continue
--- section. Returns nil when the greeting text is empty so it is hidden.
--- When `home` is given and it hasn't yet played the greeting animation, the
--- label shows its first character and reveals the rest one character at a time
--- (300ms apart).
local function buildGreeting(metrics, home, greeting_region)
    local text = Layout.getGreetingText()
    if not text or text == "" then return nil end

    -- Animate only once per Home session, and only if the label has never been
    -- shown yet (so refreshes/paging don't replay it). The label starts with a
    -- zero-width space (an empty TextWidget doesn't paint and would collapse the
    -- layout, so we need a glyph that reserves height while showing nothing);
    -- after the start delay the text is revealed one character at a time. A
    -- zero interval disables the animation (reveal the whole text at once).
    local interval = Layout.getGreetingAnimInterval()
    local chars = util.splitToChars(text)
    local animate = home and greeting_region and not home._greeting_animated
        and #chars > 1 and interval > 0
    local label = TextWidget:new{
        text = animate and "\u{200B}" or text,
        face = Layout.greetingFace(),
        fgcolor = Blitbuffer.COLOR_BLACK,
        bold = true,
        max_width = metrics.content_w,
        padding = 0,
    }

    if animate then
        home._greeting_animated = true
        home._greeting_label = label
        ContinueSection._scheduleGreetingReveal(home, label, chars, greeting_region, interval)
    end

    return TopContainer:new{
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
        LeftContainer:new{
            dimen = Geom:new{ w = metrics.content_w, h = label:getSize().h },
            label,
        },
    }
end

--- Reveal the greeting on `label` one character at a time, `interval` seconds
--- apart. The whole reveal is held back by `START_DELAY`: until then the label
--- shows only a zero-width space (blank but with reserved height), and the first
--- character appears together with the rest of the typewriter run.
--- Each step repaints the fixed `region` (screen-space rect of the greeting
--- slot; TextWidget:paintTo never sets its own .dimen, so we can't derive it at
--- runtime). Guards against the label being torn down (Home refreshed/closed).
ContinueSection.GREETING_START_DELAY = 0.5

function ContinueSection._scheduleGreetingReveal(home, label, chars, region, interval)
    local i = 0 -- nothing revealed yet; first step shows chars[1]

    local function step()
        -- Bail if Home was rebuilt/closed and this label is no longer the live
        -- greeting (its widget was freed by Home:refresh -> self[1]:free()).
        if home._greeting_label ~= label then return end
        i = i + 1
        label:setText(table.concat(chars, "", 1, i))
        UIManager:setDirty(home, "ui", region)
        if i < #chars then
            UIManager:scheduleIn(interval, step)
        end
    end

    UIManager:scheduleIn(ContinueSection.GREETING_START_DELAY, step)
end

--- @return table Continue widget
function ContinueSection.build(filepath, metrics, on_open, home, greeting_region)
    local meta = BookRepository.getBookMeta(filepath)

    local content_row = ContinueContentRow.build(filepath, meta, metrics)

    -- The progress row sits below the cover row; the gap is applied via
    -- padding_top rather than a Span placeholder.
    local progress_row = DebugOverlay.wrap("continue_row_gap", FrameContainer:new{
        bordersize = 0,
        margin = 0,
        padding = 0,
        padding_top = metrics.continue_row_gap,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_row_gap + metrics.progress_row_h },
        ContinueProgressRow.build(meta, metrics),
    }, metrics.content_w, metrics.continue_row_gap + metrics.progress_row_h, "continue_row_gap")

    local inner = DebugOverlay.wrap("continue_inner", VerticalGroup:new{
        align = "left",
        content_row,
        progress_row,
    }, metrics.content_w, metrics.continue_h, "continue_inner")

    local section = ContinueCenter.wrap(inner, metrics)

    -- Pin the greeting to the top-left corner while the book content sits at the
    -- bottom of the slot.
    local greeting = buildGreeting(metrics, home, greeting_region)
    if greeting then
        section = DebugOverlay.wrap("continue_with_greeting", OverlapGroup:new{
            dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
            section,
            greeting,
        }, metrics.content_w, metrics.continue_slot_h, "continue_with_greeting")
    end

    local tap = TapCell.wrap(section, Geom:new{
        w = metrics.content_w,
        h = metrics.continue_slot_h,
    }, function()
        on_open(filepath)
    end)

    return DebugOverlay.wrap("continue_section", tap,
        metrics.content_w, metrics.continue_slot_h, "continue_section")
end

return ContinueSection

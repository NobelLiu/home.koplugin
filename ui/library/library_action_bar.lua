--[[--
library_action_bar.lua — Library action bar (sort toggle + pagination).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Layout = require("ui/common/layout")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local StatusBar = require("ui/status_bar")
local TapCell = require("ui/common/tap_cell")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local TypewriterLabel = require("ui/common/typewriter_label")

local LibraryActionBar = {}

-- How long the fully-revealed greeting stays on screen before it is replaced
-- by the current time (root folder only).
local GREETING_TO_TIME_DELAY = 2 -- seconds

--- Current time for the greeting → time swap, zero-padded ("02:23", or
--- "02:23 PM" on a 12-hour clock).
local function currentTimeText()
    local now = os.time()
    if G_reader_settings:isTrue("twelve_hour_clock") then
        return os.date("%I:%M %p", now)
    end
    return os.date("%H:%M", now)
end

-- nerdfonts/symbols.ttf
local ICON_LEFT = "\u{F47D}"
local ICON_RIGHT = "\u{F460}"
local ICON_BACK = "\u{E74C}"
local ICON_SORT_NAME = "\u{F15D}"
local ICON_SORT_RECENT = "\u{F161}"

local function symbolFace(size)
    return Font:getFace("cfont", size)
end

local function symbolWidget(glyph, enabled, size)
    return TextWidget:new{
        text = BD.wrap(glyph),
        face = symbolFace(size),
        fgcolor = enabled and Blitbuffer.COLOR_BLACK or Layout.COLOR_MUTED,
        padding = 0,
        bold = false,
    }
end

-- Icon sizes anchored to Font sizemap presets (orig/unscaled px):
--   pager  -> "tfont" (26)
--   sort   -> "x_smallinfofont" (20), matching the section face
local PAGER_ICON_SIZE = Font:getFace("tfont").orig_size
local SORT_ICON_SIZE = Font:getFace("x_smallinfofont").orig_size

--- Square, icon-centered tappable button. Side length matches the action bar
--- height, so tapping inverts the whole square (black) as feedback.
local function buildSquareIconButton(glyph, enabled, callback, icon_font_size)
    local side = Layout.dim.action_bar
    local icon = symbolWidget(glyph, enabled, icon_font_size)
    local icon_size = icon:getSize()
    icon.overlap_offset = {
        math.floor((side - icon_size.w) / 2),
        math.floor((side - icon_size.h) / 2),
    }
    local cell = OverlapGroup:new{
        dimen = Geom:new{ w = side, h = side },
        allow_mirroring = false,
        icon,
    }
    local content = FrameContainer:new{
        bordersize = 0,
        color = enabled and Blitbuffer.COLOR_BLACK or Layout.COLOR_MUTED,
        padding = 0,
        margin = 0,
        radius = 0,
        width = side,
        height = side,
        cell,
    }
    return TapCell.wrap(content, Geom:new{ w = side, h = side },
        enabled and callback or nil, { highlight = enabled })
end

local function buildSortButton(sort_mode, on_sort_menu)
    local glyph = sort_mode == "name" and ICON_SORT_NAME or ICON_SORT_RECENT
    return buildSquareIconButton(glyph, true, on_sort_menu, SORT_ICON_SIZE)
end

local function buildPagerButton(glyph, enabled, callback)
    return buildSquareIconButton(glyph, enabled, callback, PAGER_ICON_SIZE)
end

--- Pagination controls; both arrows are shown always and rendered as disabled
--- (muted, non-tappable) when there is no previous/next page.
local function buildPagerButtons(page, page_count, on_page_change)
    local left_glyph = ICON_LEFT
    local right_glyph = ICON_RIGHT
    if BD.mirroredUILayout() then
        left_glyph, right_glyph = right_glyph, left_glyph
    end

    local prev_enabled = page > 0
    local next_enabled = page < page_count - 1

    local prev_btn = buildPagerButton(left_glyph, prev_enabled, function()
        on_page_change(page - 1)
    end)
    local next_btn = buildPagerButton(right_glyph, next_enabled, function()
        on_page_change(page + 1)
    end)

    return HorizontalGroup:new{
        align = "center",
        prev_btn,
        next_btn,
    }
end

--- Schedule the root greeting → time swap. Once the greeting has been fully
--- revealed (after the typewriter animation, or instantly when animation is
--- disabled), it dwells for GREETING_TO_TIME_DELAY and is then replaced by the
--- current time, which types itself out with the same typewriter effect;
--- `on_time_done` (e.g. revealing the status display) fires when the time
--- reveal completes. Folder titles never swap: they must keep showing the
--- folder name (and their back/up action). The swap is guarded so it bails
--- out once Home is rebuilt (the label is no longer the live one) or the user
--- left the root folder.
local function scheduleGreetingSwap(label, home, region, on_time_done)
    if not home or not region then return end
    label._tw_on_finish = function()
        UIManager:scheduleIn(GREETING_TO_TIME_DELAY, function()
            if home._title_label ~= label then return end
            if home.current_dir ~= home.root_dir then return end
            -- Never paint under the lock screen / screensaver.
            if Device.screen_saver_mode then return end
            -- The time shares the status display's face: same font, size and
            -- regular weight as the battery percentage.
            label.face = StatusBar.face()
            label.bold = false
            label:reveal(home, region, currentTimeText(), 0, on_time_done)
        end)
    end
end

--- Size of the time text as rendered after the swap (status face, regular
--- weight), so the status slot can start exactly one section padding after the
--- time instead of after the wider greeting.
local function timeTextSize(max_w)
    local tw = TextWidget:new{
        text = currentTimeText(),
        face = StatusBar.face(),
        bold = false,
        max_width = max_w,
        padding = 0,
    }
    return tw:getSize()
end

--- Build the status display label (battery / Wi-Fi / frontlight), kept hidden
--- until the time reveal finishes, then typed out like the greeting and time.
--- It keeps its own live guard on `home._status_label` so a rebuild cancels
--- any in-flight reveal. Returns nil when there is nothing to display.
local function buildStatusLabel(home, content_w)
    if not home then return nil end
    local status_text = StatusBar.statusText(StatusBar.collectInfo())
    if status_text == "" then
        home._status_label = nil
        return nil
    end
    local status_label = TypewriterLabel.build{
        text = status_text,
        face = StatusBar.face(),
        bold = false,
        fgcolor = Blitbuffer.COLOR_BLACK,
        max_width = math.floor(content_w * 0.3),
        guard_key = "_status_label",
    }
    -- Keep it invisible until its reveal starts.
    status_label:setText("\u{200B}")
    home._status_label = status_label
    return status_label
end

--- Left segment: a back icon + title. At the root the title is the greeting
--- text (no icon) that swaps to the current time after a short dwell, with the
--- status display (battery / Wi-Fi / frontlight) typing out to its left once
--- the time reveal finishes; the whole row opens the status panel on tap.
--- Inside a subfolder the title is the folder name preceded by a back icon,
--- and tapping returns to the parent folder. The title reveals its text with a
--- typewriter effect when `home`/`title_region` are supplied and animation is
--- enabled.
local function buildTitle(current_title, content_w, on_go_up, home, title_region, animate)
    local at_root = not current_title or current_title == ""
    local label_text = at_root and Layout.getGreetingText() or current_title
    local max_label_w = math.floor(content_w * 0.5)
    local label = TypewriterLabel.build{
        text = label_text,
        face = Layout.greetingFace(),
        bold = true,
        fgcolor = Blitbuffer.COLOR_BLACK,
        max_width = max_label_w,
        animate = animate and home ~= nil and title_region ~= nil,
    }
    local status_label
    if at_root then
        status_label = buildStatusLabel(home, content_w)
        scheduleGreetingSwap(label, home, title_region, status_label and function()
            -- Collects the status text fresh at reveal time and marks the label
            -- settled for the live refreshes (Home:_revealStatusLabel).
            home:_revealStatusLabel(status_label, title_region)
        end)
    elseif home then
        home._status_label = nil
    end
    label:play(home, title_region)

    if at_root then
        -- Row: [greeting/time][Library section padding][status display]. The tap area
        -- is sized for the final strings so it doesn't grow as the reveals add
        -- characters. Both labels reveal in place (their text grows inside the
        -- fixed slot), so they are positioned with fixed overlap offsets: a
        -- HorizontalGroup would cache its offsets from the initial zero-width
        -- placeholders and the growing texts would overlap.
        local label_size = label:getFullSize()
        local time_size = timeTextSize(max_label_w)
        local row_content = label
        local row_w = label_size.w
        local row_h = label_size.h
        if status_label then
            local status_size = status_label:getFullSize()
            local gap = Layout.pad.cover
            row_w = math.max(label_size.w, time_size.w) + gap + status_size.w
            row_h = math.max(status_size.h, label_size.h)
            label.overlap_offset = {
                0,
                math.floor((row_h - time_size.h) / 2),
            }
            status_label.overlap_offset = {
                time_size.w + gap,
                math.floor((row_h - status_size.h) / 2),
            }
            row_content = OverlapGroup:new{
                dimen = Geom:new{ w = row_w, h = row_h },
                label,
                status_label,
            }
        end
        -- Tapping the greeting/time/status row opens Home's quick status panel.
        local on_tap = home and home.onShowStatusPanel and function()
            home:onShowStatusPanel()
        end
        return TapCell.wrap(row_content, Geom:new{ w = row_w, h = row_h }, on_tap,
            { highlight = true })
    end

    local icon = symbolWidget(ICON_BACK, true)
    local row = HorizontalGroup:new{
        align = "center",
        icon,
        HorizontalSpan:new{ width = Size.padding.buttontable },
        label,
    }
    -- Size the tap-area for the full title width even while the reveal starts
    -- from a near-zero-width placeholder, so the back-tap region doesn't grow
    -- as characters appear.
    local icon_size = icon:getSize()
    local label_size = label:getFullSize()
    local row_w = icon_size.w + Size.padding.buttontable + label_size.w
    local row_h = math.max(icon_size.h, label_size.h)
    return TapCell.wrap(row, Geom:new{ w = row_w, h = row_h }, on_go_up,
        { highlight = true })
end

--- @return table action bar widget, number action_bar_h
function LibraryActionBar.build(opts, page_count)
    local action_bar_h = Layout.dim.action_bar
    local title = buildTitle(opts.current_title, opts.metrics.content_w,
        opts.on_go_up, opts.home, opts.title_region, opts.animate_title)
    local sort_btn = buildSortButton(opts.sort_mode, opts.on_sort_menu)
    local pager = buildPagerButtons(opts.page, page_count, opts.on_page_change)

    -- Right cluster: sort button, then pager. The pager is always shown; its
    -- arrows appear disabled (muted, non-tappable) when there is no prev/next
    -- page.
    local right_group = HorizontalGroup:new{
        align = "center",
        sort_btn,
        HorizontalSpan:new{ width = Size.padding.large },
        pager,
    }

    local row = OverlapGroup:new{
        dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
        LeftContainer:new{
            dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
            title,
        },
        RightContainer:new{
            dimen = Geom:new{ w = opts.metrics.content_w, h = action_bar_h },
            right_group,
        },
    }

    return row, action_bar_h
end

return LibraryActionBar

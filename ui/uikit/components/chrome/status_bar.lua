--[[--
Left title (or time) and a right status cluster. No device I/O.
Horizontal inset from padding_horizontal; content vertically centered; optional
full-width bottom border flush to the bar bottom edge.
]]

local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Icon = require("ui/uikit/components/icon")
local Label = require("ui/uikit/components/controls/label")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local Spacer = require("ui/uikit/components/layout/spacer")
local TapCell = require("ui/common/tap_cell")
local TextWidget = require("ui/widget/textwidget")
local Theme = require("ui/uikit/components/theme")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local pt = Theme.pt

local StatusBar = WidgetContainer:extend{
    title = nil,
    title_widget = nil,
    time_text = "",
    status_text = "",
    status_icons = nil,
    status_widget = nil,
    width = nil,
    height = nil,
    padding_horizontal = nil,
    on_status_tap = nil,
    show_divider = true,
    title_role = nil,
    time_role = nil,
    status_role = nil,
    icon_size = nil,
    color = nil,
    divider_color = nil,
    divider_size = nil,
}

local function iconRow(icons, icon_size, gap)
    local row = HorizontalGroup:new{ align = "center", allow_mirroring = false }
    for i, spec in ipairs(icons or {}) do
        local name = type(spec) == "table" and spec.icon or spec
        local dim = type(spec) == "table" and spec.dim or false
        if i > 1 then
            table.insert(row, Spacer.horizontal(gap))
        end
        table.insert(row, Icon:new{
            icon = name,
            width = icon_size,
            height = icon_size,
            dim = dim,
        })
    end
    return row
end

-- LeftContainer:paintTo left-aligns and vertically centers using the child's
-- live getSize(), so no fixed-width inner box is needed (and a frozen one would
-- misplace the content if it later changed width, e.g. in a mirrored layout).
local function vCenterLeftSlot(widget, slot_w, slot_h)
    return LeftContainer:new{
        dimen = Geom:new{ w = slot_w, h = slot_h },
        widget,
    }
end

-- RightContainer:paintTo already right-aligns and vertically centers its child
-- using the child's *live* getSize() at paint time. Wrapping the child in a
-- fixed-width CenterContainer would freeze the horizontal box at build time, so
-- when the cluster shrinks (e.g. the frontlight glyph turns off) the stale box
-- keeps the old width and the content drifts left of the true right edge. Place
-- the widget directly so alignment tracks its current size.
local function vCenterRightSlot(widget, slot_w, slot_h)
    return RightContainer:new{
        dimen = Geom:new{ w = slot_w, h = slot_h },
        widget,
    }
end

function StatusBar:init()
    local width = self.width
    local padding_horizontal = self.padding_horizontal or pt(Theme.pad.page_horizontal)
    local bar_h = self.height or pt(Theme.dim.status_height)
    local line_height = (self.show_divider ~= false)
        and (self.divider_size or pt(Theme.border.default)) or 0
    local content_slot_h = math.max(0, bar_h - line_height)
    local inner_width = width and math.max(0, math.floor(width - 2 * padding_horizontal)) or nil
    local color = self.color or Theme.color.black
    local icon_size = self.icon_size or pt(Theme.dim.status_icon)
    local icon_gap = self.icon_gap or pt(Theme.gap.default)
    local title_role = self.title_role or "h3"
    local has_title = self.title_widget ~= nil
        or (self.title ~= nil and self.title ~= "")

    local title = self.title_widget or Label:new{
        text = has_title and (self.title or "") or (self.time_text or ""),
        role = title_role,
        color = color,
        max_width = inner_width and math.floor(inner_width * 0.5) or nil,
    }

    local status
    if self.status_widget then
        status = self.status_widget
    elseif self.status_icons and #self.status_icons > 0 then
        status = iconRow(self.status_icons, icon_size, icon_gap)
    elseif self.status_text and self.status_text ~= "" then
        if has_title then
            status = TextWidget:new{
                text = self.status_text,
                face = Theme.symbolFace(Theme.size.status_icon),
                fgcolor = color,
                padding = 0,
            }
        else
            status = Label:new{
                text = self.status_text,
                role = self.status_role or "caption",
                color = color,
                max_width = inner_width and math.floor(inner_width * 0.5) or nil,
            }
        end
    end
    self.status_label = status

    local time
    if has_title and self.time_text and self.time_text ~= "" then
        time = Label:new{
            text = self.time_text,
            role = self.time_role or title_role,
            color = color,
        }
        self.time_label = time[1]
    elseif not has_title and self.time_text and self.time_text ~= "" then
        self.time_label = title[1]
    end

    local right = HorizontalGroup:new{ align = "center", allow_mirroring = false }
    if has_title then
        if status then
            table.insert(right, status)
        end
        if time then
            if status then
                table.insert(right, Spacer.horizontal(self.status_gap or pt(Theme.gap.section)))
            end
            table.insert(right, time)
        end
    elseif status then
        table.insert(right, status)
    end

    local right_w = math.floor((right:getSize().w or 0) + 0.5)
    local right_content = right
    if self.on_status_tap and #right > 0 then
        right_content = TapCell:new{
            width = right_w,
            height = content_slot_h,
            vertical_align = "center",
            content = right,
            callback = self.on_status_tap,
        }
        self.status_tap = right_content
    end

    local row_width = inner_width or math.max(
        math.floor((title:getSize().w or 0) + 0.5),
        right_w)
    local row = OverlapGroup:new{
        dimen = Geom:new{ w = row_width, h = content_slot_h },
        allow_mirroring = false,
        vCenterLeftSlot(title, row_width, content_slot_h),
        vCenterRightSlot(right_content, row_width, content_slot_h),
    }

    local frame = FrameContainer:new{
        radius = Theme.radius,
        bordersize = 0,
        padding = 0,
        padding_left = width and padding_horizontal or 0,
        padding_right = width and padding_horizontal or 0,
        margin = 0,
        width = width,
        height = content_slot_h,
        background = self.background or Theme.color.white,
        row,
    }

    if self.show_divider ~= false then
        local bar_width = width or frame:getSize().w
        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = bar_width, h = bar_h },
            allow_mirroring = false,
            frame,
            LineWidget:new{
                dimen = Geom:new{ w = bar_width, h = line_height },
                background = self.divider_color or Theme.color.black,
                overlap_offset = { 0, content_slot_h },
            },
        }
    else
        self[1] = frame
    end
end

return StatusBar

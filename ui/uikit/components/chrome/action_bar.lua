--[[--
Action bar row: [leading icons] title [trailing icons]
Horizontal inset; row content is vertically centered in the bar height.
]]

local Divider = require("ui/uikit/components/layout/divider")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local IconButton = require("ui/uikit/components/controls/icon_button")
local Label = require("ui/uikit/components/controls/label")
local LeftContainer = require("ui/widget/container/leftcontainer")
local Spacer = require("ui/uikit/components/layout/spacer")
local TapCell = require("ui/common/tap_cell")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local ActionBar = WidgetContainer:extend{
    title = "",
    actions = nil,
    leading = nil,
    trailing = nil,
    width = nil,
    height = nil,
    show_divider = true,
    title_role = nil,
    title_size = nil,
    title_weight = nil,
    title_emphasized = nil,
    icon_size = nil,
    icon_role = nil,
    icon_weight = nil,
    icon_emphasized = nil,
    padding_horizontal = nil,
    icon_padding_horizontal = nil,
    title_gap = nil,
    gap = nil,
    divider_color = nil,
}

local function iconButtons(items, bar_height, icon_opts)
    local group = HorizontalGroup:new{ align = "center", allow_mirroring = false }
    for _, item in ipairs(items or {}) do
        table.insert(group, IconButton:new{
            icon = item.icon,
            enabled = item.enabled ~= false,
            callback = item.callback,
            height = bar_height,
            icon_size = icon_opts.size,
            icon_role = icon_opts.role,
            icon_weight = icon_opts.weight,
            icon_emphasized = icon_opts.emphasized,
            padding_horizontal = item.padding_horizontal or icon_opts.pad,
            width = item.width,
            alignment = item.alignment,
        })
    end
    return group
end

local function textActions(actions, gap, bar_height)
    local group = HorizontalGroup:new{ align = "center", allow_mirroring = false }
    for i, action in ipairs(actions or {}) do
        if i > 1 then
            table.insert(group, Spacer.horizontal(gap))
        end
        table.insert(group, TapCell:new{
            height = bar_height,
            callback = action.callback,
            content = Label:new{
                text = action.text or "",
                role = action.role or "label",
                color = action.color,
            },
        })
    end
    return group
end

function ActionBar:init()
    local width = self.width
    local h = self.height or pt(Theme.dim.action_bar_height)
    local icon_role = self.icon_role
    local icon_weight = self.icon_weight
    local icon_emphasized = self.icon_emphasized
    local icon_size = self.icon_size
    if not icon_size and not icon_role then
        icon_size = Theme.dim.icon
    end
    local pad_h = self.padding_horizontal or pt(Theme.pad.page_horizontal)
    local icon_pad = self.icon_padding_horizontal or 0
    local gap = self.gap or pt(Theme.gap.default)
    local title_gap = self.title_gap or pt(Theme.pad.page_horizontal)
    local has_icons = (self.leading and #self.leading > 0)
        or (self.trailing and #self.trailing > 0)
    local icon_opts = {
        size = icon_size,
        role = icon_role,
        weight = icon_weight,
        emphasized = icon_emphasized,
        pad = icon_pad,
    }

    local leading = iconButtons(self.leading, h, icon_opts)
    local trailing = has_icons and iconButtons(self.trailing, h, icon_opts)
        or textActions(self.actions, gap, h)

    local leading_width = math.floor((leading:getSize().w or 0) + 0.5)
    local trailing_width = math.floor((trailing:getSize().w or 0) + 0.5)
    local inner_width = width and math.max(0, math.floor(width - 2 * pad_h)) or nil

    local gap_before = leading_width > 0 and title_gap or 0
    local gap_after = trailing_width > 0 and title_gap or 0
    local title_width
    if inner_width then
        title_width = math.max(0, math.floor(inner_width - leading_width - trailing_width
            - gap_before - gap_after))
    end

    local title_role = self.title_role or "body"
    local title_type_opts = {
        weight = self.title_weight,
        emphasized = self.title_emphasized,
    }
    if self.title_size then
        title_type_opts.size = self.title_size
    end
    local title = Label:new{
        text = self.title or "",
        role = title_role,
        size = self.title_size,
        weight = self.title_weight,
        emphasized = self.title_emphasized,
        color = self.color,
        max_width = title_width,
        height = Theme.type.leading(title_role, title_type_opts),
    }

    local row = HorizontalGroup:new{ align = "center", allow_mirroring = false }
    if leading_width > 0 then
        table.insert(row, leading)
        table.insert(row, Spacer.horizontal(gap_before))
    end
    if title_width then
        table.insert(row, LeftContainer:new{
            dimen = Geom:new{ w = title_width, h = h },
            title,
        })
    else
        table.insert(row, title)
    end
    if trailing_width > 0 then
        table.insert(row, Spacer.horizontal(gap_after))
        table.insert(row, trailing)
    end

    local bar = FrameContainer:new{
        width = width,
        height = h,
        bordersize = 0,
        padding = 0,
        padding_left = width and pad_h or 0,
        padding_right = width and pad_h or 0,
        margin = 0,
        row,
    }

    local col = VerticalGroup:new{ align = "left", bar }
    if self.show_divider ~= false then
        table.insert(col, Divider:new{
            width = width or bar:getSize().w,
            color = self.divider_color or Theme.color.black,
        })
    end
    self[1] = col
end

return ActionBar

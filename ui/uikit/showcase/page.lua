--[[--
Fullscreen Swiss showcase chrome: title, top-right close, scrollable body.
]]

local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Spacer = require("ui/uikit/components/layout/spacer")
local VerticalGroup = require("ui/widget/verticalgroup")
local UIManager = require("ui/uimanager")
local ActionBar = require("ui/uikit/components/chrome/action_bar")
local Theme = require("ui/uikit/components/theme")
local pt = Theme.pt
local Screen = Device.screen

local ShowcasePage = InputContainer:extend{
    name = "home_showcase",
    covers_fullscreen = true,
    stop_events_propagation = true,
    title = "",
    -- function(width) → widget [, step_scroll_grid]
    build_content = nil,
}

function ShowcasePage:init()
    local size = Screen:getSize()
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    self:build()
end

function ShowcasePage:build()
    local width = self.dimen.w
    local height = self.dimen.h
    local close = function()
        self:onClose()
    end
    local bar = ActionBar:new{
        title = self.title or "",
        title_role = "subhead",
        title_weight = "bold",
        icon_role = "headline",
        icon_weight = "bold",
        width = width,
        trailing = {
            {
                icon = "close",
                callback = close,
                alignment = "right",
            },
        },
    }
    local bar_h = bar:getSize().h
    local crop_h = math.max(0, height - bar_h)
    local pad_h = pt(Theme.pad.page_horizontal)
    local pad_v = pt(Theme.pad.page_vertical)
    local scroll_w = ScrollableContainer:getScrollbarWidth()
    local inner_width = math.max(0, width - 2 * pad_h - scroll_w)
    local body, step_scroll_grid
    if self.build_content then
        body, step_scroll_grid = self.build_content(inner_width)
    end
    local content = VerticalGroup:new{ align = "left" }
    table.insert(content, Spacer.vertical(pad_v))
    if body then
        table.insert(content, body)
    end
    table.insert(content, Spacer.vertical(pad_v))

    self.cropping_widget = ScrollableContainer:new{
        dimen = Geom:new{ w = width, h = crop_h },
        show_parent = self,
        step_scroll_grid = step_scroll_grid,
        FrameContainer:new{
            bordersize = 0,
            padding = 0,
            padding_left = pad_h,
            padding_right = pad_h,
            margin = 0,
            background = Theme.color.white,
            content,
        },
    }
    self[1] = FrameContainer:new{
        width = width,
        height = height,
        radius = Theme.radius,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Theme.color.white,
        VerticalGroup:new{
            align = "left",
            bar,
            self.cropping_widget,
        },
    }
end

function ShowcasePage:onSetDimensions(dimen)
    if self.dimen and self.dimen.w == dimen.w and self.dimen.h == dimen.h then
        return
    end
    self.dimen = dimen
    if self[1] and self[1].free then
        self[1]:free()
    end
    self:build()
    UIManager:setDirty(self, "full")
end

function ShowcasePage:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function ShowcasePage:onCloseWidget()
    UIManager:setDirty(nil, "full")
end

function ShowcasePage:onClose()
    UIManager:close(self)
    return true
end

function ShowcasePage.show(opts)
    UIManager:show(ShowcasePage:new(opts), "full")
end

return ShowcasePage

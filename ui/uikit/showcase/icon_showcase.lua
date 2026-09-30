--[[--
Paged grid of every visible Material Symbols Outlined glyph.
Catalog: ui/uikit/showcase/icon_catalog.lua (generated from the TTF).
]]

local BD = require("ui/bidi")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Icon = require("ui/uikit/components/icon")
local InputContainer = require("ui/widget/container/inputcontainer")
local Label = require("ui/uikit/components/controls/label")
local PageIndicator = require("ui/uikit/components/chrome/page_indicator")
local Spacer = require("ui/uikit/components/layout/spacer")
local TopContainer = require("ui/widget/container/topcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local ActionBar = require("ui/uikit/components/chrome/action_bar")
local Theme = require("ui/uikit/components/theme")
local UIManager = require("ui/uimanager")
local util = require("util")
local T = require("ffi/util").template
local pt = Theme.pt
local Screen = Device.screen
local _ = require("gettext")

local IconShowcase = InputContainer:extend{
    name = "home_icon_showcase",
    covers_fullscreen = true,
    stop_events_propagation = true,
    page = 0,
}

local CATALOG = require("ui/uikit/showcase/icon_catalog")

local function utf8Codepoint(s, i)
    local c = s:byte(i)
    if not c then
        return nil, i
    end
    if c < 0x80 then
        return c, i + 1
    end
    local c2 = s:byte(i + 1)
    if c < 0xE0 then
        if not c2 then
            return c, i + 1
        end
        return (c - 0xC0) * 0x40 + (c2 - 0x80), i + 2
    end
    local c3 = s:byte(i + 2)
    if c < 0xF0 then
        if not c2 or not c3 then
            return c, i + 1
        end
        return (c - 0xE0) * 0x1000 + (c2 - 0x80) * 0x40 + (c3 - 0x80), i + 3
    end
    local c4 = s:byte(i + 3)
    if not c2 or not c3 or not c4 then
        return c, i + 1
    end
    return (c - 0xF0) * 0x40000 + (c2 - 0x80) * 0x1000
        + (c3 - 0x80) * 0x40 + (c4 - 0x80), i + 4
end

local function themeAliasMap()
    local map = {}
    for name, glyph in pairs(Theme.icon) do
        if type(glyph) == "string" and glyph ~= "" then
            local cp = utf8Codepoint(glyph, 1)
            if cp then
                local list = map[cp]
                if not list then
                    list = {}
                    map[cp] = list
                end
                list[#list + 1] = name
            end
        end
    end
    for _, list in pairs(map) do
        table.sort(list)
    end
    return map
end

local cached_items

local function catalogItems()
    if cached_items then
        return cached_items
    end
    local aliases = themeAliasMap()
    local items = {}
    for _, row in ipairs(CATALOG) do
        local cp = row[1]
        local name = row[2] or ""
        local extra = aliases[cp]
        local desc = name
        if extra and #extra > 0 then
            local bits = {}
            for _, alias in ipairs(extra) do
                if alias ~= name then
                    bits[#bits + 1] = alias
                end
            end
            if #bits > 0 then
                if desc ~= "" then
                    desc = desc .. " · " .. table.concat(bits, ", ")
                else
                    desc = table.concat(bits, ", ")
                end
            end
        end
        items[#items + 1] = {
            cp = cp,
            name = name,
            desc = desc,
            unicode = string.format("U+%04X", cp),
            char = util.unicodeCodepointToUtf8(cp),
        }
    end
    cached_items = items
    return items
end

local function columnCount(width)
    local min_w = pt(Theme.dim.showcase_min_width)
    if min_w < 1 then
        min_w = 1
    end
    local cols = math.floor(width / min_w)
    if cols < 2 then
        return 2
    end
    if cols > 4 then
        return 4
    end
    return cols
end

local function splitWidths(width, cols)
    local base = math.floor(width / cols)
    local extra = width - base * cols
    local widths = {}
    for i = 1, cols do
        widths[i] = base + (i <= extra and 1 or 0)
    end
    return widths
end

local function cellMetrics()
    local border = pt(Theme.border.thin)
    local pad = pt(Theme.pad.small)
    local gap = pt(Theme.gap.stack)
    local icon_side = pt(Theme.type.size("title2"))
    local unicode_h = Theme.type.leading("caption1")
    local name_h = Theme.type.leading("caption2")
    local height = 2 * border + 2 * pad + icon_side + 2 * gap + unicode_h + name_h
    return {
        border = border,
        pad = pad,
        gap = gap,
        icon_side = icon_side,
        height = height,
    }
end

local function cellWidget(entry, width, metrics)
    local inner_w = math.max(0, width - 2 * metrics.border - 2 * metrics.pad)
    local inner_h = math.max(0, metrics.height - 2 * metrics.border - 2 * metrics.pad)
    local col = VerticalGroup:new{
        align = "left",
        Icon:new{
            icon = entry.char,
            role = "title2",
            width = metrics.icon_side,
            height = metrics.icon_side,
        },
        Spacer.vertical(metrics.gap),
        Label:new{
            text = entry.unicode,
            role = "caption1",
            max_width = inner_w,
            multiline = false,
        },
        Spacer.vertical(metrics.gap),
        Label:new{
            text = entry.desc,
            role = "caption2",
            max_width = inner_w,
            multiline = false,
        },
    }
    return FrameContainer:new{
        width = width,
        height = metrics.height,
        radius = Theme.radius,
        bordersize = metrics.border,
        padding = metrics.pad,
        margin = 0,
        background = Theme.color.white,
        color = Theme.color.black,
        TopContainer:new{
            dimen = Geom:new{ w = inner_w, h = inner_h },
            col,
        },
    }
end

local function gridWidget(page_items, widths, cols, metrics)
    local rows = VerticalGroup:new{ align = "left" }
    local i = 1
    while i <= #page_items do
        local row = HorizontalGroup:new{ align = "top" }
        for col = 1, cols do
            local entry = page_items[i]
            if entry then
                table.insert(row, cellWidget(entry, widths[col], metrics))
            else
                table.insert(row, HorizontalSpan:new{ width = widths[col] })
            end
            i = i + 1
        end
        table.insert(rows, row)
    end
    return rows
end

function IconShowcase:init()
    local size = Screen:getSize()
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.page = self.page or 0
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.NextPage = { { Device.input.group.PgFwd } }
        self.key_events.PrevPage = { { Device.input.group.PgBack } }
    end
    if Device:isTouchDevice() then
        local range = Geom:new{ w = size.w, h = size.h }
        self.ges_events.SwipePage = {
            GestureRange:new{ ges = "swipe", range = range },
        }
    end
    self:build()
end

function IconShowcase:pageCount(page_size)
    local n = #catalogItems()
    if page_size <= 0 then
        return 1
    end
    return math.max(1, math.ceil(n / page_size))
end

function IconShowcase:build()
    local width = self.dimen.w
    local height = self.dimen.h
    local items = catalogItems()
    local close = function()
        self:onClose()
    end
    local bar = ActionBar:new{
        title = T(_("Icons · %1"), tostring(#items)),
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
    local footer_h = pt(Theme.dim.footer_height)
    local pad_h = pt(Theme.pad.page_horizontal)
    local inner_w = math.max(0, width - 2 * pad_h)
    local grid_h = math.max(0, height - bar_h - footer_h)
    local metrics = cellMetrics()
    local cols = columnCount(inner_w)
    local rows = math.max(1, math.floor(grid_h / metrics.height))
    local page_size = cols * rows
    local page_count = self:pageCount(page_size)
    local page = self.page or 0
    if page > page_count - 1 then
        page = page_count - 1
    end
    if page < 0 then
        page = 0
    end
    self.page = page
    self._page_count = page_count
    local start_idx = page * page_size + 1
    local page_items = {}
    for i = start_idx, math.min(start_idx + page_size - 1, #items) do
        page_items[#page_items + 1] = items[i]
    end
    local widths = splitWidths(inner_w, cols)
    local grid = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        padding_left = pad_h,
        padding_right = pad_h,
        margin = 0,
        width = width,
        height = grid_h,
        background = Theme.color.white,
        TopContainer:new{
            dimen = Geom:new{ w = inner_w, h = grid_h },
            gridWidget(page_items, widths, cols, metrics),
        },
    }
    local footer = PageIndicator:new{
        page = page,
        page_count = page_count,
        on_page = function(next_page)
            self:setPage(next_page)
        end,
        width = width,
        height = footer_h,
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
            grid,
            footer,
        },
    }
end

function IconShowcase:rebuild()
    if self[1] and self[1].free then
        self[1]:free()
    end
    self:build()
    UIManager:setDirty(self, "ui")
end

function IconShowcase:setPage(page)
    local page_count = self._page_count or 1
    if page < 0 then
        page = 0
    end
    if page > page_count - 1 then
        page = page_count - 1
    end
    if page == self.page then
        return
    end
    self.page = page
    self:rebuild()
end

function IconShowcase:onNextPage()
    self:setPage((self.page or 0) + 1)
    return true
end

function IconShowcase:onPrevPage()
    self:setPage((self.page or 0) - 1)
    return true
end

function IconShowcase:onSwipePage(_, ges)
    local direction = BD.flipDirectionIfMirroredUILayout(ges and ges.direction)
    if direction == "west" then
        self:onNextPage()
        return true
    elseif direction == "east" then
        self:onPrevPage()
        return true
    end
    return true
end

function IconShowcase:onSetDimensions(dimen)
    if self.dimen and self.dimen.w == dimen.w and self.dimen.h == dimen.h then
        return
    end
    self.dimen = dimen
    self:rebuild()
    UIManager:setDirty(self, "full")
end

function IconShowcase:onShow()
    UIManager:setDirty(self, "full")
    return true
end

function IconShowcase:onCloseWidget()
    UIManager:setDirty(nil, "full")
end

function IconShowcase:onClose()
    UIManager:close(self)
    return true
end

function IconShowcase.show()
    UIManager:show(IconShowcase:new{}, "full")
end

return IconShowcase

--[[--
Page dots in the footer bar. page is 0-based.

Selected dot: black, 5pt diameter. Others: #EEEEEE.
Dots are drawn with analytic (per-pixel coverage) anti-aliasing so the
small 3-4px radii on 1x/1.5x e-ink screens still read as round circles
rather than the rounded squares paintCircle produces at that size.
Dots hidden when page_count <= 1; footer height is still reserved.
]]

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local Spacer = require("ui/uikit/components/layout/spacer")
local TapCell = require("ui/common/tap_cell")
local Theme = require("ui/uikit/components/theme")
local Widget = require("ui/widget/widget")
local pt = Theme.pt
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local DotWidget = Widget:extend{
    diameter = 5,
    color = Blitbuffer.COLOR_BLACK,
}

function DotWidget:init()
    local d = math.max(2, math.floor((self.diameter or 5) + 0.5))
    -- Even diameter keeps the filled circle symmetric on the pixel grid.
    if d % 2 == 1 then
        d = d + 1
    end
    self._diameter = d
    -- Geometric radius sits on the pixel-corner grid: for an even diameter the
    -- true centre is the shared corner of the four middle pixels, so the edge
    -- is exactly d/2 away from that corner (not from a pixel centre).
    self._radius = d / 2
    self.dimen = Geom:new{ w = d, h = d }
end

--- Base color as ColorRGB32 so we can modulate alpha for edge coverage.
--- paintCircle only steps on whole pixels, which makes 3-4px dots (1x/1.5x
--- e-ink) look like rounded squares. Analytic coverage keeps them round.
function DotWidget:_rgb32()
    -- Never compare the cached cdata color with `==`: the color __eq metamethod
    -- calls getColorRGB32() on the other operand, so `base == nil` would crash.
    if not self._base_rgb32_ready then
        local ok, c = pcall(function() return self.color:getColorRGB32() end)
        self._base_rgb32 = ok and c or Blitbuffer.ColorRGB32(0, 0, 0, 0xFF)
        self._base_rgb32_ready = true
    end
    return self._base_rgb32
end

function DotWidget:paintTo(bb, x, y)
    local d = self._diameter or math.floor((self.dimen.w or 0) + 0.5)
    local r = self._radius or d / 2
    if r < 1 then return end

    -- Circle centre sits on the pixel-corner grid (integer for even d).
    local cx = x + r
    local cy = y + r
    local base = self:_rgb32()
    local br, bg, bb_c, ba = base:getR(), base:getG(), base:getB(), base:getAlpha()

    -- 1px-wide analytic edge: full inside r-0.5, empty past r+0.5, linear
    -- coverage in between. Approximates true pixel-area coverage cheaply.
    local inner = r - 0.5
    local outer = r + 0.5
    local span = outer - inner

    for py = 0, d - 1 do
        -- Sample at pixel centres (x+0.5, y+0.5) relative to the dot origin.
        local dy = (y + py + 0.5) - cy
        for px = 0, d - 1 do
            local dx = (x + px + 0.5) - cx
            local dist = math.sqrt(dx * dx + dy * dy)
            local coverage
            if dist <= inner then
                coverage = 1
            elseif dist >= outer then
                coverage = 0
            else
                coverage = (outer - dist) / span
            end
            if coverage > 0 then
                local a = math.floor(ba * coverage + 0.5)
                if a >= 0xFF then
                    bb:setPixel(x + px, y + py, base)
                elseif a > 0 then
                    bb:setPixelBlend(x + px, y + py,
                        Blitbuffer.ColorRGB32(br, bg, bb_c, a))
                end
            end
        end
    end
end

local PageIndicator = WidgetContainer:extend{
    page = 0,
    page_count = 1,
    on_page = nil,
    width = nil,
    height = nil,
    max_buttons = 7,
    gap = nil,
    dot_size = nil,
    selected_color = nil,
    idle_color = nil,
}

local function window(page, page_count, max_n)
    if page_count <= max_n then
        return 0, page_count - 1
    end
    local half = math.floor(max_n / 2)
    local first = page - half
    local last = first + max_n - 1
    if first < 0 then
        first = 0
        last = max_n - 1
    end
    if last > page_count - 1 then
        last = page_count - 1
        first = last - max_n + 1
    end
    return first, last
end

local function dot(index, current, opts)
    local selected = index == current
    local diameter = opts.dot_size
    local color = selected and opts.selected_color or opts.idle_color
    local circle = DotWidget:new{
        diameter = diameter,
        color = color,
    }
    local size = circle:getSize()
    return TapCell:new{
        width = size.w,
        height = size.h,
        callback = (not selected) and opts.callback or nil,
        content = circle,
    }
end

local function emptyFooter(self, width, height)
    -- FrameContainer:getSize() requires a child widget even when the footer
    -- is visually empty (single-page libraries).
    local w = math.max(1, math.floor((width or 0) + 0.5))
    local h = math.max(1, math.floor((height or 0) + 0.5))
    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        width = width,
        height = height,
        background = self.background or Theme.color.white,
        Widget:new{ dimen = Geom:new{ w = w, h = h } },
    }
end

function PageIndicator:init()
    local page_count = self.page_count or 1
    local height = self.height or pt(Theme.pad.page_horizontal)
    local width = self.width

    if page_count <= 1 then
        emptyFooter(self, width, height)
        return
    end

    local page = self.page or 0
    if page < 0 then page = 0 end
    if page > page_count - 1 then page = page_count - 1 end
    local tokens = {
        dot_size = self.dot_size or pt(Theme.dim.page_dot),
        selected_color = self.selected_color or Theme.color.black,
        idle_color = self.idle_color or Theme.color.gray_e,
    }
    local first, last = window(page, page_count, self.max_buttons or 7)
    local row = HorizontalGroup:new{ align = "center" }
    local gap = self.gap
    if gap == nil then
        gap = pt(Theme.dim.page_dot_gap)
    end
    for i = first, last do
        if i > first and gap > 0 then
            table.insert(row, Spacer.horizontal(gap))
        end
        local index = i
        tokens.callback = self.on_page and function()
            self.on_page(index)
        end
        table.insert(row, dot(index, page, tokens))
    end

    self[1] = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        margin = 0,
        width = width,
        height = height,
        background = self.background or Theme.color.white,
        CenterContainer:new{
            dimen = Geom:new{ w = width or math.floor((row:getSize().w or 0) + 0.5), h = height },
            row,
        },
    }
end

return PageIndicator

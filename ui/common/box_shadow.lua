-- BoxShadow.lua
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Widget = require("ui/widget/widget")

local BoxShadow = Widget:extend({
    target_widget = nil,
    target_x = nil, target_y = nil,
    offset_x = 8, offset_y = 8,
    color = nil,
    color2 = nil,
    -- The rectangle the shadow is cast from, in design space. Only its
    -- bounding box is used (as the widget's layout size) unless `dimen` is
    -- given explicitly; the actual shadow polygon is derived at paint time
    -- from that size plus offset_x/offset_y.
    shape = {
        {0, 0}, {150, 0}, {150, 200}, {0, 200},
    },
})

function BoxShadow:init()
    if not self.shape or #self.shape < 3 then
        error("BoxShadow: shape 必须包含 at least 3 个顶点")
    end
    local min_x, max_x = self.shape[1][1], self.shape[1][1]
    local min_y, max_y = self.shape[1][2], self.shape[1][2]
    for i = 2, #self.shape do
        local px, py = self.shape[i][1], self.shape[i][2]
        if px < min_x then min_x = px end
        if px > max_x then max_x = px end
        if py < min_y then min_y = py end
        if py > max_y then max_y = py end
    end
    if self.dimen then
        self.width = self.dimen.w
        self.height = self.dimen.h
    else
        self.width = max_x - min_x
        self.height = max_y - min_y
        -- 关键：布局系统读的是 self.dimen
        self.dimen = Geom:new{ w = self.width, h = self.height }
    end

    -- All Blitbuffer.COLOR_* constants are already Color8 cdata objects
    -- (never raw numbers), so no conversion is needed.
    self._color = self.color or Blitbuffer.COLOR_BLACK
    self._color2 = self.color2 or self._color
end

-- 布局容器（HorizontalGroup 等）会调用此方法把可用空间传下来
function BoxShadow:propagateSize(dimen)
    if dimen then
        self.dimen = dimen
        self.width = dimen.w
        self.height = dimen.h
    end
end

function BoxShadow:getSize()
    return self.dimen or Geom:new{ w = self.width, h = self.height }
end

function BoxShadow:getTargetPos()
    if self.target_widget then
        return self.target_widget.x or 0, self.target_widget.y or 0
    end
    return self.target_x or 0, self.target_y or 0
end

local function drawLine(bb, x0, y0, x1, y1, color)
    x0, y0, x1, y1 = math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)
    local dx = math.abs(x1 - x0); local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1; local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    while true do
        bb:paintRect(x0, y0, 1, 1, color)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 > -dy then err = err - dy; x0 = x0 + sx end
        if e2 < dx then err = err + dx; y0 = y0 + sy end
    end
end

local function fillPolygon(bb, ox, oy, points, color)
    local n = #points
    if n < 3 then return end
    local min_y, max_y = points[1][2], points[1][2]
    for i = 2, n do
        if points[i][2] < min_y then min_y = points[i][2] end
        if points[i][2] > max_y then max_y = points[i][2] end
    end
    for y = min_y, max_y do
        local intersections = {}
        for i = 1, n do
            local p1, p2 = points[i], points[i % n + 1]
            if p1[2] ~= p2[2] then
                if p1[2] > p2[2] then p1, p2 = p2, p1 end
                if y > p1[2] and y <= p2[2] then
                    local x = p1[1] + (y - p1[2]) * (p2[1] - p1[1]) / (p2[2] - p1[2])
                    intersections[#intersections + 1] = math.floor(x + 0.5)
                end
            end
        end
        if #intersections > 1 then
            table.sort(intersections)
            local uniq = { intersections[1] }
            for i = 2, #intersections do
                if intersections[i] ~= intersections[i - 1] then
                    uniq[#uniq + 1] = intersections[i]
                end
            end
            for i = 1, #uniq - 1, 2 do
                local x0, x1 = uniq[i], uniq[i + 1]
                if x1 > x0 then
                    bb:paintRect(ox + x0, oy + y, x1 - x0, 1, color)
                end
            end
        end
    end
end

-- 投射阴影：把源矩形 (0,0)-(w,h) 和它的偏移副本
-- (ox,oy)-(ox+w,oy+h) 拆成两个四边形：
--   1) 左侧竖条 (0,0) (ox,oy) (ox,oy+h) (0,h)     → color
--   2) 底部横条 (ox,oy+h) (ox+w,oy+h) (w,h) (0,h) → color2
-- 竖条和横条共用边 (ox,oy+h)-(0,h)，合起来就是原来的 6 点投射阴影。
function BoxShadow:paintTo(bb, x, y)
    local tx, ty = self:getTargetPos()
    local ox = tx + self.offset_x
    local oy = ty + self.offset_y
    local w, h = self.width, self.height
    local vertical = {
        {0, 0},
        {ox, oy},
        {ox, oy + h},
        {0, h},
    }
    local horizontal = {
        {ox, oy + h},
        {ox + w, oy + h},
        {w, h},
        {0, h},
    }
    fillPolygon(bb, x, y, vertical, self._color)
    fillPolygon(bb, x, y, horizontal, self._color2)

    local function outline(poly, color)
        local n = #poly
        for i = 1, n do
            local p1, p2 = poly[i], poly[i % n + 1]
            drawLine(bb,
                x + p1[1], y + p1[2],
                x + p2[1], y + p2[2],
                color)
        end
    end
    outline(vertical, self._color)
    outline(horizontal, self._color2)
end

return BoxShadow

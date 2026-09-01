--[[--
continue_cover.lua — Cover column for the Continue hero. Builds the book cover
with its adaptive cast shadow centered inside the gray cover column, and wraps
the whole Continue row in the outer slot container (absorbing the former
continue_center indirection).
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookCover = require("ui/library/book_cover")
local BoxShadow = require("ui/common/box_shadow")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local TopContainer = require("ui/widget/container/topcontainer")

local ContinueCover = {}

--- Build the cover column: the bare cover plus its adaptive cast shadow,
--- centered inside the gray column (cover_col_w × col_h).
--- @param filepath string
--- @param metrics table layout metrics
--- @return table cover column widget
function ContinueCover.build(filepath, metrics)
    local col_h = metrics.cover_col_h or metrics.continue_content_h

    -- 1) Build the bare cover (white bg + image, no border, no shadow yet)
    local cover_w = metrics.cover_w
    local cover_h = metrics.cover_h
    local cover = BookCover.build(filepath, cover_w, cover_h, nil, Layout.COLOR_COVER_BORDER)

    -- 2) Wrap cover with BoxShadow (the shared polygon-based module).
    --    BoxShadow derives a 6-point cast-shadow polygon from the cover size
    --    and the offset: the cover rect (0,0)-(cover_w,cover_h) connected to
    --    its offset copy via the top-left and bottom-right corners, so the
    --    shadow visibly attaches to the cover's corners (P1 = cover top-left,
    --    P5 = cover bottom-right, P6 = cover bottom-left).
    --
    -- The widget that visually wraps the cover is the cover column
    -- (cover_col_w × col_h, cover_h_pad side padding, cover centered inside).
    -- Compute how much room the cover actually has on each side inside that
    -- widget; the shadow offset mirrors that inset, so the shadow reaches
    -- exactly the column's edges (e.g. bg 140×260 with a centered 100×200
    -- cover → ox = -(140-100)/2 = -20, oy = (260-200)/2 = 30).
    local cover_inner_w = metrics.cover_col_w - 2 * metrics.cover_h_pad
    if cover_inner_w < 0 then cover_inner_w = 0 end
    local cover_inner_h = col_h
    if cover_inner_h < 0 then cover_inner_h = 0 end
    local cover_cx = math.floor((cover_inner_w - cover_w) / 2)
    local cover_cy = math.floor((cover_inner_h - cover_h) / 2)
    local space_left   = metrics.cover_h_pad + cover_cx
    local space_bottom = (cover_inner_h - cover_h) - cover_cy
    local shadow_ox = -space_left
    local shadow_oy = space_bottom
    local shadow = BoxShadow:new{
        dimen = Geom:new{ w = cover_w, h = cover_h },
        offset_x = shadow_ox,
        offset_y = shadow_oy,
        color = Layout.COLOR_COVER_SHADOW_1,
        color2 = Layout.COLOR_COVER_SHADOW_2,
    }

    -- 3) Wrapper dimen matches the bare cover exactly → CenterContainer puts
    --    the cover at THE SAME centered position as before (requirement #2).
    --    The shadow offset mirrors the cover's insets in the column, so the
    --    shadow stays inside the column and reaches its edges.
    local cover_with_shadow = OverlapGroup:new{
        dimen = Geom:new{ w = cover_w, h = cover_h },
        allow_mirroring = false,
        shadow,  -- painted first (bottom layer, drawn at offset)
        cover,   -- painted second (on top, at wrapper's top-left origin)
    }

    return FrameContainer:new{
        background = Layout.COLOR_COVER_BG,
        bordersize = 0,
        padding = 0,
        padding_left = metrics.cover_h_pad,
        padding_right = metrics.cover_h_pad,
        dimen = Geom:new{ w = metrics.cover_col_w, h = col_h },
        CenterContainer:new{
            dimen = Geom:new{ w = cover_inner_w, h = cover_inner_h },
            cover_with_shadow,
        },
    }
end

--- Wrap the whole Continue row in the outer slot container.
--- @param content table inner Continue content widget
--- @param metrics table layout metrics (continue_slot_h, continue_content_h,
---   content_w)
--- @return table
function ContinueCover.wrap(content, metrics)
    local inner_h = metrics.continue_content_h
    if inner_h < 0 then inner_h = 0 end
    local slot = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
        TopContainer:new{
            dimen = Geom:new{ w = metrics.content_w, h = inner_h },
            content,
        },
    }
    -- 1px light-gray bottom border for the whole Continue section, drawn over
    -- the slot's bottom edge pixels so the slot footprint is unchanged.
    local bottom_border = LineWidget:new{
        dimen = Geom:new{ w = metrics.content_w, h = Layout.dim.border },
        background = Layout.COLOR_COVER_BORDER,
        overlap_offset = { 0, metrics.continue_slot_h - 1 },
    }
    return OverlapGroup:new{
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_slot_h },
        allow_mirroring = false,
        slot,
        bottom_border,
    }
end

return ContinueCover

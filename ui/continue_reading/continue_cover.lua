--[[--
continue_cover.lua — Cover column for the Continue hero. Builds the book cover
with its adaptive cast shadow centered inside the gray cover column, and wraps
the whole Continue row in the outer slot container (absorbing the former
continue_center indirection).
--]]

local BookCover = require("ui/library/book_cover")
local BoxShadow = require("ui/common/box_shadow")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local TopContainer = require("ui/widget/container/topcontainer")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local ContinueCover = {}

--- Build the cover column: the bare cover plus its adaptive cast shadow,
--- centered inside the gray column (cover_column_width × column_height).
--- @param filepath string
--- @param metrics table layout metrics
--- @return table cover column widget
function ContinueCover.build(filepath, metrics)
    local column_height = metrics.cover_column_height or metrics.continue_content_height

    -- 1) Build the bare cover (white bg + image, no border, no shadow yet)
    local cover_width = metrics.cover_width
    local cover_height = metrics.cover_height
    local cover = BookCover.build(filepath, cover_width, cover_height, nil, Layout.COLOR_COVER_BORDER)

    -- 2) Wrap cover with BoxShadow (the shared polygon-based module).
    --    BoxShadow derives a 6-point cast-shadow polygon from the cover size
    --    and the offset: the cover rect (0,0)-(cover_width,cover_height) connected to
    --    its offset copy via the top-left and bottom-right corners, so the
    --    shadow visibly attaches to the cover's corners (P1 = cover top-left,
    --    P5 = cover bottom-right, P6 = cover bottom-left).
    --
    -- The widget that visually wraps the cover is the cover column
    -- (cover_column_width × column_height, side padding, cover top-aligned).
    -- Shadow offset mirrors the insets so it reaches the column's left and
    -- bottom edges.
    local cover_inner_width = math.max(0, math.floor(
        metrics.cover_column_width - 2 * metrics.cover_horizontal_padding))
    local pad_top = metrics.cover_top_padding or metrics.cover_horizontal_padding
    local pad_bottom = metrics.cover_bottom_padding or metrics.cover_horizontal_padding
    local cover_inner_height = math.max(0, math.floor((column_height or 0) - pad_top - pad_bottom))
    local cover_cx = math.floor((cover_inner_width - cover_width) / 2)
    local space_left   = metrics.cover_horizontal_padding + cover_cx
    local space_bottom = math.max(0, cover_inner_height - cover_height)
    local shadow_ox = -space_left
    local shadow_oy = space_bottom
    local shadow = BoxShadow:new{
        dimen = Geom:new{ w = cover_width, h = cover_height },
        offset_x = shadow_ox,
        offset_y = shadow_oy,
        color = Layout.COLOR_COVER_SHADOW_1,
        color2 = Layout.COLOR_COVER_SHADOW_2,
    }

    -- Wrapper dimen matches the bare cover. align=top keeps horizontal centering
    -- without a top inset.
    local cover_with_shadow = OverlapGroup:new{
        dimen = Geom:new{ w = cover_width, h = cover_height },
        allow_mirroring = false,
        shadow,  -- painted first (bottom layer, drawn at offset)
        cover,   -- painted second (on top, at wrapper's top-left origin)
    }

    return FrameContainer:new{
        background = Layout.COLOR_COVER_BG,
        bordersize = 0,
        padding = 0,
        padding_left = metrics.cover_horizontal_padding,
        padding_right = metrics.cover_horizontal_padding,
        padding_top = pad_top,
        padding_bottom = pad_bottom,
        dimen = Geom:new{ w = metrics.cover_column_width, h = column_height },
        WidgetContainer:new{
            dimen = Geom:new{ w = cover_inner_width, h = cover_inner_height },
            align = "top",
            cover_with_shadow,
        },
    }
end

--- Wrap the whole Continue row in the outer slot container.
--- @param content table inner Continue content widget
--- @param metrics table layout metrics (continue_slot_height, continue_content_height,
---   content_width)
--- @return table
function ContinueCover.wrap(content, metrics)
    local inner_height = metrics.continue_content_height
    if inner_height < 0 then inner_height = 0 end
    local slot = FrameContainer:new{
        bordersize = 0,
        padding = 0,
        dimen = Geom:new{ w = metrics.content_width, h = metrics.continue_slot_height },
        TopContainer:new{
            dimen = Geom:new{ w = metrics.content_width, h = inner_height },
            content,
        },
    }
    -- Full-width bottom rule between Continue and Library (edge to edge).
    local line_height = pt(Layout.dim.border)
    local bottom_border = LineWidget:new{
        dimen = Geom:new{ w = metrics.content_width, h = line_height },
        background = Layout.COLOR_COVER_BORDER,
        overlap_offset = { 0, metrics.continue_slot_height - line_height },
    }
    return OverlapGroup:new{
        dimen = Geom:new{ w = metrics.content_width, h = metrics.continue_slot_height },
        allow_mirroring = false,
        slot,
        bottom_border,
    }
end

return ContinueCover

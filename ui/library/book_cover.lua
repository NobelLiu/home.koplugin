--[[--
book_cover.lua — Book cover widget (includes a no-cover placeholder and a
light inner-border overlay that does not affect layout).
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local Layout = require("ui/common/layout")
local OverlapGroup = require("ui/widget/overlapgroup")
local Widget = require("ui/widget/widget")

local BookCover = {}

local function borderSize()
    return Layout.dim.border
end

local SolidRect = Widget:extend{ color = Layout.COLOR_PLACEHOLDER }

function SolidRect:init()
    self.dimen = self.dimen or Geom:new{ w = 1, h = 1 }
end

function SolidRect:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, self.color)
end

local CoverBorder = Widget:extend{
    border_color = Layout.COLOR_COVER_BORDER,
}

function CoverBorder:init()
    self.dimen = self.border_dimen or Geom:new{ w = 1, h = 1 }
    self.bordersize = self.bordersize or borderSize()
end

function CoverBorder:paintTo(bb, x, y)
    bb:paintInnerBorder(x, y, self.dimen.w, self.dimen.h,
        self.bordersize, self.border_color, 0)
end

local function wrapWithBorder(inner_widget, w, h, border_color)
    local border = borderSize()
    local cover_dimen = Geom:new{ w = w, h = h }
    local cover = OverlapGroup:new{
        dimen = cover_dimen,
        allow_mirroring = false,
        SolidRect:new{ dimen = cover_dimen, color = Blitbuffer.COLOR_WHITE },
        inner_widget,
    }
    if border_color then
        cover[#cover + 1] = CoverBorder:new{
            border_dimen = cover_dimen,
            bordersize = border,
            border_color = border_color,
        }
    end
    return cover
end

local function placeholder(w, h, border_color)
    return wrapWithBorder(
        SolidRect:new{ dimen = Geom:new{ w = w, h = h }, color = Layout.COLOR_PLACEHOLDER },
        w, h, border_color)
end

local function coverScaleFactor(bb, w, h)
    local bb_w, bb_h = bb:getWidth(), bb:getHeight()
    if bb_w <= 0 or bb_h <= 0 then return 1 end
    return math.max(w / bb_w, h / bb_h)
end

--- @param meta table|nil pass in to avoid a duplicate metadata lookup
--- @param border_color Blitbuffer color for the cover's inner border;
---   when nil, no border is drawn
function BookCover.build(filepath, w, h, meta, border_color)
    meta = meta or BookRepository.getBookMeta(filepath)
    local cover_wg

    local ok_bim, BIM = pcall(require, "bookinfomanager")
    if ok_bim and BIM then
        local ok, bi = pcall(BIM.getBookInfo, BIM, filepath, true)
        if ok and bi and bi.cover_bb then
            local ok_img, img = pcall(ImageWidget.new, ImageWidget, {
                image = bi.cover_bb,
                image_disposable = false,
                width = w,
                height = h,
                scale_factor = coverScaleFactor(bi.cover_bb, w, h),
            })
            if ok_img and img then cover_wg = img end
        end
    end

    if not cover_wg then
        return placeholder(w, h, border_color)
    end

    return wrapWithBorder(cover_wg, w, h, border_color)
end

return BookCover

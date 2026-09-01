--[[--
folder_cover.lua — Folder cover widget: same outer frame/aspect as a book
cover, split by a center cross into four quadrants that show covers of the
books filtered from the subfolder (cover-bearing books first, remaining
quadrants filled with placeholders).
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local Layout = require("ui/common/layout")
local OverlapGroup = require("ui/widget/overlapgroup")
local Widget = require("ui/widget/widget")

local FolderCover = {}

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

local function coverScaleFactor(bb, w, h)
    local bb_w, bb_h = bb:getWidth(), bb:getHeight()
    if bb_w <= 0 or bb_h <= 0 then return 1 end
    return math.max(w / bb_w, h / bb_h)
end

--- One quadrant: a scaled cover image if the book has one, otherwise a
--- placeholder rect. Positioned via overlap_offset inside the OverlapGroup.
local function quadrant(filepath, qw, qh, ox, oy)
    if filepath then
        local ok_bim, BIM = pcall(require, "bookinfomanager")
        if ok_bim and BIM then
            local ok, bi = pcall(BIM.getBookInfo, BIM, filepath, true)
            if ok and bi and bi.cover_bb then
                local ok_img, img = pcall(ImageWidget.new, ImageWidget, {
                    image = bi.cover_bb,
                    image_disposable = false,
                    width = qw,
                    height = qh,
                    scale_factor = coverScaleFactor(bi.cover_bb, qw, qh),
                    overlap_offset = { ox, oy },
                })
                if ok_img and img then return img end
            end
        end
    end
    return SolidRect:new{
        dimen = Geom:new{ w = qw, h = qh },
        color = Layout.COLOR_PLACEHOLDER,
        overlap_offset = { ox, oy },
    }
end

--- @param dir string subfolder path
--- @param w number cover width (scaled)
--- @param h number cover height (scaled)
--- @param sort_mode string|nil "recent"|"name"
function FolderCover.build(dir, w, h, sort_mode)
    local border = borderSize()
    local cover_dimen = Geom:new{ w = w, h = h }

    -- Center cross gap; quadrants split the remaining space evenly.
    local gap = math.max(1, Layout.dim.divider)
    local qw = math.floor((w - gap) / 2)
    local qh = math.floor((h - gap) / 2)
    local x2 = w - qw
    local y2 = h - qh

    local books = BookRepository.getFolderCoverBooks(dir, sort_mode, 4)

    local cover = OverlapGroup:new{
        dimen = cover_dimen,
        allow_mirroring = false,
        SolidRect:new{ dimen = cover_dimen, color = Blitbuffer.COLOR_WHITE },
        quadrant(books[1], qw, qh, 0, 0),
        quadrant(books[2], qw, qh, x2, 0),
        quadrant(books[3], qw, qh, 0, y2),
        quadrant(books[4], qw, qh, x2, y2),
    }
    -- The folder cover itself has no border; instead each sub-cover gets its
    -- own light-gray inner border (same style as book covers), drawn on top of
    -- its quadrant.
    local quadrant_offsets = { { 0, 0 }, { x2, 0 }, { 0, y2 }, { x2, y2 } }
    for _, off in ipairs(quadrant_offsets) do
        cover[#cover + 1] = CoverBorder:new{
            border_dimen = Geom:new{ w = qw, h = qh },
            bordersize = border,
            border_color = Layout.COLOR_COVER_BORDER,
            overlap_offset = { off[1], off[2] },
        }
    end

    return cover
end

return FolderCover

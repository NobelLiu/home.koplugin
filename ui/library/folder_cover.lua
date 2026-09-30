--[[--
folder_cover.lua — Folder cover widget: same outer frame/aspect as a book
cover, split by a center cross into four quadrants. Book cover images fill
first; remaining quadrants use the missing-cover placeholder with the
folder title.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookCover = require("ui/library/book_cover")
local BookRepository = require("book_repository")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local OverlapGroup = require("ui/widget/overlapgroup")
local Widget = require("ui/widget/widget")

local FolderCover = {}

local SolidRect = Widget:extend{ color = Layout.COLOR_PLACEHOLDER }

function SolidRect:init()
    self.dimen = self.dimen or Geom:new{ w = 1, h = 1 }
end

function SolidRect:paintTo(bb, x, y)
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, self.color)
end

--- One quadrant: a book cover image, or the folder-title placeholder.
--- Positioned via overlap_offset inside the OverlapGroup.
local function quadrant(filepath, qw, qh, ox, oy, folder_meta)
    local cover = filepath
        and BookCover.build(filepath, qw, qh, nil, Layout.COLOR_COVER_BORDER)
        or BookCover.build(nil, qw, qh, folder_meta, Layout.COLOR_COVER_BORDER)
    cover.overlap_offset = { ox, oy }
    return cover
end

--- @param dir string subfolder path
--- @param w number cover width (scaled)
--- @param h number cover height (scaled)
--- @param sort_mode string|nil BookList.collates id (e.g. "strcoll", "access")
--- @param name string|nil folder title for leftover placeholder slots
function FolderCover.build(dir, w, h, sort_mode, name)
    local cover_dimen = Geom:new{ w = w, h = h }
    local folder_meta = { title = name or dir:match("([^/]+)$") or dir }

    -- Center cross gap; quadrants split the remaining space evenly.
    local gap = math.max(Layout.px(1), pt(Layout.dim.divider))
    local qw = math.floor((w - gap) / 2)
    local qh = math.floor((h - gap) / 2)
    local x2 = math.floor(w - qw)
    local y2 = math.floor(h - qh)

    local books = BookRepository.getFolderCoverBooks(dir, sort_mode, 4)

    return OverlapGroup:new{
        dimen = cover_dimen,
        allow_mirroring = false,
        SolidRect:new{ dimen = cover_dimen, color = Blitbuffer.COLOR_WHITE },
        quadrant(books[1], qw, qh, 0, 0, folder_meta),
        quadrant(books[2], qw, qh, x2, 0, folder_meta),
        quadrant(books[3], qw, qh, 0, y2, folder_meta),
        quadrant(books[4], qw, qh, x2, y2, folder_meta),
    }
end

return FolderCover

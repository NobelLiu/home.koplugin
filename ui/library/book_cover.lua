--[[--
book_cover.lua — Book cover widget (includes a no-cover placeholder and a
light inner-border overlay that does not affect layout).
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")

local BookCover = {}

-- Missing-cover art is designed at 100×140. Type and padding scale with the
-- rendered cover (library cell, Continue hero, etc.).
local PLACEHOLDER_DESIGN_W = 100
local PLACEHOLDER_TITLE_SIZE = 6
local PLACEHOLDER_TITLE_LEADING = 7
local PLACEHOLDER_TITLE_LINES = 2
local PLACEHOLDER_AUTHOR_SIZE = 5
local PLACEHOLDER_AUTHOR_LEADING = 6
local PLACEHOLDER_PAD = 10

local function borderSize()
    return pt(Layout.dim.border)
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

--- Face that renders at `px` device pixels (Font:getFace still applies scaleBySize).
local function faceAtPx(font, px)
    px = math.floor((px or 0) + 0.5)
    if px < 1 then px = 1 end
    local sample = Device.screen:scaleBySize(100)
    local size = px
    if sample and sample > 0 then
        size = px * 100 / sample
    end
    if size < 1 then size = 1 end
    return Layout.theme().getFace(font, size)
end

local function scalePx(n, scale)
    local v = math.floor(n * scale + 0.5)
    if n > 0 and v < 1 then
        return 1
    end
    return v
end

local function oneLine(text)
    if type(text) ~= "string" then
        return ""
    end
    return (text:gsub("[%s\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lineHeightEm(face, leading_px)
    local size = face and face.size or 0
    if size <= 0 then
        return 0
    end
    local em = (leading_px / size) - 1
    if em < 0 then
        return 0
    end
    return em
end

local function placeholder(w, h, border_color, meta)
    meta = meta or {}
    local scale = (w > 0) and (w / PLACEHOLDER_DESIGN_W) or 1
    local gray_h = math.floor(h * Layout.PHI + 0.5)
    if gray_h < 1 then gray_h = math.min(1, h) end
    if gray_h > h then gray_h = h end
    local white_h = h - gray_h

    local pad_h = scalePx(PLACEHOLDER_PAD, scale)
    if pad_h * 2 >= w then
        pad_h = math.max(0, math.floor((w - 1) / 2))
    end
    local pad_bottom = scalePx(PLACEHOLDER_PAD, scale)
    if pad_bottom >= gray_h then
        pad_bottom = math.max(0, gray_h - 1)
    end
    local text_w = math.max(1, w - 2 * pad_h)

    local font = Layout.theme().font.semibold
        or Layout.theme().font.medium
        or Layout.theme().font.regular
        or "cfont"

    local title_text = oneLine(meta.title)
    local author_text = oneLine(meta.authors)

    local white = OverlapGroup:new{
        dimen = Geom:new{ w = w, h = white_h },
        allow_mirroring = false,
        SolidRect:new{
            dimen = Geom:new{ w = w, h = white_h },
            color = Blitbuffer.COLOR_WHITE,
        },
    }
    if title_text ~= "" and white_h > 0 and text_w > 0 then
        local title_face = faceAtPx(font, scalePx(PLACEHOLDER_TITLE_SIZE, scale))
        local title_leading = scalePx(PLACEHOLDER_TITLE_LEADING, scale)
        local title_em = lineHeightEm(title_face, title_leading)
        local title_line = math.max(1, math.floor(title_leading + 0.5))
        local title_h = math.min(white_h, title_line * PLACEHOLDER_TITLE_LINES)
        white[#white + 1] = CenterContainer:new{
            dimen = Geom:new{ w = w, h = white_h },
            TextBoxWidget:new{
                text = BD.auto(title_text),
                face = title_face,
                bold = false,
                fgcolor = Blitbuffer.COLOR_BLACK,
                bgcolor = Blitbuffer.COLOR_WHITE,
                width = text_w,
                height = title_h,
                alignment = "center",
                alignment_strict = true,
                line_height = title_em,
                height_adjust = true,
                height_overflow_show_ellipsis = true,
            },
        }
    end

    local gray = OverlapGroup:new{
        dimen = Geom:new{ w = w, h = gray_h },
        allow_mirroring = false,
        SolidRect:new{
            dimen = Geom:new{ w = w, h = gray_h },
            color = Blitbuffer.COLOR_GRAY_D,
        },
    }
    if author_text ~= "" and gray_h > 0 and text_w > 0 then
        local author_face = faceAtPx(font, scalePx(PLACEHOLDER_AUTHOR_SIZE, scale))
        local author_leading = scalePx(PLACEHOLDER_AUTHOR_LEADING, scale)
        local author_h = math.max(1, math.floor(author_leading + 0.5))
        local author_label = TextBoxWidget:new{
            text = BD.auto(author_text),
            face = author_face,
            bold = false,
            fgcolor = Blitbuffer.COLOR_BLACK,
            bgcolor = Blitbuffer.COLOR_GRAY_D,
            width = text_w,
            height = author_h,
            alignment = "center",
            alignment_strict = true,
            line_height = lineHeightEm(author_face, author_leading),
            height_overflow_show_ellipsis = true,
        }
        local author_block = author_label
        if pad_bottom > 0 then
            author_block = VerticalGroup:new{
                align = "center",
                author_label,
                VerticalSpan:new{ width = pad_bottom },
            }
        end
        gray[#gray + 1] = BottomContainer:new{
            dimen = Geom:new{ w = w, h = gray_h },
            author_block,
        }
    end

    return wrapWithBorder(
        VerticalGroup:new{
            align = "left",
            allow_mirroring = false,
            white,
            gray,
        },
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
    local cover_wg
    if filepath then
        meta = meta or BookRepository.getBookMeta(filepath)
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
    end

    if cover_wg then
        return wrapWithBorder(cover_wg, w, h, border_color)
    end
    return placeholder(w, h, border_color, meta or {})
end

return BookCover

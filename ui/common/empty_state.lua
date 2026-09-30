--[[--
empty_state.lua — The empty-state widget shown when there are no books.
--]]

local BD = require("ui/bidi")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local Stack = require("ui/uikit/components/layout/stack")
local TapCell = require("ui/common/tap_cell")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local _ = require("gettext")

local EmptyState = {}

--- @param content_width number
--- @param folder_path string
--- @param on_switch_fm function|nil
function EmptyState.build(content_width, folder_path, on_switch_fm)
    local gap = pt(Layout.scaledSetting("content_gap"))

    local path_wg = TextBoxWidget:new{
        text = BD.filepath(folder_path or ""),
        face = Layout.captionFace(),
        width = content_width,
        fgcolor = require("ffi/blitbuffer").COLOR_BLACK,
        alignment = "center",
    }
    local path_h = path_wg:getSize().h

    local path_row = CenterContainer:new{
        dimen = Geom:new{ w = content_width, h = path_h },
        path_wg,
    }
    if on_switch_fm then
        path_row = TapCell.wrap(path_row, Geom:new{ w = content_width, h = path_h }, on_switch_fm)
    end

    local col = Stack:new{
        align = "center",
        gap = gap,
        children = {
            TextWidget:new{
                text = _("No books in this folder"),
                face = Layout.bodyFace(),
                fgcolor = Layout.COLOR_MUTED,
            },
            path_row,
        },
    }

    return CenterContainer:new{
        dimen = Geom:new{
            w = content_width,
            h = math.floor(col:getSize().h + pt(Layout.dim.empty_extra) + 0.5),
        },
        col,
    }
end

return EmptyState

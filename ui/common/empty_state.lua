--[[--
empty_state.lua — The empty-state widget shown when there are no books.
--]]

local BD = require("ui/bidi")
local CenterContainer = require("ui/widget/container/centercontainer")
local Geom = require("ui/geometry")
local Layout = require("ui/common/layout")
local TapCell = require("ui/common/tap_cell")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")

local EmptyState = {}

--- @param content_w number
--- @param folder_path string
--- @param on_switch_fm function|nil
function EmptyState.build(content_w, folder_path, on_switch_fm)
    local gap = Layout.scaledSetting("content_gap")

    local path_wg = TextBoxWidget:new{
        text = BD.filepath(folder_path or ""),
        face = Layout.captionFace(),
        width = content_w,
        fgcolor = require("ffi/blitbuffer").COLOR_BLACK,
        alignment = "center",
    }
    local path_h = path_wg:getSize().h

    local path_row = CenterContainer:new{
        dimen = Geom:new{ w = content_w, h = path_h },
        path_wg,
    }
    if on_switch_fm then
        path_row = TapCell.wrap(path_row, Geom:new{ w = content_w, h = path_h }, on_switch_fm)
    end

    local col = VerticalGroup:new{
        align = "center",
        TextWidget:new{
            text = _("No books in this folder"),
            face = Layout.bodyFace(),
            fgcolor = Layout.COLOR_MUTED,
        },
        VerticalSpan:new{ width = gap },
        path_row,
    }

    return CenterContainer:new{
        dimen = Geom:new{ w = content_w, h = col:getSize().h + Layout.dim.empty_extra },
        col,
    }
end

return EmptyState

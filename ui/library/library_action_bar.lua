--[[--
library_action_bar.lua — Folder back/forward, title, sort menu.
]]

local BD = require("ui/bidi")
local _ = require("gettext")

local ActionBar = require("ui/uikit/components/chrome/action_bar")
local IconButton = require("ui/uikit/components/controls/icon_button")

local LibraryActionBar = {}

local TITLE_ROLE = "subhead"
local TITLE_WEIGHT = "bold"
local ICON_ROLE = "headline"
local ICON_WEIGHT = "bold"

local function iconMeasureOpts(icon)
    return {
        icon = icon,
        icon_role = ICON_ROLE,
        icon_weight = ICON_WEIGHT,
    }
end

local function halfIconButtonWidth(icon)
    return math.floor(IconButton.naturalWidth(iconMeasureOpts(icon)) / 2)
end

function LibraryActionBar.build(opts)
    opts = opts or {}
    local back_icon = "chevron.left"
    local forward_icon = "chevron.right"
    if BD.mirroredUILayout() then
        back_icon, forward_icon = forward_icon, back_icon
    end
    local title = opts.current_title
    if not title or title == "" then
        title = _("Home")
    end
    return ActionBar:new{
        title = title,
        title_role = TITLE_ROLE,
        title_weight = TITLE_WEIGHT,
        icon_role = ICON_ROLE,
        icon_weight = ICON_WEIGHT,
        width = opts.metrics and opts.metrics.content_width,
        show_divider = false,
        leading = {
            {
                icon = back_icon,
                enabled = opts.can_back == true,
                callback = opts.on_back,
                width = halfIconButtonWidth(back_icon),
                alignment = "left",
            },
            {
                icon = forward_icon,
                enabled = opts.can_forward == true,
                callback = opts.on_forward,
                width = halfIconButtonWidth(forward_icon),
                alignment = "right",
            },
        },
        trailing = {
            {
                icon = "sort",
                callback = opts.on_sort_menu,
                width = halfIconButtonWidth("sort"),
                alignment = "right",
            },
        },
    }
end

return LibraryActionBar

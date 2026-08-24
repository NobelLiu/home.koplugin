--[[--
settings.lua — Home display mode padding settings menu.
--]]

local Layout = require("layout")
local UIManager = require("ui/uimanager")
local T = require("ffi/util").template
local _ = require("gettext")

local Settings = {}

local PADDING_ITEMS = {
    {
        key = "vstack_padding",
        label = _("Content padding: %1"),
        title = _("Content padding"),
    },
    {
        key = "section_title_v_pad",
        label = _("Section title padding: %1"),
        title = _("Section title padding"),
    },
    {
        key = "content_gap",
        label = _("Content gap: %1"),
        title = _("Content gap"),
    },
    {
        key = "section_gap",
        label = _("Section gap: %1"),
        title = _("Section gap"),
    },
    {
        key = "status_side_padding",
        label = _("Status bar horizontal padding: %1"),
        title = _("Status bar horizontal padding"),
    },
    {
        key = "status_vert_padding",
        label = _("Status bar vertical padding: %1"),
        title = _("Status bar vertical padding"),
    },
    {
        key = "continue_row_gap",
        label = _("Continue reading row gap: %1"),
        title = _("Continue reading row gap"),
    },
}

local GETTERS = {
    vstack_padding = Layout.getVstackPadding,
    section_title_v_pad = Layout.getSectionTitleVPad,
    content_gap = Layout.getContentGap,
    section_gap = Layout.getSectionGap,
    status_side_padding = Layout.getStatusSidePadding,
    status_vert_padding = Layout.getStatusVertPadding,
    continue_row_gap = Layout.getContinueRowGap,
}

local function getPaddingValue(key)
    return GETTERS[key]()
end

local function refreshHomeOverlay()
    for widget in UIManager:topdown_widgets_iter() do
        if widget and widget.name == "home_widget" and widget.refresh then
            widget:refresh()
            return
        end
    end
end

function Settings.buildPaddingMenu()
    local items = {
        {
            text = _("Debug mode"),
            separator = true,
            keep_menu_open = true,
            checked_func = function()
                return Layout.isDebugLayout()
            end,
            callback = function(touchmenu_instance)
                G_reader_settings:flipNilOrFalse(Layout.SETTING_KEYS.debug_layout)
                refreshHomeOverlay()
                if touchmenu_instance then
                    touchmenu_instance:updateItems()
                end
            end,
        },
    }
    for i, spec in ipairs(PADDING_ITEMS) do
        items[#items + 1] = {
            text_func = function()
                return T(spec.label, getPaddingValue(spec.key))
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local SpinWidget = require("ui/widget/spinwidget")
                local current = getPaddingValue(spec.key)
                UIManager:show(SpinWidget:new{
                    value = current,
                    value_min = 0,
                    value_max = 60,
                    value_step = 1,
                    value_hold_step = 5,
                    title_text = spec.title,
                    callback = function(spin)
                        G_reader_settings:saveSetting(Layout.SETTING_KEYS[spec.key], spin.value)
                        refreshHomeOverlay()
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end,
                })
            end,
        }
    end
    return items
end

function Settings.registerDisplayModeMenu(menu_items)
    if not menu_items.filemanager_display_mode then
        menu_items.filemanager_display_mode = {
            text = _("Display mode"),
            sub_item_table = {},
        }
    end

    local sub = menu_items.filemanager_display_mode.sub_item_table
    for i, item in ipairs(sub) do
        if item.text == _("Home display mode") then
            return
        end
    end

    table.insert(sub, {
        text = _("Home display mode"),
        separator = true,
        sub_item_table = Settings.buildPaddingMenu(),
    })
end

return Settings

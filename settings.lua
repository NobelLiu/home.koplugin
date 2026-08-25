--[[--
settings.lua — Home display mode settings menu (greeting text + debug mode).
--]]

local Layout = require("layout")
local UIManager = require("ui/uimanager")
local T = require("ffi/util").template
local _ = require("gettext")

local Settings = {}

local function refreshHomeOverlay()
    for widget in UIManager:topdown_widgets_iter() do
        if widget and widget.name == "home_widget" and widget.refresh then
            widget:refresh()
            return
        end
    end
end

local function buildGreetingMenu()
    return {
        {
            text_func = function()
                return T(_("Greeting text: %1"), Layout.getGreetingText())
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local InputDialog = require("ui/widget/inputdialog")
                local dialog
                dialog = InputDialog:new{
                    title = _("Greeting text"),
                    input = Layout.getGreetingText(),
                    buttons = {{
                        {
                            text = _("Cancel"),
                            id = "close",
                            callback = function()
                                UIManager:close(dialog)
                            end,
                        },
                        {
                            text = _("Default"),
                            callback = function()
                                UIManager:close(dialog)
                                G_reader_settings:saveSetting(
                                    Layout.SETTING_KEYS.greeting_text,
                                    Layout.DEFAULTS.greeting_text)
                                refreshHomeOverlay()
                                if touchmenu_instance then
                                    touchmenu_instance:updateItems()
                                end
                            end,
                        },
                        {
                            text = _("Save"),
                            is_enter_default = true,
                            callback = function()
                                local value = dialog:getInputText() or ""
                                UIManager:close(dialog)
                                G_reader_settings:saveSetting(
                                    Layout.SETTING_KEYS.greeting_text, value)
                                refreshHomeOverlay()
                                if touchmenu_instance then
                                    touchmenu_instance:updateItems()
                                end
                            end,
                        },
                    }},
                }
                UIManager:show(dialog)
                dialog:onShowKeyboard()
            end,
        },
        {
            text_func = function()
                local FontChooser = require("ui/widget/fontchooser")
                local font_file = Layout.getGreetingFont()
                local name = _("Default")
                if font_file then
                    name = FontChooser.getFontNameText(font_file) or font_file
                end
                return T(_("Greeting font: %1"), name)
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local FontChooser = require("ui/widget/fontchooser")
                UIManager:show(FontChooser:new{
                    title = _("Greeting font"),
                    font_file = Layout.getGreetingFont(),
                    callback = function(font_file)
                        G_reader_settings:saveSetting(
                            Layout.SETTING_KEYS.greeting_font, font_file)
                        refreshHomeOverlay()
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end,
                })
            end,
            hold_callback = function(touchmenu_instance)
                G_reader_settings:delSetting(Layout.SETTING_KEYS.greeting_font)
                refreshHomeOverlay()
                if touchmenu_instance then
                    touchmenu_instance:updateItems()
                end
            end,
        },
        {
            text_func = function()
                return T(_("Greeting font size: %1"), Layout.getGreetingFontSize())
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local SpinWidget = require("ui/widget/spinwidget")
                UIManager:show(SpinWidget:new{
                    value = Layout.getGreetingFontSize(),
                    value_min = Layout.GREETING_FONT_SIZE_MIN,
                    value_max = Layout.GREETING_FONT_SIZE_MAX,
                    value_step = 1,
                    value_hold_step = 4,
                    default_value = Layout.DEFAULTS.greeting_font_size,
                    title_text = _("Greeting font size"),
                    callback = function(spin)
                        G_reader_settings:saveSetting(
                            Layout.SETTING_KEYS.greeting_font_size, spin.value)
                        refreshHomeOverlay()
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end,
                })
            end,
        },
        {
            text_func = function()
                return T(_("Greeting animation speed: %1 ms"),
                    Layout.getGreetingAnimMs())
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local SpinWidget = require("ui/widget/spinwidget")
                UIManager:show(SpinWidget:new{
                    value = Layout.getGreetingAnimMs(),
                    value_min = Layout.GREETING_ANIM_MS_MIN,
                    value_max = Layout.GREETING_ANIM_MS_MAX,
                    value_step = 10,
                    value_hold_step = 50,
                    default_value = Layout.DEFAULTS.greeting_anim_ms,
                    title_text = _("Greeting animation speed"),
                    info_text = _("Milliseconds between each character reveal. Set to 0 to show the greeting instantly (no animation)."),
                    callback = function(spin)
                        G_reader_settings:saveSetting(
                            Layout.SETTING_KEYS.greeting_anim_ms, spin.value)
                        refreshHomeOverlay()
                        if touchmenu_instance then
                            touchmenu_instance:updateItems()
                        end
                    end,
                })
            end,
        },
    }
end

function Settings.buildPaddingMenu()
    local items = {
        {
            text = _("Debug mode"),
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
        {
            text = _("Greeting"),
            sub_item_table = buildGreetingMenu(),
        },
    }
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

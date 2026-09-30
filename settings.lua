--[[--
settings.lua — Home display mode settings menu (greeting text).
--]]

local Device = require("device")
local Layout = require("ui/common/layout")
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

local function libraryInnerDimensions()
    local screen = Device.screen
    local w, h = screen:getWidth(), screen:getHeight()
    local metrics = Layout.mainContentMetrics(w, h, Layout.pt(Layout.dim.status_bar))
    local inset = Layout.libraryInnerSize(metrics.content_width, metrics.library_height)
    return inset.inner_width, inset.inner_height
end

local function buildLibraryMenu()
    return {
        {
            text_func = function()
                local inner_width, inner_height = libraryInnerDimensions()
                return T(_("Shelf rows: %1"), Layout.getLibraryShelfRows(inner_width, inner_height))
            end,
            keep_menu_open = true,
            callback = function(touchmenu_instance)
                local SpinWidget = require("ui/widget/spinwidget")
                local inner_width, inner_height = libraryInnerDimensions()
                local max_rows = Layout.getLibraryShelfRowsMax(inner_width, inner_height)
                local default_rows = Layout.inferDefaultLibraryShelfRows(inner_width, inner_height)
                UIManager:show(SpinWidget:new{
                    value = Layout.getLibraryShelfRows(inner_width, inner_height),
                    value_min = 1,
                    value_max = max_rows,
                    value_step = 1,
                    value_hold_step = 1,
                    default_value = default_rows,
                    title_text = _("Shelf rows"),
                    info_text = _("Number of visible shelf rows in the Library. Book size and spacing are computed automatically from the row count. Use a two-finger pinch on the grid to adjust quickly."),
                    callback = function(spin)
                        Layout.setLibraryShelfRows(spin.value, inner_width, inner_height)
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

--- Sort and filter options for the Library, honoring the same global
--- FileManager settings Home reads (collate / reverse_collate / collate_mixed /
--- show_filter.status). These mirror the file-browser menus but are Home-aware:
--- they refresh the Home overlay and keep the menu open, matching the rest of
--- Home's settings. Kept in sync via BookRepository (single source of truth).
local function buildSortFilterMenu()
    local BookRepository = require("book_repository")
    local BookList = require("ui/widget/booklist")

    -- "Sort by" — one radio entry per BookList collate, ordered like the file
    -- browser's submenu.
    local function buildSortByMenu()
        local ordered = {}
        for id, collate in pairs(BookList.collates) do
            ordered[#ordered + 1] = { id = id, collate = collate }
        end
        table.sort(ordered, function(a, b)
            return (a.collate.menu_order or 0) < (b.collate.menu_order or 0)
        end)
        local items = {}
        for _, entry in ipairs(ordered) do
            local id = entry.id
            items[#items + 1] = {
                text = entry.collate.text,
                radio = true,
                checked_func = function()
                    return select(2, BookRepository.getCollate()) == id
                end,
                callback = function(touchmenu_instance)
                    BookRepository.setCollate(id)
                    -- Keep the file browser's own sort cache in sync.
                    local FileChooser = require("ui/widget/filechooser")
                    if FileChooser.clearSortingCache then
                        FileChooser:clearSortingCache()
                    end
                    refreshHomeOverlay()
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            }
        end
        return items
    end

    -- "Book status" filter — mirrors FileManager's show_filter.status set.
    local function buildBookStatusMenu()
        local statuses = { "new", "reading", "abandoned", "complete" }
        local function getFilter()
            return G_reader_settings:readSetting("show_filter", {})
        end
        local items = {
            {
                text = BookList.getBookStatusString("all"):lower(),
                radio = true,
                checked_func = function()
                    return getFilter().status == nil
                end,
                callback = function(touchmenu_instance)
                    getFilter().status = nil
                    refreshHomeOverlay()
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
                separator = true,
            },
        }
        for _, v in ipairs(statuses) do
            items[#items + 1] = {
                text = BookList.getBookStatusString(v):lower(),
                checked_func = function()
                    local status = getFilter().status
                    return status and status[v] == true
                end,
                callback = function(touchmenu_instance)
                    local filter = getFilter()
                    filter.status = filter.status or {}
                    filter.status[v] = not filter.status[v] or nil
                    local util = require("util")
                    local n = util.tableSize(filter.status)
                    if n == 0 or n == #statuses then
                        filter.status = nil
                    end
                    refreshHomeOverlay()
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            }
        end
        return items
    end

    return {
        {
            text_func = function()
                local collate = BookRepository.getCollate()
                return T(_("Sort by: %1"), collate.text)
            end,
            sub_item_table_func = buildSortByMenu,
        },
        {
            text = _("Reverse sorting"),
            checked_func = function()
                return BookRepository.isReverseCollate()
            end,
            callback = function(touchmenu_instance)
                G_reader_settings:flipNilOrFalse("reverse_collate")
                refreshHomeOverlay()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
        {
            text = _("Folders and files mixed"),
            enabled_func = function()
                local collate = BookRepository.getCollate()
                return collate.can_collate_mixed or false
            end,
            checked_func = function()
                local collate = BookRepository.getCollate()
                return collate.can_collate_mixed and BookRepository.isCollateMixed()
            end,
            callback = function(touchmenu_instance)
                G_reader_settings:flipNilOrFalse("collate_mixed")
                refreshHomeOverlay()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
            separator = true,
        },
        {
            text_func = function()
                local status = G_reader_settings:readSetting("show_filter", {}).status
                local text
                if status == nil then
                    text = BookList.getBookStatusString("all"):lower()
                else
                    for _, v in ipairs({ "new", "reading", "abandoned", "complete" }) do
                        if status[v] then
                            local s = BookList.getBookStatusString(v):lower()
                            text = text and text .. ", " .. s or s
                        end
                    end
                end
                return T(_("Book status: %1"), text)
            end,
            sub_item_table_func = buildBookStatusMenu,
            hold_callback = function(touchmenu_instance)
                G_reader_settings:readSetting("show_filter", {}).status = nil
                refreshHomeOverlay()
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
        },
    }
end

function Settings.buildPaddingMenu()
    local items = {
        {
            text = _("Greeting"),
            sub_item_table = buildGreetingMenu(),
        },
        {
            text = _("Library"),
            sub_item_table = buildLibraryMenu(),
            separator = true,
        },
    }
    -- Sort/filter options live at the top level (not nested).
    for _idx, item in ipairs(buildSortFilterMenu()) do
        items[#items + 1] = item
    end
    return items
end

--- Menu items for the first FileManager menu tab when Home is the active view.
--- Home replaces the file-browser "Settings" tab with its own settings, so the
--- top menu reflects Home instead of the file browser (see main.lua patch).
function Settings.buildHomeSettingsItems()
    local items = {
        {
            text = _("Greeting"),
            sub_item_table = buildGreetingMenu(),
        },
        {
            text = _("Library"),
            sub_item_table = buildLibraryMenu(),
            separator = true,
        },
    }
    -- Sort/filter options live at the top level (not nested).
    for _idx, item in ipairs(buildSortFilterMenu()) do
        items[#items + 1] = item
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

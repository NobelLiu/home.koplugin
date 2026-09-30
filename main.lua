--[[--
home.koplugin/main.lua — Plugin entry point and FileManager integration layer.

Architecture:
  Home is shown as an **overlay** on top of the FileManager (FM), which is
  always kept alive. This lets the user still use KOReader's native menus,
  underneath. Gestures work as follows: while Home is shown, Home's own
  gestures take priority; unhandled gestures are forwarded to the FileManager
  (Gestures-plugin zones), and Dispatcher events they emit are forwarded
  through Home:handleEvent so actions still reach FM modules (see ui/home.lua).

  main.lua is responsible for:
    - Showing/hiding the Home overlay
    - Persisting the home_active / start_with settings
    - Patching FileManager.showFiles (re-shows the overlay when returning
      from the reader)
    - Patching the "Start with" settings menu
    - Registering the FM main-menu toggle item and Dispatcher action

  The UI itself lives in ui/home.lua; widget modules are under ui/ (grouped
  into ui/common/, ui/continue_reading/ and ui/library/).
--]]

require("i18n").install()

local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local BookRepository = require("book_repository")

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Dispatcher = require("dispatcher")
local Settings = require("settings")
local T = require("ffi/util").template
local _ = require("gettext")

-- ---------------------------------------------------------------------------
-- Migration from the legacy "newhome" settings
-- ---------------------------------------------------------------------------
local function _migrateLegacySettings()
    if G_reader_settings:isTrue("newhome_active") then
        G_reader_settings:saveSetting("home_active", true)
        G_reader_settings:delSetting("newhome_active")
    end
    if G_reader_settings:readSetting("start_with") == "newhome" then
        G_reader_settings:saveSetting("start_with", "home")
    end
end
_migrateLegacySettings()

-- ---------------------------------------------------------------------------
-- Path and state helpers
-- ---------------------------------------------------------------------------

-- Strip trailing slashes so paths compare equal regardless of formatting.
local function _norm(p)
    if not p then return "" end
    return (p:gsub("/+$", ""))
end

local function _getHomeDir()
    if G_reader_settings and type(G_reader_settings.readSetting) == "function" then
        return G_reader_settings:readSetting("home_dir")
            or (Device and Device.home_dir)
            or (lfs and lfs.currentdir and lfs.currentdir())
    end
    return (Device and Device.home_dir)
        or (lfs and lfs.currentdir and lfs.currentdir())
end

local function _findHomeOnStack()
    for widget in UIManager:topdown_widgets_iter() do
        if widget and widget.name == "home_widget" then
            return widget
        end
    end
end

local function _isHomeShown()
    return _findHomeOnStack() ~= nil
end

local function _setHomeActive(active)
    G_reader_settings:saveSetting("home_active", active and true or false)
end

-- ---------------------------------------------------------------------------
-- Overlay show / hide (never closes the FM)
-- ---------------------------------------------------------------------------

local function _showHomeOverlay()
    if _isHomeShown() then return end

    local existing = _findHomeOnStack()
    if existing then
        UIManager:close(existing)
    end

    local ok_h, Home = pcall(require, "ui/home")
    if not ok_h then
        local err = tostring(Home)
        logger.err("home.koplugin: failed to load Home module:", err)
        UIManager:show(require("ui/widget/infomessage"):new{
            text = _("Failed to load Home module:\n") .. err,
            timeout = 3,
        })
        return
    end

    -- Creating the widget computes layout metrics; on early boot the screen
    -- dimensions may not be ready yet, producing an arithmetic error. Retry a
    -- few times on the next ticks before giving up.
    local function tryShow(attempt)
        attempt = attempt or 1
        local ok_i, instance = pcall(Home.new, Home)
        if not ok_i then
            local err = tostring(instance)
            if attempt < 5 and string.find(err, "attempt to perform arithmetic") then
                logger.warn("home.koplugin: Home.new retry", attempt, "/5 —", err)
                UIManager:scheduleIn(0.1, function() tryShow(attempt + 1) end)
            else
                logger.err("home.koplugin: failed to create Home instance after", attempt, "attempt(s):", err)
                UIManager:show(require("ui/widget/infomessage"):new{
                    text = _("Failed to create Home:\n") .. err,
                    timeout = 5,
                })
            end
            return
        end
        UIManager:show(instance, "full")
    end
    tryShow()
end

local function _hideHomeOverlay()
    local home = _findHomeOnStack()
    if home then
        UIManager:close(home)
    end
end

local function _restoreFMInstance()
    local ok, Home = pcall(require, "ui/home")
    if ok and Home and Home.liveFileManager then
        return Home.liveFileManager()
    end
    return FileManager.instance
end

local function _ensureFM()
    local fm = _restoreFMInstance()
    if fm then
        return fm
    end
    local home_dir = _getHomeDir()
    if not home_dir then return nil end
    FileManager._home_bypass = true
    FileManager:showFiles(home_dir)
    FileManager._home_bypass = nil
    return _restoreFMInstance()
end

local function switchToHome()
    _ensureFM()
    _setHomeActive(true)
    _showHomeOverlay()
end

local function switchToFileManager()
    _setHomeActive(false)
    _hideHomeOverlay()
    local fm = FileManager.instance
    if fm then
        UIManager:setDirty(fm, "flashui")
    end
end

local function _menuToggleCallback()
    UIManager:nextTick(function()
        if _isHomeShown() then
            switchToFileManager()
        else
            switchToHome()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Show the overlay on boot (only when start_with == "home")
-- ---------------------------------------------------------------------------

local _boot_overlay_done = false

local function _overlayOnBootIfNeeded()
    -- HomePlugin:init() runs every time a FileManager instance is created
    -- (first launch, but also on any FM reinit: refresh, sort change, folder
    -- navigation to the same view, etc.). The boot overlay must only fire on
    -- the genuine first launch, otherwise routine FM actions while browsing the
    -- home directory would keep re-opening Home on top of the file browser.
    if _boot_overlay_done then
        return
    end
    _boot_overlay_done = true

    if G_reader_settings:readSetting("start_with") ~= "home" then
        return
    end

    local fm = FileManager.instance
    if not fm then return end

    local home_dir = _getHomeDir()
    local fc = fm.file_chooser
    local fm_path = fc and fc.path or nil
    if not fm_path or not home_dir or _norm(fm_path) ~= _norm(home_dir) then
        return
    end

    _setHomeActive(true)
    _showHomeOverlay()
end

-- ---------------------------------------------------------------------------
-- Patch FileManager.showFiles: re-show the overlay when the FM navigates
-- (back) to the home directory while Home is the active view.
-- ---------------------------------------------------------------------------
do
    local _orig_showFiles = FileManager.showFiles
    FileManager.showFiles = function(fm_self, path, ...)
        local extra_args = { ... }
        local home_dir = _getHomeDir()
        local should_overlay = not FileManager._home_bypass
            and home_dir and path
            and _norm(path) == _norm(home_dir)
            and G_reader_settings:isTrue("home_active")

        -- showFiles closes the current FM. If it is already on this path,
        -- only put Home back — do not tear down the live instance.
        local live = _restoreFMInstance()
        if should_overlay and live then
            local current = live.file_chooser and live.file_chooser.path
            if current and _norm(current) == _norm(path) then
                _showHomeOverlay()
                return
            end
        end

        local result = _orig_showFiles(fm_self, path, unpack(extra_args))
        _restoreFMInstance()
        if should_overlay then
            _showHomeOverlay()
        end
        return result
    end
end

-- ---------------------------------------------------------------------------
-- Reader → file browser: restore Home when the reader was opened from Home
-- ---------------------------------------------------------------------------
-- The reader's "back to file browser" entry points (top-menu filemanager icon,
-- Home key / "back in reader = file browser", and the end-of-book file-browser
-- action) normally open FM at the current document's folder. When the reader
-- was launched from Home, they must instead restore Home, whatever the
-- document's location, with Home keeping its own root folder as data source.
do
    local ReaderUI = require("apps/reader/readerui")
    local ReaderMenu = require("apps/reader/modules/readermenu")
    local ReaderStatus = require("apps/reader/modules/readerstatus")

    local function _backToHomeFromReader()
        local origin_dir = BookRepository.consumeHomeOrigin()
        if not origin_dir then return false end
        -- FM lands on Home's root; the overlay is re-shown by switchToHome
        -- (or already by the showFiles patch when the root matches home_dir).
        FileManager:showFiles(origin_dir)
        switchToHome()
        return true
    end

    -- Top-menu filemanager button (the reader is closed first, like upstream).
    if not ReaderMenu._home_back_to_home_patched then
        ReaderMenu._home_back_to_home_patched = true
        local _orig_get_default_menu_buttons = ReaderMenu.getDefaultMenuButtons
        function ReaderMenu:getDefaultMenuButtons()
            local buttons = _orig_get_default_menu_buttons(self)
            local fm_btn = buttons and buttons.filemanager
            if fm_btn and type(fm_btn.callback) == "function" then
                -- Icon reflects where the button actually goes: Home vs file browser.
                fm_btn.icon = BookRepository.readerBackIcon()
                fm_btn.callback = function()
                    self:onTapCloseMenu()
                    local file = self.ui.document.file
                    self.ui:onClose()
                    if not _backToHomeFromReader() then
                        self.ui:showFileManager(file)
                    end
                end
            end
            return buttons
        end
    end

    -- Home key / "back in reader = file browser".
    if not ReaderUI._home_back_to_home_patched then
        ReaderUI._home_back_to_home_patched = true
        function ReaderUI:onHome()
            local file = self.document.file
            self:onClose()
            if not _backToHomeFromReader() then
                self:showFileManager(file)
            end
            return true
        end
    end

    -- End-of-book / book-status "file browser" action.
    if not ReaderStatus._home_back_to_home_patched then
        ReaderStatus._home_back_to_home_patched = true
        function ReaderStatus:openFileBrowser()
            local file = self.document.file
            self.ui:onClose()
            if not _backToHomeFromReader() then
                self.ui:showFileManager(file)
            end
        end
    end

    -- Any other reader→file-browser transition ("Show folder", password-cancel,
    -- unsupported file...) consumes the Home-origin marker, so it can never
    -- misdirect a later session that was not started from Home.
    if not ReaderUI._home_consume_origin_patched then
        ReaderUI._home_consume_origin_patched = true
        local _orig_show_file_manager = ReaderUI.showFileManager
        function ReaderUI:showFileManager(file, selected_files)
            BookRepository.consumeHomeOrigin()
            return _orig_show_file_manager(self, file, selected_files)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Replace the first FM menu tab with Home's settings while Home is shown
-- ---------------------------------------------------------------------------

-- The FileManager top menu's first tab is the file-browser "Settings" tab
-- (id "filemanager_settings", icon "appbar.filebrowser"). While Home is the
-- active view we swap that tab's icon and contents for Home's own settings, so
-- the menu reflects Home; when the file browser is active the tab is untouched.
local HOME_SETTINGS_TAB_ID = "filemanager_settings"
local HOME_SETTINGS_TAB_ICON = "home"

local function _applyHomeSettingsTab(tab_item_table)
    if type(tab_item_table) ~= "table" then return end
    for _idx, tab in ipairs(tab_item_table) do
        if type(tab) == "table" and tab.id == HOME_SETTINGS_TAB_ID then
            -- Swap the tab-bar icon.
            tab.icon = HOME_SETTINGS_TAB_ICON
            tab.text = _("Home settings")
            -- Replace the tab's children (stored as array elements) with Home's
            -- own settings items. Clear existing numeric entries first.
            for i = #tab, 1, -1 do
                tab[i] = nil
            end
            -- First section: the Home / file-browser toggle, divided from the
            -- rest. (Rebuilding the tab dropped the toggle that the menu order
            -- had placed here, so re-add it.)
            local toggle = {
                text_func = function()
                    if _isHomeShown() then
                        return _("file browser")
                    end
                    return _("Home")
                end,
                callback = _menuToggleCallback,
                separator = true,
            }
            tab[#tab + 1] = toggle
            local ok_s, items = pcall(Settings.buildHomeSettingsItems)
            if ok_s and type(items) == "table" then
                for i, item in ipairs(items) do
                    tab[#tab + 1] = item
                end
            end
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Patch Settings → "Start with" to add a "Home" radio option
-- ---------------------------------------------------------------------------
do
    local ok, FileManagerMenu = pcall(require, "apps/filemanager/filemanagermenu")
    if ok and FileManagerMenu then
        -- Home keeps FM on the widget stack while FileManager.instance may be
        -- nil (e.g. after opening the reader, or right after a showFiles
        -- transition). Core menus such as screensaver_menu.lua read that
        -- global at load time (via dofile) and crash when it is nil, so make
        -- sure a live instance exists before the menu table is built. Prefer
        -- restoring the on-stack widget; only create one as a last resort.
        local function _ensureFMForMenu(fmm_self)
            if _restoreFMInstance() then
                return
            end
            -- No FM widget on the stack: fall back to the menu owner's own UI
            -- reference, then to creating a fresh instance so the global is
            -- never nil when the core menu code dereferences it.
            local owner = fmm_self and (fmm_self.ui or fmm_self.filemanager)
            if owner and owner.name == "filemanager" then
                FileManager.instance = owner
                return
            end
            _ensureFM()
        end
        if not FileManagerMenu._home_setUpdateItemTable_orig then
            FileManagerMenu._home_setUpdateItemTable_orig = FileManagerMenu.setUpdateItemTable
            function FileManagerMenu:setUpdateItemTable(...)
                _ensureFMForMenu(self)
                -- The core builder (menusorter) crashes with
                -- "bad argument #1 to 'ipairs' (table expected, got nil)" when
                -- it runs before the menu registry is populated: self.menu_items
                -- ends up empty, so order ids (including "KOMenu:menu_buttons")
                -- resolve to nil. This can happen when the menu is triggered too
                -- early in the FM lifecycle. Guard the original call so a
                -- not-yet-ready menu degrades to a no-op rebuild instead of
                -- taking the whole process down.
                local packed = { pcall(FileManagerMenu._home_setUpdateItemTable_orig, self, ...) }
                local ok = packed[1]
                if not ok then
                    logger.warn("home.koplugin: setUpdateItemTable skipped (menu not ready):", packed[2])
                    -- Leave any previously built table untouched; do not mark
                    -- it as built so a later, well-timed call can rebuild it.
                    return
                end
                -- Drop the pcall status flag; the rest is the original result.
                table.remove(packed, 1)
                local result = packed
                -- When Home is the active view, replace the first menu tab (the
                -- file-browser "Settings" tab) with Home's own settings, and swap
                -- its icon, so the top menu reflects Home instead of the file
                -- browser. When FM is active, the original tab is left intact.
                local home_shown = _isHomeShown()
                if home_shown then
                    local ok_tab, tab_err = pcall(_applyHomeSettingsTab, self.tab_item_table)
                    if not ok_tab then
                        logger.warn("home.koplugin: failed to apply Home settings tab:", tab_err)
                    end
                end
                -- Remember which mode this cached table was built for, so
                -- onShowMenu can rebuild when the mode changes.
                self._home_tab_built_for_home = home_shown
                return unpack(result)
            end
        end
        if not FileManagerMenu._home_onShowMenu_orig then
            FileManagerMenu._home_onShowMenu_orig = FileManagerMenu.onShowMenu
            function FileManagerMenu:onShowMenu(...)
                _ensureFMForMenu(self)
                -- The tab table is cached after the first build. Invalidate it
                -- when the Home/FM mode changed since, so the first tab reflects
                -- the current view (Home settings vs file-browser settings).
                if self.tab_item_table ~= nil
                        and self._home_tab_built_for_home ~= _isHomeShown() then
                    self.tab_item_table = nil
                end
                return FileManagerMenu._home_onShowMenu_orig(self, ...)
            end
        end

        if not FileManagerMenu._home_startwith_orig then
            FileManagerMenu._home_startwith_orig = FileManagerMenu.getStartWithMenuTable
        end
        local orig_getStartWithMenuTable = FileManagerMenu._home_startwith_orig

        FileManagerMenu.getStartWithMenuTable = function(fmm_self)
            local result = orig_getStartWithMenuTable(fmm_self)
            local sub = result.sub_item_table
            if type(sub) ~= "table" then return result end

            -- Selecting any other "Start with" option must deactivate Home.
            for i, item in ipairs(sub) do
                if item.radio and type(item.callback) == "function" then
                    local orig_cb = item.callback
                    item.callback = function()
                        _setHomeActive(false)
                        orig_cb()
                    end
                end
            end

            -- Insert our "Home" radio option once (idempotent across re-patches).
            local home_text = _("Home")
            local found = false
            for i, item in ipairs(sub) do
                if item.text == home_text and item.radio then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(sub, math.max(1, #sub), {
                    text = home_text,
                    checked_func = function()
                        return G_reader_settings:readSetting("start_with") == "home"
                    end,
                    callback = function()
                        G_reader_settings:saveSetting("start_with", "home")
                        _setHomeActive(true)
                    end,
                    radio = true,
                })
            end

            local orig_text_func = result.text_func
            result.text_func = function()
                if G_reader_settings:readSetting("start_with") == "home" then
                    return T(_("Start with: %1"), _("Home"))
                end
                return orig_text_func and orig_text_func() or _("Start with")
            end
            return result
        end
    end
end

-- ---------------------------------------------------------------------------
-- Plugin container: menu registration, Dispatcher, and public API
-- ---------------------------------------------------------------------------
local HomePlugin = WidgetContainer:extend{
    name = "home",
    is_doc_only = false,
}

function HomePlugin:onDispatcherRegisterActions()
    Dispatcher:registerAction("home_open", {
        category = "none",
        event = "HomeOpen",
        title = _("Open Home"),
        general = true,
    })
end

-- Register Home items into the FM/reader menus. The Home/file-browser toggle
-- goes at the very top of the first menu tab (filemanager_settings), in its own
-- section separated by a divider. Migrates the old "newhome_toggle" id and is
-- idempotent across re-inits.
local SETTINGS_DIVIDER = "----------------------------"

local function _removeMenuId(list, id)
    for i = #list, 1, -1 do
        if list[i] == id then
            table.remove(list, i)
        end
    end
end

local function _registerMenuOrder()
    pcall(function()
        local function patch(order_module)
            local ok, order = pcall(require, order_module)
            if not ok or type(order) ~= "table" then
                return
            end
            -- Migrate legacy id everywhere it might still live.
            for _key, group in pairs(order) do
                if type(group) == "table" then
                    for i, id in ipairs(group) do
                        if id == "newhome_toggle" then
                            group[i] = "home_toggle"
                        end
                    end
                end
            end

            -- The toggle used to live in the "main" tab; move it to the first
            -- tab's first section. Remove any stale copies first.
            if order["main"] then
                _removeMenuId(order["main"], "home_toggle")
            end

            -- Prepend "home_toggle" + a divider to the first tab. Reader has no
            -- filemanager_settings group, so fall back to the main tab there.
            local first = order["filemanager_settings"] or order["main"]
            if first then
                local present = false
                for _, id in ipairs(first) do
                    if id == "home_toggle" then present = true break end
                end
                if not present then
                    table.insert(first, 1, SETTINGS_DIVIDER)
                    table.insert(first, 1, "home_toggle")
                end
            end
        end
        patch("ui/elements/filemanager_menu_order")
        patch("ui/elements/reader_menu_order")
    end)
end

function HomePlugin:init()
    self:onDispatcherRegisterActions()
    _registerMenuOrder()
    self.ui.menu:registerToMainMenu(self)

    if not self.ui.document then
        UIManager:nextTick(_overlayOnBootIfNeeded)
    end
end

function HomePlugin:addToMainMenu(menu_items)
    menu_items.home_toggle = {
        text_func = function()
            if _isHomeShown() then
                return _("file browser")
            end
            return _("Home")
        end,
        callback = _menuToggleCallback,
    }

    Settings.registerDisplayModeMenu(menu_items)
end

function HomePlugin:onHomeOpen()
    _ensureFM()
    switchToHome()
end

function HomePlugin:switchToHome()
    switchToHome()
end

function HomePlugin:switchToFileManager()
    switchToFileManager()
end

-- Backwards-compatible aliases for older callers.
function HomePlugin:showHome()
    self:switchToHome()
end

function HomePlugin:switchToNewHome()
    self:switchToHome()
end

function HomePlugin:showNewHome()
    self:switchToHome()
end

function HomePlugin:onNewHomeOpen()
    self:onHomeOpen()
end

return HomePlugin

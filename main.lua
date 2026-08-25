--[[--
home.koplugin/main.lua — Plugin entry point and FileManager integration layer.

Architecture:
  Home is shown as an **overlay** on top of the FileManager (FM), which is
  always kept alive. This lets the user still use KOReader's native menus,
  plugins, gestures and other FM capabilities underneath.

  main.lua is responsible for:
    - Showing/hiding the Home overlay
    - Persisting the home_active / start_with settings
    - Patching FileManager.showFiles (re-shows the overlay when returning
      from the reader)
    - Patching the "Start with" settings menu
    - Registering the FM main-menu toggle item and Dispatcher action

  The UI itself lives in home.lua; widget modules are layout / continue_* /
  recent_* etc.; the status bar is in status_bar.lua.
--]]

require("i18n").install()

local Device = require("device")
local FileManager = require("apps/filemanager/filemanager")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")

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

    local ok_h, Home = pcall(require, "home")
    if not ok_h then
        UIManager:show(require("ui/widget/infomessage"):new{
            text = _("Failed to load Home module:\n") .. tostring(Home),
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
                UIManager:scheduleIn(0.1, function() tryShow(attempt + 1) end)
            else
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

local function _ensureFM()
    if FileManager.instance then
        return FileManager.instance
    end
    local home_dir = _getHomeDir()
    if not home_dir then return nil end
    FileManager._home_bypass = true
    FileManager:showFiles(home_dir)
    FileManager._home_bypass = nil
    return FileManager.instance
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

local function _overlayOnBootIfNeeded()
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
        local result = _orig_showFiles(fm_self, path, unpack(extra_args))

        if not FileManager._home_bypass
                and home_dir and path
                and _norm(path) == _norm(home_dir)
                and G_reader_settings:isTrue("home_active") then
            local ok_h, _ = pcall(require, "home")
            if ok_h then
                -- Show Home synchronously (NOT on nextTick): showFiles has just
                -- queued the FileManager's paint but nothing has been rendered
                -- yet this tick. By showing the fullscreen Home overlay now, in
                -- the same tick, UIManager coalesces the pending refreshes and
                -- only repaints the top-most fullscreen widget (Home) — so the
                -- FileManager never flashes underneath before Home appears.
                _showHomeOverlay()
            end
        end
        return result
    end
end

-- ---------------------------------------------------------------------------
-- Patch Settings → "Start with" to add a "Home" radio option
-- ---------------------------------------------------------------------------
do
    local ok, FileManagerMenu = pcall(require, "apps/filemanager/filemanagermenu")
    if ok and FileManagerMenu then
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

-- Register the toggle item into the FM main menu order, migrating the old
-- "newhome_toggle" id and avoiding duplicate insertions.
local function _registerMenuOrder()
    pcall(function()
        local order = require("ui/elements/filemanager_menu_order")
        local main = order["main"]
        if not main then return end
        for i, id in ipairs(main) do
            if id == "newhome_toggle" then
                main[i] = "home_toggle"
            end
        end
        for i, id in ipairs(main) do
            if id == "home_toggle" then return end
        end
        table.insert(main, 1, "home_toggle")
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

--[[--
home.koplugin/ui/home.lua — The full-screen Home main-view widget.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local CenterContainer = require("ui/widget/container/centercontainer")
local ContinueSection = require("ui/continue_reading/continue_section")
local Device = require("device")
local EmptyState = require("ui/common/empty_state")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Layout = require("ui/common/layout")
local pt = Layout.pt
local BD = require("ui/bidi")
local MainContent = require("ui/common/main_content")
local LibrarySection = require("ui/library/library_section")
local OverlapGroup = require("ui/widget/overlapgroup")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local ffiUtil = require("ffi/util")
local _ = require("gettext")
local Screen = Device.screen
local StatusBar = require("ui/status_bar")

local Label = require("ui/uikit/components/controls/label")
local Theme = require("ui/uikit/components/theme")

-- Max pinch-zoom updates per second. The grid is rebuilt on each change, so
-- the rate keeps e-ink repaints responsive without thrashing the CPU.
local LIBRARY_PINCH_RATE = 20

local Home = InputContainer:extend {
    name = "home_widget",
    covers_fullscreen = true,
}

--- Home is an overlay: the FileManager widget can still be on the stack after
--- FileManager.instance was cleared. FM's own menu reads that global (e.g.
--- screensaver_menu.lua), so restore it before opening KOReader menus.
function Home.liveFileManager()
    local FileManager = require("apps/filemanager/filemanager")
    if FileManager.instance then
        return FileManager.instance
    end
    for widget in UIManager:topdown_widgets_iter() do
        if widget and widget.name == "filemanager" then
            FileManager.instance = widget
            return widget
        end
    end
end

function Home:init()
    local s = Screen:getSize()
    self.dimen = s
    self.screen_width = s.w
    self.screen_height = s.h
    self.sort_mode = select(2, BookRepository.getCollate())
    self.library_page = self.library_page or 0
    self.root_dir = self.root_dir or BookRepository.resolveBrowseDir()
    self.current_dir = self.current_dir or self.root_dir
    self.nav_back = self.nav_back or self.dir_stack or {}
    self.nav_forward = self.nav_forward or {}
    self.dir_stack = self.nav_back

    self.activation_menu = G_reader_settings:readSetting("activate_menu") or "swipe_tap"

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.KeyPressShowMenu = { { "Menu" } }
        if Device:hasFewKeys() then
            self.key_events.KeyPressShowMenu = { { { "Menu", "Right" } } }
        end
    end

    self:buildLayout()
end

function Home:initMenuGesListener()
    if not Device:isTouchDevice() then return end

    local status_zone = self:_statusScreenZone()
    local DTAP_ZONE_MENU = G_defaults:readSetting("DTAP_ZONE_MENU")
    local DTAP_ZONE_MENU_EXT = G_defaults:readSetting("DTAP_ZONE_MENU_EXT")
    self:registerTouchZones({
        {
            id = "home_tap",
            ges = "tap",
            screen_zone = status_zone,
            overrides = { "home_continue_tap" },
            handler = function(ges) return self:onTapShowMenu(ges) end,
        },
        {
            id = "home_ext_tap",
            ges = "tap",
            screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 },
            overrides = { "home_tap", "home_continue_tap" },
            handler = function(ges) return self:onTapShowMenu(ges) end,
        },
        {
            id = "home_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x,
                ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w,
                ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = { "rolling_swipe", "paging_swipe" },
            handler = function(ges) return self:onSwipeShowMenu(ges) end,
        },
        {
            id = "home_ext_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x,
                ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w,
                ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
            overrides = { "home_swipe" },
            handler = function(ges) return self:onSwipeShowMenu(ges) end,
        },
        {
            id = "home_library_swipe",
            ges = "swipe",
            screen_zone = self:_librarySwipeScreenZone(),
            overrides = {
                "home_swipe", "home_ext_swipe",
                "rolling_swipe", "paging_swipe",
            },
            handler = function(ges) return self:onLibrarySwipe(ges) end,
        },
        {
            id = "home_library_pinch_reset",
            ges = "touch",
            screen_zone = self:_libraryPinchScreenZone(),
            handler = function()
                -- A fresh touch starts a fresh gesture: forget any pinch base
                -- left over from a gesture that ended without a final pinch.
                self._pinch_base_rows = nil
                return false
            end,
        },
        {
            id = "home_library_pinch",
            ges = "inward_pan",
            screen_zone = self:_libraryPinchScreenZone(),
            rate = LIBRARY_PINCH_RATE,
            overrides = {
                "home_library_swipe", "home_swipe", "home_ext_swipe",
                "rolling_swipe", "paging_swipe",
            },
            handler = function(ges) return self:onLibraryPinchZoom(ges) end,
        },
        {
            id = "home_library_spread",
            ges = "outward_pan",
            screen_zone = self:_libraryPinchScreenZone(),
            rate = LIBRARY_PINCH_RATE,
            overrides = {
                "home_library_swipe", "home_swipe", "home_ext_swipe",
                "rolling_swipe", "paging_swipe",
            },
            handler = function(ges) return self:onLibraryPinchZoom(ges) end,
        },
        {
            id = "home_library_pinch_end",
            ges = "pinch",
            screen_zone = self:_libraryPinchScreenZone(),
            overrides = {
                "home_library_swipe", "home_swipe", "home_ext_swipe",
                "rolling_swipe", "paging_swipe",
            },
            handler = function(ges) return self:onLibraryPinchZoom(ges) end,
        },
        {
            id = "home_library_spread_end",
            ges = "spread",
            screen_zone = self:_libraryPinchScreenZone(),
            overrides = {
                "home_library_swipe", "home_swipe", "home_ext_swipe",
                "rolling_swipe", "paging_swipe",
            },
            handler = function(ges) return self:onLibraryPinchZoom(ges) end,
        },
        {
            id = "home_status_tap",
            ges = "tap",
            screen_zone = self:_statusTapScreenZone(),
            overrides = { "home_tap", "home_ext_tap" },
            handler = function() return self:onShowStatusPanel() end,
        },
        {
            id = "home_continue_tap",
            ges = "tap",
            screen_zone = self:_continueScreenZone(),
            handler = function(ges) return self:onContinueTap(ges) end,
        },
    })
end

--- While Home is the topmost fullscreen overlay, UIManager:sendEvent only
--- delivers non-gesture events to Home. Gestures-plugin actions ultimately
--- call Dispatcher:execute, which emits those events (ToggleFrontlight,
--- RefreshContent, etc.) on the top widget. Forward anything Home itself
--- does not consume to the FileManager underneath so its modules/plugins
--- can react, mirroring normal file-browser behaviour.
function Home:handleEvent(event)
    if WidgetContainer.handleEvent(self, event) then
        return true
    end

    local fm = Home.liveFileManager()
    if fm and fm ~= self then
        return fm:handleEvent(event)
    end
end

--- InputContainer.onGesture override: while Home is shown, Home's own touch
--- zones get first priority. UIManager only delivers Gesture events to the
--- topmost widget (Home), so anything Home does not handle is forwarded to
--- the FileManager underneath (Gestures-plugin zones, etc.). Dispatcher
--- actions triggered there are then routed back through Home:handleEvent.
function Home:onGesture(ev)
    if InputContainer.onGesture(self, ev) then
        return true
    end

    local fm = Home.liveFileManager()
    if fm and fm ~= self and type(fm.onGesture) == "function" then
        return fm:onGesture(ev)
    end
end

--- Screen zone (ratios) for the Home status bar row.
function Home:_statusScreenZone()
    local region = self._status_region
    if not region or self.screen_width <= 0 or self.screen_height <= 0 then
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_width,
        ratio_y = region.y / self.screen_height,
        ratio_w = region.w / self.screen_width,
        ratio_h = region.h / self.screen_height,
    }
end

--- Screen zone (ratios) for the right-hand status cluster (opens quick panel).
function Home:_statusTapScreenZone()
    local region = self._status_tap_region
    if not region or self.screen_width <= 0 or self.screen_height <= 0 then
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_width,
        ratio_y = region.y / self.screen_height,
        ratio_w = region.w / self.screen_width,
        ratio_h = region.h / self.screen_height,
    }
end

--- Keep the status-cluster tap target in sync when the frontlight icon
--- appears or disappears (HorizontalGroup caches its size).
function Home:_syncStatusTapGeometry()
    local cluster = self._status_cluster
    local tap = self._status_tap
    if cluster and cluster.resetLayout then
        cluster:resetLayout()
    end
    if tap and tap[1] and tap[1].resetLayout then
        tap[1]:resetLayout()
    end
    local status_region = self._status_region
    if cluster and status_region and cluster:getSize().w > 0 then
        local cluster_w = math.floor((cluster:getSize().w or 0) + 0.5)
        self._status_tap_region = Geom:new{
            x = status_region.x + status_region.w - pt(Layout.pad.bar) - cluster_w,
            y = status_region.y,
            w = cluster_w,
            h = status_region.h,
        }
        if tap and tap.dimen then
            tap.dimen.w = cluster_w
            tap.width = cluster_w
        end
    else
        self._status_tap_region = nil
    end
    self:_updateStatusTapZone()
end

function Home:_updateStatusTapZone()
    local zone = self._zones and self._zones.home_status_tap
    if not (zone and zone.gs_range and zone.gs_range.range) then
        return
    end
    local screen_zone = self:_statusTapScreenZone()
    zone.def.screen_zone = screen_zone
    local range = zone.gs_range.range
    range.x = self.screen_width * screen_zone.ratio_x
    range.y = self.screen_height * screen_zone.ratio_y
    range.w = self.screen_width * screen_zone.ratio_w
    range.h = self.screen_height * screen_zone.ratio_h
end

function Home:_continueScreenZone()
    local region = self._continue_tap_region
    if not region or self.screen_width <= 0 or self.screen_height <= 0 then
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_width,
        ratio_y = region.y / self.screen_height,
        ratio_w = region.w / self.screen_width,
        ratio_h = region.h / self.screen_height,
    }
end

function Home:onContinueTap()
    if self._continue_book then
        self:onOpenBook(self._continue_book)
        return true
    end
    return false
end

--- Screen zone (ratios) covering the Library grid, where left/right swipes page,
--- upward swipe goes back in folder history, and downward swipe goes forward.
function Home:_librarySwipeScreenZone()
    local region = self._library_refresh_region
    if not region or self.screen_width <= 0 or self.screen_height <= 0 then
        -- No library grid yet: use an empty zone so the handler never fires.
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_width,
        ratio_y = region.y / self.screen_height,
        ratio_w = region.w / self.screen_width,
        ratio_h = region.h / self.screen_height,
    }
end

--- Pinch zones use the Library region plus a small margin, so the gesture
--- stays live when the fingers' midpoint drifts slightly (inward pan/pinch
--- report the current midpoint as their position).
function Home:_libraryPinchScreenZone()
    local region = self._library_refresh_region
    if not region or self.screen_width <= 0 or self.screen_height <= 0 then
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    local margin = pt(Layout.pad.cover)
    local x = math.max(0, region.x - margin)
    local y = math.max(0, region.y - margin)
    local w = math.min(self.screen_width, region.x + region.w + margin) - x
    local h = math.min(self.screen_height, region.y + region.h + margin) - y
    return {
        ratio_x = x / self.screen_width,
        ratio_y = y / self.screen_height,
        ratio_w = w / self.screen_width,
        ratio_h = h / self.screen_height,
    }
end

function Home:onTapShowMenu(ges)
    if self.activation_menu ~= "swipe" then
        return self:onShowKOMenu(ges)
    end
end

function Home:onSwipeShowMenu(ges)
    if self.activation_menu ~= "tap" and ges.direction == "south" then
        return self:onShowKOMenu(ges)
    end
end

function Home:onKeyPressShowMenu()
    return self:onShowKOMenu()
end

function Home:onShowKOMenu(ges)
    local fm = Home.liveFileManager()
    if fm and fm.menu then
        local tab_index = ges and fm.menu:_getTabIndexFromLocation(ges) or nil
        fm.menu:onShowMenu(tab_index)
        return true
    end
end

function Home:onOpenBook(filepath)
    BookRepository.openBook(filepath, self)
end

--- Tear down Home, then hand off to FM's menu helper (closes the menu if
--- open, then FM). Exit/restart must close Home first: otherwise FM is
--- destroyed while this overlay keeps the window stack alive, the app
--- never quits, and menu gestures break because FileManager.instance is nil.
function Home:_exitThroughFileManager(callback)
    G_reader_settings:saveSetting("home_active", false)
    UIManager:close(self)
    local fm = Home.liveFileManager()
    if fm and fm.menu then
        fm.menu:exitOrRestart(callback)
    elseif callback then
        callback()
    else
        UIManager:quit(0)
    end
end

function Home:onExit(callback)
    self:_exitThroughFileManager(callback)
    return true
end

function Home:onRestart()
    self:_exitThroughFileManager(function()
        UIManager:restartKOReader()
    end)
    return true
end

--- Gestures-plugin "File browser" action dispatches the Home event. In the
--- reader that closes the book and opens FM; on FM itself it only navigates
--- to the home folder. While our overlay is shown we must hide it instead.
function Home:onHome()
    self:onSwitchToFileManager()
    return true
end

function Home:onSwitchToFileManager()
    G_reader_settings:saveSetting("home_active", false)
    UIManager:close(self)
    local fm = Home.liveFileManager()
    if fm then UIManager:setDirty(fm, "flashui") end
end

--- Open the quick status panel. Tapping the status/time cluster calls this.
function Home:onShowStatusPanel()
    local StatusPanel = require("ui/status_panel")
    local status_height = self._status_bar_height
    if not status_height then
        status_height = StatusBar.metrics(self.screen_width).height
    end
    UIManager:show(StatusPanel:new{
        home = self,
        row_height = status_height,
    })
    return true
end

-- ---------------------------------------------------------------------------
-- Live status display (battery / Wi-Fi / frontlight, right of the time)
-- ---------------------------------------------------------------------------

--- Live-refresh the top-bar status icons and clock without rebuilding Home.
function Home:_refreshStatusLabel()
    if self._status_refresh_paused then
        self._status_refresh_pending = true
        return
    end
    local region = self._status_region
    if not region then return end
    if Device.screen_saver_mode then return end
    local dirty = false
    local status_label = self._status_label
    if StatusBar.refreshStatusCluster(self._status_cluster, StatusBar.collectInfo()) then
        dirty = true
        self:_syncStatusTapGeometry()
    elseif status_label and status_label.setText then
        local status_text = StatusBar.statusText(StatusBar.collectInfo())
        if status_text ~= status_label._tw_last_status_text then
            status_label._tw_last_status_text = status_text
            status_label:setText(status_text)
            dirty = true
        end
    end
    local time_label = self._time_label
    if time_label and time_label.setText then
        local time_text = StatusBar.currentTimeText()
        if time_text ~= time_label._tw_last_time_text then
            time_label._tw_last_time_text = time_text
            time_label:setText(time_text)
            dirty = true
        end
    end
    if dirty then
        UIManager:setDirty(self, "ui", region)
    end
end

--- The status panel calls these while it is open so Home does not repaint the
--- status area underneath it; refreshes arriving in between are deferred and
--- applied once the panel closes.
function Home:pauseStatusBar()
    self._status_refresh_paused = true
end

function Home:resumeStatusBar()
    self._status_refresh_paused = false
    self._status_refresh_pending = nil
    self:_refreshStatusLabel()
end

--- One-shot delayed status refresh, e.g. re-reading the capacity shortly after
--- a charging event (the HW reading can lag the plug/unplug event).
function Home:_scheduleStatusRefresh(delay)
    if self._status_refresh_task then return end
    local task = function()
        self._status_refresh_task = nil
        self:_refreshStatusLabel()
    end
    self._status_refresh_task = task
    UIManager:scheduleIn(delay, task)
end

--- Minute-aligned periodic status refresh while Home is shown, so slow-moving
--- values (battery capacity while charging/discharging) stay current without
--- rebuilding the layout. Cheap when nothing changed: the refresh itself
--- dedupes identical text and skips the repaint.
function Home:_schedulePeriodicStatusRefresh()
    if self._periodic_status_task then return end
    local task = function()
        self._periodic_status_task = nil
        self:_refreshStatusLabel()
        self:_schedulePeriodicStatusRefresh()
    end
    self._periodic_status_task = task
    UIManager:scheduleIn(61 - tonumber(os.date("%S")), task)
end

--- The status display follows frontlight / Wi-Fi / charging changes live via
--- the same broadcast events the ReaderFooter and the status panel listen to.
function Home:onFrontlightStateChanged()
    self:_refreshStatusLabel()
end

--- Night mode is flipped by DeviceListener after this handler returns (or via
--- the status panel, which updates the setting before closing). Refresh on the
--- next tick so sun/moon follows the new theme.
function Home:onToggleNightMode()
    UIManager:nextTick(function()
        if self._status_cluster then
            self:_refreshStatusLabel()
        end
    end)
end
Home.onSetNightMode = Home.onToggleNightMode

function Home:onCharging()
    self:_refreshStatusLabel()
    self:_scheduleStatusRefresh(1)
end
Home.onNotCharging = Home.onCharging
Home.onNetworkConnected = Home.onFrontlightStateChanged
Home.onNetworkConnecting = Home.onFrontlightStateChanged
Home.onNetworkDisconnected = Home.onFrontlightStateChanged
Home.onNetworkDisconnecting = Home.onFrontlightStateChanged

--- Open KOReader's native FileManager "Sort by" submenu directly (no custom
--- UI). We reuse FileManagerMenu:getSortingMenuTable() so wording, ordering,
--- radio state and callbacks (onSetSortBy) match the file browser exactly, and
--- refresh Home when the menu closes so the new global collate takes effect.
function Home:onShowSortMenu()
    local fm = Home.liveFileManager()
    if not (fm and fm.menu and fm.file_chooser) then return end

    local TouchMenu = require("ui/widget/touchmenu")

    local sort_menu = fm.menu:getSortingMenuTable()
    -- getSortingMenuTable() returns a menu entry ({ text_func, sub_item_table });
    -- present its sub_item_table as the single tab's page so we land straight on
    -- the sort choices. The tab needs an icon for the TouchMenu bar.
    local tab = {}
    for k, v in pairs(sort_menu.sub_item_table) do tab[k] = v end
    -- Append the Reverse / Mixed sorting toggles (in the file browser these are
    -- separate menu items, not inside the sort_by submenu). Defined inline to
    -- match FileManager exactly without depending on its lazily-built menu_items.
    local FileChooser = fm.file_chooser
    -- Draw a divider above the toggles. The collate items are shared references
    -- from FileManager's menu, so shallow-copy the last one before flagging it
    -- (avoids mutating a separator into the real file-browser sort menu).
    local n = #tab
    if tab[n] then
        local copy = {}
        for k, v in pairs(tab[n]) do copy[k] = v end
        copy.separator = true
        tab[n] = copy
    end
    tab[#tab + 1] = {
        text = _("Reverse sorting"),
        checked_func = function()
            return G_reader_settings:isTrue("reverse_collate")
        end,
        callback = function()
            G_reader_settings:flipNilOrFalse("reverse_collate")
            FileChooser:refreshPath()
        end,
    }
    tab[#tab + 1] = {
        text = _("Folders and files mixed"),
        enabled_func = function()
            local collate = FileChooser:getCollate()
            return collate.can_collate_mixed or false
        end,
        checked_func = function()
            local collate = FileChooser:getCollate()
            return collate.can_collate_mixed and G_reader_settings:isTrue("collate_mixed")
        end,
        callback = function()
            G_reader_settings:flipNilOrFalse("collate_mixed")
            FileChooser:refreshPath()
        end,
        separator = true,
    }
    -- Native "Book status" filter submenu, so Home can filter by status too.
    tab[#tab + 1] = fm.menu:getShowFilterMenuTable()
    tab.icon = "appbar.filebrowser"

    local menu_container = CenterContainer:new{
        ignore = "height",
        dimen = Screen:getSize(),
    }
    local touch_menu = TouchMenu:new{
        width = Screen:getWidth(),
        tab_item_table = { tab },
        is_borderless = true,
        is_popout = false,
        show_parent = menu_container,
    }
    touch_menu.close_callback = function()
        UIManager:close(menu_container)
        -- The native callbacks already saved the global collate and cleared
        -- FileManager's sort cache; re-read it and rebuild Home's Library.
        self.sort_mode = select(2, BookRepository.getCollate())
        self.library_page = 0
        self:refreshLibrary()
    end
    menu_container[1] = touch_menu
    UIManager:show(menu_container)
end

function Home:onPageChange(page)
    self.library_page = page
    self:refreshLibrary()
end

--- Two-finger pinch/spread over the Library grid: adjusts shelf row count from
--- the gesture's starting span (spread = fewer rows / larger books, pinch = more
--- rows / smaller books), updating the grid live as the fingers move.
function Home:onLibraryPinchZoom(ges)
    if not (ges and ges.start_span and ges.span and ges.start_span > 0) then
        return false
    end
    local inner_width, inner_height = self:_libraryInnerDimensions()
    local base = self._pinch_base_rows or Layout.getLibraryShelfRows(inner_width, inner_height)
    self._pinch_base_rows = base
    local new_rows = math.floor(base * ges.start_span / ges.span + 0.5)
    local max_rows = Layout.getLibraryShelfRowsMax(inner_width, inner_height)
    if new_rows < 1 then new_rows = 1 end
    if new_rows > max_rows then new_rows = max_rows end
    self:_setLibraryShelfRows(new_rows, inner_width, inner_height)
    if ges.ges == "pinch" or ges.ges == "spread" then
        self._pinch_base_rows = nil
        G_reader_settings:flush()
    end
    return true
end

--- Inner Library grid dimensions for shelf-row settings and pinch gestures.
function Home:_libraryInnerDimensions()
    local w = self.screen_width or 0
    local h = self.screen_height or 0
    local status_height = pt(Layout.dim.status_bar)
    local metrics = Layout.mainContentMetrics(w, h, status_height)
    local inset = Layout.libraryInnerSize(metrics.content_width, metrics.library_height)
    return inset.inner_width, inset.inner_height
end

--- Update the user-configured shelf row count and rebuild the Library grid
--- when it actually changed.
function Home:_setLibraryShelfRows(rows, inner_width, inner_height)
    if rows == Layout.getLibraryShelfRows(inner_width, inner_height) then return end
    Layout.setLibraryShelfRows(rows, inner_width, inner_height)
    self:refreshLibrary()
end

--- Number of Library pages given the current page size and entry count.
function Home:_libraryPageCount()
    local page_size = self._library_page_size or 0
    if page_size <= 0 then return 1 end
    local count = self._library_entry_count or 0
    return math.max(1, math.ceil(count / page_size))
end

--- Turn the Library grid one page in the given direction (-1 prev, +1 next),
--- clamped to the available pages. No-op (returns false) at the boundary.
function Home:_turnLibraryPage(delta)
    local page_count = self:_libraryPageCount()
    local target = (self.library_page or 0) + delta
    if target < 0 or target > page_count - 1 then return false end
    self:onPageChange(target)
    return true
end

--- Swipe over the Library grid: left/right page (honoring RTL mirroring),
--- upward swipe navigates back, downward swipe navigates forward.
function Home:onLibrarySwipe(ges)
    local direction = ges and ges.direction
    if direction == "north" then
        self:onGoUp()
        return true
    elseif direction == "south" then
        self:onNavForward()
        return true
    end

    direction = BD.flipDirectionIfMirroredUILayout(direction)
    if direction == "east" then
        self:_turnLibraryPage(-1)
        return true
    elseif direction == "west" then
        self:_turnLibraryPage(1)
        return true
    end
    return false
end

function Home:_goToDir(dir)
    self.current_dir = dir
    self.library_page = 0
    self:refreshLibrary()
end

function Home:onEnterFolder(dir)
    if not dir or dir == self.current_dir then return end
    self.nav_back[#self.nav_back + 1] = self.current_dir
    self.nav_forward = {}
    self:_goToDir(dir)
end

function Home:onNavBack()
    local prev = table.remove(self.nav_back)
    if not prev then return end
    self.nav_forward[#self.nav_forward + 1] = self.current_dir
    self:_goToDir(prev)
end

function Home:onNavForward()
    local nxt = table.remove(self.nav_forward)
    if not nxt then return end
    self.nav_back[#self.nav_back + 1] = self.current_dir
    self:_goToDir(nxt)
end

--- Swipe-up pops folder history (same as Action Bar back).
--- Swipe-down advances folder history (same as Action Bar forward).
function Home:onGoUp()
    self:onNavBack()
end

local function folderTitle(dir)
    local name = dir and dir:match("([^/]+)/?$")
    if name and name ~= "" then return name end
    return _("Home")
end

-- Library slot, below the status bar and Continue hero.
local function scaleText()
    local scale = Layout.theme().screenScale()
    if scale == math.floor(scale) then
        return string.format("%d×", scale)
    end
    return string.format("%g×", scale)
end

local function screenMetricsText()
    local width = Screen:getWidth()
    local height = Screen:getHeight()
    local dpi = Screen.getDPI and Screen:getDPI()
    if type(dpi) ~= "number" then
        dpi = Device.getDeviceScreenDPI and Device:getDeviceScreenDPI()
    end
    local scale = scaleText()
    if type(dpi) == "number" then
        return string.format("%d×%d  %d dpi  %s", width, height, math.floor(dpi + 0.5), scale)
    end
    return string.format("%d×%d  %s", width, height, scale)
end

local function _libraryRefreshRegion(metrics)
    return Geom:new {
        x = metrics.main_horizontal_padding,
        y = metrics.main_vertical_padding + metrics.status_bar_height + metrics.continue_slot_height,
        w = metrics.content_width,
        h = metrics.library_height,
    }
end

function Home:buildLayout()
    local content_width = Layout.contentWidth(self.screen_width, 0)
    local status_metrics = StatusBar.metrics(content_width)
    local status_height = status_metrics.height
    self._status_bar_height = status_height
    local metrics = Layout.mainContentMetrics(self.screen_width, self.screen_height, status_height)
    local inner_height = metrics.inner_height

    -- Greeting typewriter plays in the Continue header on first paint and
    -- explicit reentry (reader / lock). Paging, sort, and folder history skip it.
    local animate_greeting = self._title_replay == true or self._greeting_played ~= true
    self._title_replay = nil
    self._greeting_played = true

    local status_region = Geom:new {
        x = metrics.main_horizontal_padding,
        y = metrics.main_vertical_padding,
        w = metrics.content_width,
        h = status_height,
    }
    self._status_region = status_region

    local content_sections = VerticalGroup:new {
        align = "left",
        StatusBar.build({
            home = self,
            width = metrics.content_width,
            metrics = status_metrics,
        }),
    }

    self:_syncStatusTapGeometry()

    local continue_book = BookRepository.getGlobalLastReadBook()
    -- The FileManager ui backs metadata collates (title/authors/series/...):
    -- their item_func calls ui.bookinfo:getDocProps(). Pass the live FM instance.
    local fm = Home.liveFileManager()
    -- Always read the current global sort (collate) so any change made via the
    -- settings menu or the sort button is reflected on the next rebuild.
    self.sort_mode = select(2, BookRepository.getCollate())
    local entries = BookRepository.getLibraryEntries(self.current_dir, self.sort_mode, fm)
    local on_open = function(fp) self:onOpenBook(fp) end
    local on_enter = function(dir) self:onEnterFolder(dir) end

    if not continue_book then
        self._library_refresh_region = nil
        self._library_page_size = 0
        self._library_entry_count = 0
        self._continue_book = nil
        self._continue_tap_region = nil
        self._continue_header_label = nil
        self._continue_header_region = nil
        local empty = EmptyState.build(
            metrics.content_width,
            BookRepository.resolveBrowseDir(),
            function() self:onSwitchToFileManager() end
        )
        content_sections[#content_sections + 1] = CenterContainer:new {
            dimen = Geom:new { w = metrics.content_width, h = math.max(0, inner_height - status_height) },
            empty,
        }
    else
        local ContinueInfoColumn = require("ui/continue_reading/continue_info_column")
        local header_label, header_region = ContinueInfoColumn.buildHeader(
            self, metrics, animate_greeting)
        content_sections[#content_sections + 1] = ContinueSection.build(
            continue_book, metrics, on_open, { header_label = header_label })
        if animate_greeting and header_label.play then
            self._pending_continue_header_anim = {
                label = header_label,
                region = header_region,
            }
        else
            self._pending_continue_header_anim = nil
        end
        self._continue_header_label = header_label
        self._continue_header_region = header_region
        self._continue_book = continue_book
        self._continue_tap_region = Geom:new {
            x = metrics.main_horizontal_padding,
            y = metrics.main_vertical_padding + status_height,
            w = metrics.content_width,
            h = metrics.continue_slot_height,
        }

        local continue_rp = ffiUtil.realpath(continue_book) or continue_book
        local library_entries = {}
        for _, entry in ipairs(entries) do
            local keep = true
            if entry.type == "book" then
                local rp = ffiUtil.realpath(entry.path) or entry.path
                if rp == continue_rp then keep = false end
            end
            if keep then library_entries[#library_entries + 1] = entry end
        end

        content_sections[#content_sections + 1] = LibrarySection.build(library_entries, metrics, on_open, {
            sort_mode = self.sort_mode,
            page = self.library_page,
            current_title = folderTitle(self.current_dir),
            can_back = #self.nav_back > 0,
            can_forward = #self.nav_forward > 0,
            on_enter = on_enter,
            on_sort_menu = function() self:onShowSortMenu() end,
            on_page_change = function(page) self:onPageChange(page) end,
            on_back = function() self:onNavBack() end,
            on_forward = function() self:onNavForward() end,
        })
        self._library_refresh_region = _libraryRefreshRegion(metrics)

        local inset = Layout.libraryInnerSize(metrics.content_width, metrics.library_height)
        local grid_metrics = Layout.libraryGridMetrics(inset.inner_width, inset.inner_height)
        self._library_page_size = grid_metrics.library_cols * grid_metrics.library_rows
        self._library_entry_count = #library_entries
    end

    self.main_group = MainContent.build(self.screen_width, metrics, content_sections)
    local frame = FrameContainer:new {
        width = self.screen_width,
        height = self.screen_height,
        radius = 0,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        self.main_group,
    }
    -- Top-left screen-metrics overlay (resolution / DPI / scale). Off for now.
    local show_screen_metrics = false
    if show_screen_metrics then
        local metrics_label = FrameContainer:new{
            bordersize = 0,
            padding = 0,
            margin = 0,
            background = Theme.color.white,
            Label:new{
                text = screenMetricsText(),
                role = "caption1",
                color = Theme.color.black,
            },
        }
        metrics_label.overlap_offset = { 0, 0 }
        self[1] = OverlapGroup:new{
            dimen = Geom:new{ w = self.screen_width, h = self.screen_height },
            allow_mirroring = false,
            frame,
            metrics_label,
        }
    else
        self[1] = frame
    end
    self:initMenuGesListener()
end

function Home:_unscheduleContinueHeaderReveal()
    if self._continue_header_reveal_task then
        UIManager:unschedule(self._continue_header_reveal_task)
        self._continue_header_reveal_task = nil
    end
end

function Home:_startContinueHeaderAnimation()
    local pending = self._pending_continue_header_anim
    self._pending_continue_header_anim = nil
    if not pending then return end
    self._continue_header_label = pending.label
    self._continue_header_region = pending.region
    if pending.label.play then
        pending.label:play(self, pending.region)
    end
end

function Home:onSetDimensions(dimen)
    if self.dimen and self.dimen.w == dimen.w and self.dimen.h == dimen.h then
        return
    end
    self.dimen = dimen
    self.screen_width = dimen.w
    self.screen_height = dimen.h
    self:refresh()
end

--- Called whenever Home becomes the frontmost view again (returning from the
--- reader or waking from the lock screen). Replays the Continue-header greeting.
function Home:refreshOnReentry()
    self._continue_header_label = nil
    self._continue_header_region = nil
    self._status_label = nil
    self._status_cluster = nil
    self._status_tap = nil
    self._time_label = nil
    self._title_replay = true
    self:refresh()
end

function Home:onShow()
    UIManager:setDirty(self, "full")
    self:_startContinueHeaderAnimation()
    -- Keep slow-moving status values (battery capacity, …) current while Home
    -- is on screen. Cancelled in onCloseWidget.
    self:_schedulePeriodicStatusRefresh()
end

-- If a screensaver_delay is active, the screensaver is dismissed later via
-- OutOfScreenSaver, so defer the reentry refresh until then to avoid painting
-- under the lock screen.
function Home:onResume()
    local screensaver_delay = G_reader_settings:readSetting("screensaver_delay")
    if screensaver_delay and screensaver_delay ~= "disable" then
        self._delayed_reentry_refresh = true
        return
    end
    self:_reentryIfFrontmost()
end

function Home:onOutOfScreenSaver()
    if not self._delayed_reentry_refresh then return end
    self._delayed_reentry_refresh = nil
    self:_reentryIfFrontmost()
end

-- Waking / dismissing the lock screen only re-enters Home if Home is actually
-- the frontmost view now (the reader or another widget may be on top instead).
-- When it is, refresh immediately and replay the greeting; otherwise there is
-- nothing to repaint.
function Home:_reentryIfFrontmost()
    if UIManager:getTopmostVisibleWidget() == self then
        self:refreshOnReentry()
    end
end

function Home:refreshLibrary()
    self:refresh({
        refreshtype = "ui",
        partial_library = true,
        refreshdither = true,
    })
end

function Home:refresh(opts)
    opts = opts or {}
    -- A rebuild regenerates the status label from current state, so any
    -- deferred live refresh is obsolete.
    self._status_refresh_pending = nil
    self:_unscheduleContinueHeaderReveal()
    if self[1] and self[1].free then self[1]:free() end
    self:buildLayout()
    local refreshtype = opts.refreshtype or "flashui"
    local region = opts.refreshregion
    if opts.partial_library and self._library_refresh_region then
        region = self._library_refresh_region
    end
    local dither = opts.refreshdither
    if region then
        UIManager:setDirty(self, refreshtype, region, dither)
    else
        UIManager:setDirty(self, refreshtype)
    end
    if self._pending_continue_header_anim
        and UIManager:getTopmostVisibleWidget() == self then
        self:_startContinueHeaderAnimation()
    end
end

function Home:onCloseWidget()
    -- Stop any in-flight Continue-header reveal (scheduled ticks bail once this
    -- reference no longer matches the animating label).
    self:_unscheduleContinueHeaderReveal()
    self._pending_continue_header_anim = nil
    self._continue_header_label = nil
    self._continue_header_region = nil
    self._status_label = nil
    self._status_cluster = nil
    self._status_tap = nil
    self._time_label = nil
    self._status_region = nil
    -- Cancel pending status refreshes so they can't run against freed widgets.
    if self._status_refresh_task then
        UIManager:unschedule(self._status_refresh_task)
        self._status_refresh_task = nil
    end
    if self._periodic_status_task then
        UIManager:unschedule(self._periodic_status_task)
        self._periodic_status_task = nil
    end
    self._status_refresh_pending = nil
    self._status_refresh_paused = nil
end

function Home:onClose()
    UIManager:close(self)
    return true
end

return Home

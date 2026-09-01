--[[--
home.koplugin/ui/home.lua — The full-screen Home main-view widget.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local ContinueSection = require("ui/continue_reading/continue_section")
local Device = require("device")
local EmptyState = require("ui/common/empty_state")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Layout = require("ui/common/layout")
local BD = require("ui/bidi")
local MainContent = require("ui/common/main_content")
local LibrarySection = require("ui/library/library_section")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local ffiUtil = require("ffi/util")
local _ = require("gettext")
local Screen = Device.screen
local StatusBar = require("ui/status_bar")

-- Max pinch-zoom updates per second. The grid is rebuilt on each change, so
-- the rate keeps e-ink repaints responsive without thrashing the CPU.
local LIBRARY_PINCH_RATE = 20

local Home = InputContainer:extend {
    name = "home_widget",
    covers_fullscreen = true,
}

function Home:init()
    local s = Screen:getSize()
    self.dimen = s
    self.screen_w = s.w
    self.screen_h = s.h
    self.sort_mode = BookRepository.getSortMode()
    self.library_page = self.library_page or 0
    self.root_dir = self.root_dir or BookRepository.resolveBrowseDir()
    self.current_dir = self.current_dir or self.root_dir
    self.dir_stack = self.dir_stack or {}

    self.activation_menu = G_reader_settings:readSetting("activate_menu") or "swipe_tap"

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.KeyPressShowMenu = { { "Menu" } }
        if Device:hasFewKeys() then
            self.key_events.KeyPressShowMenu = { { { "Menu", "Right" } } }
        end
    end

    self:buildLayout()
    self:initMenuGesListener()
end

function Home:initMenuGesListener()
    if not Device:isTouchDevice() then return end

    local DTAP_ZONE_MENU = G_defaults:readSetting("DTAP_ZONE_MENU")
    local DTAP_ZONE_MENU_EXT = G_defaults:readSetting("DTAP_ZONE_MENU_EXT")
    self:registerTouchZones({
        {
            id = "home_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x,
                ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w,
                ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = { "home_continue_tap" },
            handler = function(ges) return self:onTapShowMenu(ges) end,
        },
        {
            id = "home_ext_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x,
                ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w,
                ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
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
                self._pinch_base_w = nil
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
            id = "home_continue_tap",
            ges = "tap",
            screen_zone = self:_continueScreenZone(),
            handler = function(ges) return self:onContinueTap(ges) end,
        },
    })
end

--- InputContainer.onGesture override: while Home is shown, only Home's own
--- touch zones may handle gestures. Events are deliberately NOT forwarded to
--- the FileManager underneath. UIManager only delivers Gesture events to the
--- topmost widget, so forwarding was what let the FM's zones -- including the
--- ones registered by the Gestures plugin for the menu-configured gestures --
--- react to input while Home was shown, conflicting with Home's own
--- swipe/tap/pinch zones.
function Home:onGesture(ev)
    return InputContainer.onGesture(self, ev)
end

--- Screen zone (ratios) covering the Continue hero. Tapping it opens the book.
--- Lower priority than the top menu / status-panel zones (they override it), so
--- top-of-screen gestures win.
function Home:_continueScreenZone()
    local region = self._continue_tap_region
    if not region or self.screen_w <= 0 or self.screen_h <= 0 then
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_w,
        ratio_y = region.y / self.screen_h,
        ratio_w = region.w / self.screen_w,
        ratio_h = region.h / self.screen_h,
    }
end

function Home:onContinueTap()
    if self._continue_book then
        self:onOpenBook(self._continue_book)
        return true
    end
    return false
end

--- Screen zone (ratios) covering the Library grid, where left/right swipes page
--- and an upward swipe returns to the parent folder.
function Home:_librarySwipeScreenZone()
    local region = self._library_refresh_region
    if not region or self.screen_w <= 0 or self.screen_h <= 0 then
        -- No library grid yet: use an empty zone so the handler never fires.
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_w,
        ratio_y = region.y / self.screen_h,
        ratio_w = region.w / self.screen_w,
        ratio_h = region.h / self.screen_h,
    }
end

--- Pinch zones use the Library region plus a small margin, so the gesture
--- stays live when the fingers' midpoint drifts slightly (inward pan/pinch
--- report the current midpoint as their position).
function Home:_libraryPinchScreenZone()
    local region = self._library_refresh_region
    if not region or self.screen_w <= 0 or self.screen_h <= 0 then
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    local margin = Layout.pad.cover
    local x = math.max(0, region.x - margin)
    local y = math.max(0, region.y - margin)
    local w = math.min(self.screen_w, region.x + region.w + margin) - x
    local h = math.min(self.screen_h, region.y + region.h + margin) - y
    return {
        ratio_x = x / self.screen_w,
        ratio_y = y / self.screen_h,
        ratio_w = w / self.screen_w,
        ratio_h = h / self.screen_h,
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
    local FileManager = require("apps/filemanager/filemanager")
    local fm = FileManager.instance
    if fm and fm.menu then
        local tab_index = ges and fm.menu:_getTabIndexFromLocation(ges) or nil
        fm.menu:onShowMenu(tab_index)
        return true
    end
end

function Home:onOpenBook(filepath)
    BookRepository.openBook(filepath, self)
end

function Home:onSwitchToFileManager()
    G_reader_settings:saveSetting("home_active", false)
    UIManager:close(self)
    local FileManager = require("apps/filemanager/filemanager")
    local fm = FileManager.instance
    if fm then UIManager:setDirty(fm, "flashui") end
end

--- Open the quick status panel. Tapping the root greeting/time title calls
--- this; closing the panel replays the greeting via refreshOnReentry.
function Home:onShowStatusPanel()
    local StatusPanel = require("ui/status_panel")
    UIManager:show(StatusPanel:new{
        home = self,
    })
    return true
end

-- ---------------------------------------------------------------------------
-- Live status display (battery / Wi-Fi / frontlight, right of the time)
-- ---------------------------------------------------------------------------

--- Live-refresh the status display text without rebuilding the layout: the
--- status label is revealed by the title row's typewriter, so after it settles
--- we can just swap its text and repaint the Library header row region.
--- Skips repaints when the text is unchanged; defers while the status panel is
--- open (pauseStatusBar) or the status area is still in its build → reveal
--- phase, and applies the deferred refresh once those end.
function Home:_refreshStatusLabel()
    if self._status_refresh_paused then
        self._status_refresh_pending = true
        return
    end
    local label = self._status_label
    if not label or not self._title_region then return end
    if Device.screen_saver_mode then return end
    if not label._tw_settled then
        -- The status area is still in the greeting → time → status reveal
        -- sequence: painting it early would break the animation order, so
        -- defer and let the reveal's completion drain the pending refresh.
        self._status_refresh_pending = true
        return
    end
    local status_text = StatusBar.statusText(StatusBar.collectInfo())
    if status_text == label._tw_last_status_text then return end
    label._tw_last_status_text = status_text
    label:setText(status_text)
    UIManager:setDirty(self, "ui", self._title_region)
end

--- Reveal the status display with the *current* status text (collected fresh
--- at reveal time, so it never shows a snapshot captured at build time), then
--- mark the label settled so later live refreshes apply instantly. Any refresh
--- that arrived while the reveal was still running is drained once it ends.
function Home:_revealStatusLabel(label, region)
    if self._status_label ~= label then return end
    if self.current_dir ~= self.root_dir then return end
    if Device.screen_saver_mode then return end
    local status_text = StatusBar.statusText(StatusBar.collectInfo())
    label._tw_last_status_text = status_text
    label:reveal(self, region, status_text, 0, function()
        label._tw_settled = true
        if self._status_refresh_pending then
            self._status_refresh_pending = nil
            self:_refreshStatusLabel()
        end
    end)
end

--- The status panel calls these while it is open so Home does not repaint the
--- status area underneath it; refreshes arriving in between are deferred and
--- applied once the panel closes.
function Home:pauseStatusBar()
    self._status_refresh_paused = true
end

function Home:resumeStatusBar()
    self._status_refresh_paused = false
    if self._status_refresh_pending then
        self._status_refresh_pending = nil
        self:_refreshStatusLabel()
    end
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

function Home:onCharging()
    self:_refreshStatusLabel()
    self:_scheduleStatusRefresh(1)
end
Home.onNotCharging = Home.onCharging
Home.onNetworkConnected = Home.onFrontlightStateChanged
Home.onNetworkConnecting = Home.onFrontlightStateChanged
Home.onNetworkDisconnected = Home.onFrontlightStateChanged
Home.onNetworkDisconnecting = Home.onFrontlightStateChanged

function Home:setSortMode(mode)
    mode = mode == "name" and "name" or "recent"
    BookRepository.setSortMode(mode)
    self.sort_mode = mode
    self.library_page = 0
    self:refreshLibrary()
end

function Home:onShowSortMenu()
    local dialog
    local function pick(mode)
        return function()
            UIManager:close(dialog)
            self:setSortMode(mode)
        end
    end
    dialog = ButtonDialog:new {
        title = _("Sort by"),
        title_align = "center",
        buttons = {
            { {
                text = _("Name"),
                checked_func = function() return self.sort_mode == "name" end,
                callback = pick("name"),
            } },
            { {
                text = _("Last read"),
                checked_func = function() return self.sort_mode == "recent" end,
                callback = pick("recent"),
            } },
        },
    }
    UIManager:show(dialog)
end

function Home:onPageChange(page)
    self.library_page = page
    self:refreshLibrary()
end

--- Two-finger pinch/spread over the Library grid: scales the minimum book
--- width from the gesture's starting span, updating the grid live as the
--- fingers move (inward_pan/outward_pan), and finalizing on pinch/spread.
function Home:onLibraryPinchZoom(ges)
    if not (ges and ges.start_span and ges.span and ges.start_span > 0) then
        return false
    end
    local base = self._pinch_base_w or Layout.getLibraryCellWidthMin()
    self._pinch_base_w = base
    local ratio = ges.span / ges.start_span
    local new_w = math.floor(base * ratio + 0.5)
    if new_w < Layout.CELL_W_LIMIT_MIN then new_w = Layout.CELL_W_LIMIT_MIN end
    if new_w > Layout.CELL_W_LIMIT_MAX then new_w = Layout.CELL_W_LIMIT_MAX end
    -- Never let the zoom push the minimum width past what still shows at
    -- least one book on this screen.
    local max_for_screen = Layout.getLibraryCellWidthMaxForScreen()
    if new_w > max_for_screen then new_w = max_for_screen end
    self:_setLibraryCellWidthMin(new_w)
    if ges.ges == "pinch" or ges.ges == "spread" then
        self._pinch_base_w = nil
        G_reader_settings:flush()
    end
    return true
end

--- Update the user-configured minimum book width and rebuild the Library grid
--- when it actually changed.
function Home:_setLibraryCellWidthMin(min_w)
    if min_w == Layout.getLibraryCellWidthMin() then return end
    G_reader_settings:saveSetting(Layout.SETTING_KEYS.library_cell_w_min, min_w)
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

--- Swipe over the Library grid: left/right page (honoring RTL mirroring), an
--- upward swipe returns to the parent folder.
function Home:onLibrarySwipe(ges)
    local direction = ges and ges.direction
    if direction == "north" then
        self:onGoUp()
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

function Home:onEnterFolder(dir)
    self.dir_stack[#self.dir_stack + 1] = self.current_dir
    self.current_dir = dir
    self.library_page = 0
    self:refreshLibrary()
end

function Home:onGoUp()
    local parent = table.remove(self.dir_stack)
    if parent then
        self.current_dir = parent
        self.library_page = 0
        self:refreshLibrary()
    end
end

-- Region covering only the Library grid, used for partial refreshes when
-- paging or toggling sort without repainting the whole screen. Library is the
-- bottom section; it starts right below the Continue slot (no status bar row,
-- no divider/gap).
local function _libraryRefreshRegion(metrics)
    return Geom:new {
        x = metrics.main_h_padding,
        y = metrics.main_v_padding + metrics.continue_slot_h,
        w = metrics.content_w,
        h = metrics.library_h,
    }
end

function Home:buildLayout()
    local metrics = Layout.mainContentMetrics(self.screen_w, self.screen_h, 0)
    local inner_h = metrics.inner_h

    -- Play the title typewriter reveal only when the folder changed since the
    -- last build (enter/exit) or a replay was explicitly requested (reentry
    -- from the reader or the lock screen). Paging, sorting and periodic status
    -- refreshes rebuild the layout too, but must not re-animate.
    local animate_title = self._title_replay or self._title_anim_dir ~= self.current_dir
    self._title_replay = nil
    self._title_anim_dir = self.current_dir

    local continue_book = BookRepository.getGlobalLastReadBook()
    local entries = BookRepository.getLibraryEntries(self.current_dir, self.sort_mode)
    local on_open = function(fp) self:onOpenBook(fp) end
    local on_enter = function(dir) self:onEnterFolder(dir) end

    local content_sections = VerticalGroup:new { align = "left" }

    -- With no book to continue, show the empty state; otherwise render the
    -- Continue hero followed by the Library grid.
    if not continue_book then
        self._library_refresh_region = nil
        self._library_page_size = 0
        self._library_entry_count = 0
        self._continue_book = nil
        self._continue_tap_region = nil
        -- No Library/action bar is built, so no live title or status label
        -- exists; clear the guards so any in-flight reveal bails instead of
        -- painting freed widgets.
        self._title_label = nil
        self._status_label = nil
        self._title_region = nil
        local empty = EmptyState.build(
            metrics.content_w,
            BookRepository.resolveBrowseDir(),
            function() self:onSwitchToFileManager() end
        )
        content_sections[#content_sections + 1] = CenterContainer:new {
            dimen = Geom:new { w = metrics.content_w, h = inner_h },
            empty,
        }
    else
        local continue_section = ContinueSection.build(continue_book, metrics, on_open)
        content_sections[#content_sections + 1] = continue_section

        -- Continue open-book tap is a Home touch zone (see initMenuGesListener)
        -- so the top-of-screen menu gestures keep priority. Store the book +
        -- the Continue slot's screen rect for that zone.
        self._continue_book = continue_book
        self._continue_tap_region = Geom:new {
            x = metrics.main_h_padding,
            y = metrics.main_v_padding,
            w = metrics.content_w,
            h = metrics.continue_slot_h,
        }

        -- Hide the Continue book wherever it appears in the grid (path match).
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

        local current_title = nil
        if self.current_dir ~= self.root_dir then
            current_title = self.current_dir:match("([^/]+)/?$") or self.current_dir
        end

        -- Screen-space rect of the Library header (action bar row), used to
        -- refresh just the title as its typewriter reveal adds characters. It
        -- accounts for the Library section padding (the top inset uses the
        -- smaller library_top pad, matching LibrarySection.build).
        local lib_hdr_pad = Layout.pad.cover
        local title_region = Geom:new {
            x = metrics.main_h_padding + lib_hdr_pad,
            y = metrics.main_v_padding + metrics.continue_slot_h + Layout.pad.library_top,
            w = math.max(0, metrics.content_w - 2 * lib_hdr_pad),
            h = Layout.dim.action_bar,
        }
        -- Keep the header row's screen-space rect for the live status refresh.
        self._title_region = title_region

        content_sections[#content_sections + 1] = LibrarySection.build(library_entries, metrics, on_open, {
            sort_mode = self.sort_mode,
            page = self.library_page,
            show_parent = self,
            current_title = current_title,
            home = self,
            title_region = title_region,
            animate_title = animate_title,
            on_open = on_open,
            on_enter = on_enter,
            on_sort_menu = function() self:onShowSortMenu() end,
            on_page_change = function(page) self:onPageChange(page) end,
            on_go_up = function() self:onGoUp() end,
        })
        self._library_refresh_region = _libraryRefreshRegion(metrics)

        -- Paging state consulted by swipe handling: page size (columns * rows)
        -- and the total number of Library entries let us clamp/short-circuit at
        -- bounds. Must mirror the section padding applied in LibrarySection.build
        -- (including the smaller top pad) so the page size matches the grid.
        local lib_pad = Layout.pad.cover
        local lib_inner_w = math.max(0, metrics.content_w - 2 * lib_pad)
        local lib_inner_h = math.max(0, metrics.library_h - Layout.pad.library_top - lib_pad)
        local grid_metrics = Layout.libraryGridMetrics(lib_inner_w, lib_inner_h)
        self._library_page_size = grid_metrics.library_cols * grid_metrics.library_rows
        self._library_entry_count = #library_entries
    end

    local main_content = MainContent.build(self.screen_w, metrics, content_sections)

    -- Home is a clean vertical stack: Continue on top, Library below. No overlay.
    self.main_group = main_content

    self[1] = FrameContainer:new {
        width = self.screen_w,
        height = self.screen_h,
        radius = 0,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        self.main_group,
    }
end

function Home:onSetDimensions(dimen)
    self.dimen = dimen
    self.screen_w = dimen.w
    self.screen_h = dimen.h
    self:refresh()
end

--- Called whenever Home becomes the frontmost view again (returning from the
--- reader or waking from the lock screen). Does an immediate refresh once and
--- replays the title animation. Dismissing the status panel intentionally
--- does NOT replay: the greeting/time label keeps its current state.
function Home:refreshOnReentry()
    -- Replay the title typewriter animation on the next rebuild.
    self._title_label = nil
    self._status_label = nil
    self._title_replay = true
    -- Rebuild + full flashing refresh (re-runs the title reveal from its
    -- first character).
    self:refresh()
end

function Home:onShow()
    UIManager:setDirty(self, "full")
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
end

function Home:onCloseWidget()
    -- Stop any in-flight title reveal (its scheduled ticks bail once this
    -- reference no longer matches the animating label).
    self._title_label = nil
    self._status_label = nil
    self._title_region = nil
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

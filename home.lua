--[[--
home.koplugin/home.lua — The full-screen Home main-view widget.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local ContinueSection = require("continue_section")
local DebugOverlay = require("debug_overlay")
local Device = require("device")
local EmptyState = require("empty_state")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Layout = require("layout")
local BD = require("ui/bidi")
local LineWidget = require("ui/widget/linewidget")
local MainContent = require("main_content")
local RecentSection = require("recent_section")
local Slider = require("slider")
local StatusBar = require("status_bar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local ffiUtil = require("ffi/util")
local _ = require("gettext")
local Screen = Device.screen

local Home = InputContainer:extend{
    name = "home_widget",
    covers_fullscreen = true,
}

function Home:init()
    local s = Screen:getSize()
    self.dimen = s
    self.screen_w = s.w
    self.screen_h = s.h
    self.sort_mode = BookRepository.getSortMode()
    self.recent_page = self.recent_page or 0
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
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            handler = function(ges) return self:onTapShowMenu(ges) end,
        },
        {
            id = "home_ext_tap",
            ges = "tap",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x, ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w, ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
            overrides = { "home_tap" },
            handler = function(ges) return self:onTapShowMenu(ges) end,
        },
        {
            id = "home_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU.x, ratio_y = DTAP_ZONE_MENU.y,
                ratio_w = DTAP_ZONE_MENU.w, ratio_h = DTAP_ZONE_MENU.h,
            },
            overrides = { "rolling_swipe", "paging_swipe" },
            handler = function(ges) return self:onSwipeShowMenu(ges) end,
        },
        {
            id = "home_ext_swipe",
            ges = "swipe",
            screen_zone = {
                ratio_x = DTAP_ZONE_MENU_EXT.x, ratio_y = DTAP_ZONE_MENU_EXT.y,
                ratio_w = DTAP_ZONE_MENU_EXT.w, ratio_h = DTAP_ZONE_MENU_EXT.h,
            },
            overrides = { "home_swipe" },
            handler = function(ges) return self:onSwipeShowMenu(ges) end,
        },
        {
            id = "home_recent_swipe",
            ges = "swipe",
            screen_zone = self:_recentSwipeScreenZone(),
            overrides = {
                "home_swipe", "home_ext_swipe",
                "rolling_swipe", "paging_swipe",
            },
            handler = function(ges) return self:onRecentSwipe(ges) end,
        },
        {
            id = "home_statusbar_icons_tap",
            ges = "tap",
            screen_zone = self:_statusBarIconsScreenZone(),
            overrides = { "home_tap", "home_ext_tap" },
            handler = function(ges) return self:onShowStatusPanel(ges) end,
        },
    })
end

--- Screen zone (ratios) covering the status bar's right-hand icon cluster
--- (frontlight / Wi-Fi / battery). Tapping it opens the status panel.
function Home:_statusBarIconsScreenZone()
    local region = self.status_bar and self.status_bar.right_region
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

function Home:onShowStatusPanel()
    local StatusPanel = require("status_panel")
    local row_h = self.status_bar and self.status_bar:getHeight() or nil
    UIManager:show(StatusPanel:new{ row_h = row_h, home = self })
    return true
end

--- While the status panel is open, its own controls own the frontlight/Wi-Fi
--- state and it covers the status bar, so suppress the status bar's periodic
--- and event-driven refreshes to avoid repainting underneath the panel.
function Home:pauseStatusBar()
    self._status_bar_paused = true
    StatusBar.unschedule(self)
end

function Home:resumeStatusBar()
    self._status_bar_paused = false
    -- Dismissing the panel returns Home to the front: replay the greeting and
    -- rebuild the whole layout so the panel's closing full-screen flash paints
    -- a freshly-refreshed Home (including an up-to-date status bar). We rebuild
    -- here WITHOUT issuing our own partial refresh — the panel's close does the
    -- flashing full-screen repaint; a partial refresh here would race it and
    -- leave the panel ghosting. This also re-arms the periodic timer, which was
    -- parked while the panel covered Home.
    self._greeting_animated = nil
    self._greeting_label = nil
    if self[1] and self[1].free then self[1]:free() end
    StatusBar.unschedule(self)
    self:buildLayout()
    StatusBar.scheduleRefresh(self, function()
        if self.status_bar and self.status_bar.updatePeriodic then
            self.status_bar:updatePeriodic()
        end
    end)
end

--- Screen zone (ratios) covering the Recent grid, where left/right swipes page
--- and an upward swipe returns to the parent folder.
function Home:_recentSwipeScreenZone()
    local region = self._recent_refresh_region
    if not region or self.screen_w <= 0 or self.screen_h <= 0 then
        -- No recent grid yet: use an empty zone so the handler never fires.
        return { ratio_x = 0, ratio_y = 0, ratio_w = 0, ratio_h = 0 }
    end
    return {
        ratio_x = region.x / self.screen_w,
        ratio_y = region.y / self.screen_h,
        ratio_w = region.w / self.screen_w,
        ratio_h = region.h / self.screen_h,
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

function Home:setSortMode(mode)
    mode = mode == "name" and "name" or "recent"
    BookRepository.setSortMode(mode)
    self.sort_mode = mode
    self.recent_page = 0
    self:refreshRecent()
end

function Home:onShowSortMenu()
    local dialog
    local function pick(mode)
        return function()
            UIManager:close(dialog)
            self:setSortMode(mode)
        end
    end
    dialog = ButtonDialog:new{
        title = _("Sort by"),
        title_align = "center",
        buttons = {
            {{
                text = _("Name"),
                checked_func = function() return self.sort_mode == "name" end,
                callback = pick("name"),
            }},
            {{
                text = _("Last read"),
                checked_func = function() return self.sort_mode == "recent" end,
                callback = pick("recent"),
            }},
        },
    }
    UIManager:show(dialog)
end

function Home:onPageChange(page)
    self.recent_page = page
    self:refreshRecent()
end

--- Number of Recent pages given the current page size and entry count.
function Home:_recentPageCount()
    local page_size = self._recent_page_size or 0
    if page_size <= 0 then return 1 end
    local count = self._recent_entry_count or 0
    return math.max(1, math.ceil(count / page_size))
end

--- Turn the Recent grid one page in the given direction (-1 prev, +1 next),
--- clamped to the available pages. No-op (returns false) at the boundary.
function Home:_turnRecentPage(delta)
    local page_count = self:_recentPageCount()
    local target = (self.recent_page or 0) + delta
    if target < 0 or target > page_count - 1 then return false end
    self:onPageChange(target)
    return true
end

--- Swipe over the Recent grid: left/right page (honoring RTL mirroring), an
--- upward swipe returns to the parent folder.
function Home:onRecentSwipe(ges)
    local direction = ges and ges.direction
    if direction == "north" then
        self:onGoUp()
        return true
    end

    direction = BD.flipDirectionIfMirroredUILayout(direction)
    if direction == "east" then
        self:_turnRecentPage(-1)
        return true
    elseif direction == "west" then
        self:_turnRecentPage(1)
        return true
    end
    return false
end

function Home:onEnterFolder(dir)
    self.dir_stack[#self.dir_stack + 1] = self.current_dir
    self.current_dir = dir
    self.recent_page = 0
    self:refreshRecent()
end

function Home:onGoUp()
    local parent = table.remove(self.dir_stack)
    if parent then
        self.current_dir = parent
        self.recent_page = 0
        self:refreshRecent()
    end
end

-- Region covering only the Recent grid, used for partial refreshes when
-- paging or toggling sort without repainting the whole screen.
local function _recentRefreshRegion(metrics, status_bar_h)
    return Geom:new{
        x = metrics.main_h_padding,
        y = status_bar_h + metrics.main_v_padding
            + metrics.continue_slot_h + metrics.section_gap,
        w = metrics.content_w,
        h = metrics.recent_h,
    }
end

function Home:buildLayout()
    self.status_bar = StatusBar:new()
    local status_bar_h = self.status_bar:getHeight()
    local metrics = Layout.mainContentMetrics(self.screen_w, self.screen_h, status_bar_h)
    local inner_h = metrics.inner_h

    local continue_book = BookRepository.getGlobalLastReadBook()
    local entries = BookRepository.getRecentEntries(self.current_dir, self.sort_mode)
    local on_open = function(fp) self:onOpenBook(fp) end
    local on_enter = function(dir) self:onEnterFolder(dir) end

    local content_sections = VerticalGroup:new{ align = "left" }

    -- With no book to continue, show the empty state; otherwise render the
    -- Continue hero followed by the Recent grid.
    if not continue_book then
        self._recent_refresh_region = nil
        self._recent_page_size = 0
        self._recent_entry_count = 0
        local empty = EmptyState.build(
            metrics.content_w,
            BookRepository.resolveBrowseDir(),
            function() self:onSwitchToFileManager() end
        )
        content_sections[#content_sections + 1] = DebugOverlay.wrap("empty_state", CenterContainer:new{
            dimen = Geom:new{ w = metrics.content_w, h = inner_h },
            empty,
        }, metrics.content_w, inner_h, "empty_state")
    else
        -- Screen-space rect of the greeting slot (top-left of the Continue
        -- section), used to refresh just the greeting as its typewriter reveal
        -- adds characters. TextWidget doesn't expose its painted rect, so we
        -- derive it from the layout: content column, just below the status bar.
        local greeting_region = Geom:new{
            x = metrics.main_h_padding,
            y = status_bar_h + metrics.main_v_padding,
            w = metrics.content_w,
            h = math.min(metrics.continue_slot_h, Layout.greetingFace().size * 3),
        }
        content_sections[#content_sections + 1] = ContinueSection.build(continue_book, metrics, on_open, self, greeting_region)

        -- Hide the Continue book wherever it appears in the grid (path match).
        local continue_rp = ffiUtil.realpath(continue_book) or continue_book
        local recent_entries = {}
        for _, entry in ipairs(entries) do
            local keep = true
            if entry.type == "book" then
                local rp = ffiUtil.realpath(entry.path) or entry.path
                if rp == continue_rp then keep = false end
            end
            if keep then recent_entries[#recent_entries + 1] = entry end
        end

        if metrics.section_gap > 0 then
            -- A 1px divider flanked by equal edge gaps. The bottom edge gap
            -- (divider -> Recent header) equals the Recent header title -> books
            -- gap, and the divider line center lands on the golden-ratio point.
            local line_h = metrics.divider_line_h
            local top_h = metrics.section_edge_gap
            local bottom_h = metrics.section_edge_gap
            if top_h > 0 then
                content_sections[#content_sections + 1] = VerticalSpan:new{ width = top_h }
            end
            content_sections[#content_sections + 1] = LineWidget:new{
                dimen = Geom:new{ w = metrics.content_w, h = line_h },
                background = Blitbuffer.COLOR_GRAY_E,
            }
            if bottom_h > 0 then
                content_sections[#content_sections + 1] = VerticalSpan:new{ width = bottom_h }
            end
        end

        local current_title = nil
        if self.current_dir ~= self.root_dir then
            current_title = self.current_dir:match("([^/]+)/?$") or self.current_dir
        end

        content_sections[#content_sections + 1] = RecentSection.build(recent_entries, metrics, on_open, {
            sort_mode = self.sort_mode,
            page = self.recent_page,
            show_parent = self,
            current_title = current_title,
            on_open = on_open,
            on_enter = on_enter,
            on_sort_menu = function() self:onShowSortMenu() end,
            on_page_change = function(page) self:onPageChange(page) end,
            on_go_up = function() self:onGoUp() end,
        })
        self._recent_refresh_region = _recentRefreshRegion(metrics, status_bar_h)

        -- Paging state consulted by swipe handling: page size (columns) and the
        -- total number of Recent entries let us clamp/short-circuit at bounds.
        local grid_metrics = Layout.recentGridMetrics(metrics.content_w, metrics.recent_h)
        self._recent_page_size = grid_metrics.recent_cols
        self._recent_entry_count = #recent_entries
    end

    content_sections = DebugOverlay.wrap("content_sections", content_sections,
        metrics.content_w, inner_h, "content_sections")

    -- Home slider (reusable; will drive frontlight brightness later). Centered
    -- within the content column.
    self.slider = Slider:new{
        value = self.slider_value or 16,
        min = 0,
        max = 100,
        show_parent = self,
        on_change = function(v) self.slider_value = v end,
    }
    content_sections[#content_sections + 1] = VerticalSpan:new{ width = metrics.section_gap }
    content_sections[#content_sections + 1] = CenterContainer:new{
        dimen = Geom:new{ w = metrics.content_w, h = self.slider.h },
        self.slider,
    }

    local main_content = MainContent.build(self.screen_w, metrics, content_sections)

    local main_group = VerticalGroup:new{
        align = "left",
        self.status_bar,
        main_content,
    }
    local main_group_h = status_bar_h + metrics.main_h
    self.main_group = DebugOverlay.wrap("main_group", main_group,
        self.screen_w, main_group_h, "main_group")

    self[1] = DebugOverlay.wrap("home_root", FrameContainer:new{
        width = self.screen_w,
        height = self.screen_h,
        radius = 0,
        bordersize = 0,
        padding = 0,
        margin = 0,
        background = Blitbuffer.COLOR_WHITE,
        self.main_group,
    }, self.screen_w, self.screen_h, "home_root")
end

function Home:onSetDimensions(dimen)
    self.dimen = dimen
    self.screen_w = dimen.w
    self.screen_h = dimen.h
    self:refresh()
end

function Home:refreshStatusBarTime()
    if self._status_bar_paused then return end
    if self.status_bar and self.status_bar.updateTime then
        self.status_bar:updateTime()
    end
end

function Home:refreshStatusBarRight()
    if self._status_bar_paused then return end
    if self.status_bar and self.status_bar.updateRight then
        self.status_bar:updateRight()
    end
end

function Home:onNetworkConnected()
    self:refreshStatusBarRight()
end
Home.onNetworkDisconnected = Home.onNetworkConnected

function Home:onFrontlightStateChanged()
    self:refreshStatusBarRight()
end
Home.onFrontlightTurnedOff = Home.onFrontlightStateChanged

function Home:onCharging()
    self:refreshStatusBarRight()
end
Home.onNotCharging = Home.onCharging

function Home:onTimeFormatChanged()
    self:refreshStatusBarTime()
end

local function _scheduleStatusBarRefresh(home)
    StatusBar.scheduleRefresh(home, function()
        if home.status_bar and home.status_bar.updatePeriodic then
            home.status_bar:updatePeriodic()
        end
    end)
end

--- Called whenever Home becomes the frontmost view again (returning from the
--- reader, dismissing the status panel, or waking from the lock screen). Does
--- an immediate refresh once and replays the greeting animation; the periodic
--- per-minute refresh only runs while Home is frontmost (see
--- StatusBar.scheduleRefresh), so this both re-arms that timer and repaints now.
function Home:refreshOnReentry()
    if self._status_bar_paused then return end
    -- Replay the greeting typewriter animation on the next rebuild.
    self._greeting_animated = nil
    self._greeting_label = nil
    -- Rebuild + full flashing refresh (re-runs the greeting reveal from its
    -- first character) and re-arm the periodic status-bar timer.
    self:refresh()
end

function Home:onShow()
    _scheduleStatusBarRefresh(self)
    -- Full flashing refresh to clear any ghosting when returning from the FM
    -- or the reader.
    UIManager:setDirty(self, "full")
end

-- When the device suspends (screen locks), the periodic status-bar timer must
-- be cancelled: Home stays on the widget stack under the lock screen, so a
-- tick would flash the status bar region behind the screensaver.
function Home:onSuspend()
    StatusBar.unschedule(self)
end

-- Reschedule the periodic refresh once we're back. If a screensaver_delay is
-- active, the screensaver is dismissed later via OutOfScreenSaver, so defer
-- until then to avoid painting under the lock screen.
function Home:onResume()
    local screensaver_delay = G_reader_settings:readSetting("screensaver_delay")
    if screensaver_delay and screensaver_delay ~= "disable" then
        self._delayed_statusbar_resume = true
        return
    end
    self:_reentryIfFrontmost()
end

function Home:onOutOfScreenSaver()
    if not self._delayed_statusbar_resume then return end
    self._delayed_statusbar_resume = nil
    self:_reentryIfFrontmost()
end

-- Waking / dismissing the lock screen only re-enters Home if Home is actually
-- the frontmost view now (the reader or another widget may be on top instead).
-- When it is, refresh immediately and replay the greeting; otherwise there is
-- nothing to repaint (and the periodic timer stays parked until Home is front).
function Home:_reentryIfFrontmost()
    if UIManager:getTopmostVisibleWidget() == self then
        self:refreshOnReentry()
    end
end

function Home:refreshRecent()
    self:refresh({
        refreshtype = "ui",
        partial_recent = true,
        refreshdither = true,
    })
end

function Home:refresh(opts)
    opts = opts or {}
    if self[1] and self[1].free then self[1]:free() end
    StatusBar.unschedule(self)
    self:buildLayout()
    _scheduleStatusBarRefresh(self)
    local refreshtype = opts.refreshtype or "flashui"
    local region = opts.refreshregion
    if opts.partial_recent and self._recent_refresh_region then
        region = self._recent_refresh_region
    end
    local dither = opts.refreshdither
    if region then
        UIManager:setDirty(self, refreshtype, region, dither)
    else
        UIManager:setDirty(self, refreshtype)
    end
end

function Home:onCloseWidget()
    -- Stop any in-flight greeting reveal (its scheduled ticks bail once this
    -- reference no longer matches the animating label).
    self._greeting_label = nil
    StatusBar.unschedule(self)
end

function Home:onClose()
    UIManager:close(self)
    return true
end

return Home

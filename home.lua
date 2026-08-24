--[[--
home.koplugin/home.lua — The full-screen Home main-view widget.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local BookRepository = require("book_repository")
local CenterContainer = require("ui/widget/container/centercontainer")
local ContinueSection = require("continue_section")
local DebugOverlay = require("debug_overlay")
local Device = require("device")
local EmptyState = require("empty_state")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Layout = require("layout")
local MainContent = require("main_content")
local RecentSection = require("recent_section")
local StatusBar = require("status_bar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
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
    })
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

function Home:onSortToggle()
    self.sort_mode = BookRepository.toggleSortMode()
    self.recent_page = 0
    self:refreshRecent()
end

function Home:onPageChange(page)
    self.recent_page = page
    self:refreshRecent()
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

    local continue_book = BookRepository.getLastReadBook()
    local books = BookRepository.getSortedBooks(nil, self.sort_mode)
    local on_open = function(fp) self:onOpenBook(fp) end

    local content_sections = VerticalGroup:new{ align = "left" }

    -- With no book to continue, show the empty state; otherwise render the
    -- Continue hero followed by the Recent grid.
    if not continue_book then
        self._recent_refresh_region = nil
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
        content_sections[#content_sections + 1] = ContinueSection.build(continue_book, metrics, on_open)

        local recent_paths = {}
        for _, path in ipairs(books) do
            if path ~= continue_book then
                recent_paths[#recent_paths + 1] = path
            end
        end

        if metrics.section_gap > 0 then
            content_sections[#content_sections + 1] = VerticalSpan:new{
                width = metrics.section_gap,
            }
        end

        content_sections[#content_sections + 1] = RecentSection.build(recent_paths, metrics, on_open, {
            sort_mode = self.sort_mode,
            page = self.recent_page,
            show_parent = self,
            on_sort_toggle = function() self:onSortToggle() end,
            on_page_change = function(page) self:onPageChange(page) end,
        })
        self._recent_refresh_region = _recentRefreshRegion(metrics, status_bar_h)
    end

    content_sections = DebugOverlay.wrap("content_sections", content_sections,
        metrics.content_w, inner_h, "content_sections")

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
    if self.status_bar and self.status_bar.updateTime then
        self.status_bar:updateTime()
    end
end

function Home:refreshStatusBarRight()
    if self.status_bar and self.status_bar.updateRight then
        self.status_bar:updateRight()
    end
end

function Home:onNetworkConnected()
    self:refreshStatusBarRight()
end
Home.onNetworkDisconnected = Home.onNetworkConnected

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

function Home:onShow()
    _scheduleStatusBarRefresh(self)
    -- Full flashing refresh to clear any ghosting when returning from the FM
    -- or the reader.
    UIManager:setDirty(self, "full")
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
    StatusBar.unschedule(self)
end

function Home:onClose()
    UIManager:close(self)
    return true
end

return Home

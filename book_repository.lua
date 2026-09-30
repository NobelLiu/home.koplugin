--[[--
book_repository.lua — Book scanning, sorting, metadata and open logic (no UI).
--]]

local BookList = require("ui/widget/booklist")
local DataStorage = require("datastorage")
local Device = require("device")
local DocSettings = require("docsettings")
local ReadHistory = require("readhistory")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local realpath = ffiUtil.realpath
local util = require("util")

local BookRepository = {}

-- Collate ids whose item_func needs a FileManager ui (ui.bookinfo:getDocProps).
-- Used to guard the folder-cover mosaic path, which has no ui available.
local UI_DEPENDENT_COLLATES = {
    title = true, authors = true, series = true, keywords = true, rating = true,
}

-- Home-origin marker: set when a reader is opened from Home, so the reader's
-- "back to file browser" actions can restore Home (whatever the document's own
-- location) instead of opening the file manager at the document's folder.
-- The value is the Home root folder at open time (nil when not from Home).
local _home_origin_dir = nil

-- The reading statistics plugin persists per-book total reading time in its
-- SQLite DB (book.total_read_time, keyed by the book's partial md5), NOT in the
-- sidecar's `stats` table. Query the DB directly so the "Continue" progress row
-- can show how long the book has actually been read.
local STATISTICS_DB = DataStorage:getSettingsDir() .. "/statistics.sqlite3"

--- Looks up the total reading time (in seconds) for a book by its partial md5.
--- @param md5 string|nil The book's partial_md5_checksum from its sidecar.
--- @return number Total reading time in seconds (0 if unavailable).
local function getReadTimeFromStatsDB(md5)
    if type(md5) ~= "string" or not md5:match("^%x+$") then return 0 end
    if lfs.attributes(STATISTICS_DB, "mode") ~= "file" then return 0 end

    local read_time = 0
    local ok, err = pcall(function()
        local SQ3 = require("lua-ljsqlite3/init")
        local conn = SQ3.open(STATISTICS_DB, "ro")
        -- md5 is validated as hex above, so direct interpolation is safe here
        -- (matches the statistics plugin's own rowexec-based queries).
        local t = conn:rowexec(string.format(
            "SELECT sum(total_read_time) FROM book WHERE md5 = '%s';", md5))
        read_time = tonumber(t) or 0
        conn:close()
    end)
    if not ok then
        logger.dbg("home: getReadTimeFromStatsDB failed:", err)
        return 0
    end
    return read_time
end

local ALLOWED_SUFFIXES = {
    epub = true, pdf = true, djvu = true, djv = true,
    xps = true, cbt = true, cbz = true, fb2 = true,
    pdb = true, txt = true, html = true, htm = true,
    rtf = true, chm = true, doc = true, mobi = true, zip = true,
}

local MAX_SCAN = 10000

function BookRepository.resolveHomeDir()
    local home = G_reader_settings:readSetting("home_dir")
    if home and home ~= "" then return home end
    return Device.home_dir or (lfs.currentdir and lfs.currentdir())
end

function BookRepository.resolveBrowseDir()
    local ok, FileManager = pcall(require, "apps/filemanager/filemanager")
    if ok and FileManager and FileManager.instance then
        local path = FileManager.instance.file_chooser and FileManager.instance.file_chooser.path
        if path and path ~= "" then return path end
    end
    return BookRepository.resolveHomeDir()
end

function BookRepository.setHomeOrigin(dir)
    _home_origin_dir = dir or BookRepository.resolveHomeDir()
end

--- Non-destructive peek at the Home-origin marker (nil when the current reader
--- was not opened from Home). Used e.g. to pick the reader top-menu icon.
function BookRepository.getHomeOrigin()
    return _home_origin_dir
end

--- True when the reader's "back to file browser" action should restore Home
--- (not the document folder in FileManager). Matches _backToHomeFromReader().
function BookRepository.readerBackGoesToHome()
    return _home_origin_dir ~= nil
end

--- KOReader top-menu icon for the reader filemanager/home back button.
function BookRepository.readerBackIcon()
    if BookRepository.readerBackGoesToHome() then
        return "home"
    end
    return "appbar.filebrowser"
end

--- One-shot: returns the stored Home root folder (and clears the marker), or
--- nil if the current reader session was not opened from Home.
function BookRepository.consumeHomeOrigin()
    local dir = _home_origin_dir
    _home_origin_dir = nil
    return dir
end

local function isAllowedBookName(name)
    if util.stringStartsWith(name, "._") then return false end
    return ALLOWED_SUFFIXES[util.getFileNameSuffix(name):lower()] == true
end

local function listBooksInDir(dir)
    local books = {}
    if not dir or lfs.attributes(dir, "mode") ~= "directory" then
        return books
    end
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then return books end
    for name in iter, dir_obj do
        if #books >= MAX_SCAN then break end
        if name ~= "." and name ~= ".." then
            local path = ffiUtil.joinPath(dir, name)
            local attr = lfs.attributes(path)
            if attr and attr.mode == "file" and isAllowedBookName(name) then
                books[#books + 1] = path
            end
        end
    end
    return books
end

local function listSubdirsInDir(dir)
    local dirs = {}
    if not dir or lfs.attributes(dir, "mode") ~= "directory" then
        return dirs
    end
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then return dirs end
    for name in iter, dir_obj do
        if #dirs >= MAX_SCAN then break end
        if name ~= "." and name ~= ".."
                and not util.stringStartsWith(name, "._")
                and not util.stringEndsWith(name, ".sdr") then
            local path = ffiUtil.joinPath(dir, name)
            local attr = lfs.attributes(path)
            if attr and attr.mode == "directory" then
                dirs[#dirs + 1] = path
            end
        end
    end
    return dirs
end

local function basename(filepath)
    return filepath:match("([^/]+)$") or filepath
end

local function buildReadTimeMap()
    ReadHistory:reload()
    local map = {}
    for _, item in ipairs(ReadHistory.hist or {}) do
        if item.file then
            local fp = realpath(item.file) or item.file
            local t = item.time or 0
            if not map[fp] or t > map[fp] then map[fp] = t end
        end
    end
    return map
end

local function getLastReadTime(filepath, read_times)
    local fp = realpath(filepath) or filepath
    local t = read_times[fp]
    if t and t > 0 then return t end
    if DocSettings:hasSidecarFile(fp) then
        local sidecar = DocSettings:findSidecarFile(fp)
        if sidecar then
            local attr = lfs.attributes(sidecar)
            if attr and attr.modification then return attr.modification end
        end
    end
    return 0
end

--- The Library shares KOReader's global FileManager "Sort by" setting
--- (G_reader_settings "collate"), along with "reverse_collate" and
--- "collate_mixed". All sort modes are defined once in BookList.collates.
--- Mirrors FileChooser:getCollate(): returns the collate table plus its id,
--- falling back to "strcoll" (name) for an unknown/missing setting.
function BookRepository.getCollate()
    local BookList = require("ui/widget/booklist")
    local collate_id = G_reader_settings:readSetting("collate", "strcoll")
    local collate = BookList.collates[collate_id]
    if collate ~= nil then
        return collate, collate_id
    end
    G_reader_settings:saveSetting("collate", "strcoll")
    return BookList.collates.strcoll, "strcoll"
end

--- Save the global FileManager "Sort by" (collate) setting. `id` must be a
--- BookList.collates key; unknown ids fall back to "strcoll".
function BookRepository.setCollate(id)
    local BookList = require("ui/widget/booklist")
    if not (id and BookList.collates[id]) then
        id = "strcoll"
    end
    G_reader_settings:saveSetting("collate", id)
end

--- Build a collate item for a book/folder path so BookList.collates can sort
--- it (they operate on { text, path, attr, ... }). `ui` is the live FileManager
--- instance (fm), needed by metadata collates (title/authors/series/keywords/
--- rating) whose item_func calls ui.bookinfo:getDocProps(...). When such a
--- collate is requested without a `ui`, the caller should have substituted a
--- safe collate; this guards against a nil index just in case.
local function makeCollateItem(path, is_file, collate, ui)
    local item = {
        text = basename(path),
        path = path,
        attr = lfs.attributes(path) or {},
        is_file = is_file,
    }
    local function runItemFunc()
        if collate and collate.item_func ~= nil then
            local ok = pcall(collate.item_func, item, ui)
            if not ok then
                -- Metadata collate without a usable ui: leave keys unset; the
                -- comparator's strcoll fallback on item.text still orders it.
            end
        end
    end
    if is_file then
        runItemFunc()
        if item.opened == nil then
            item.opened = require("ui/widget/booklist").hasBookBeenOpened(path)
        end
    elseif collate and collate.can_collate_mixed then
        runItemFunc()
    end
    return item
end

--- Sorting comparator for the given collate, wrapping for reverse order.
--- Mirrors FileChooser:getSortingFunction().
local function collateSortingFunction(collate, reverse_collate)
    local sorting = collate.init_sort_func()
    if reverse_collate then
        local unreversed = sorting
        sorting = function(a, b) return unreversed(b, a) end
    end
    return sorting
end

--- FileManager "Book status" filter (menu: filemanager_show_filter). Stored in
--- G_reader_settings "show_filter".status as a set of visible statuses
--- ("new"/"reading"/"abandoned"/"complete"); nil means show all. Applies to
--- books only, matching FileChooser:show_file().
--- @return function(path)->boolean  true when the book should be shown
local function makeBookStatusFilter()
    local show_filter = G_reader_settings:readSetting("show_filter")
    local status = show_filter and show_filter.status
    if not status then
        return function() return true end
    end
    local BookList = require("ui/widget/booklist")
    return function(path)
        return status[BookList.getBookStatus(path)] == true
    end
end

--- Most recently read book in the given directory (independent of the Library
--- sort mode). Continue hero uses ReadHistory/sidecar semantics, not the
--- FileManager collate.
function BookRepository.getLastReadBook(dir)
    local books = listBooksInDir(dir or BookRepository.resolveBrowseDir())
    if #books == 0 then return nil end
    local read_times = buildReadTimeMap()
    table.sort(books, function(a, b)
        local ta = getLastReadTime(a, read_times)
        local tb = getLastReadTime(b, read_times)
        if ta ~= tb then return ta > tb end
        return ffiUtil.strcoll(basename(a), basename(b))
    end)
    return books[1]
end

--- Books directly inside `dir`, sorted by the current (or given) collate.
--- Used by the folder-cover mosaic. `ui` is the live FileManager instance,
--- required by metadata collates; when absent, such collates fall back to
--- name sorting so the mosaic never crashes on missing doc_props.
function BookRepository.getSortedBooks(dir, collate_id, ui)
    local isBookVisible = makeBookStatusFilter()
    local books = {}
    for _, fp in ipairs(listBooksInDir(dir or BookRepository.resolveBrowseDir())) do
        if isBookVisible(fp) then books[#books + 1] = fp end
    end
    if #books == 0 then return books end

    local BookList = require("ui/widget/booklist")
    local collate = collate_id and BookList.collates[collate_id]
    if not collate then
        collate, collate_id = BookRepository.getCollate()
    end
    -- Metadata collates need a FileManager ui (ui.bookinfo:getDocProps). Without
    -- one, sort the mosaic by name instead of risking a nil doc_props.
    if not ui and UI_DEPENDENT_COLLATES[collate_id] then
        collate = BookList.collates.strcoll
    end
    local reverse = BookRepository.isReverseCollate()

    local items = {}
    for _, fp in ipairs(books) do
        items[#items + 1] = makeCollateItem(fp, true, collate, ui)
    end
    table.sort(items, collateSortingFunction(collate, reverse))

    local sorted = {}
    for _, item in ipairs(items) do
        sorted[#sorted + 1] = item.path
    end
    return sorted
end

--- Whether a book has a usable cover image (best-effort via BookInfoManager).
local function hasCover(filepath)
    local ok_bim, BIM = pcall(require, "bookinfomanager")
    if not (ok_bim and BIM) then return false end
    local ok, bi = pcall(BIM.getBookInfo, BIM, filepath, true)
    return ok and bi and bi.cover_bb ~= nil
end

--- Books with cover images for a folder's mosaic, in the current sort order,
--- capped at `n` (default 4). Books without covers are skipped so remaining
--- mosaic slots can show the folder title instead.
function BookRepository.getFolderCoverBooks(dir, collate_id, n, ui)
    n = n or 4
    local result = {}
    for _, fp in ipairs(BookRepository.getSortedBooks(dir, collate_id, ui)) do
        if hasCover(fp) then
            result[#result + 1] = fp
            if #result >= n then break end
        end
    end
    return result
end

--- FileManager menu options that Home honors too:
---   reverse_collate — descending order
---   collate_mixed   — interleave folders and files instead of grouping them
function BookRepository.isReverseCollate()
    return G_reader_settings:isTrue("reverse_collate")
end

function BookRepository.isCollateMixed()
    return G_reader_settings:isTrue("collate_mixed")
end

--- Unified Library entries, sorted by KOReader's global FileManager "Sort by"
--- (collate) setting plus "Reverse sorting" (reverse_collate) and "Sort folders
--- and files together" (collate_mixed):
---   mixed (only when collate.can_collate_mixed): books and folders interleaved
---     and sorted by the same key; reverse flips the combined order.
---   grouped (default): books first (sorted by the collate), then folders
---     (always sorted by name, matching FileManager); reverse flips books only.
--- `ui` is the live FileManager instance (metadata collates call
--- ui.bookinfo:getDocProps); when absent, those collates fall back to name.
--- @return table list of { type = "book"|"folder", path, name }
function BookRepository.getLibraryEntries(dir, collate_id, ui)
    dir = dir or BookRepository.resolveBrowseDir()

    local BookList = require("ui/widget/booklist")
    local collate = collate_id and BookList.collates[collate_id]
    if not collate then
        collate, collate_id = BookRepository.getCollate()
    end
    -- Metadata collates need a FileManager ui. Without one, fall back to name.
    if not ui and UI_DEPENDENT_COLLATES[collate_id] then
        collate, collate_id = BookList.collates.strcoll, "strcoll"
    end
    local reverse = BookRepository.isReverseCollate()
    local mixed = collate.can_collate_mixed and BookRepository.isCollateMixed()

    local isBookVisible = makeBookStatusFilter()
    local books = {}
    for _, fp in ipairs(listBooksInDir(dir)) do
        if isBookVisible(fp) then books[#books + 1] = fp end
    end
    local subdirs = listSubdirsInDir(dir)

    local function toEntry(item)
        return { type = item.is_file and "book" or "folder", path = item.path, name = basename(item.path) }
    end

    if mixed then
        -- One combined list sorted by a single collate key.
        local items = {}
        for _, fp in ipairs(books) do
            items[#items + 1] = makeCollateItem(fp, true, collate, ui)
        end
        for _, d in ipairs(subdirs) do
            items[#items + 1] = makeCollateItem(d, false, collate, ui)
        end
        table.sort(items, collateSortingFunction(collate, reverse))
        local entries = {}
        for _, item in ipairs(items) do
            entries[#entries + 1] = toEntry(item)
        end
        return entries
    end

    -- Grouped: books first (collate-sorted, reversible), then folders. Folders
    -- are always sorted by name (strcoll) and not reversed, matching FileManager.
    local book_items = {}
    for _, fp in ipairs(books) do
        book_items[#book_items + 1] = makeCollateItem(fp, true, collate, ui)
    end
    table.sort(book_items, collateSortingFunction(collate, reverse))

    local folder_items = {}
    for _, d in ipairs(subdirs) do
        folder_items[#folder_items + 1] = makeCollateItem(d, false, BookList.collates.strcoll, ui)
    end
    table.sort(folder_items, collateSortingFunction(BookList.collates.strcoll, false))

    local entries = {}
    for _, item in ipairs(book_items) do
        entries[#entries + 1] = toEntry(item)
    end
    for _, item in ipairs(folder_items) do
        entries[#entries + 1] = toEntry(item)
    end
    return entries
end

--- Most recently read book across the entire ReadHistory (path-independent),
--- used by the Continue hero so it never changes with the browsed directory.
function BookRepository.getGlobalLastReadBook()
    ReadHistory:reload()
    for _, item in ipairs(ReadHistory.hist or {}) do
        if item.file and lfs.attributes(item.file, "mode") == "file" then
            return item.file
        end
    end
    return nil
end

function BookRepository.getBookMeta(filepath)
    local title = filepath:match("([^/]+)%.[^%.]+$") or filepath:match("([^/]+)$") or filepath
    local authors, description, percent, read_time = "", "", 0, 0

    local book_info = BookList.getBookInfo(filepath)
    if book_info then percent = book_info.percent_finished or 0 end

    if DocSettings:hasSidecarFile(filepath) then
        local ok, ds = pcall(DocSettings.open, DocSettings, filepath)
        if ok and ds then
            local props = ds:readSetting("doc_props") or {}
            if props.title and props.title ~= "" then title = props.title end
            if props.authors and props.authors ~= "" then authors = props.authors end
            if props.description and props.description ~= "" then description = props.description end
            percent = ds:readSetting("percent_finished") or percent
            -- Prefer the statistics DB (authoritative, live total), falling back
            -- to the sidecar stats snapshot only if the DB has no entry.
            local md5 = ds:readSetting("partial_md5_checksum")
            read_time = getReadTimeFromStatsDB(md5)
            if read_time == 0 then
                local stats = ds:readSetting("stats") or {}
                read_time = stats.total_time_in_sec or 0
            end
        end
    end

    local ok_bim, BIM = pcall(require, "bookinfomanager")
    if ok_bim and BIM then
        local ok, bi = pcall(BIM.getBookInfo, BIM, filepath, false)
        if ok and bi then
            if bi.title and bi.title ~= "" then title = bi.title end
            if bi.authors and bi.authors ~= "" then authors = bi.authors end
            if bi.description and bi.description ~= "" then description = bi.description end
        end
    end

    return {
        title = title,
        authors = authors,
        description = description,
        percent = percent,
        read_time = read_time,
    }
end

function BookRepository.openBook(filepath, parent_widget)
    local ReaderUI = require("apps/reader/readerui")
    if parent_widget then
        -- Remember that this reader was launched from Home (and which folder
        -- Home considers its root), so returning to the file browser goes back
        -- to Home rather than to the document's folder.
        BookRepository.setHomeOrigin(parent_widget.root_dir or BookRepository.resolveHomeDir())
        UIManager:close(parent_widget)
    end
    ReaderUI:showReader(filepath)
end

return BookRepository

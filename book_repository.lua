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

local SORT_MODE_KEY = "home_sort_mode"

function BookRepository.getSortMode()
    local mode = G_reader_settings:readSetting(SORT_MODE_KEY)
    if mode == "name" then return "name" end
    return "recent"
end

function BookRepository.setSortMode(mode)
    G_reader_settings:saveSetting(SORT_MODE_KEY, mode == "name" and "name" or "recent")
end

function BookRepository.toggleSortMode()
    local mode = BookRepository.getSortMode()
    local next_mode = mode == "recent" and "name" or "recent"
    BookRepository.setSortMode(next_mode)
    return next_mode
end

local function sortBooksByRecent(books)
    local read_times = buildReadTimeMap()
    table.sort(books, function(a, b)
        local ta = getLastReadTime(a, read_times)
        local tb = getLastReadTime(b, read_times)
        if ta ~= tb then return ta > tb end
        return ffiUtil.strcoll(basename(a), basename(b))
    end)
end

--- Most recently read book in the given directory (independent of the Recent
--- sort mode).
function BookRepository.getLastReadBook(dir)
    local books = listBooksInDir(dir or BookRepository.resolveBrowseDir())
    if #books == 0 then return nil end
    sortBooksByRecent(books)
    return books[1]
end

function BookRepository.getSortedBooks(dir, sort_mode)
    local books = listBooksInDir(dir or BookRepository.resolveBrowseDir())
    if #books == 0 then return books end
    sort_mode = sort_mode or BookRepository.getSortMode()
    if sort_mode == "name" then
        table.sort(books, function(a, b)
            return ffiUtil.strcoll(basename(a), basename(b))
        end)
        return books
    end
    sortBooksByRecent(books)
    return books
end

--- Whether a book has a usable cover image (best-effort via BookInfoManager).
local function hasCover(filepath)
    local ok_bim, BIM = pcall(require, "bookinfomanager")
    if not (ok_bim and BIM) then return false end
    local ok, bi = pcall(BIM.getBookInfo, BIM, filepath, true)
    return ok and bi and bi.cover_bb ~= nil
end

--- Books to render inside a folder's mosaic cover: sorted by the current mode,
--- with cover-bearing books pulled to the front, capped at `n` (default 4).
function BookRepository.getFolderCoverBooks(dir, sort_mode, n)
    n = n or 4
    local books = BookRepository.getSortedBooks(dir, sort_mode)
    if #books == 0 then return {} end
    local with_cover, without_cover = {}, {}
    for _, fp in ipairs(books) do
        if #with_cover >= n then break end
        if hasCover(fp) then
            with_cover[#with_cover + 1] = fp
        elseif #without_cover < n then
            without_cover[#without_cover + 1] = fp
        end
    end
    local result = {}
    for _, fp in ipairs(with_cover) do
        if #result >= n then break end
        result[#result + 1] = fp
    end
    for _, fp in ipairs(without_cover) do
        if #result >= n then break end
        result[#result + 1] = fp
    end
    return result
end

--- Most recent read time across all filtered books directly inside `dir`.
local function getFolderRecentTime(dir, read_times)
    local books = listBooksInDir(dir)
    local best = 0
    for _, fp in ipairs(books) do
        local t = getLastReadTime(fp, read_times)
        if t > best then best = t end
    end
    return best
end

--- Unified Recent entries: filtered books first (in the given sort order),
--- followed by subfolders. Folders sort by name in "name" mode, or by their
--- most recently read contained book (descending) in "recent" mode.
--- @return table list of { type = "book"|"folder", path, name }
function BookRepository.getRecentEntries(dir, sort_mode)
    dir = dir or BookRepository.resolveBrowseDir()
    sort_mode = sort_mode or BookRepository.getSortMode()

    local entries = {}
    for _, fp in ipairs(BookRepository.getSortedBooks(dir, sort_mode)) do
        entries[#entries + 1] = { type = "book", path = fp }
    end

    local subdirs = listSubdirsInDir(dir)
    if #subdirs > 0 then
        if sort_mode == "name" then
            table.sort(subdirs, function(a, b)
                return ffiUtil.strcoll(basename(a), basename(b))
            end)
        else
            local read_times = buildReadTimeMap()
            local times = {}
            for _, d in ipairs(subdirs) do
                times[d] = getFolderRecentTime(d, read_times)
            end
            table.sort(subdirs, function(a, b)
                if times[a] ~= times[b] then return times[a] > times[b] end
                return ffiUtil.strcoll(basename(a), basename(b))
            end)
        end
        for _, d in ipairs(subdirs) do
            entries[#entries + 1] = { type = "folder", path = d, name = basename(d) }
        end
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
    if parent_widget then UIManager:close(parent_widget) end
    ReaderUI:showReader(filepath)
end

return BookRepository

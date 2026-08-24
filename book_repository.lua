--[[--
book_repository.lua — Book scanning, sorting, metadata and open logic (no UI).
--]]

local BookList = require("ui/widget/booklist")
local Device = require("device")
local DocSettings = require("docsettings")
local ReadHistory = require("readhistory")
local UIManager = require("ui/uimanager")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local realpath = ffiUtil.realpath
local util = require("util")

local BookRepository = {}

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
            local stats = ds:readSetting("stats") or {}
            read_time = stats.total_time_in_sec or 0
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

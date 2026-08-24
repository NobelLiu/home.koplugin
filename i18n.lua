--[[--
i18n.lua — Inject plugin .po translations into KOReader's GetText tables.
Call install() before any _() usage in main.lua.
--]]

local _dir = (debug.getinfo(1, "S").source:match("^@(.+/)") or "./")

local function parsePO(path)
    local f = io.open(path, "r")
    if not f then return nil end

    local translations = {}
    local contexts = {}
    local ctx, id, str
    local in_id, in_str, in_ctx = false, false, false

    local function unescape(s)
        return s:gsub("\\n", "\n")
                :gsub("\\t", "\t")
                :gsub('\\"', '"')
                :gsub("\\\\", "\\")
    end

    local function flush()
        if id and id ~= "" and str and str ~= "" then
            if ctx and ctx ~= "" then
                if not contexts[ctx] then contexts[ctx] = {} end
                contexts[ctx][id] = str
            else
                translations[id] = str
            end
        end
        ctx, id, str = nil, nil, nil
        in_id, in_str, in_ctx = false, false, false
    end

    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line == "" or line:match("^#") then
            if line == "" then flush() end
        elseif line:match("^msgctxt%s+\"") then
            flush()
            ctx = unescape(line:match('^msgctxt%s+"(.*)"') or "")
            in_ctx = true; in_id = false; in_str = false
        elseif line:match("^msgid%s+\"") then
            if not in_ctx then flush() end
            in_ctx = false
            id = unescape(line:match('^msgid%s+"(.*)"') or "")
            in_id = true; in_str = false
        elseif line:match("^msgstr%s+\"") then
            str = unescape(line:match('^msgstr%s+"(.*)"') or "")
            in_str = true; in_id = false; in_ctx = false
        elseif line:match('^"') then
            local cont = unescape(line:match('^"(.*)"') or "")
            if in_ctx and ctx then ctx = ctx .. cont end
            if in_id and id then id = id .. cont end
            if in_str and str then str = str .. cont end
        end
    end
    flush()
    f:close()

    local count = 0
    for _ in pairs(translations) do count = count + 1 end
    for _ in pairs(contexts) do count = count + 1 end
    return translations, contexts, count
end

local function detectLang()
    local lang = G_reader_settings and G_reader_settings:readSetting("language")
    if type(lang) == "string" and lang ~= "" then return lang end
    local lc = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or ""
    lang = lc:match("^([a-zA-Z_]+)")
    return lang or "en"
end

local function loadTranslationsForLang(lang)
    if not lang or lang == "en" or lang:match("^en_") then return nil, nil end

    local function try(name)
        local path = _dir .. "locales/" .. name .. ".po"
        local t, c, n = parsePO(path)
        if t and n and n > 0 then return t, c end
        return nil, nil
    end

    local LANG_ALIASES = {
        it = "it_IT",
        nl = "nl_NL",
        ko = "ko_KR",
        pt = "pt_BR",
        zh = "zh_CN",
    }

    local t, c = try(lang)
    if t then return t, c end

    local alias = LANG_ALIASES[lang]
    if alias then
        t, c = try(alias)
        if t then return t, c end
    end

    local prefix = lang:match("^([a-zA-Z]+)")
    if prefix and prefix ~= lang then
        t, c = try(prefix)
        if t then return t, c end
        alias = LANG_ALIASES[prefix]
        if alias then
            return try(alias)
        end
    end
    return nil, nil
end

local _installed = false
local _orig_gettext = nil
local _orig_changeLang = nil

local function applyTranslations(GetText, lang)
    local translations, contexts = loadTranslationsForLang(lang)
    if not translations then return end
    for msgid, msgstr in pairs(translations) do
        GetText.translation[msgid] = msgstr
    end
    for msgctxt, msgs in pairs(contexts or {}) do
        if not GetText.context[msgctxt] then
            GetText.context[msgctxt] = {}
        end
        for msgid, msgstr in pairs(msgs) do
            GetText.context[msgctxt][msgid] = msgstr
        end
    end
end

local function install()
    if _installed then return end

    local GetText = package.loaded["gettext"]
    if not GetText then
        local ok, gt = pcall(require, "gettext")
        if not ok or not gt then return end
        GetText = gt
    end
    _orig_gettext = GetText

    applyTranslations(GetText, detectLang())

    local mt = getmetatable(GetText)
    if mt and type(mt.__index) == "table" then
        local mt_index = mt.__index
        local orig_changeLang = mt_index.changeLang
        _orig_changeLang = orig_changeLang
        mt_index.changeLang = function(new_lang)
            local result = orig_changeLang(new_lang)
            applyTranslations(GetText, new_lang)
            return result
        end
    end

    _installed = true
end

return { install = install }

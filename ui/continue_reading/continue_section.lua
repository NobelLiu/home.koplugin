--[[--
continue_section.lua — Assembles the Continue section: a single row of a cover
column (left, built by continue_cover) and an info column (right, containing
title, author, description and read-status). The outer slot wrapper comes from
continue_cover too (absorbing the former continue_center indirection). The
open-book tap is handled by a Home touch zone (so the top-of-screen menu
gestures keep priority), not by this widget.
--]]

local BookRepository = require("book_repository")
local ContinueCover = require("ui/continue_reading/continue_cover")
local ContinueInfoColumn = require("ui/continue_reading/continue_info_column")
local HorizontalGroup = require("ui/widget/horizontalgroup")

local ContinueSection = {}

--- @return table Continue widget
function ContinueSection.build(filepath, metrics, on_open)
    local meta = BookRepository.getBookMeta(filepath)

    local cover_col = ContinueCover.build(filepath, metrics)
    local info_col = ContinueInfoColumn.build(meta, metrics)

    local content_row = HorizontalGroup:new{
        align = "top",
        cover_col,
        info_col,
    }

    return ContinueCover.wrap(content_row, metrics)
end

return ContinueSection

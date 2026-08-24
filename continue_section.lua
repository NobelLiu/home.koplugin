--[[--
continue_section.lua — Assembles the Continue section.
--]]

local BookRepository = require("book_repository")
local ContinueCenter = require("continue_center")
local ContinueContentRow = require("continue_content_row")
local ContinueProgressRow = require("continue_progress_row")
local DebugOverlay = require("debug_overlay")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local TapCell = require("tap_cell")
local VerticalGroup = require("ui/widget/verticalgroup")

local ContinueSection = {}

--- @return table Continue widget
function ContinueSection.build(filepath, metrics, on_open)
    local meta = BookRepository.getBookMeta(filepath)

    local content_row = ContinueContentRow.build(filepath, meta, metrics)

    -- The progress row sits below the cover row; the gap is applied via
    -- padding_top rather than a Span placeholder.
    local progress_row = DebugOverlay.wrap("continue_row_gap", FrameContainer:new{
        bordersize = 0,
        margin = 0,
        padding = 0,
        padding_top = metrics.continue_row_gap,
        dimen = Geom:new{ w = metrics.content_w, h = metrics.continue_row_gap + metrics.progress_row_h },
        ContinueProgressRow.build(meta, metrics),
    }, metrics.content_w, metrics.continue_row_gap + metrics.progress_row_h, "continue_row_gap")

    local inner = DebugOverlay.wrap("continue_inner", VerticalGroup:new{
        align = "left",
        content_row,
        progress_row,
    }, metrics.content_w, metrics.continue_h, "continue_inner")

    local section = ContinueCenter.wrap(inner, metrics)

    local tap = TapCell.wrap(section, Geom:new{
        w = metrics.content_w,
        h = metrics.continue_slot_h,
    }, function()
        on_open(filepath)
    end)

    return DebugOverlay.wrap("continue_section", tap,
        metrics.content_w, metrics.continue_slot_h, "continue_section")
end

return ContinueSection

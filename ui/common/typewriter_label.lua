--[[--
typewriter_label.lua — A text label that reveals its text one character at a
time (a "typewriter" effect).

Generalized from the former Continue-section greeting. Build a label with
`TypewriterLabel.build{...}`; if the caller wants animation it passes the owning
Home widget and a screen-space refresh region to `label:play(home, region)`.

The reveal is held back by START_DELAY, then each character is added `interval`
seconds apart. A zero interval (or a single-character text) reveals the whole
text at once. The animation stores the live TextWidget on `home._title_label`
so a Home rebuild/close (which frees the widget) cancels any in-flight reveal.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Layout = require("ui/common/layout")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local util = require("util")

local TypewriterLabel = {}

TypewriterLabel.START_DELAY = 0.5

--- Build a typewriter label.
--- @param opts table {
---   text = string,
---   face = Font face,
---   bold = bool (default true),
---   fgcolor = Blitbuffer color (default COLOR_BLACK),
---   max_width = number,
---   width = number (TextBoxWidget wrap width; wrapping, no line cap),
---   height = number (optional locked wrap-box height),
---   line_height = number (TextBoxWidget extra em, when wrapping),
---   bgcolor = Blitbuffer color (when wrapping),
---   animate = bool (whether this instance should reveal char-by-char),
---   on_finish = function (optional, called once the full text is revealed;
---     for a non-animated label this fires immediately on :play()),
---   guard_key = string (optional, Home field used as this label's live guard;
---     defaults to "_title_label", use "_status_label" for the status text),
--- }
--- @return table The TextWidget, augmented with a :play(home, region) method.
function TypewriterLabel.build(opts)
    opts = opts or {}
    local text = opts.text or ""
    local interval = Layout.getGreetingAnimInterval()
    local chars = util.splitToChars(text)
    -- Only animate when requested, with a non-trivial text and a positive
    -- interval. An empty TextWidget doesn't paint and would collapse the
    -- layout, so the animated start value is a zero-width space (blank but with
    -- reserved height).
    local will_animate = opts.animate and #chars > 1 and interval > 0

    local label
    if opts.width then
        label = TextBoxWidget:new{
            text = text,
            face = opts.face,
            width = opts.width,
            height = opts.height,
            bold = opts.bold ~= false,
            fgcolor = opts.fgcolor or Blitbuffer.COLOR_BLACK,
            bgcolor = opts.bgcolor,
            line_height = opts.line_height,
            alignment = "left",
        }
    else
        label = TextWidget:new{
            text = text,
            face = opts.face,
            fgcolor = opts.fgcolor or Blitbuffer.COLOR_BLACK,
            bold = opts.bold ~= false,
            max_width = opts.max_width,
            padding = 0,
        }
    end

    -- Measure the label at its full text so tap-areas/layout are sized for the
    -- final string, then (when animating) swap in the zero-width-space
    -- placeholder that the reveal grows from. An empty TextWidget doesn't paint
    -- and would collapse the layout, so the placeholder still reserves height.
    local measured = label:getSize()
    local full_size = { w = measured.w, h = measured.h }
    if opts.width and not opts.height then
        label.height = measured.h
    end
    if will_animate then
        label:setText("\u{200B}")
    end

    label._tw_chars = chars
    label._tw_interval = interval
    label._tw_will_animate = will_animate
    label._tw_full_size = full_size
    label._tw_on_finish = opts.on_finish
    label._tw_guard_key = opts.guard_key or "_title_label"

    --- Full-text size (independent of the current reveal state), for callers
    --- sizing a fixed tap-area or container around the animated label.
    function label:getFullSize()
        return self._tw_full_size
    end

    --- Start the reveal. `home` owns the live-label guard field
    --- (`home._title_label`); `region` is the screen-space rect repainted after
    --- each character is added. A label built without animation reveals its
    --- text instantly, so its `on_finish` callback fires right away.
    function label:play(home, region)
        if not home or not region then return end
        home[label._tw_guard_key] = self
        if self._tw_will_animate then
            TypewriterLabel._scheduleReveal(home, self, self._tw_chars, region,
                self._tw_interval, TypewriterLabel.START_DELAY, self._tw_on_finish)
        elseif self._tw_on_finish then
            self._tw_on_finish()
        end
    end

    --- Reveal replacement text on an existing label (e.g. the greeting → time
    --- swap, or the status display after it), using the same per-character
    --- interval. Starts after `start_delay` (default 0); `on_finish` fires once
    --- the reveal completes (or immediately for an instantly-set text). A
    --- non-animated / single-character text is set at once. As with the
    --- initial reveal, it bails via the live-label guard if Home is rebuilt or
    --- closed mid-reveal.
    function label:reveal(home, region, new_text, start_delay, on_finish)
        if not home or not region then return end
        local new_chars = util.splitToChars(new_text)
        local reveal_interval = self._tw_interval
        home[label._tw_guard_key] = self
        if #new_chars > 1 and reveal_interval > 0 then
            self:setText("\u{200B}")
            TypewriterLabel._scheduleReveal(home, self, new_chars, region,
                reveal_interval, start_delay or 0, on_finish)
        else
            self:setText(new_text)
            UIManager:setDirty(home, "ui", region)
            if on_finish then on_finish() end
        end
    end

    return label
end

--- Reveal `label` one character at a time, `interval` seconds apart, after
--- `start_delay` (default START_DELAY). Each step repaints the fixed `region`.
--- Bails if Home was rebuilt/closed and this label is no longer the live one.
function TypewriterLabel._scheduleReveal(home, label, chars, region, interval,
        start_delay, on_finish)
    local i = 0

    local function step()
        if home[label._tw_guard_key] ~= label then return end
        i = i + 1
        label:setText(table.concat(chars, "", 1, i))
        UIManager:setDirty(home, "ui", region)
        if i < #chars then
            UIManager:scheduleIn(interval, step)
        elseif on_finish then
            on_finish()
        end
    end

    UIManager:scheduleIn(start_delay or TypewriterLabel.START_DELAY, step)
end

return TypewriterLabel

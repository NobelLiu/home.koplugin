require("i18n").install()
local _ = require("gettext")
return {
    name = "home",
    fullname = _("Home"),
    description = _([[A reading-focused home screen with a hero cover for your latest book and a row of recent titles.]]),
    version = 5,
}

local scheme = require("scheme.glyph")
local vars   = require("variables")

hl.config({
    group = {
        col = {
            border_active          = vars.activeWindowBorderColour,
            border_inactive        = vars.inactiveWindowBorderColour,
            border_locked_active   = vars.activeWindowBorderColour,
            border_locked_inactive = "rgb(" .. scheme.mute .. ")",
        },
        groupbar = {
            font_family               = "Space Mono",
            font_size                 = 13,
            gradients                 = true,
            gradient_round_only_edges = false,
            gradient_rounding         = 0,
            height                    = 25,
            indicator_height          = 0,
            gaps_in                   = 3,
            gaps_out                  = 3,
            text_color                = "rgb(" .. scheme.fg .. ")",
            col                       = {
                active          = "rgb(" .. scheme.s3 .. ")",
                inactive        = "rgb(" .. scheme.s1 .. ")",
                locked_active   = "rgb(" .. scheme.s3 .. ")",
                locked_inactive = "rgb(" .. scheme.s1 .. ")",
            },
        },
    },
})

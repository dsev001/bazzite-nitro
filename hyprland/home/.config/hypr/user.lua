-- Personal Hyprland settings, loaded at the end of hyprland.lua
-- Everything here overrides the base config

hl.config({
    input = {
        kb_layout = "de",
        -- Keyboard focus only on click; hover and scroll still reach the window under the cursor
        follow_mouse = 2,
        -- No focus change when the cursor crosses between tiled and floating windows
        float_switch_override_focus = 0,
    },
})

-- Screenshots go to the same folder as in Plasma (Spectacle)
hl.env("SCREENSHOT_DIR", os.getenv("HOME") .. "/Bilder/Bildschirmfotos")

-- Border colors from the wallpaper (matugen, see ~/.config/matugen/)
require("./colors")

-- Windows start 8 px below the bar, like the bar's own margin to the screen edge
hl.config({ general = { gaps_out = { top = 8, right = 20, bottom = 20, left = 20 } } })

-- Frosted glass behind fuzzel (launcher and the dropdowns of scripts/dropdown.sh); ignore_alpha keeps the transparent corners sharp
hl.layer_rule({ name = "blur-fuzzel", match = { namespace = "^(launcher|dropdown-.*)$" }, blur = true, ignore_alpha = 0.5 })

-- Frosted glass behind mako notifications
hl.layer_rule({ name = "blur-mako", match = { namespace = "^notifications$" }, blur = true, ignore_alpha = 0.5 })

-- Windows: rounding like the bar islands, thin border, inactive windows slightly dimmed
hl.config({ general = { border_size = 1 }, decoration = { rounding = 16, dim_inactive = true, dim_strength = 0.1 } })

-- Hyprland base config: neutral, no personal data
-- Based on example/hyprland.lua from Hyprland v0.56.2
-- Personal settings go to user.lua, loaded at the end of this file
-- Environment variables live in ~/.config/uwsm/env-hyprland
-- Wiki: https://wiki.hypr.land/Configuring/Start/


------------------
---- MONITORS ----
------------------

-- Laptop panel; 1.6 keeps the logical size integer (1600x1000)
-- auto-left: plain auto puts a panel that comes back on at runtime right of the other monitor
local panel = { output = "eDP-1", mode = "2560x1600@180", position = "auto-left", scale = 1.6 }
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- A closed lid only locks (logind HandleLidSwitch=lock), the panel would keep its workspaces
-- out of reach. While another monitor runs, the panel goes off and Hyprland moves its
-- workspaces there; with the lid open or no other monitor left, it comes back on
local function lid_closed()
    local f = io.open("/proc/acpi/button/lid/LID0/state")
    if not f then return false end
    local state = f:read("a")
    f:close()
    return state:find("closed") ~= nil
end

-- get_monitors() lists only enabled monitors, without one that is being removed
local function update_panel(closed, force)
    local on, other = false, false
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == panel.output then on = true else other = true end
    end
    local off = closed and other
    if not force and on ~= off then return end
    -- disabled = false must be explicit, else a runtime call does not turn the panel back on
    panel.disabled = off
    hl.monitor(panel)
end

update_panel(lid_closed(), true)
hl.bind("switch:on:Lid Switch",  function () update_panel(true)  end, { locked = true })
hl.bind("switch:off:Lid Switch", function () update_panel(false) end, { locked = true })
hl.on("monitor.added",   function () update_panel(lid_closed()) end)
hl.on("monitor.removed", function () update_panel(lid_closed()) end)


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "konsole"
local fileManager = "dolphin"
local menu        = "fuzzel"


-------------------
---- AUTOSTART ----
-------------------

-- uwsm also starts XDG autostart entries (nm-applet and blueman-applet are off
-- via ~/.config/autostart, waybar shows Wi-Fi and Bluetooth), but not
-- pam_kwallet_init: its entry has X-systemd-skip=true, so it is started here first
-- Each tool runs as its own systemd unit, logs: journalctl --user -u 'app-*<tool>*'
-- waybar runs as waybar.service instead (Restart=on-failure, skipped in Plasma),
-- because it crashes when a monitor goes away
hl.on("hyprland.start", function ()
    hl.exec_cmd("/usr/libexec/pam_kwallet_init")
    hl.exec_cmd("uwsm app -- hyprpaper")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("uwsm app -- hyprsunset")
    hl.exec_cmd("uwsm app -- mako")
    hl.exec_cmd("uwsm app -- swayosd-server")
    hl.exec_cmd("uwsm app -- /usr/libexec/kf6/polkit-kde-authentication-agent-1")
    hl.exec_cmd("uwsm app -- wl-paste --watch cliphist store")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})


----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        -- No anime wallpaper or logo behind windows when hyprpaper is gone; plain background_color
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        -- A crashed hyprlock can be restarted without a TTY; the session stays locked
        allow_session_lock_restore = true,
    },
})


---------------
---- INPUT ----
---------------

-- The keyboard layout is personal and lives in user.lua
hl.config({
    input = {
        numlock_by_default = true,

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            tap_to_click   = true,
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


---------------------
---- KEYBINDINGS ----
---------------------

-- Default binds from example/hyprland.lua, plus lock, power menu, clipboard, screenshots, color picker
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/power-menu.sh --center"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Maximize the active window over the workspace, keeps the bar and gaps
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

-- Lock (hypridle starts hyprlock on lock-session), clipboard history, color picker
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))

-- Screenshots: area or current monitor, edited in satty; Ctrl+S saves, Ctrl+C copies
-- Folder: $SCREENSHOT_DIR (set in user.lua), else <Pictures>/Screenshots; created on demand
local shotDir = [[${SCREENSHOT_DIR:-$(xdg-user-dir PICTURES)/Screenshots}]]
local satty   = [[satty --filename - --output-filename "]] .. shotDir .. [[/%Y-%m-%d_%H-%M-%S.png" --copy-command wl-copy --early-exit]]
local mkShot  = [[mkdir -p "]] .. shotDir .. [[" && ]]
hl.bind("Print",         hl.dsp.exec_cmd(mkShot .. "grimblast save area - | " .. satty))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(mkShot .. "grimblast save output - | " .. satty))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9], move the active window with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Close the dropdowns of the right waybar island (scripts/dropdown.sh) on a click outside them;
-- fuzzel keeps the focus otherwise. Clicks on waybar are left out: the icons close them themselves
local function inside(p, l) return p.x >= l.x and p.x < l.x + l.w and p.y >= l.y and p.y < l.y + l.h end
hl.bind("mouse:272", function ()
    local p = hl.get_cursor_pos()
    if not p then return end
    local menu = false
    for _, l in ipairs(hl.get_layers()) do
        if l.namespace == "waybar" and inside(p, l) then return end
        if l.namespace:find("^dropdown%-") then
            if inside(p, l) then return end
            menu = true
        end
    end
    if menu then hl.exec_cmd("pkill -f -- '^fuzzel .*--namespace=dropdown-[a-z]+( |$)'") end
end, { non_consuming = true })

-- Volume and brightness through swayosd (shows the OSD), also when locked
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower"),       { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),  { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"),          { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"),          { locked = true, repeating = true })

-- Media keys through playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    -- Ignore maximize requests from all apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})


-----------------------
---- PERSONAL FILE ----
-----------------------

-- Must stay last, so personal settings override the base
require("./user")

local vars = require("variables")
local fn   = require("hyprland.functions")

hl.on("hyprland.start", function()
    -- Shell: тот, что выбран в rice
    hl.exec_cmd(vars.rice .. " start")

    -- во вложенной сессии системные демоны уже работают снаружи
    if vars.nested then return end

    -- Keyring and auth
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Auto delete trash 30 days old
    hl.exec_cmd("trash-empty 30")

    -- Cursors
    hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)

    -- Location provider
    hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")

    -- Forward bluetooth media commands to MPRIS
    hl.exec_cmd("mpris-proxy")

    -- hypridle поднимает шелл (Rules.idle): тайминги из house rules → ~/.config/demonshot/hypridle.conf
end)

local function is_browser_popup(win)
    if not win or win.floating or not win.class or not win.title then return false end
    local is_browser = win.class:match("^zen") ~= nil
        or win.class == "app.zen_browser.zen"
        or win.class:match("^[Gg]oogle%-chrome$") ~= nil
    if not is_browser then return false end

    local t = win.title
    if t:match("^Extension:") or t:match("^Ext:") or t:match("^Developer Tools") or t:match("^DevTools") or t:match("^Page Info") then
        return true
    end

    local init = win.initial_title or ""
    if init == "" or init:match("^about:blank") then
        return t:match("^Sign in") ~= nil
            or t:match("^Log in") ~= nil
            or t:match("^Entrar") ~= nil
            or t:match("^Fazer login") ~= nil
            or t:match("^Google Accounts") ~= nil
            or t:match("^Contas do Google") ~= nil
            or t:match("^Authoriz") ~= nil
    end
    return false
end

-- Resizer listener
local function handle_window(win)
    local d = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, d, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)

    if is_browser_popup(win) then
        for _, action in ipairs(d) do
            hl.dispatch(action)
        end
    end
end

hl.on("window.title", handle_window)
hl.on("window.open", handle_window)

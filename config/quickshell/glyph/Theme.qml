pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "schemes.js" as Schemes

// Tema central do shell: paleta, fontes, animações, estado persistente e sincronização com Hyprland/Kitty/GTK/Qt.
Singleton {
    id: root

    readonly property alias state: st
    readonly property var pal: make({})
    readonly property bool light: pal.light

    readonly property var glyphDark: ["#000000", "#0E0E0E", "#1A1A1A", "#2A2A2A", "#4A4A4A", "#8C8C8C", "#F2F2F2"]
    readonly property var glyphLight: ["#E9E9E9", "#FFFFFF", "#F1F1F1", "#D9D9D9", "#B8B8B8", "#6E6E6E", "#0B0B0B"]
    readonly property var greys: pal.c
    readonly property color bg: greys[0]   // fundo, wallpaper
    readonly property color s1: greys[1]   // barra, painéis
    readonly property color s2: greys[2]   // tiles, desligado
    readonly property color s3: greys[3]   // linhas, bordas inativas
    readonly property color mute: greys[4] // inativo
    readonly property color grey: greys[5] // rótulos, texto secundário
    readonly property color fg: greys[6]   // texto principal, ligado, foco
    readonly property color ink: light ? s1 : bg
    readonly property color accent: pal.accent
    readonly property color red: pal.red
    readonly property color nothingRed: "#D71921"
    readonly property color glow: light ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(1, 1, 1, 0.6)
    readonly property color scrim: fade(bg, light ? 0.8 : 0.74)

    readonly property string dot: "Space Grotesk"
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "Space Mono"
    readonly property string nf: "JetBrainsMono Nerd Font"

    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }

    function sid(name) {
        const m = Quickshell.screens.find(s => s.name === name)?.model.trim();
        return m && Quickshell.screens.filter(s => s.model.trim() === m).length === 1 ? m : name;
    }
    function own(name) { return st.screens[sid(name)] ?? st.screens[name]; }
    function scr(name, key) { return own(name)?.[key] ?? { wall: st.wall, widgets: st.widgets }[key] ?? true; }
    function setScr(name, key, v) {
        const o = Object.assign({}, own(name)), all = Object.assign({}, st.screens);
        if (v === undefined) delete o[key];
        else o[key] = v;
        all[sid(name)] = o;
        st.screens = all;
    }

    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/glyph/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""; }
    readonly property string wall: scr(Quickshell.screens[0]?.name, "wall")

    function make(o) {
        const k = Object.assign({ scheme: st.scheme, light: st.light }, o);
        const found = Schemes.ALL.find(p => p.id === k.scheme);
        if (found) return found;
        return k.light ? Schemes.ALL[1] : Schemes.ALL[0];
    }

    function pair(l) {
        return pal.light === l ? pal : Schemes.ALL.find(x => x.group === pal.group && x.light === l) ?? null;
    }
    function setLight(l) {
        const p = pair(l);
        if (!p) return;
        st.scheme = p.id;
        st.light = l;
    }

    readonly property var styles: {
        const it = (name, p, now, run, fill) => ({ name, pal: p, fill: fill ?? p.c[1], dot: p.accent, now, run });
        const groups = Schemes.GROUPS.map(g => ({
            head: g,
            items: Schemes.ALL.filter(p => p.group === g).map(p =>
                Object.assign(it(p.name, p, st.scheme === p.id, () => { st.scheme = p.id; st.light = p.light; }), { extra: g })
            )
        }));
        return groups.concat([
            { head: "theme", items: [["dark", false], ["light", true]].map(([n, l]) =>
                it(n, make({ light: l, scheme: pair(l)?.id ?? st.scheme }), light === l, () => setLight(l))
            ) }
        ]);
    }

    function lum(c) { c = Qt.lighter(c, 1); const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
    function on(c) { return lum(c) > 0.18 ? "#000000" : "#FFFFFF"; }
    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function corner(px) { return px * st.corners / 100; }
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    readonly property string configDir: Quickshell.env("HOME") + "/.config/glyph"
    readonly property string riceState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/glyph"
    Component.onCompleted: stateFile.waitForJob()

    FileView {
        id: stateFile
        path: root.configDir + "/glyph.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property string scheme: "default"
            property bool dnd: false
            property int unread: 0
            property var widgets: ["calendar", "cpu", "player", "ram", "system"]
            property bool clock24: true
            property bool blink: true
            property string name: ""
            property bool grid: false
            property bool orb: false
            property string wall: ""
            property string wallDir: ""
            property int wallLook: 2 // 1 mono, 2 color
            property int wallPitch: 10
            property int wallBright: 85
            property int rounding: 20
            property int corners: 100
            property bool edges: true
            property int briSteps: 20
            property bool quickHover: true
            property bool deckHover: true
            property var deck: ["clock", "weather", "perf", "net", "media"]
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"]
            property bool barTitle: true
            property string barAt: "left"
            property var screens: ({})
            property int recArea: 0
            property int recAudio: 0
            property int recFps: 60
            property int recQuality: 2
            property bool recCursor: true
            property string vpnUrl: ""
            property bool vpnPortal: false
        }
    }

    readonly property var kinds: ({ calendar: 2, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, player: 2, system: 3 })
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"]

    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    FileView { id: kitty; path: root.configDir + "/kitty.conf"; printErrors: false }
    readonly property var ansi: Schemes.DEFAULT_ANSI_DARK

    function apply() {
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        const shadow = light ? "rgba(0000002E)" : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn} }, shadow = { enabled = ${Rules.shadowOn}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        kitty.setText("# glyph: gerado por Theme.apply(), não editar manualmente\n" + [
            ["font_family", "CaskaydiaCove Nerd Font"], ["window_padding_width", "26 30"], ["cursor_trail", "0"],
            ["foreground", fg], ["background", s1], ["cursor", fg], ["cursor_text_color", s1],
            ["selection_foreground", fg], ["selection_background", s3], ["url_color", grey],
            ["active_border_color", fg], ["inactive_border_color", s3],
            ["active_tab_foreground", ink], ["active_tab_background", fg],
            ["inactive_tab_foreground", grey], ["inactive_tab_background", s1], ["tab_bar_background", bg]
        ].concat(pal.ansi.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }

    function apps() {
        const from = glyphDark.concat(ansi.slice(1, 7));
        const p = pal.light ? pair(false) ?? make({ light: false, scheme: "default" }) : pal;
        const to = p.c.concat([p.red], p.ansi.slice(2, 7));
        const pairs = from.map((c, i) => [c, "#" + hex(Qt.lighter(to[i], 1))]).filter(([a, b]) => a !== b);
        const sed = pairs.map(([a], i) => ["-e", `s/${a}/@${i}@/gI`]).concat(pairs.map(([, b], i) => ["-e", `s/@${i}@/${b}/g`])).reduce((x, y) => x.concat(y), []);
        Quickshell.execDetached(["bash", "-c", `t=$1 o=$2; shift 2
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css qtengine.colors; do
    l=$HOME/.config/$f
    [ -L "$l" ] || [ ! -e "$l" ] || continue
    if [ $# -gt 0 ]; then mkdir -p "$(dirname "$o/$f")" && sed "$@" "$t/$f" > "$o/$f" && ln -sfn "$o/$f" "$l"; else ln -sfn "$t/$f" "$l"; fi
done`,
            "bash", Quickshell.shellPath("term"), riceState].concat(sed));
    }
}

pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// подсветка экрана: встроенный дисплей — brightnessctl + sysfs/udev, внешние мониторы — ddcutil (DDC/CI VCP 0x10).
// Активный монитор (Hyprland.focusedMonitor) выбирает цель для глобальных клавиш и Quick Settings; в Prefs — каждый отдельно.
Singleton {
    id: root

    property string dev: ""         // /sys/class/backlight/<имя>
    property real internalValue: 0  // 0…1 встроенного дисплея
    property var ddcMap: ({})       // connector (e.g. "DP-1") -> { bus, value, max }
    property int steps: 20          // делений шкалы для клавиш; glyph ставит из настроек (Sys)
    signal moved()                  // изменение яркости (клавиша, ползунок или внешний uevent) — для OSD

    readonly property string focusedMon: Hyprland.focusedMonitor?.name ?? ""
    readonly property bool isDdcFocused: !!ddcMap[focusedMon]
    readonly property real value: isDdcFocused ? ddcMap[focusedMon].value : internalValue
    readonly property bool available: isDdcFocused || !!dev

    function isInternalMon(mon) { return !!dev && /^(eDP|LVDS|DSI)-/.test(mon); }
    function hasFor(mon) { return !!ddcMap[mon] || isInternalMon(mon); }
    function valueFor(mon) { return ddcMap[mon] ? ddcMap[mon].value : (isInternalMon(mon) ? internalValue : 0); }

    function read() {
        cur.reload();
        const v = parseInt(cur.text());
        if (!isNaN(v)) internalValue = v / (parseInt(max.text()) || 1);
    }

    property var ddcPending: ({})   // bus -> raw value (копим частые шаги, пока идёт I2C)
    property string ddcBusyBus: ""

    function flushDdc() {
        if (ddcSet.running) return;
        const buses = Object.keys(ddcPending);
        if (!buses.length) return;
        const bus = buses[0];
        const raw = ddcPending[bus];
        const next = Object.assign({}, ddcPending);
        delete next[bus];
        ddcPending = next;
        ddcBusyBus = bus;
        ddcSet.command = ["ddcutil", "--bus", bus, "setvcp", "10", String(raw)];
        ddcSet.running = true;
    }

    function setFor(mon, v) {
        const entry = mon ? ddcMap[mon] : null;
        if (entry) {
            const m = entry.max || 100;
            const raw = Math.round(Math.max(0, Math.min(1, v)) * m);
            const next = Object.assign({}, ddcMap);
            next[mon] = { bus: entry.bus, value: raw / m, max: m };
            ddcMap = next;
            const p = Object.assign({}, ddcPending);
            p[entry.bus] = raw;
            ddcPending = p;
            ddcWriteDebounce.restart();
            moved();
            return;
        }
        const m = parseInt(max.text()) || 0;
        if (!m) return;
        const raw = Math.round(Math.max(0.01, Math.min(1, v)) * m);
        internalValue = raw / m;
        sync.restart();
        Quickshell.execDetached(["brightnessctl", "-q", "-d", dev.slice(dev.lastIndexOf("/") + 1), "set", String(raw)]);
        moved();
    }

    // value ставим сразу, не ждём brightnessctl и uevent; пока свои записи в пути, их uevent'ы не читаем — sync сверит потом
    function set(v) { setFor(isDdcFocused ? focusedMon : "", v); }

    // клавиши: steps делений по корню 4-й степени (20 — как у brightnessctl -e4 5%), внизу шкалы мельче. Шаг от ближайшего
    // деления, а не от value: иначе дробная ошибка копится (вверх до 399998 вместо 400000)
    function step(d) {
        set(Math.pow(Math.max(0, Math.min(steps, Math.round(Math.pow(value, 0.25) * steps) + d)) / steps, 4));
    }

    Timer { id: sync; interval: 300; onTriggered: root.read() }
    Timer { id: ddcWriteDebounce; interval: 80; onTriggered: root.flushDdc() }
    Timer { id: ddcRescan; interval: 800; onTriggered: if (!ddcDetect.running) ddcDetect.running = true }

    GlobalShortcut { appid: "shell"; name: "briUp"; description: "яркость +"; onPressed: root.step(1) }
    GlobalShortcut { appid: "shell"; name: "briDown"; description: "яркость −"; onPressed: root.step(-1) }

    Connections {
        target: Quickshell
        function onScreensChanged() { ddcRescan.restart(); }
    }

    FileView { id: cur; path: root.dev ? root.dev + "/brightness" : ""; blockAllReads: true; printErrors: false }
    FileView { id: max; path: root.dev ? root.dev + "/max_brightness" : ""; blockLoading: true; printErrors: false }

    // brightnessctl -m: «имя,класс,текущее,процент,максимум»
    Process {
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim().split(",")[0];
                if (!name) return;
                root.dev = "/sys/class/backlight/" + name;
                root.read();
            }
        }
    }
    Process {
        running: !!root.dev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        stdout: SplitParser { onRead: l => { if (l.includes(" change ")) { if (!sync.running) root.read(); root.moved(); } } }
    }

    // ---- внешние мониторы по DDC/CI (ddcutil) ----
    property var ddcReadQueue: []
    property string ddcReadingMon: ""

    function nextDdcRead() {
        if (ddcGet.running || !ddcReadQueue.length) return;
        const mon = ddcReadQueue[0];
        ddcReadQueue = ddcReadQueue.slice(1);
        const entry = ddcMap[mon];
        if (!entry) { nextDdcRead(); return; }
        ddcReadingMon = mon;
        ddcGet.command = ["ddcutil", "--bus", entry.bus, "getvcp", "10", "--brief"];
        ddcGet.running = true;
    }

    Process {
        id: ddcDetect
        running: true
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                let valid = false, bus = "", conn = "";
                for (const rawLine of text.split("\n")) {
                    const line = rawLine.trim();
                    if (/^Display\s+\d+/.test(line)) {
                        valid = true; bus = ""; conn = "";
                    } else if (/^Invalid display/.test(line)) {
                        valid = false; bus = ""; conn = "";
                    } else if (valid) {
                        const bm = line.match(/^I2C bus:\s*\/dev\/i2c-(\d+)/);
                        if (bm) bus = bm[1];
                        const cm = line.match(/^DRM connector:\s*card\d+-(.+)/);
                        if (cm) conn = cm[1].trim();
                        if (bus && conn) { found[conn] = bus; valid = false; }
                    }
                }
                const next = {};
                const toRead = [];
                for (const k of Object.keys(found)) {
                    const prev = root.ddcMap[k];
                    if (prev && prev.bus === found[k]) {
                        next[k] = prev;
                    } else {
                        next[k] = { bus: found[k], value: 1, max: 100 };
                        toRead.push(k);
                    }
                }
                root.ddcMap = next;
                if (toRead.length) {
                    root.ddcReadQueue = root.ddcReadQueue.concat(toRead);
                    root.nextDdcRead();
                }
            }
        }
    }

    Process {
        id: ddcGet
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^VCP\s+10\s+\S+\s+(\d+)\s+(\d+)/);
                const mon = root.ddcReadingMon;
                if (m && mon && root.ddcMap[mon]) {
                    const curV = parseInt(m[1]), maxV = parseInt(m[2]) || 100;
                    const next = Object.assign({}, root.ddcMap);
                    next[mon] = { bus: next[mon].bus, value: curV / maxV, max: maxV };
                    root.ddcMap = next;
                }
            }
        }
        onExited: root.nextDdcRead()
    }

    Process {
        id: ddcSet
        onExited: { root.ddcBusyBus = ""; root.flushDdc(); }
    }
}

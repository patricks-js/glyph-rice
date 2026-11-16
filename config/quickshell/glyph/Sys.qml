pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.services
import qs.settings

// то, что трогают бар, быстрые настройки, Glyph и лок: звук, яркость, раскладка, запись, ночник, авиарежим, кофеин, vpn
Singleton {
    id: root

    // deck (панель снизу) открыта — SysStats нужен подробный опрос, как на пустом воркспейсе (Home)
    property bool deckOpen: false
    // пикер обоев открыт — дом меняет обои сразу, без волны: её уже показал пикер
    property bool wallOpen: false

    // ---- звук ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var mic: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.mic] }
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property bool micOn: !(mic?.audio?.muted ?? true)
    function setVol(v) {
        if (!sink?.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    // микрофон кто-то слушает — центр знака в баре краснеет
    PwNodeLinkTracker { id: micUse; node: root.mic }
    readonly property bool live: rec || micUse.linkGroups.length > 0

    // ---- яркость: общий с demonshot Backlight (устройство ищет brightnessctl) ----
    readonly property real bri: Backlight.value
    readonly property bool hasBri: !!Backlight.dev // нет подсветки (ПК с монитором) — регуляторов яркости нет
    function setBri(v) { Backlight.set(v); }
    Binding { target: Backlight; property: "steps"; value: Theme.state.briSteps }

    // ---- раскладка: старт — main-клавиатура из hyprctl, дальше событие activelayout ----
    property string kbd: ""
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: root.kbd = JSON.parse(this.text).keyboards.find(k => k.main)?.active_keymap ?? "" }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") root.kbd = e.data.slice(e.data.lastIndexOf(",") + 1); }
    }
    readonly property string layout: kbd.slice(0, 2).toLowerCase() // "English (US)" → en

    // ---- запись и авиарежим: их же включают бинды hypr, поэтому опрос. Ночник — общий с demonshot, в его rules.json
    // ponytail: pgrep раз в 3 с; станет заметно — следить за процессами через systemd-run --scope ----
    property bool rec: false
    readonly property bool night: Rules.store.night
    property bool air: false
    Process {
        id: poll
        command: ["sh", "-c", "pgrep -f '^gpu-screen-recorder' >/dev/null && echo rec; "
                            + "rfkill -rno SOFT | grep -qv '^blocked' || echo air"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.rec = text.includes("rec");
                root.air = text.includes("air");
            }
        }
    }
    Timer { running: true; repeat: true; interval: 3000; triggeredOnStart: true; onTriggered: poll.running = true }

    function sh(c) { Quickshell.execDetached(["sh", "-c", c]); }
    // настройки записи из Theme.state (quick/Rec) → флаги gpu-screen-recorder; их же берёт скриншотилка
    readonly property var recFps: [30, 60, 120]
    function recArgs() {
        const st = Theme.state;
        const a = ["", "default_output", "default_input", "default_output|default_input"][st.recAudio];
        return `-f ${st.recFps} -q ${["medium", "high", "very_high", "ultra"][st.recQuality]} -cursor ${st.recCursor ? "yes" : "no"}` + (a ? ` -a "${a}"` : "");
    }
    // второй раз — стоп. Область — slurp; отменили выбор — gsr не стартует, rec поправит опрос
    function toggleRec() {
        const w = Theme.state.recArea ? `-w region -region "$(slurp -f %wx%h+%x+%y)"` : `-w ${Hyprland.focusedMonitor?.name ?? "screen"}`;
        sh(`pkill -INT -f '^gpu-screen-recorder' || exec gpu-screen-recorder ${w} ${recArgs()} -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"`);
        rec = !rec;
    }
    function toggleNight() { Rules.store.night = !night; Rules.night(); }
    function toggleAir() { Quickshell.execDetached(["rfkill", air ? "unblock" : "block", "all"]); air = !air; }
    function toggleMic() { if (mic?.audio) mic.audio.muted = !mic.audio.muted; }

    // ---- Bluetooth сам не переподключает устройства, когда адаптер включили обратно (пилюля, авиарежим, rfkill).
    // BlueZ сначала рвёт соединения и только потом гасит адаптер (Connected:false за 40–90 мс до Powered:false), так что
    // снимок в момент выключения пуст. Поэтому список подключённых пишем с задержкой: выключение её отменяет, и в
    // btResume остаётся то, что было до. Отключил сам или наушники убрали в кейс — через полсекунды список это примет ----
    readonly property var btOn: Bluetooth.devices.values.filter(d => d.connected).map(d => d.address)
    property var btResume: []
    onBtOnChanged: btKeep.restart()
    Timer { id: btKeep; interval: 500; running: true; onTriggered: if (Bluetooth.defaultAdapter?.enabled && !btResumeT.running) root.btResume = root.btOn }
    Connections {
        target: Bluetooth.defaultAdapter
        function onEnabledChanged() { if (Bluetooth.defaultAdapter.enabled) btResumeT.restart(); else { btKeep.stop(); btResumeT.stop(); } }
    }
    // адаптеру нужно время после включения
    Timer { id: btResumeT; interval: 1500; onTriggered: { for (const d of Bluetooth.devices.values) if (root.btResume.includes(d.address) && !d.connected) d.connect(); } }

    // ---- кофеин: не спать. Ингибитору нужно живое окно — невидимое 0×0, как в demonshot ----
    property bool caffeine: false
    IdleInhibitor {
        enabled: root.caffeine
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "glyph-caffeine"
            mask: Region {}
        }
    }

    // ---- vpn: NetBird ----
    readonly property string vpnUrl: Theme.state.vpnUrl
    property bool vpn: false
    property bool vpnBusy: false
    property bool vpnInstalled: true
    property string vpnIp: ""
    property string vpnFqdn: ""
    property string vpnMgmt: ""
    property bool vpnMgmtConnected: false
    property var vpnPeers: []
    property var vpnProfiles: []

    function refreshVpn() {
        if (!nbStatus.running) nbStatus.running = true;
        if (!nbProfiles.running) nbProfiles.running = true;
    }

    function toggleVpn() {
        if (vpnBusy) return;
        vpnBusy = true;
        nbToggle.command = vpn
            ? ["netbird", "down"]
            : (vpnUrl ? ["netbird", "up", "--management-url", vpnUrl] : ["netbird", "up"]);
        nbToggle.running = true;
    }

    function selectVpnProfile(name) {
        if (vpnBusy || !name) return;
        vpnBusy = true;
        nbProfAct.command = ["netbird", "profile", "select", name];
        nbProfAct.running = true;
    }

    function addVpnProfile(name) {
        if (vpnBusy || !name) return;
        vpnBusy = true;
        nbProfAct.command = ["sh", "-c", 'netbird profile add "$1" && netbird profile select "$1"', "sh", name];
        nbProfAct.running = true;
    }

    Process {
        id: nbStatus
        running: true
        command: ["netbird", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.vpnInstalled = true;
                    root.vpn = j.localPeerState?.state === "Connected";
                    root.vpnIp = j.localPeerState?.netbirdIp ?? "";
                    root.vpnFqdn = j.localPeerState?.fqdn ?? "";
                    root.vpnMgmt = j.managementState?.url ?? "";
                    root.vpnMgmtConnected = !!j.managementState?.connected;
                    root.vpnPeers = (j.peers?.details ?? []).slice().sort((a, b) => {
                        const ca = a.status === "Connected" ? 0 : 1;
                        const cb = b.status === "Connected" ? 0 : 1;
                        return ca - cb || (a.fqdn || "").localeCompare(b.fqdn || "");
                    });
                } catch (e) {
                    root.vpn = false;
                    root.vpnPeers = [];
                }
            }
        }
        onExited: code => {
            if (code === 127) root.vpnInstalled = false;
            else if (code !== 0) root.vpn = false;
        }
    }

    Process {
        id: nbProfiles
        running: true
        command: ["netbird", "profile", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.trim().split("\n")) {
                    const t = line.trim();
                    if (!t || /^NAME\b/i.test(t)) continue;
                    const active = /\*\s*$/.test(t);
                    const name = t.replace(/\s*\*\s*$/, "").trim().split(/\s+/)[0];
                    if (name) list.push({ name, active });
                }
                root.vpnProfiles = list;
            }
        }
    }

    Process {
        id: nbToggle
        onExited: {
            root.vpnBusy = false;
            root.refreshVpn();
        }
    }

    Process {
        id: nbProfAct
        onExited: {
            root.vpnBusy = false;
            root.refreshVpn();
        }
    }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refreshVpn() }
}

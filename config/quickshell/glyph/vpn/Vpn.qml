import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Painel VPN (Super+P): integração com NetBird.
// Esquerda: anel de status ON/OFF, seletor de perfil e info do peer local.
// Direita: velocidade em tempo real na interface wt0, matriz de tráfego (10 min) e lista de peers com latência.
PanelWindow {
    id: root

    readonly property bool connected: Sys.vpn
    readonly property bool busy: Sys.vpnBusy
    readonly property var peers: Sys.vpnPeers
    readonly property var profiles: Sys.vpnProfiles
    readonly property string activeProfile: profiles.find(p => p.active)?.name ?? "default"
    readonly property int onlinePeers: peers.filter(p => p.status === "Connected").length

    property date since: new Date()
    onConnectedChanged: {
        if (connected) since = new Date();
        else { up = 0; down = 0; prevNet = [0, 0, 0]; }
    }

    function flip() { Sys.toggleVpn(); }

    // Tráfego em tempo real lendo a interface wt0 em /proc/net/dev
    property var toll: []
    property real up: 0
    property real down: 0
    property var prevNet: [0, 0, 0] // [rx, tx, ms]

    FileView { id: netdev; path: "/proc/net/dev"; blockAllReads: true }
    Timer {
        running: root.connected
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netdev.reload();
            const line = netdev.text().split("\n").find(l => /^\s*(wt\d+|netbird\d*):/.test(l));
            if (!line) { root.up = 0; root.down = 0; return; }
            const f = line.split(":")[1].trim().split(/\s+/).map(Number);
            const now = Date.now();
            const [prx, ptx, pt] = root.prevNet;
            const dt = (now - pt) / 1000;
            if (pt && dt > 0) {
                const rx = Math.max(0, (f[0] - prx) / dt);
                const tx = Math.max(0, (f[8] - ptx) / dt);
                root.down = rx;
                root.up = tx;
                root.toll = root.toll.slice(-599).concat([[tx, rx]]);
            }
            root.prevNet = [f[0], f[8], now];
        }
    }

    // Matriz de tráfego: 50 colunas de 12s (10 minutos)
    readonly property var cols: {
        if (!root.visible) return [];
        const s = Array(Math.max(0, 600 - toll.length)).fill([0, 0]).concat(toll), c = [];
        let max = 1;
        for (let i = 0; i < 50; i++) {
            let a = 0, b = 0;
            for (let j = i * 12; j < i * 12 + 12; j++) { a += s[j][0]; b += s[j][1]; }
            c.push([b / 12, a / 12]);
            max = Math.max(max, a / 12, b / 12);
        }
        const lv = v => v > 0 ? Math.max(1, Math.round(5 * v / max)) : 0;
        return c.map(([i, o]) => [lv(i), lv(o)]);
    }
    function speed(b) { const k = b / 1024; return k >= 1000 ? [(k / 1024).toFixed(1), "mb/s"] : [k.toFixed(1), "kb/s"]; }
    function parseMs(lat) {
        if (!lat) return 0;
        const m = /([\d.]+)\s*(ms|s|µs|us)/i.exec(String(lat));
        if (!m) return 0;
        const v = parseFloat(m[1]), u = m[2].toLowerCase();
        return u === "s" ? Math.round(v * 1000) : (u === "µs" || u === "us") ? Math.max(1, Math.round(v / 1000)) : Math.round(v);
    }

    property int cur: 0
    property bool shown: false
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function open() {
        cur = 0;
        Sys.refreshVpn();
        shown = true;
        panel.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-vpn"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 - 20 + 24 * (1 - root.t)
            width: 1040
            height: 760
            opacity: root.t
            radius: Theme.corner(44)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            focus: true
            MouseArea { anchors.fill: parent }

            Keys.onPressed: e => {
                const n = root.peers.length;
                if ((e.key === Qt.Key_Up || e.key === Qt.Key_K) && n) root.cur = (root.cur + n - 1) % n;
                else if ((e.key === Qt.Key_Down || e.key === Qt.Key_J) && n) root.cur = (root.cur + 1) % n;
                else if (e.key === Qt.Key_S) root.flip();
                else if (e.key === Qt.Key_R) Sys.refreshVpn();
                else if (e.key === Qt.Key_Escape) root.close();
                else return;
                list.positionViewAtIndex(root.cur, ListView.Contain);
                e.accepted = true;
            }

            // ---- esquerda: anel ON/OFF, perfis e info local ----
            Column {
                x: 36
                y: 36
                width: 340
                spacing: 16

                Item {
                    width: 340
                    height: 340
                    Ring { anchors.fill: parent; n: 60; dot: 10; f: root.shown && root.connected ? 1 : 0 }
                    Column {
                        anchors.centerIn: parent
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: root.connected ? Theme.accent : Theme.s3
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                        }
                        Num {
                            anchors.horizontalCenter: parent.horizontalCenter
                            topPadding: lead + 22
                            bottomPadding: lead + 16
                            text: root.busy ? "..." : root.connected ? "ON" : "OFF"
                            font.pixelSize: 120
                            color: root.connected ? Theme.fg : Theme.mute
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                        }
                        Lb {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: !Sys.vpnInstalled ? "netbird not installed"
                                : root.busy ? "switching ···"
                                : root.connected ? `since ${Qt.formatTime(root.since, "hh:mm")}`
                                : "tap to connect"
                        }
                    }
                    TapHandler { onTapped: root.flip() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }

                Item { width: 1; height: 8 }

                // Perfis NetBird
                Lb { text: "profiles · netbird"; px: 11 }
                Flow {
                    width: 340
                    spacing: 10
                    Repeater {
                        model: root.profiles
                        Rectangle {
                            required property var modelData
                            readonly property bool on: modelData.active
                            width: Math.max(96, plab.implicitWidth + 32)
                            height: 44
                            radius: Theme.corner(22)
                            color: on ? Theme.fg : Theme.s2
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                            Lb {
                                id: plab
                                anchors.centerIn: parent
                                text: parent.modelData.name
                                px: 11
                                color: parent.on ? Theme.ink : Theme.fg
                            }
                            TapHandler { onTapped: Sys.selectVpnProfile(parent.modelData.name) }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            Column {
                x: 36
                anchors { bottom: parent.bottom; bottomMargin: 36 }
                width: 340
                spacing: 6
                Lb { text: `netbird · ${root.activeProfile}`; px: 11 }
                Lb { width: parent.width; elide: Text.ElideRight; text: Sys.vpnFqdn || "offline"; px: 14; color: Theme.fg }
                Lb { width: parent.width; elide: Text.ElideRight; text: Sys.vpnIp ? `ip ${Sys.vpnIp}` : (Sys.vpnUrl || "default management"); px: 11 }
                Lb { text: `mgmt · ${Sys.vpnMgmtConnected ? "connected" : "disconnected"}`; px: 11; color: Sys.vpnMgmtConnected ? Theme.fg : Theme.grey }
            }

            // ---- direita: velocidade, matriz de tráfego e peers ----
            Item {
                x: 420
                y: 36
                width: parent.width - x - 36
                height: parent.height - 72

                Column {
                    id: rcol
                    width: parent.width
                    spacing: 12

                    Row {
                        spacing: 56
                        Stat { k: `↓ in · ${root.speed(root.down)[1]}`; v: root.speed(root.down)[0] }
                        Stat { k: `↑ out · ${root.speed(root.up)[1]}`; v: root.speed(root.up)[0] }
                    }
                    Item { width: 1; height: 14 }

                    Item {
                        width: parent.width
                        height: tl.height
                        Lb { id: tl; text: "traffic · in / out · 10 min" }
                        Lb { anchors.right: parent.right; text: `${root.onlinePeers}/${root.peers.length} peers online`; color: Theme.fg }
                    }
                    Grid {
                        id: mx
                        width: parent.width
                        columns: 50
                        spacing: 4
                        readonly property real d: (width - 49 * spacing) / 50
                        Repeater {
                            model: 50 * 10
                            Rectangle {
                                required property int index
                                readonly property int r: Math.floor(index / 50)
                                readonly property int lv: r < 5 ? 5 - r : r - 4
                                readonly property int h: root.cols[index % 50]?.[r < 5 ? 0 : 1] ?? 0
                                width: mx.d
                                height: mx.d
                                radius: mx.d / 2
                                color: lv === h ? Theme.fg : lv < h ? Theme.grey : Theme.s2
                            }
                        }
                    }
                    Item { width: 1; height: 14 }

                    Item {
                        width: parent.width
                        height: nl.height
                        Lb { id: nl; text: "peers" }
                        Lb {
                            anchors.right: parent.right
                            text: "refresh"
                            color: Theme.fg
                            TapHandler { onTapped: Sys.refreshVpn() }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }

                ListView {
                    id: list
                    anchors { top: rcol.bottom; topMargin: 8; bottom: parent.bottom; left: parent.left; right: parent.right }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.peers.length
                    delegate: Rectangle {
                        id: row
                        required property int index
                        readonly property var p: root.peers[index] ?? ({})
                        readonly property bool on: p.status === "Connected"
                        readonly property int ms: root.parseMs(p.latency)
                        width: list.width
                        height: 52
                        radius: Theme.corner(26)
                        color: index === root.cur ? Theme.s2 : Theme.fade(Theme.s2, 0)
                        Behavior on color { ColorAnimation { duration: Theme.t } }

                        Rectangle {
                            id: statusDot
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: row.on ? Theme.accent : Theme.mute
                        }
                        Column {
                            anchors { left: statusDot.right; leftMargin: 14; right: ping.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: (row.p.fqdn || row.p.netbirdIp || "peer").replace(/\.$/, "")
                                textFormat: Text.PlainText
                                font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold }
                                color: row.on ? Theme.fg : Theme.grey
                            }
                            Lb {
                                width: parent.width
                                elide: Text.ElideRight
                                text: [row.p.netbirdIp, row.p.connectionType].filter(Boolean).join(" · ")
                                px: 10
                                color: Theme.grey
                            }
                        }
                        Row {
                            id: ping
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Seg {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 54
                                height: 6
                                n: 5
                                f: row.ms > 0 ? Math.max(0.2, 1 - row.ms / 500) : 0
                                on: Theme.fg
                                off: Theme.s3
                            }
                            Lb {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64
                                horizontalAlignment: Text.AlignRight
                                text: row.ms ? `${row.ms} ms` : (row.on ? "on" : "off")
                                px: 11
                                color: row.on ? Theme.fg : Theme.grey
                            }
                        }
                        TapHandler { onTapped: root.cur = row.index }
                    }
                }
                Lb { visible: !root.peers.length; anchors.centerIn: list; text: root.connected ? "no peers" : "netbird disconnected" }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: panel.y + panel.height + 30
            opacity: root.t
            spacing: 34
            Repeater {
                model: ["↑↓ peer", "s tunnel", "r refresh", "esc close"]
                Lb { required property string modelData; text: modelData }
            }
        }
    }

    component Stat: Column {
        property string k
        property string v
        width: 264
        Lb { text: parent.k }
        Num { topPadding: lead + 10; text: parent.v; font.pixelSize: 80 }
    }
}

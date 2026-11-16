#!/usr/bin/env bash
# Glyph: instala pacotes, serviços, symlinks e tema SDDM no Arch Linux.
#   ./install.sh          pacotes + netbird + serviços + symlinks + sddm
#   ./install.sh --links  apenas symlinks
#   ./install.sh --sddm   apenas tema de login SDDM (sudo)
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"

PACMAN=(
    # base
    base-devel git curl jq python
    # sessão
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    # áudio, rede, bluetooth
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    # utilitários usados pelos binds e pelo shell
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    # terminal e console
    kitty fish starship fastfetch btop lsd zoxide direnv
    # apps padrão
    nautilus pavucontrol
    # fontes, ícones e base GTK
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    zen-browser-bin gearlever
)

G=config/quickshell/glyph
# repo-path → path em $HOME
LINKS=(
    "config/hypr                                .config/hypr"
    "$G                                         .config/quickshell/glyph"
    "$G/rice                                    .local/bin/rice"
    "config/kitty                               .config/kitty"
    "config/qtengine                            .config/qtengine"
    "$G/term/qtengine.colors                    .config/qtengine.colors"
    "$G/term/starship.toml                      .config/starship.toml"
    "$G/term/fastfetch                          .config/fastfetch"
    "$G/term/btop                               .config/btop"
    "$G/term/gtk-3.0/gtk.css                    .config/gtk-3.0/gtk.css"
    "$G/term/gtk-4.0/gtk.css                    .config/gtk-4.0/gtk.css"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
)

say() { printf '\e[38;2;215;25;33m●\e[0m %s\n' "$*"; }

packages() {
    say "pacman"
    local pa; pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer,equalizer-ladspa} 2>/dev/null || true)
    [ -z "$pa" ] || sudo pacman -R $pa
    pacman -Q pulseaudio &>/dev/null && say "pacman will ask \"Remove pulseaudio?\": answer y, pipewire-pulse replaces it"
    sudo pacman -Syu --needed "${PACMAN[@]}"

    if ! command -v paru >/dev/null; then
        say "paru"
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
        (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "aur"
    paru -S --needed --noconfirm "${AUR[@]}" || say "aur: some packages failed, see above"

    if ! command -v netbird >/dev/null; then
        say "netbird"
        curl -fsSL https://pkgs.netbird.io/install.sh | sh
    fi
}

services() {
    say "services"
    sudo systemctl enable NetworkManager bluetooth power-profiles-daemon
    systemctl list-unit-files netbird.service &>/dev/null && sudo systemctl enable netbird || true
    systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
    systemctl --user enable pipewire-pulse.socket wireplumber ydotool
    sudo usermod -aG input,video "$USER"
    xdg-user-dirs-update
}

links() {
    say "symlinks (old files → $BACKUP)"
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        [ "$(readlink "$dst")" = "$src" ] && continue
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
            mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        fi
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        echo "  $dst"
    done
    mkdir -p "$HOME/.config/glyph"
    mkdir -p "$HOME/Pictures/Wallpapers"
    fc-cache -f >/dev/null
    command -v gsettings >/dev/null || return 0
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
}

vpn_config() {
    local cfg="$HOME/.config/glyph/glyph.json"
    local cur=""
    [ -f "$cfg" ] && cur=$(jq -r '.vpnUrl // ""' "$cfg" 2>/dev/null || true)
    say "netbird management URL (leave empty for default${cur:+, current: $cur}):"
    local url=""
    read -rp "  > " url || true
    [ -n "$url" ] || return 0
    mkdir -p "$HOME/.config/glyph"
    if [ -f "$cfg" ]; then
        local tmp; tmp="$(mktemp)"
        jq --arg u "$url" '.vpnUrl = $u' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
    else
        jq -n --arg u "$url" '{ vpnUrl: $u }' > "$cfg"
    fi
}

greeter() {
    say "sddm: glyph theme"
    [ -d /usr/share/sddm/themes ] || { say "sddm isn't installed, skipping the theme"; return 0; }
    sudo rm -rf /usr/share/sddm/themes/glyph
    sudo cp -rLT "$DOTS/config/sddm/glyph" /usr/share/sddm/themes/glyph
    sudo chmod -R a+rX /usr/share/sddm/themes/glyph
    sudo mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=glyph\n\n[General]\nInputMethod=\n' | sudo tee /etc/sddm.conf.d/zz-glyph.conf >/dev/null
    if grep -qsE '^\s*Current=' /etc/sddm.conf && ! grep -qsE '^\s*Current=glyph\s*$' /etc/sddm.conf; then
        say "/etc/sddm.conf sets its own theme and wins over conf.d: set Current=glyph there"
    fi
}

[ "$EUID" -eq 0 ] && { echo "run as your user, not root: sudo asks when it needs to"; exit 1; }

case "${1:-}" in
    --links) links ;;
    --sddm) greeter ;;
    "") command -v pacman >/dev/null || { echo "packages install on Arch only; on another distro: $0 --links"; exit 1; }
        packages; services; links; vpn_config; greeter
        say "done. reboot and pick Hyprland in sddm" ;;
    *) echo "usage: $0 [--links | --sddm]"; exit 1 ;;
esac

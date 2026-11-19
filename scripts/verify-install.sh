#!/usr/bin/env bash
# ==============================================================================
# Перевірка стану установки MangoWM + Noctalia
# ==============================================================================

set -u

RED='\033[1;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'

results=()

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        results+=("<b>✓</b> $1 — знайдено")
    else
        results+=("<b>✗</b> $1 — <i>не знайдено</i>")
    fi
}

check_file() {
    if [ -f "$1" ]; then
        results+=("<b>✓</b> $1 — існує")
    else
        results+=("<b>✗</b> $1 — <i>відсутній</i>")
    fi
}

check_systemd() {
    if systemctl is-enabled "$1" >/dev/null 2>&1; then
        results+=("<b>✓</b> $1 — увімкнено")
    else
        results+=("<b>✗</b> $1 — <i>не увімкнено</i>")
    fi
}

echo "=== Перевірка установки ==="

check_cmd mango
check_cmd mmsg
check_cmd noctalia
check_cmd hermes
check_cmd opencode
check_cmd kitty
check_cmd zenity
check_file ~/.config/mango/config.conf
check_file ~/.config/mango/noctalia.conf
check_file ~/.hermes/.env
check_file /usr/share/wayland-sessions/mango.desktop
check_systemd lightdm

if [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; then
    results+=("<b>✓</b> graphical.target — активний")
else
    results+=("<b>✗</b> graphical.target — <i>не активний</i>")
fi

if grep -qE '^NVIDIA_API_KEY=nvapi-' ~/.hermes/.env 2>/dev/null; then
    results+=("<b>✓</b> NVIDIA_API_KEY — настроєно")
else
    results+=("<b>✗</b> NVIDIA_API_KEY — <i>додайте у ~/.hermes/.env</i>")
fi

# Показуємо результат у вікні zenity.
TEXT=$(printf '%s\n' "${results[@]}")
zenity --info --title="Результат перевірки" \
    --text="$TEXT" \
    --width=600 --height=400 2>/dev/null || echo "$TEXT"

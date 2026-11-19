#!/usr/bin/env bash
# ==============================================================================
# Перевірка стану установки MangoWM + Noctalia
# ==============================================================================

set -u

results=()

check_cmd() {
    local name="$1"; shift
    local found=""
    if command -v "$name" >/dev/null 2>&1; then
        found="$(command -v "$name")"
    else
        local path
        for path in "$@"; do
            if [ -x "$path" ]; then
                found="$path"
                break
            fi
        done
    fi
    if [ -n "$found" ]; then
        results+=("<b>✓</b> $name — знайдено ($found)")
    else
        results+=("<b>✗</b> $name — <i>не знайдено</i>")
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

check_mango_config() {
    local conf="$HOME/.config/mango/config.conf"
    if [ ! -f "$conf" ]; then
        results+=("<b>✗</b> конфігурація Mango — <i>файл відсутній</i>")
        return
    fi
    if mango -c "$conf" -p >/dev/null 2>&1; then
        results+=("<b>✓</b> конфігурація Mango — без помилок")
    else
        results+=("<b>✗</b> конфігурація Mango — <i>є помилки (mango -p)</i>")
    fi
}

echo "=== Перевірка установки ==="

check_cmd mango /usr/bin/mango
check_cmd mmsg /usr/bin/mmsg
check_cmd noctalia /usr/bin/noctalia
check_cmd hermes "$HOME/.local/bin/hermes"
check_cmd opencode "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
check_cmd kitty /usr/bin/kitty
check_cmd zenity /usr/bin/zenity

check_file "$HOME/.config/mango/config.conf"
check_file "$HOME/.config/mango/env"
check_file "$HOME/.hermes/.env"
check_file /usr/share/wayland-sessions/mango.desktop
check_systemd lightdm

if [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; then
    results+=("<b>✓</b> graphical.target — активний")
else
    results+=("<b>✗</b> graphical.target — <i>не активний</i>")
fi

check_mango_config

if [ -f "$HOME/.config/mango/noctalia.conf" ] \
    && grep -qE '^(root_color|border_color)=' "$HOME/.config/mango/noctalia.conf" 2>/dev/null; then
    results+=("<b>!</b> noctalia.conf містить синтаксис Mango 0.18+ — вимкніть шаблон Mango у Noctalia")
fi

if grep -qE '^NVIDIA_API_KEY=nvapi-' "$HOME/.hermes/.env" 2>/dev/null; then
    results+=("<b>✓</b> NVIDIA_API_KEY — налаштовано")
else
    results+=("<b>✗</b> NVIDIA_API_KEY — <i>додайте у ~/.hermes/.env</i>")
fi

# Показуємо результат у вікні zenity.
TEXT=$(printf '%s\n' "${results[@]}")
zenity --info --title="Результат перевірки" \
    --text="$TEXT" \
    --width=600 --height=420 2>/dev/null || echo "$TEXT"

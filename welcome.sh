#!/usr/bin/env bash
# ==============================================================================
# Ласкаво просимо до MangoWM + Noctalia Shell
# Показується один раз після першого входу. Під час повторних входів не з'являється.
# Файл прапора: ~/.config/mango/.welcome-shown
# ==============================================================================

set -u

FLAG="$HOME/.config/mango/.welcome-shown"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_script() {
    if [ -x "$1" ]; then
        "$1"
    else
        zenity --error --title="Помилка" \
            --text="Скрипт не знайдено:\n$1" \
            --width=500 --height=150
    fi
}

# Якщо уже показували — вихід.
[ -f "$FLAG" ] && exit 0

# Перевіряємо zenity.
if ! command -v zenity >/dev/null 2>&1; then
    echo "welcome.sh: zenity не знайдено, вікно вітання не буде показано" >&2
    touch "$FLAG"
    exit 0
fi

ACTION=$(zenity --list --title="Ласкаво просимо до MangoWM + Noctalia Shell" \
    --text="<b>Ваше робоче середовище встановлено.</b>\n\n\
• <b>MangoWM</b> 0.14.4 (mangowc з ButterRepo)\n\
• <b>Noctalia Shell</b> 5.5.0 — оболонка Wayland\n\
• <b>Hermes Agent</b> + <b>OpenCode</b> у scratchpad-вікнах kitty\n\
• <b>Debian 13</b> (Trixie), uk_UA.UTF-8, Europe/Kyiv, us/ua (Alt+Shift)\n\
• <b>lightdm</b> — графічний вхід після перезавантаження\n\n\
Оберіть, що хочете зробити зараз:" \
    --column="Дія" --column="Опис" \
    verify "Перевірити установку" \
    nvidia "Налаштувати NVIDIA API-ключ" \
    autologin "Автовхід (без пароля)" \
    readme "Відкрити інструкцію на GitHub" \
    skip "Не показувати більше" \
    --width=700 --height=420) || { touch "$FLAG"; exit 0; }

case "$ACTION" in
    verify)
        run_script "$SCRIPT_DIR/scripts/verify-install.sh"
        ;;
    nvidia)
        run_script "$SCRIPT_DIR/scripts/setup-nvidia.sh"
        ;;
    autologin)
        run_script "$SCRIPT_DIR/scripts/setup-autologin.sh"
        ;;
    readme)
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "https://github.com/Karnemorkon/mangowm-noctalia-setup" &
        elif command -v kitty >/dev/null 2>&1; then
            kitty -e sh -c 'curl -sL https://raw.githubusercontent.com/Karnemorkon/mangowm-noctalia-setup/main/README.md | less' &
        else
            zenity --info --title="Інструкція" \
                --text="Відкрийте:\nhttps://github.com/Karnemorkon/mangowm-noctalia-setup" \
                --width=500 --height=150
        fi
        ;;
    skip|*)
        ;;
esac

# Після будь-якої дії більше не показувати автоматично.
touch "$FLAG"
exit 0

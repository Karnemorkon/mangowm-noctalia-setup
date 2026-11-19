#!/usr/bin/env bash
# ==============================================================================
# Допомога з налаштуванням NVIDIA API-ключа для Hermes
# ==============================================================================

set -u

ENV_FILE="$HOME/.hermes/.env"

zenity --question --title="NVIDIA API-ключ" \
    --text="<b>Для Hermes потрібен NVIDIA API-ключ.</b>\n\n\
Зараз відкриється сторінка створення ключів на build.nvidia.com.\n\
Скопіюйте ключ (починається з nvapi-...) та вставте у файл:\n\
<b>$ENV_FILE</b>\n\n\
Формат у файлі:\n\
NVIDIA_API_KEY=nvapi-...\n\n\
Відкрити сторінку зараз?" \
    --width=600 --height=300 || exit 0

mkdir -p "$HOME/.hermes"
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"
grep -qE '^NVIDIA_API_KEY=' "$ENV_FILE" 2>/dev/null \
    || printf '\nNVIDIA_API_KEY=\n' >> "$ENV_FILE"

if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://build.nvidia.com/settings/api-keys" >/dev/null 2>&1 &
fi

# Відкриваємо .env у текстовому редакторі (nano є в базових пакетах).
editor=""
for candidate in nano vi vim; do
    if command -v "$candidate" >/dev/null 2>&1; then
        editor="$candidate"
        break
    fi
done

if command -v kitty >/dev/null 2>&1 && [ -n "$editor" ]; then
    kitty -e "$editor" "$ENV_FILE"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$ENV_FILE" >/dev/null 2>&1 &
fi

zenity --info --title="Наступний крок" \
    --text="Після додавання ключа перезавантажте Hermes або просто продовжуйте працювати.\n\
Перевірку можна запустити знову через вікно вітання." \
    --width=500 --height=200 2>/dev/null || true

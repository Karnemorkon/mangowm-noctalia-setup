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

if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "https://build.nvidia.com/settings/api-keys" &
fi

# Спробуємо відкрити .env у текстовому редакторі.
if command -v kitty >/dev/null 2>&1; then
    kitty -e sh -c "if [ ! -f '$ENV_FILE' ]; then touch '$ENV_FILE'; chmod 600 '$ENV_FILE'; fi; nano '$ENV_FILE'" &
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$ENV_FILE" &
fi

zenity --info --title="Наступний крок" \
    --text="Після додавання ключа перезавантажте Hermes або просто продовжуйте працювати.\
Перевірку можна запустити знову через вікно вітання." \
    --width=500 --height=200 2>/dev/null || true

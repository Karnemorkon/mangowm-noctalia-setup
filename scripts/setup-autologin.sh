#!/usr/bin/env bash
# ==============================================================================
# Автовхід у lightdm (без введення пароля)
# Потребує прав адміністратора (pkexec; polkit-агент надає Noctalia).
# ==============================================================================

set -u

REAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
CONF_DIR="/etc/lightdm/lightdm.conf.d"
CONF_FILE="$CONF_DIR/50-autologin.conf"

zenity --question --title="Автовхід" \
    --text="<b>Увімкнути автовхід для користувача <i>$REAL_USER</i>?</b>\n\n\
Після ввімкнення комп’ютер буде завантажуватися прямо в сесію Mango, \
без введення пароля.\n\n\
Потребує прав адміністратора." \
    --width=600 --height=250 || exit 0

manual_cmd="sudo mkdir -p $CONF_DIR
printf '[Seat:*]\nautologin-user=$REAL_USER\nautologin-user-timeout=0\nautologin-session=mango\n' | sudo tee $CONF_FILE"

if ! command -v pkexec >/dev/null 2>&1; then
    zenity --error --title="Помилка" \
        --text="pkexec не знайдено. Виконайте вручну:\n\n$manual_cmd" \
        --width=600 --height=300
    exit 1
fi

TMP_CONF="$(mktemp)"
ERR_FILE="$(mktemp)"
trap 'rm -f "$TMP_CONF" "$ERR_FILE"' EXIT

cat > "$TMP_CONF" <<EOF
[Seat:*]
autologin-user=$REAL_USER
autologin-user-timeout=0
autologin-session=mango
EOF

pkexec sh -c 'install -d -m 0755 "$1" && install -m 0644 "$2" "$3"' \
    sh "$CONF_DIR" "$TMP_CONF" "$CONF_FILE" 2>"$ERR_FILE"
rc=$?

if [ "$rc" -eq 0 ]; then
    zenity --info --title="Готово" \
        --text="Автовхід увімкнено для $REAL_USER.\n\
Сесія за замовчуванням: Mango.\n\
Перезавантажте комп’ютер." \
        --width=500 --height=200
else
    zenity --error --title="Помилка" \
        --text="Не вдалося увімкнути автовхід (код $rc):\n\
$(cat "$ERR_FILE")\n\n\
Спробуйте вручну:\n$manual_cmd" \
        --width=600 --height=350
    exit 1
fi

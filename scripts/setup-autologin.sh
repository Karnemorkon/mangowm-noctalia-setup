#!/usr/bin/env bash
# ==============================================================================
# Автоувійн у lightdm (без введення пароля)
# Потребує прав адміністратора (pkexec / sudo).
# ==============================================================================

set -u

REAL_USER="${SUDO_USER:-$USER}"
CONF_DIR="/etc/lightdm/lightdm.conf.d"
CONF_FILE="$CONF_DIR/50-autologin.conf"

zenity --question --title="Автоувійн" \
    --text="<b>Увімкнути автоувійн для користувача <i>$REAL_USER</i>?</b>\n\n\
Після ввімкнення комп’ютер буде завантажуватися прямий у сесію Mango,\
без введення паролю.\n\n\
Потребує прав адміністратора." \
    --width=600 --height=250 || exit 0

if ! command -v pkexec >/dev/null 2>&1; then
    zenity --error --title="Помилка" \
        --text="pkexec не знайдено. Виконайте вручну:\n\
sudo mkdir -p $CONF_DIR\n\
echo -e '[Seat:*]\nautologin-user=$REAL_USER\nautologin-user-timeout=0' | sudo tee $CONF_FILE" \
        --width=600 --height=250
    exit 1
fi

pkexec bash -c "
mkdir -p $CONF_DIR
cat > $CONF_FILE <<EOF
[Seat:*]
autologin-user=$REAL_USER
autologin-user-timeout=0
EOF
chmod 644 $CONF_FILE
" 2>/tmp/autologin-err

if [ $? -eq 0 ]; then
    zenity --info --title="Готово" \
        --text="Автоувійн увімкнено для $REAL_USER.\n\
Перезавантажте комп’ютер." \
        --width=500 --height=200
else
    zenity --error --title="Помилка" \
        --text="Не вдалося увімкнути автоувійн:\n$(cat /tmp/autologin-err)" \
        --width=600 --height=300
fi

#!/usr/bin/env bash
# ==============================================================================
# MangoWM (mangowc 0.14.4) + Noctalia Shell + Hermes Agent + OpenCode
# Автоматичне встановлення для Debian 13 (Trixie), amd64
#
# Запуск:
#   sudo ./setup-system.sh
#
# Скрипт розрахований на чисту систему Debian 13. Він не робить
# apt-get upgrade і не змінює чужі конфіги: перед перезаписом
# ~/.config/mango робиться резервна копія.
#
# Стеки використані:
#   • MangoWM (mangowc) 0.14.4 з ButterRepo (amd64-only) — пов'язаний із
#     libwlroots-0.19 та libscenefx-0.4, що nudують на trixie Wayland-стек.
#   • Noctalia Shell 5.5.0 з офіційного APT-репозиторію.
#   • Hermes Agent + OpenCode у іменованих scratchpad-вікнах kitty.
# ==============================================================================

set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() {
    :
}
on_error() {
    local rc=$?
    printf '\033[1;31m[✗] Помилка на рядку %s (код %s). Дивіться вивід вище.\n' \
        "${LINENO:-?}" "$rc" >&2
    exit "$rc"
}
trap on_error ERR

# ------------------------------------------------------------------------------
# 0. Перевірки
# ------------------------------------------------------------------------------
[ "$EUID" -eq 0 ] || die "Запустіть скрипт через sudo: sudo ./setup-system.sh"
[ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] \
    || die "Запускайте через sudo зі звичайного користувача (не з root-сесії)."

REAL_USER="$SUDO_USER"
REAL_GROUP="$(id -gn "$REAL_USER")"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -n "$USER_HOME" ] && [ -d "$USER_HOME" ] || die "Не знайдено домашній каталог для $REAL_USER."

. /etc/os-release
[ "${ID:-}" = "debian" ] || die "Скрипт призначений для Debian 13 (Trixie)."
if [ "${VERSION_ID:-}" != "13" ]; then
    warn "Виявлено Debian ${VERSION_ID:-?}, а не 13 (Trixie). Продовжую на власний ризик."
fi

ARCH="$(dpkg --print-architecture)"
[ "$ARCH" = "amd64" ] \
    || die "Скрипт розрахований на amd64 (mangowc і noctalia-trixie.sources — тільки amd64)."

log "Користувач: $REAL_USER ($USER_HOME), архітектура: $ARCH"

# ------------------------------------------------------------------------------
# 1. Базові пакети, локаль, часовий пояс
# ------------------------------------------------------------------------------
log "[1/7] Базові пакети, локаль uk_UA.UTF-8, часовий пояс Europe/Kyiv"

apt-get update
apt-get install -y \
    ca-certificates curl wget gnupg git unzip \
    locales tzdata

timedatectl set-timezone Europe/Kyiv 2>/dev/null \
    || ln -sf /usr/share/zoneinfo/Europe/Kyiv /etc/localtime

sed -i -E 's/^#[[:space:]]*uk_UA\.UTF-8 UTF-8/uk_UA.UTF-8 UTF-8/' /etc/locale.gen
grep -qE '^uk_UA\.UTF-8 UTF-8' /etc/locale.gen || echo 'uk_UA.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
update-locale LANG=uk_UA.UTF-8

# ------------------------------------------------------------------------------
# 2. Репозиторії: ButterRepo (mangowc) та офіційний Noctalia
# ------------------------------------------------------------------------------
log "[2/7] Підключення ButterRepo та офіційного репозиторію Noctalia"

# ButterRepo — amd64-only ключ та репозиторій stable main.
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://apt.justaguy.dev/key.asc | gpg --dearmor -o /usr/share/keyrings/butterrepo.gpg
chmod 0644 /usr/share/keyrings/butterrepo.gpg

cat > /etc/apt/sources.list.d/butterrepo.list <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/butterrepo.gpg] https://apt.justaguy.dev stable main
EOF

# Офіційний репозиторій Noctalia (Trixie, amd64).
wget -q -O /usr/share/keyrings/nickh-archive-keyring.gpg \
    https://pkg.noctalia.dev/deb/nickh-archive-keyring.gpg
chmod 0644 /usr/share/keyrings/nickh-archive-keyring.gpg

cat > /etc/apt/sources.list.d/noctalia-trixie.sources <<'EOF'
Enabled: True
Types: deb deb-src
URIs: https://pkg.noctalia.dev/deb/
Signed-By: /usr/share/keyrings/nickh-archive-keyring.gpg
Suites: trixie/ trixie-backports/
Architectures: amd64
EOF

apt-get update

# ------------------------------------------------------------------------------
# 3. Wayland-стек + допоміжні пакети
# ------------------------------------------------------------------------------
log "[3/7] Встановлення Wayland-стеку (mangowc, wlroots 0.19, scenefx 0.4) та застосунків"

apt-get install -y \
    mangowc libwlroots-0.19 libscenefx-0.4 \
    noctalia kitty xwayland \
    slurp wl-clipboard ripgrep jq fzf git curl wget unzip ca-certificates \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    pipewire pipewire-audio wireplumber polkitd pkexec \
    fonts-noto-color-emoji upower power-profiles-daemon \
    lightdm lightdm-gtk-greeter zenity

# ------------------------------------------------------------------------------
# 4. Конфігурація MangoWM (0.14.x, ButterRepo)
# ------------------------------------------------------------------------------
log "[4/7] Створення конфігурації MangoWM"

MANGO_CONF_DIR="$USER_HOME/.config/mango"
install -d -o "$REAL_USER" -g "$REAL_GROUP" "$USER_HOME/.config"

if [ -d "$MANGO_CONF_DIR" ] && [ -n "$(ls -A "$MANGO_CONF_DIR" 2>/dev/null)" ]; then
    MANGO_BACKUP="$MANGO_CONF_DIR.bak.$(date +%Y%m%d-%H%M%S)"
    cp -a "$MANGO_CONF_DIR" "$MANGO_BACKUP"
    log "  → резервна копія: $MANGO_BACKUP"
fi
install -d -o "$REAL_USER" -g "$REAL_GROUP" "$MANGO_CONF_DIR"

cat > "$MANGO_CONF_DIR/config.conf" <<'EOF'
# Головна конфігурація MangoWM (mangowc 0.14.x).
# Документація: https://mangowm.github.io/docs/
source=~/.config/mango/layout.conf
source=~/.config/mango/input.conf
source=~/.config/mango/keybinds.conf
source=~/.config/mango/rules.conf
source=~/.config/mango/autostart.conf

# Noctalia сама анімує свої поверхні; анімації шарів композитора викликають
# візуальні артефакти (див. docs Noctalia для Mango).
layer_animations=0

# Мапа клавіатури us,ua, перемикання Alt+Shift.
xkb_rules_layout=us,ua
xkb_rules_options=grp:alt_shift_toggle

# Noctalia дописує сюди кольори теми. Файл створюємо заздалегідь, щоб
# source був стабільним і Noctalia не додавала дублікат.
source-optional=~/.config/mango/noctalia.conf
EOF

cat > "$MANGO_CONF_DIR/layout.conf" <<'EOF'
# Макети вікон: цикл Super+N
circle_layout=scroller,tile,grid

# Параметри Scroller
scroller_structs=20
scroller_default_proportion=0.9
scroller_focus_center=0
scroller_prefer_center=0
scroller_prefer_overspread=1
edge_scroller_pointer_focus=1
scroller_proportion_preset=0.5,0.8,1.0
EOF

cat > "$MANGO_CONF_DIR/input.conf" <<'EOF'
# Розкладки us,ua; перемикання Alt+Shift
xkb_rules_layout=us,ua
xkb_rules_options=grp:alt_shift_toggle

repeat_rate=40
repeat_delay=300
EOF

cat > "$MANGO_CONF_DIR/rules.conf" <<'EOF'
# Іменовані scratchpad-вікна для AI-агентів.
# isnamedscratchpad:1 робить вікно плаваючим і"name_size"; single_scratchpad
# (default 1) обмежує одночасний показ, тому ставимо 0 для двох агентів.
windowrule=isnamedscratchpad:1,single_scratchpad:0,width:1100,height:700,appid:hermes-scratchpad
windowrule=isnamedscratchpad:1,single_scratchpad:0,width:1200,height:750,appid:opencode-scratchpad
EOF

cat > "$MANGO_CONF_DIR/keybinds.conf" <<'EOF'
# --- Термінал та AI-агенти -------------------------------------------------
bind=SUPER,Return,spawn,kitty
bind=SUPER,a,toggle_named_scratchpad,hermes-scratchpad,none,kitty --class hermes-scratchpad -e "$HOME/.local/bin/hermes"
bind=SUPER,o,toggle_named_scratchpad,opencode-scratchpad,none,kitty --class opencode-scratchpad -e "$HOME/.opencode/bin/opencode"

# --- Noctalia Shell (IPC) --------------------------------------------------
bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
bind=SUPER,s,spawn,noctalia msg panel-toggle control-center
bind=SUPER,comma,spawn,noctalia msg settings-toggle
bind=SUPER,d,spawn,noctalia msg dock-toggle
bind=SUPER,w,spawn,noctalia msg panel-toggle wallpaper

# --- Медіа ----------------------------------------------------------------
bind=NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
bind=NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
bind=NONE,XF86AudioMute,spawn,noctalia msg volume-mute
bind=NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
bind=NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down

# --- Макети ---------------------------------------------------------------
bind=SUPER,n,switch_layout
bind=SUPER,z,setlayout,scroller
bind=SUPER,t,setlayout,tile
bind=SUPER,g,setlayout,grid

# --- Вікна ---------------------------------------------------------------
bind=SUPER,q,killclient
bind=SUPER,f,togglefullscreen
bind=SUPER+SHIFT,f,togglefloating
bind=SUPER,r,reload_config
bind=SUPER,m,quit

# --- Фокус ---------------------------------------------------------------
bind=SUPER,Left,focusdir,left
bind=SUPER,Right,focusdir,right
bind=SUPER,Up,focusdir,up
bind=SUPER,Down,focusdir,down
bind=SUPER,Tab,focusstack,next

# --- Переміщення вікон (0.14.x: exchange_client, не move_client) ----------
bind=SUPER+SHIFT,Left,exchange_client,left
bind=SUPER+SHIFT,Right,exchange_client,right
bind=SUPER+SHIFT,Up,exchange_client,up
bind=SUPER+SHIFT,Down,exchange_client,down

# --- Теги (працюють як робочі столи) --------------------------------------
bind=CTRL,1,view,1,0
bind=CTRL,2,view,2,0
bind=CTRL,3,view,3,0
bind=CTRL,4,view,4,0
bind=CTRL,5,view,5,0
bind=CTRL,6,view,6,0
bind=CTRL,7,view,7,0
bind=CTRL,8,view,8,0
bind=CTRL,9,view,9,0

bind=ALT,1,tag,1,0
bind=ALT,2,tag,2,0
bind=ALT,3,tag,3,0
bind=ALT,4,tag,4,0
bind=ALT,5,tag,5,0
bind=ALT,6,tag,6,0
bind=ALT,7,tag,7,0
bind=ALT,8,tag,8,0
bind=ALT,9,tag,9,0
EOF

cat > "$MANGO_CONF_DIR/autostart.conf" <<'EOF'
# Noctalia запускається один раз при старті композитора.
# Вона сама керує шпалерами, тому окремий awww/swaybg не потрібен.
exec-once=noctalia
# Вікно вітання при першому вході (скрипт сам перевіряє прапор .welcome-shown).
exec-once=~/.config/mango/welcome.sh
EOF

# Порожній файл, який Noctalia перезапише кольорами теми.
: > "$MANGO_CONF_DIR/noctalia.conf"

chown -R "$REAL_USER:$REAL_GROUP" "$MANGO_CONF_DIR"

# Скопіювати вікно вітання та допоміжні скрипти у конфіг Mango.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/scripts" ]; then
    cp -a "$SCRIPT_DIR/scripts" "$MANGO_CONF_DIR/scripts"
    chmod +x "$MANGO_CONF_DIR/welcome.sh" "$MANGO_CONF_DIR/scripts"/*.sh 2>/dev/null || true
fi
chown -R "$REAL_USER:$REAL_GROUP" "$MANGO_CONF_DIR"

# Перевірка синтаксису конфігурації без запуску композитора.
if runuser -u "$REAL_USER" -- env HOME="$USER_HOME" PATH="/usr/bin:/bin" \
    mango -c "$MANGO_CONF_DIR/config.conf" -p >/dev/null 2>&1; then
    log "  → конфігурація Mango перевірена (mango -p OK)"
else
    warn "Mango повідомив про помилки в конфігурації. Перевірте файли в $MANGO_CONF_DIR."
fi

# ------------------------------------------------------------------------------
# 5. Hermes Agent
# ------------------------------------------------------------------------------
log "[5/7] Встановлення та налаштування Hermes Agent"

HERMES_DIR="$USER_HOME/.hermes"
HERMES_BIN="$USER_HOME/.local/bin/hermes"
install -d -o "$REAL_USER" -g "$REAL_GROUP" "$USER_HOME/.local" "$USER_HOME/.local/bin"

if [ ! -x "$HERMES_BIN" ]; then
    runuser -u "$REAL_USER" -- env HOME="$USER_HOME" USER="$REAL_USER" \
        LOGNAME="$REAL_USER" SHELL=/bin/bash CI=true \
        bash -c 'set -o pipefail; curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive'
else
    log "  → hermes уже встановлений, пропускаю інсталятор"
fi

[ -x "$HERMES_BIN" ] || die "Hermes не встановився: не знайдено $HERMES_BIN"

runuser -u "$REAL_USER" -- env HOME="$USER_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" \
    "$HERMES_BIN" config set model.provider nvidia
runuser -u "$REAL_USER" -- env HOME="$USER_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" \
    "$HERMES_BIN" config set model.default "nvidia/nemotron-3.5-super-vl-120b-a12b"
runuser -u "$REAL_USER" -- env HOME="$USER_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" \
    "$HERMES_BIN" config set terminal.backend local
runuser -u "$REAL_USER" -- env HOME="$USER_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" \
    "$HERMES_BIN" config set approvals.mode smart

mkdir -p "$HERMES_DIR"
if [ -f "$HERMES_DIR/config.yaml" ] && ! grep -qE '^fallback_providers:' "$HERMES_DIR/config.yaml"; then
    [ -n "$(tail -c 1 "$HERMES_DIR/config.yaml" 2>/dev/null)" ] && echo >> "$HERMES_DIR/config.yaml"
    cat >> "$HERMES_DIR/config.yaml" <<'EOF'

# Резервна модель, якщо основна недоступна (rate limit / outage).
fallback_providers:
  - provider: nvidia
    model: "z-ai/glm-5.3-flash"
EOF
fi

touch "$HERMES_DIR/.env"
grep -qE '^NVIDIA_API_KEY=' "$HERMES_DIR/.env" || printf '\nNVIDIA_API_KEY=\n' >> "$HERMES_DIR/.env"
chmod 600 "$HERMES_DIR/.env"

# Системна навичка Hermes. Формат — каталог із SKILL.md, а не окремий .md.
SKILL_DIR="$HERMES_DIR/skills/debian-mangowm"
mkdir -p "$SKILL_DIR"
cat > "$SKILL_DIR/SKILL.md" <<'EOF'
---
name: debian-mangowm
description: Administer Debian 13 MangoWM + Noctalia desktop
version: 1.0.0
platforms: [linux]
metadata:
  hermes:
    tags: [debian, mangowm, noctalia, wayland, desktop]
---

# Debian 13 + MangoWM + Noctalia

## Опис системи
- **ОС**: Debian 13 (Trixie), пакетний менеджер `apt`.
- **Локалізація**: `uk_UA.UTF-8`, часовий пояс `Europe/Kyiv`, розкладки `us,ua` (Alt+Shift).
- **Композитор**: MangoWM 0.14.4 (пакет `mangowc` з ButterRepo), binary `mango`, IPC `mmsg`.
- **Оболонка**: Noctalia Shell з офіційного APT-репозиторію, IPC — `noctalia msg`.
- **Агенти**: Hermes Agent (`~/.local/bin/hermes`) та OpenCode
  (`~/.opencode/bin/opencode`) у named scratchpad-вікнах kitty.

## Правила адміністрування
1. Конфігурація MangoWM: `~/.config/mango/*.conf`. Перевірка:
   `mango -c ~/.config/mango/config.conf -p`.
2. Керування оболонкою — через `noctalia msg <command>`.
3. Логи Noctalia: `~/.cache/noctalia/noctalia.log` (або `$XDG_CACHE_HOME/noctalia/`).
4. Не додавайте бібліотеки Mango до `/etc/ld.so.conf` — вони з ButteRepo
   та встановлені системно.
5. Не запускайте інтерактивні команди без потреби: `apt-get` — з `-y`,
   `hermes setup` — лише коли користувач сам цього хоче.
6. Не перезаписуйте `~/.hermes/config.yaml` повністю: використовуйте
   `hermes config set <key> <value>`.
EOF

chown -R "$REAL_USER:$REAL_GROUP" "$HERMES_DIR"

# ------------------------------------------------------------------------------
# 6. OpenCode
# ------------------------------------------------------------------------------
log "[6/8] Встановлення OpenCode"

if [ ! -x "$USER_HOME/.opencode/bin/opencode" ] && [ ! -x "$USER_HOME/.local/bin/opencode" ]; then
    runuser -u "$REAL_USER" -- env HOME="$USER_HOME" USER="$REAL_USER" \
        LOGNAME="$REAL_USER" SHELL=/bin/bash CI=true \
        bash -c 'set -o pipefail; curl -fsSL https://opencode.ai/install | bash'
else
    log "  → opencode уже встановлений, пропускаю"
fi

# ------------------------------------------------------------------------------
# 7. Графічний вхід (Display Manager)
# ------------------------------------------------------------------------------
log "[7/8] Налаштування графічного входу (lightdm)"

# Сесійний файл Mango для display manager (створюємо, якщо пакет не додав)
install -d /usr/share/wayland-sessions
if [ ! -f /usr/share/wayland-sessions/mango.desktop ]; then
    cat > /usr/share/wayland-sessions/mango.desktop <<'EOF'
[Desktop Entry]
Encoding=UTF-8
Name=Mango
DesktopNames=mango;wlroots
Comment=MangoWM (Wayland)
Exec=/usr/bin/mango-session
TryExec=/usr/bin/mango-session
Icon=mango
Type=Application
EOF
fi

# lightdm як за замовчуванням, якщо ще не вибрано інший DM
if debconf-get-selections 2>/dev/null | grep -q '^lightdm'; then
    :
else
    echo "lightdm lightdm/default_greeter string lightdm-gtk-greeter" \
        | debconf-set-selections 2>/dev/null || true
fi

# Увімкнути graphical.target та lightdm
systemctl set-default graphical.target 2>/dev/null || true
systemctl enable lightdm 2>/dev/null || true

update-desktop-database -q /usr/share/applications 2>/dev/null || true

# ------------------------------------------------------------------------------
# 8. Права доступу та підсумок
# ------------------------------------------------------------------------------
log "[8/8] Виставлення власника файлів"

chown -R "$REAL_USER:$REAL_GROUP" "$MANGO_CONF_DIR"
[ -d "$USER_HOME/.opencode" ] && chown -R "$REAL_USER:$REAL_GROUP" "$USER_HOME/.opencode"

cat <<EOF

==============================================================================
[✓] Встановлення завершено.
==============================================================================

Що зроблено:
  • локаль uk_UA.UTF-8, часовий пояс Europe/Kyiv;
  • підключено ButterRepo (mangowc 0.14.4 + libwlroots-0.19 + libscenefx-0.4);
  • встановлено Noctalia Shell з офіційного репозиторію;
  • встановлено kitty, xwayland, портали, PipeWire/WirePlumber, polkit;
  • встановлено lightdm і увімкнено graphical.target (графічний вхід після перезавантаження);
  • створено конфігурацію ~/.config/mango/ (mangowc 0.14.x синтаксис);
  • встановлено Hermes Agent та OpenCode;
  • створено навичку ~/.hermes/skills/debian-mangowm/SKILL.md.

Залишилося зробити вручну:
  1. Додати ключ NVIDIA у ~/.hermes/.env:
         NVIDIA_API_KEY=nvapi-...
     (ключ: https://build.nvidia.com/settings/api-keys)
     або запустити \`hermes setup\` і пройти майстер.
  2. Перевірити моделі:  hermes config get model
                        hermes fallback list
  3. Перезавантажити комп’ютер — з’явиться екран входу lightdm з сесією "Mango".

Гарячі клавіші:
  Super+Return — kitty            Super+A — Hermes
  Super+O      — OpenCode         Super+Space — launcher Noctalia
  Super+S      — control center   Super+, — налаштування Noctalia
  Super+W      — шпалери          Super+D — dock
  Super+N      — наступний макет  Ctrl+1..9 / Alt+1..9 — теги

Якщо щось не працює:
  mango -c ~/.config/mango/config.conf -p
  journalctl --user -n 50 --no-pager
  cat ~/.cache/noctalia/noctalia.log
==============================================================================
EOF

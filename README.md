# MangoWM + Noctalia Shell + Hermes Agent + OpenCode на Debian 13 (Trixie)

Посібник з налаштування робочого середовища Wayland на чистій Debian 13 (Trixie), amd64:

- **Композитор**: MangoWM 0.14.4 (пакет `mangowc` з [ButterRepo](https://apt.justaguy.dev)), пов'язаний із `libwlroots-0.19` + `libscenefx-0.4`.
- **Оболонка**: Noctalia Shell 5.5.0 з офіційного APT-репозиторію.
- **Термінал / AI-агенти**: kitty, Hermes Agent, OpenCode у іменованих scratchpad-вікнах.
- **Локалізація**: `uk_UA.UTF-8`, `Europe/Kyiv`, розкладки `us,ua` (Alt+Shift).

> ⚠️ ButterRepo доступний **тільки для amd64** (індекс arm64 повертає 404). `noctalia-trixie.sources` також оголошує `Architectures: amd64`.

## Чому саме цей стек (не збирання з джерел)

Раніше рекомендували збирати `libdrm 2.4.134` + `wlroots 0.20.2` + `scenefx 0.5` + `mango 0.18.6` з джерел. На Debian 13 це не слід робити:

1. `wlroots 0.20.2` вимагає `wayland >= 1.24`, `wayland-protocols >= 1.47`, `xkbcommon >= 1.8`, які у trixie старіші. Потрібні б `trixie-backports` і повне перезібраття стеку.
2. `scenefx 0.5` і `mango 0.18.6` вимагають `wlroots-0.20` — він недоступний у репозиторіях trixie.
3. ButterRepo вже збирав `mangowc 0.14.4` під `wlroots-0.19` / `scenefx 0.4`, що працює на системних бібліотеках trixie без збирання нічого з джерел.
4. `mangowc` — це пакетна назва; бінарник і команда у терміналі — `mango`. IPC-інструмент — `mmsg`.

Отже встановлюємо готові пакети ButterRepo та офіційний Noctalia, а не збираємо `libdrm/wlroots/scenefx/mango` з джерел.

## Передумови

- Чиста amd64 Debian 13 (Trixie).
- Запуск скрипта через `sudo` зі звичайного користувача (змінна `SUDO_USER` має бути задана).
- Інтернет-доступ для `apt`, `curl`, `wget` та інсталяторів Hermes/OpenCode.

## Встановлення

Завантажте і запустіть `setup-system.sh`:

```bash
sudo ./setup-system.sh
```

Скрипт робить наступне:

1. Встановлює базові пакети, локаль `uk_UA.UTF-8` та часовий пояс `Europe/Kyiv`.
2. Підключає **ButterRepo** (`https://apt.justaguy.dev`, ключ `/usr/share/keyrings/butterrepo.gpg`).
3. Підключає **офіційний репозиторій Noctalia** (`pkg.noctalia.dev/deb`, ключ `nickh-archive-keyring.gpg`, джерело `noctalia-trixie.sources`).
4. Встановлює `mangowc libwlroots-0.19 libscenefx-0.4`, `noctalia`, `kitty`, `xwayland`, портали, PipeWire/WirePlumber, polkit, шрифти, `lightdm`, `zenity` та допоміжні інструменти.
5. Пише конфігурацію MangoWM 0.14.x у `~/.config/mango/`:
   - `config.conf` — `source`-посилання, `layer_animations=0`, `single_scratchpad=0`.
   - `layout.conf` — `circle_layout=scroller,tile,grid` і параметри Scroller.
   - `input.conf` — розкладки `us,ua`, перемикання `grp:alt_shift_toggle`.
   - `rules.conf` — `windowrule=isnamedscratchpad:1,...` для `hermes-scratchpad` і `opencode-scratchpad`; `single_scratchpad=0` — в `config.conf`.
   - `keybinds.conf` — scratchpad (Super+A / Super+O), IPC-команди Noctalia, `exchange_client` (не `move_client`), макети, фокус, теги.
   - `autostart.conf` — `exec-once=noctalia` + `exec-once=~/.config/mango/welcome.sh` (вікно вітання при першому вході).
6. Перевіряє конфігурацію `mango -c ... -p`.
7. Встановлює Hermes Agent (`--non-interactive`) та конфігурує `model.provider=nvidia`, `model.default=nvidia/nemotron-3.5-super-vl-120b-a12b`, `terminal.backend=local`, `approvals.mode=smart`, додає резервну модель `z-ai/glm-5.3-flash`.
8. Встановлює OpenCode (`~/.opencode/bin/opencode`).
9. Створює навичку Hermes `~/.hermes/skills/debian-mangowm/SKILL.md`.

Шаблон теми Noctalia «Mango» **не вмикається**: він генерує синтаксис Mango 0.18+ (`root_color`, `border_color`, ...), несумісний з `mangowc` 0.14.4. Якщо шаблон уже було ввімкнено — вимкніть його, інакше Mango повідомить про невідомі ключі.

Після завершення скрипта додайте ключ NVIDIA у `~/.hermes/.env` (або запустіть `hermes setup`) і оберіть сесію "Mango" у дисплей-менеджері або запустіть `mango-session` з TTY.

### Вікно вітання при першому вході

Після першого запуску MangoWM з'явиться вікно вітання з кнопками:

- **Перевірити установку** — перевіряє наявність команд, конфігів, стану `lightdm` і ключа NVIDIA.
- **NVIDIA API-ключ** — відкриває сторінку створення ключів на build.nvidia.com та файл `~/.hermes/.env` для редагування.
- **Автовхід** — налаштовує `lightdm` для входу без пароля (потребує прав адміністратора через `pkexec`).
- **Інструкція на GitHub** — відкриває README репозиторію у браузері.
- **Не показувати більше** — приховає вікно вітання навжди.

Скрипти знаходяться у `~/.config/mango/welcome.sh` і `~/.config/mango/scripts/`.

## Конфігурація MangoWM (0.14.x, ButterRepo)

Пакети `mangowc` 0.14.4-6 ставлять бінарники `/usr/bin/mango`, `/usr/bin/mmsg`, `/usr/bin/mango-session` та сесійний файл `/usr/share/wayland-sessions/mango.desktop` (`Exec=mango-session`). Конфіг за замовчуванням — `/etc/mango/config.conf`; копіюйте його у `~/.config/mango/config.conf` для редагування.

### Синтаксис 0.14.x (відмінно від 0.18.6)

| Дію | 0.14.x (mangowc) | 0.18.6 (новіший синтаксис) |
|-----|------------------|--------------------|
| Правило вікна | `windowrule=Parameter:Value,...` | `window_rule=...` |
| Named scratchpad | `isnamedscratchpad:1` | `is_named_scratchpad:1` |
| Один scratchpad одночасно | `single_scratchpad=0` (глобальна опція в `config.conf`, **не** параметр `windowrule`) | глобальна `single_scratchpad=0` |
| Автозапуск | `exec-once=noctalia` | `exec_once=noctalia` |
| Додатковий конфіг | `source-optional=...` | `source_optional=...` |
| Обмін вікон | `exchange_client` | `move_client` (немає у 0.14.x) |
| dispatcher-команди | `togglefloating`, `togglefullscreen`, `killclient`, `reload_config`, `quit`, `spawn`, `switch_layout`, `setlayout`, `focusdir`, `focusstack`, `view`, `tag` | аналогічні, окрім `move_client` |

Перевірка конфігу без запуску композитора:

```bash
mango -c ~/.config/mango/config.conf -p
```

### layout.conf

```ini
circle_layout=scroller,tile,grid

scroller_structs=20
scroller_default_proportion=0.9
scroller_focus_center=0
scroller_prefer_center=0
scroller_prefer_overspread=1
edge_scroller_pointer_focus=1
scroller_proportion_preset=0.5,0.8,1.0
```

### input.conf

```ini
xkb_rules_layout=us,ua
xkb_rules_options=grp:alt_shift_toggle

repeat_rate=40
repeat_delay=300
```

### rules.conf

```ini
windowrule=isnamedscratchpad:1,width:1100,height:700,appid:hermes-scratchpad
windowrule=isnamedscratchpad:1,width:1200,height:750,appid:opencode-scratchpad
```

`single_scratchpad=0` задається як **глобальна опція** у `config.conf` (не як параметр `windowrule`), щоб дозволити одночасно бачити обидва scratchpad-а (Hermes і OpenCode). За замовчуванням `single_scratchpad=1` — тільки один одночасно.

### keybinds.conf

```ini
bind=SUPER,Return,spawn,kitty
bind=SUPER,a,toggle_named_scratchpad,hermes-scratchpad,none,kitty --class hermes-scratchpad -e "$HOME/.local/bin/hermes"
bind=SUPER,o,toggle_named_scratchpad,opencode-scratchpad,none,kitty --class opencode-scratchpad -e "$HOME/.opencode/bin/opencode"

bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
bind=SUPER,s,spawn,noctalia msg panel-toggle control-center
bind=SUPER,comma,spawn,noctalia msg settings-toggle
bind=SUPER,d,spawn,noctalia msg dock-toggle
bind=SUPER,w,spawn,noctalia msg panel-toggle wallpaper

bind=NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
bind=NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
bind=NONE,XF86AudioMute,spawn,noctalia msg volume-mute
bind=NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
bind=NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down

bind=SUPER,n,switch_layout
bind=SUPER,z,setlayout,scroller
bind=SUPER,t,setlayout,tile
bind=SUPER,g,setlayout,grid

bind=SUPER,q,killclient
bind=SUPER,f,togglefullscreen
bind=SUPER+SHIFT,f,togglefloating
bind=SUPER,r,reload_config
bind=SUPER,m,quit

bind=SUPER,Left,focusdir,left
bind=SUPER,Right,focusdir,right
bind=SUPER,Up,focusdir,up
bind=SUPER,Down,focusdir,down
bind=SUPER,Tab,focusstack,next

bind=SUPER+SHIFT,Left,exchange_client,left
bind=SUPER+SHIFT,Right,exchange_client,right
bind=SUPER+SHIFT,Up,exchange_client,up
bind=SUPER+SHIFT,Down,exchange_client,down

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
```

### autostart.conf

```ini
exec-once=noctalia
```

Noctalia сама керує шпалерами, тому окрема `awww` / `swaybg` не потрібна і виключена зі стеку.

Шаблон теми Noctalia «Mango» (Settings → Templates → Mango) генерує `~/.config/mango/noctalia.conf` із синтаксисом Mango 0.18+ (`root_color`, `border_color`, ...). На `mangowc` 0.14.4 цей файл не застосовується, тому скрипт його не створює і не додає `source-optional`. Не вмикайте цей шаблон на 0.14.4.

## Noctalia Shell

- Запуск: `exec-once=noctalia` у `autostart.conf` Mango.
- IPC: `noctalia msg <command>`.
- Панелі: `panel-toggle launcher`, `panel-toggle control-center`, `panel-toggle clipboard`, `panel-toggle wallpaper`, `panel-toggle session`.
- Налаштування: `settings-toggle`.
- Док: `dock-toggle`.
- Шпалери: `panel-toggle wallpaper` (вбудований вибір, окрема утиліта не потрібна).

Якщо Noctalia раніше була з проектом Quickshell (`noctalia-qs`), команда `noctalia` у v5 — це нативна C++ оболонка; команди v4 не підходять.

## Hermes Agent

Інсталятор: `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive`.
Бінарник: `~/.local/bin/hermes`. Конфіг: `~/.hermes/config.yaml`. Секрети: `~/.hermes/.env` (`chmod 600`).

Скрипт встановлює:

```yaml
model:
  provider: nvidia
  default: "nvidia/nemotron-3.5-super-vl-120b-a12b"
terminal:
  backend: local
approvals:
  mode: smart

fallback_providers:
  - provider: nvidia
    model: "z-ai/glm-5.3-flash"
```

У `~/.hermes/.env` додайте:

```
NVIDIA_API_KEY=nvapi-...
```

Ключ отримайте на [build.nvidia.com/settings/api-keys](https://build.nvidia.com/settings/api-keys) або через `hermes setup`.

Перевірка:

```bash
hermes config get model
hermes fallback list
hermes config get terminal.backend
hermes config get approvals.mode
```

Навичка системи: `~/.hermes/skills/debian-mangowm/SKILL.md`.

## OpenCode

Інсталятор: `curl -fsSL https://opencode.ai/install | bash`.
Бінарник: `~/.opencode/bin/opencode` (потрібен пакет `unzip`, встановлюється скриптом).

Запуск у scratchpad: `Super+O` (звичайний kitty: `Super+Return`).

## Перевірка після встановлення

```bash
# Конфіг Mango без запуску композитора
mango -c ~/.config/mango/config.conf -p

# Моделі Hermes
hermes config get model
hermes fallback list

# Наявність команд
command -v mango mmsg noctalia hermes opencode kitty

# Сесія
# Виберіть "Mango" у display manager або запустіть з TTY:
mango-session
```

Логи Noctalia: `~/.cache/noctalia/noctalia.log` (або `$XDG_CACHE_HOME/noctalia/`).

## Додатково: збірка з джерел (не рекомендується для trixie)

Якщо потрібна новіша версія MangoWM, пам'ятайте:

- `mango 0.18.6` потребує `wlroots-0.20`, `scenefx-0.5`, `libdrm >= 2.4.129` — вони **не існують** у репозиторіях trixie і вимагають повного збирання з джерел з `trixie-backports`.
- `mangowc 0.14.4` (ButterRepo) — остання лінія mango, що збирається на системному стеку trixie без додаткових збирань.

Цей крок опущено з основного скрипта і не входить до рекомендованого налаштування.

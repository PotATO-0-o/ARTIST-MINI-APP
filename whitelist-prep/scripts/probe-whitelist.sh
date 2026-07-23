#!/usr/bin/env bash
# Детект активации белого списка. Запускать по cron каждые 15 мин с машины в РФ.
# При обнаружении БС — отправляет алерт (настроить ALERT_CMD).
set -uo pipefail

ALERT_CMD="${ALERT_CMD:-}"  # например: 'curl -s "https://api.telegram.org/botTOKEN/sendMessage?chat_id=ID&text="'
STATE_FILE="/tmp/whitelist-probe-state"
LOG_FILE="/tmp/whitelist-probe.log"

PROBES=(
  "https://www.google.com/"
  "https://www.youtube.com/"
  "https://telegram.org/"
  "https://github.com/"
)

WHITELIST_PROBES=(
  "https://yandex.ru/"
  "https://vk.com/"
  "https://gosuslugi.ru/"
)

foreign_ok=0
foreign_fail=0
whitelist_ok=0
whitelist_fail=0

log() {
  echo "$(date -Iseconds) $*" >> "$LOG_FILE"
}

for url in "${PROBES[@]}"; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' "$url" --max-time 8 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|301|302|304)$ ]]; then
    ((foreign_ok++))
  else
    ((foreign_fail++))
  fi
done

for url in "${WHITELIST_PROBES[@]}"; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' "$url" --max-time 8 2>/dev/null || echo "000")
  if [[ "$code" =~ ^(200|301|302|304)$ ]]; then
    ((whitelist_ok++))
  else
    ((whitelist_fail++))
  fi
done

prev_state="normal"
[[ -f "$STATE_FILE" ]] && prev_state=$(cat "$STATE_FILE")

current_state="normal"
if [[ $foreign_fail -ge 3 && $whitelist_ok -ge 2 ]]; then
  current_state="whitelist_active"
elif [[ $foreign_fail -ge 3 && $whitelist_fail -ge 2 ]]; then
  current_state="full_blackout"
elif [[ $foreign_fail -ge 3 ]]; then
  current_state="partial_block"
fi

echo "$current_state" > "$STATE_FILE"
log "state=$current_state foreign_ok=$foreign_ok foreign_fail=$foreign_fail whitelist_ok=$whitelist_ok"

if [[ "$current_state" != "$prev_state" ]]; then
  msg="WHITELIST PROBE: $prev_state → $current_state (foreign: ${foreign_ok}ok/${foreign_fail}fail, whitelist: ${whitelist_ok}ok/${whitelist_fail}fail)"
  log "ALERT: $msg"
  if [[ -n "$ALERT_CMD" ]]; then
    eval "${ALERT_CMD}\"${msg}\""
  else
    echo "$msg"
  fi
fi

case "$current_state" in
  whitelist_active)
    echo "БС АКТИВЕН: зарубежные ресурсы недоступны, whitelist работает"
    exit 2
    ;;
  full_blackout)
    echo "ПОЛНОЕ ОТКЛЮЧЕНИЕ: ничего не доступно"
    exit 3
    ;;
  partial_block)
    echo "ЧАСТИЧНАЯ БЛОКИРОВКА: зарубежное недоступно, whitelist тоже"
    exit 2
    ;;
  *)
    echo "Нормальный режим"
    exit 0
    ;;
esac

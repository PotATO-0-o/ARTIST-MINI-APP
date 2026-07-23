#!/usr/bin/env bash
# Замер скорости обоих контуров через exit.
# Требует: curl, оба профиля настроены в клиенте (или прямой доступ к VM/CDN).
set -uo pipefail

CDN_HOST="${CDN_HOST:-cdn.example.com}"
VM_HOST="${VM_HOST:-vm.example.com}"
TEST_URL="${TEST_URL:-https://speed.cloudflare.com/__down?bytes=10000000}"

echo "=== Benchmark: $(date -Iseconds) ==="
echo "Тестовый файл: 10 MB"
echo ""

bench() {
  local name="$1" proxy="$2"
  echo -n "[$name] "
  result=$(curl -sS -o /dev/null -w 'time=%{time_total}s speed=%{speed_download}' \
    --max-time 30 $proxy "$TEST_URL" 2>/dev/null || echo "FAIL")
  if [[ "$result" == "FAIL" ]]; then
    echo "НЕДОСТУПЕН"
  else
    speed_bps=$(echo "$result" | grep -oP 'speed=\K[0-9.]+')
    speed_mbps=$(echo "scale=1; $speed_bps * 8 / 1000000" | bc 2>/dev/null || echo "?")
    time_s=$(echo "$result" | grep -oP 'time=\K[0-9.]+')
    echo "${speed_mbps} Мбит/с (${time_s}s)"
  fi
}

# Прямой (без прокси) — baseline
bench "Прямой (baseline)" ""

# Через SOCKS-прокси клиента (если запущен)
if [[ -n "${SOCKS_PROXY:-}" ]]; then
  bench "Через SOCKS ($SOCKS_PROXY)" "-x $SOCKS_PROXY"
fi

# Latency
echo ""
echo "[Latency]"
for host in "$CDN_HOST" "$VM_HOST"; do
  avg=$(ping -c 5 -q "$host" 2>/dev/null | tail -1 | awk -F'/' '{print $5}')
  if [[ -n "$avg" ]]; then
    echo "  $host: ${avg}ms"
  else
    echo "  $host: недоступен"
  fi
done

#!/usr/bin/env bash
# Проверка всех звеньев цепочки. Запускать с машины в РФ (или через VPN в РФ).
set -uo pipefail

CDN_HOST="${CDN_HOST:-cdn.example.com}"
ORIGIN_HOST="${ORIGIN_HOST:-origin.example.com}"
VM_HOST="${VM_HOST:-vm.example.com}"
RELAY_HOST="${RELAY_HOST:-relay.example.com}"
RELAY_IP="${RELAY_IP:-}"
XHTTP_PATH="${XHTTP_PATH:-/api-test}"

PASS=0
FAIL=0
WARN=0

check() {
  local name="$1" result="$2"
  if [[ "$result" == "OK" ]]; then
    echo "  ✓ $name"
    ((PASS++))
  elif [[ "$result" == "WARN" ]]; then
    echo "  ⚠ $name"
    ((WARN++))
  else
    echo "  ✗ $name"
    ((FAIL++))
  fi
}

echo "=== Health Check: $(date -Iseconds) ==="
echo ""

# 1. DNS
echo "[DNS]"
for host in "$CDN_HOST" "$VM_HOST" "$RELAY_HOST"; do
  if getent ahostsv4 "$host" &>/dev/null; then
    ip=$(getent ahostsv4 "$host" | head -1 | awk '{print $1}')
    check "$host → $ip" "OK"
  else
    check "$host DNS" "FAIL"
  fi
done
echo ""

# 2. CDN OPTIONS (контур 1)
echo "[Контур 1: CDN]"
cdn_code=$(curl -sS -o /dev/null -w '%{http_code}' -X OPTIONS --data-binary 'test' \
  "https://${CDN_HOST}/cdn-check?nocache=$(date +%s)" --max-time 10 2>/dev/null || echo "000")
if [[ "$cdn_code" == "204" ]]; then
  check "CDN OPTIONS /cdn-check → $cdn_code" "OK"
else
  check "CDN OPTIONS /cdn-check → $cdn_code" "FAIL"
fi

cdn_tls=$(echo | openssl s_client -connect "${CDN_HOST}:443" -servername "$CDN_HOST" 2>/dev/null \
  | openssl x509 -noout -dates 2>/dev/null | head -1)
if [[ -n "$cdn_tls" ]]; then
  check "CDN TLS cert valid" "OK"
else
  check "CDN TLS cert" "FAIL"
fi
echo ""

# 3. Fast VM (контур 2)
echo "[Контур 2: Fast VM]"
vm_tls=$(echo | openssl s_client -connect "${VM_HOST}:443" -servername "yandex.ru" 2>/dev/null \
  | head -5)
if echo "$vm_tls" | grep -q "CONNECTED"; then
  check "VM :443 TLS handshake" "OK"
else
  check "VM :443 TLS handshake" "FAIL"
fi

vm_http=$(curl -sS -o /dev/null -w '%{http_code}' "http://${VM_HOST}/" --max-time 5 2>/dev/null || echo "000")
if [[ "$vm_http" =~ ^(200|301|302)$ ]]; then
  check "VM :80 decoy → $vm_http" "OK"
else
  check "VM :80 decoy → $vm_http" "WARN"
fi
echo ""

# 4. Egress (критический — индикатор сценария B)
echo "[Egress: исходящий из РФ к exit]"
if [[ -n "$RELAY_IP" ]]; then
  if nc -zw5 "$RELAY_IP" 10443 2>/dev/null; then
    check "Egress → exit :10443" "OK"
  else
    check "Egress → exit :10443 (СЦЕНАРИЙ B?)" "FAIL"
  fi
else
  check "Egress (RELAY_IP не задан)" "WARN"
fi
echo ""

# 5. Whitelist probe
echo "[Whitelist probe]"
foreign_code=$(curl -sS -o /dev/null -w '%{http_code}' "https://www.google.com/" --max-time 5 2>/dev/null || echo "000")
if [[ "$foreign_code" =~ ^(200|301|302)$ ]]; then
  check "Прямой доступ к google.com → $foreign_code (БС не активен)" "OK"
else
  check "Прямой доступ к google.com → $foreign_code (БС АКТИВЕН или блокировка)" "WARN"
fi

yandex_code=$(curl -sS -o /dev/null -w '%{http_code}' "https://yandex.ru/" --max-time 5 2>/dev/null || echo "000")
if [[ "$yandex_code" =~ ^(200|301|302)$ ]]; then
  check "Прямой доступ к yandex.ru → $yandex_code" "OK"
else
  check "Прямой доступ к yandex.ru → $yandex_code" "FAIL"
fi
echo ""

# Итог
echo "=== Итог: $PASS OK, $WARN WARN, $FAIL FAIL ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0

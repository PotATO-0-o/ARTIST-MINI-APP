# Стратегия переключения контуров
#
# v2rayN / HAPP / v2rayNG не имеют встроенного auto-switch по типу сети.
# Варианты реализации:

# ─────────────────────────────────────────────
# Вариант 1: Ручное переключение (минимум)
# ─────────────────────────────────────────────
# LTE / мобильный интернет → mobile-cdn
# Wi-Fi / домашний          → wifi-fast

# ─────────────────────────────────────────────
# Вариант 2: Два профиля + тест при подключении
# ─────────────────────────────────────────────
# В клиенте настроить "автотест задержки" (latency test):
#   1. При запуске клиента — ping обоих профилей
#   2. Выбрать профиль с меньшей задержкой И успешным handshake
#   3. Если wifi-fast недоступен (БС на Wi-Fi ещё нет) → mobile-cdn

# ─────────────────────────────────────────────
# Вариант 3: Clash / sing-box с правилами (рекомендуется)
# ─────────────────────────────────────────────
# sing-box config с двумя outbound и urltest:

{
  "outbounds": [
    {
      "type": "urltest",
      "tag": "auto",
      "outbounds": ["wifi-fast", "mobile-cdn"],
      "url": "https://www.gstatic.com/generate_204",
      "interval": "3m",
      "tolerance": 50
    },
    {
      "type": "vless",
      "tag": "wifi-fast",
      "comment": "см. wifi-fast.json"
    },
    {
      "type": "vless",
      "tag": "mobile-cdn",
      "comment": "см. mobile-cdn.json"
    }
  ],
  "route": {
    "rules": [
      {
        "outbound": "auto"
      }
    ]
  }
}

# urltest каждые 3 минуты проверяет оба контура и выбирает быстрейший.
# На Wi-Fi wifi-fast победит (меньше хопов).
# На LTE с БС mobile-cdn победит (wifi-fast не достучится до VM... 
# стоп, VM тоже в whitelist, так что wifi-fast тоже должен работать на LTE).
#
# ВАЖНО: на LTE с БС оба контура технически работают (оба IP в whitelist).
# Разница — скорость. urltest выберет wifi-fast и на LTE, что нормально.
# mobile-cdn нужен как fallback если:
#   - VM IP выпал из whitelist
#   - Reality заблокирован DPI
#   - CDN более устойчив к эвристикам

# ─────────────────────────────────────────────
# Вариант 4: DNS-based routing (продвинутый)
# ─────────────────────────────────────────────
# Один домен vm.example.com с двумя A-записями:
#   - YC VM IP (основной)
#   - CDN IP (fallback через CNAME на cdn.example.com)
# Клиент подключается к vm.example.com:443
# Если VM недоступна — DNS возвращает CDN → XHTTP контур
# Требует split-horizon DNS или health-check DNS (Route53, YC DNS).

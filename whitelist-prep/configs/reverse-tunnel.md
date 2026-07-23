# Reverse tunnel: подготовка к сценарию B
#
# Если egress из РФ заблокирован, exit инициирует соединение К VM.
# VM принимает входящее (разрешено), клиент ходит на VM локально.
#
# Схема:
#   Exit ──[исходящий, не блокируется]──→ VM:443 (reverse port)
#   Client ──→ VM:443 (Reality) ──→ localhost:REVERSE_PORT ──→ Exit

# ── На VM (принимающая сторона) ──

# Вариант A: autossh (простой)
# На exit:
#   autossh -M 0 -f -N \
#     -o "ServerAliveInterval=30" \
#     -o "ServerAliveCountMax=3" \
#     -R 127.0.0.1:10444:127.0.0.1:10443 \
#     vm-user@VM_IP
#
# На VM клиент подключается к 127.0.0.1:10444

# Вариант B: Xray reverse proxy (надёжнее)
# На exit (config.json — добавить outbound):
{
  "protocol": "vless",
  "settings": {
    "vnext": [{
      "address": "VM_IP",
      "port": 443,
      "users": [{ "id": "REVERSE_UUID", "encryption": "none" }]
    }]
  },
  "streamSettings": {
    "network": "tcp",
    "security": "tls",
    "tlsSettings": { "serverName": "vm.example.com" }
  },
  "tag": "reverse-to-vm"
}

# На VM (config.json — добавить inbound для reverse):
{
  "tag": "reverse-in",
  "listen": "127.0.0.1",
  "port": 10444,
  "protocol": "dokodemo-door",
  "settings": {
    "address": "127.0.0.1",
    "port": 10443,
    "network": "tcp"
  }
}

# ВАЖНО: reverse tunnel нужно тестировать ДО сценария B.
# Exit должен уметь инициировать TCP к VM:443 из-за рубежа.
# Это работает, пока входящие в РФ не фильтруются по IP.

# ── Мониторинг reverse tunnel ──
# На VM:
#   ss -lntp | grep 10444    # reverse port слушает?
# На exit:
#   systemctl status autossh  # туннель жив?

#!/usr/bin/env bash
# Быстрая установка Fast VM (контур 2) на Ubuntu 22.04 в Yandex Cloud
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Запускайте от root: sudo $0"
  exit 1
fi

read -rp "VM_HOST (vm.example.com): " VM_HOST
read -rp "RELAY_HOST (relay.example.com): " RELAY_HOST
read -rp "RELAY_IP (exit-сервер): " RELAY_IP
read -rp "UUID (единый для всех контуров): " UUID
read -rp "EMAIL (для certbot): " EMAIL

VM_HOST=${VM_HOST:-vm.example.com}
RELAY_HOST=${RELAY_HOST:-relay.example.com}

echo "=== Установка зависимостей ==="
apt update && apt install -y curl nginx certbot ufw

echo "=== Установка Xray 26.5.9 ==="
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --version 26.5.9

echo "=== Генерация Reality keypair ==="
KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$KEYS" | awk '/Private key:/{print $3}')
PUBLIC_KEY=$(echo "$KEYS" | awk '/Public key:/{print $3}')
SHORT_ID=$(openssl rand -hex 4)

echo ""
echo "Сохраните для клиентского профиля:"
echo "  publicKey:  $PUBLIC_KEY"
echo "  shortId:    $SHORT_ID"
echo ""

echo "=== Nginx decoy ==="
install -d -m 755 /var/www/decoy /var/www/acme
cp decoy-index.html /var/www/decoy/index.html 2>/dev/null || \
  echo '<html><body>Maintenance</body></html>' > /var/www/decoy/index.html

cat > /etc/nginx/sites-available/decoy.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${VM_HOST};

    root /var/www/decoy;
    index index.html;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/acme;
    }
}
NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/decoy.conf /etc/nginx/sites-enabled/
nginx -t && systemctl enable --now nginx

echo "=== Xray config ==="
cat > /usr/local/etc/xray/config.json <<XRAY
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "tag": "reality-in",
    "listen": "0.0.0.0",
    "port": 443,
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "${UUID}", "flow": "xtls-rprx-vision" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "yandex.ru:443",
        "xver": 0,
        "serverNames": ["yandex.ru", "www.yandex.ru"],
        "privateKey": "${PRIVATE_KEY}",
        "shortIds": ["${SHORT_ID}"]
      }
    },
    "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
  }],
  "outbounds": [
    {
      "tag": "to-exit",
      "protocol": "vless",
      "settings": {
        "vnext": [{
          "address": "${RELAY_IP}",
          "port": 10443,
          "users": [{ "id": "${UUID}", "encryption": "none", "flow": "xtls-rprx-vision" }]
        }]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": { "serverName": "${RELAY_HOST}", "alpn": ["h2", "http/1.1"] }
      }
    },
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" }
  ],
  "routing": {
    "rules": [{ "type": "field", "inboundTag": ["reality-in"], "outboundTag": "to-exit" }]
  }
}
XRAY

/usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
systemctl enable xray && systemctl restart xray

echo "=== Firewall ==="
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

echo "=== Проверка egress к exit ==="
if nc -zw5 "${RELAY_IP}" 10443; then
  echo "OK: egress к exit работает"
else
  echo "WARN: egress к exit НЕ работает — проверьте firewall на exit"
fi

echo ""
echo "=== Готово ==="
echo "Клиентский профиль: client-profiles/wifi-fast.json"
echo "  publicKey: $PUBLIC_KEY"
echo "  shortId:   $SHORT_ID"

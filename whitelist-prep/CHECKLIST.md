# Чеклист готовности

## Инфраструктура

- [ ] Exit-сервер за рубежом работает (порт 10443, TLS, Xray 26.5.9+)
- [ ] Origin-сервер (CDN-контур) работает — XHTTP на 127.0.0.1:8003
- [ ] Yandex Cloud CDN настроен, OPTIONS проходит (`/cdn-check` → 204)
- [ ] **Fast VM в Yandex Cloud** поднята (Ubuntu 22.04, публичный IP)
- [ ] Fast VM: VLESS+Reality на :443, nginx decoy на :80
- [ ] Fast VM: исходящий к Exit работает (`nc -zw3 EXIT_IP 10443`)
- [ ] Резервная VM в VK Cloud / Selectel (хотя бы создана, не обязательно активна)
- [ ] Второй exit в другой стране / у другого хостера

## Домены и сертификаты

- [ ] `cdn.example.com` → Yandex CDN (контур 1)
- [ ] `origin.example.com` → Origin IP (внутренний, не для клиента)
- [ ] `relay.example.com` → Exit IP (внутренний, не для клиента)
- [ ] `vm.example.com` → Fast VM IP (контур 2)
- [ ] `vm2.example.com` → Резервная VM (опционально)
- [ ] Certbot auto-renew на всех серверах
- [ ] Certificate Manager: сертификат CDN-домена (Issued)

## Клиент

- [ ] Профиль `mobile-cdn` импортирован и протестирован на LTE с БС
- [ ] Профиль `wifi-fast` импортирован и протестирован на Wi-Fi
- [ ] Оба профиля используют **один UUID**
- [ ] Padding-параметры в mobile-профиле совпадают с origin
- [ ] Reality-параметры в wifi-профиле совпадают с fast-vm
- [ ] Замер скорости: wifi-fast ≥ 50 Мбит/с, mobile-cdn ≥ 5 Мбит/с

## Мониторинг

- [ ] `health-check.sh` проходит без ошибок
- [ ] `probe-whitelist.sh` в cron (каждые 15 мин) на машине в РФ
- [ ] Алерт при `egress DEAD` (Telegram-бот / email)
- [ ] Алерт при недоступности CDN `/cdn-check`
- [ ] Алерт при недоступности Fast VM :443
- [ ] Логи Xray на всех серверах: `loglevel: warning`

## Безопасность

- [ ] Порт 10443 на Exit открыт **только** с IP origin + fast-vm
- [ ] Порт 8003 на Origin **не** открыт наружу
- [ ] SSH: ключи, не пароли; fail2ban
- [ ] UUID сгенерирован криптостойко (`/proc/sys/kernel/random/uuid`)
- [ ] Reality: `show: false`, `shortIds` уникальны
- [ ] Домены не афишировать публично

## Резервное копирование

- [ ] Бэкап `/usr/local/etc/xray/config.json` со всех серверов
- [ ] Бэкап nginx-конфигов
- [ ] Бэкап DNS-записей (скриншот / экспорт)
- [ ] Бэкап клиентских профилей (без UUID в открытом виде)
- [ ] Документированы все IP, домены, UUID (в зашифрованном хранилище)

## Тестирование под нагрузкой БС

- [ ] Протестировать mobile-cdn при активном БС в своём регионе
- [ ] Протестировать wifi-fast при активном БС (симуляция: отключить Wi-Fi, включить LTE hotspot с БС)
- [ ] Протестировать переключение mobile → wifi и обратно
- [ ] Протестировать failover: убить fast-vm, убедиться что mobile-cdn подхватывает
- [ ] Протестировать failover: убить CDN, убедиться что wifi-fast работает на Wi-Fi

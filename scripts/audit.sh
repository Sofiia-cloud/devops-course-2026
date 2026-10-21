#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK]  $desc"
    ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
    ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
check "Порт SSH не 22" "2222" "$(sudo sshd -T | awk '/^port/{print $2}')"
check "MaxAuthTries = 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Default deny incoming" "deny" "$(sudo ufw status verbose | grep 'Default:' | grep -o 'deny (incoming)' | cut -d' ' -f1)"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

# === ДОБАВЛЕННЫЙ РАЗДЕЛ 4 ИЗ ПР №6 ===
echo "[4] Веб-сервер"
if sudo nginx -t >/dev/null 2>&1; then actual_nginx="ok"; else actual_nginx="fail"; fi
check "Конфигурация Nginx синтаксически корректна" "ok" "$actual_nginx"

if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; then actual_cert="ok"; else actual_cert="expiring"; fi
check "Сертификат действителен более 30 дней" "ok" "$actual_cert"

check "Права ключа 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

if [[ -z "$(find /var/www/devops-site -perm -o+w 2>/dev/null)" ]]; then actual_perm="clean"; else actual_perm="dirty"; fi
check "Нет файлов доступных на запись всем" "clean" "$actual_perm"
# =====================================

echo "[5] Контейнеризация"
check "Служба docker активна" "active" "$(systemctl is-active docker)"

if [[ -n "$(docker ps -q -f name=app-db-1)" ]]; then
    check "Контейнер СУБД healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1)"
else
    check "Контейнер СУБД healthy" "healthy" "not_running"
fi

# Проверка портов (5000 и 5432 не должны слушаться на 0.0.0.0)
if [[ -z "$(ss -tln | grep -E ':(5000|5432)' | grep -v '127.0.0.1')" ]]; then
    actual_ports="safe"
else
    actual_ports="exposed"
fi
check "Порты 5000 и 5432 только на localhost" "safe" "$actual_ports"

# Права .env
if [[ -f "$HOME/app/.env" ]]; then
    check "Права .env равны 600" "600" "$(stat -c '%a' "$HOME/app/.env")"
else
    check "Права .env равны 600" "600" "not_found"
fi

echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
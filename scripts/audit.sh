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

# TODO 1: проверьте, что значение параметра port отлично от 22
check "Порт SSH не 22" "2222" "$(sudo sshd -T | awk '/^port/{print $2}')"

# TODO 2: проверьте, что значение параметра maxauthtries равно 3
check "MaxAuthTries = 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверьте, что политика по умолчанию для входящего трафика равна deny
check "Default deny incoming" "deny" "$(sudo ufw status verbose | grep 'Default:' | grep -o 'deny (incoming)' | cut -d' ' -f1)"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd
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
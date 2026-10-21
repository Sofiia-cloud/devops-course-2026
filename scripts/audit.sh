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
echo "[4] Веб-сервер"
# nginx -t
if sudo nginx -t >/dev/null 2>&1; then actual_nginx="ok"; else actual_nginx="fail"; fi
check "Конфигурация Nginx синтаксически корректна" "ok" "$actual_nginx"

# Сертификат (проверка на 30 дней)
if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; then actual_cert="ok"; else actual_cert="expiring"; fi
check "Сертификат действителен более 30 дней" "ok" "$actual_cert"

# Права ключа
check "Права ключа 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

# Отсутствие файлов 777 в каталоге
if [[ -z "$(find /var/www/devops-site -perm -o+w 2>/dev/null)" ]]; then actual_perm="clean"; else actual_perm="dirty"; fi
check "Нет файлов доступных на запись всем" "clean" "$actual_perm"
echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
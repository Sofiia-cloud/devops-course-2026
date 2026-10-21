# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- ОЗУ: 2048 МБ (2 ГБ)
- Количество ядер: 2
- Объём диска: 25 ГБ (динамически расширяемый)
- Гипервизор: VirtualBox 7.x

## 2. Сетевые интерфейсы

- Адаптер 1 (NAT): enp0s3, IP 10.0.2.15, назначение — доступ в интернет (обновление пакетов).
- Адаптер 2 (Host-only): enp0s8, IP 192.168.56.101, назначение — прямой доступ с хостовой системы.

## 3. Правило проброса портов

- Порт хостовой системы: 2222
- Порт гостевой системы: 22 (изменен на 2222 в конфигурации SSH)
- Протокол: TCP

## 4. Учётные записи

- `student` (UID 1000): группа student, sudo (по паролю). Используется для первичной настройки.
- `devops` (UID 1001): группа devops, sudo. Вход только по SSH-ключу (~/.ssh/devops_vm).

## 5. Служба SSH

- Порт: 2222
- Файл конфигурации: /etc/ssh/sshd_config.d/99-hardening.conf
- Изменённые директивы:
  - Port 2222
  - PermitRootLogin no
  - PasswordAuthentication no
  - PubkeyAuthentication yes
  - MaxAuthTries 3
  - AllowUsers devops
  - X11Forwarding no
  - ClientAliveInterval 300
  - ClientAliveCountMax 2

## 6. Правила межсетевого экрана (ufw)

- Политики по умолчанию: deny (incoming), allow (outgoing)
- Разрешающие правила:
  - 80/tcp — ALLOW IN (HTTP)
  - 443/tcp — ALLOW IN (HTTPS)
  - 2222/tcp — LIMIT IN (SSH с защитой от перебора)

## 7. Снимки состояния

- `01-clean-install` — сразу после установки ОС и обновления.
- `02-keys-Configured` — после настройки ключевой аутентификации.
- `03-ssh-hardened` — после усиления безопасности SSH.

## 8. Веб-сервер

- **Устанавливаемый пакет:** `nginx`
- **Путь к конфигурации ресурса:** `/etc/nginx/sites-available/devops-site` (симлинк в `sites-enabled/devops-site`)
- **Каталог ресурса:** `/var/www/devops-site`
  - Владелец: `devops:devops`
  - Права: каталоги `755`, файлы `644`
- **Сертификат:** `/etc/ssl/certs/devops.crt` (права `644`)
- **Ключ:** `/etc/ssl/private/devops.key` (права `600`, владелец `root`)
- **Команда формирования сертификата:** 
  `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- **Срок действия:** 365 дней.

## 9. Контейнеризация
- **Способ установки Docker Engine:** официальный скрипт `get.docker.com`, версия Docker Engine 27.x.
- **Участники группы docker:** пользователь `devops`.
- **Расположение проекта на сервере:** `/home/devops/app`.
- **Расположение файла .env и его права:** `/home/devops/app/.env`, права `600`, владелец `devops`.
- **Публикуемые порты и адреса:** только `127.0.0.1:5000` (для Nginx).
- **Именованные тома:** `app_db_data` (для базы данных PostgreSQL).
- **Конфигурация обратного прокси-сервера:** Nginx проксирует запросы с `https://devops.local/app/` на `http://127.0.0.1:5000/`.

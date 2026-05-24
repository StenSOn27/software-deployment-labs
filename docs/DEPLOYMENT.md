# Розгортання на Linux VM

## Огляд

Цей документ описує процес розгортання Software Deployment Labs на Linux VM.

## Вимоги до VM

### Апаратне забезпечення

- **CPU**: 2+ ядра
- **RAM**: 2 GB+
- **Disk**: 20 GB+ (рекомендується 30 GB для логів та даних)

### Операційна система

Рекомендуються наступні дистрибутиви:

- **Ubuntu 22.04 LTS** (рекомендується)
- **Ubuntu 24.04 LTS**
- **CentOS Stream 9**
- **Debian 12**

## Завантаження та встановлення базового образу

### Ubuntu

1. Завантажте ISO: https://ubuntu.com/download/server
2. Виберіть **Ubuntu 22.04.5 LTS (Recommended)**
3. При встановленні:
   - **Hostname**: можете залишити за-замовчуванням або `deployment-labs`
   - **Username**: будь-яке (буде використано для першого входу)
   - **Partition**: використовуйте LVM (Linux Logical Volume Manager) для гнучкості
   - **OpenSSH Server**: обов'язково увімкніть
4. За-замовчуванням користувач матиме `sudo` доступ

### CentOS

1. Завантажте ISO: https://www.centos.org/download/
2. Виберіть **CentOS Stream 9 DVD**
3. При встановленні:
   - Виберіть "Server with GUI" або "Minimal Install"
   - Налаштуйте Network & Hostname
   - Налаштуйте дисків як LVM
4. Встановіть необхідні пакети:
   ```bash
   sudo yum groupinstall "Development Tools"
   ```

## Автоматичне розгортання

### Крок 1: Підготовка VM

1. Встановіть базовий образ і запустіть VM
2. SSH на VM від користувача зі `sudo` доступом:
   ```bash
   ssh user@<ip-address>
   ```

3. Перевірте, що Python 3 встановлений:
   ```bash
   python3 --version
   ```

### Крок 2: Завантажте код

```bash
# Клонуйте репозиторій (або скопіюйте файли)
git clone https://github.com/StenSOn27/practice-software-deployment-labs.git
cd practice-software-deployment-labs
```

Або завантажте архів та розпакуйте:
```bash
unzip software-deployment-labs-main.zip
cd software-deployment-labs-main
```

### Крок 3: Запустіть скрипт розгортання

```bash
# Переконайтеся, що скрипт виконується з root доступом
sudo bash deployment/scripts/setup.sh
```

Скрипт виконує:
- Встановлення системних пакетів
- Створення користувачів (student, teacher, operator, app)
- Налаштування MySQL та створення БД
- Встановлення Python залежностей
- Запуск міграцій БД
- Налаштування systemd сервісу
- Налаштування Nginx reverse proxy
- Створення `/home/student/gradebook` файлу

### Крок 4: Перевірте встановлення

```bash
# Перевірте, що сервіс запущений
sudo systemctl status mywebapp

# Перевірте логи
sudo journalctl -u mywebapp -f

# Тестуйте ендпоінти
curl http://localhost/health/alive
curl http://localhost/health/ready
```

## Ручне розгортання

Якщо скрипт не підходить, виконайте ці кроки вручну:

### 1. Встановіть залежності

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv \
    git mysql-server nginx curl wget
```

**CentOS:**
```bash
sudo yum install -y python3 python3-pip git mysql-server nginx curl wget
```

### 2. Створіть користувачів

```bash
# app - системний користувач для сервісу
sudo useradd --system --shell /bin/false --home-dir /opt/software-deployment-labs app

# student - розробник
sudo useradd --shell /bin/bash -m student
echo "student:12345678" | sudo chpasswd
sudo usermod -aG sudo student
sudo chage -d 0 student

# teacher - перевіряючий
sudo useradd --shell /bin/bash -m teacher
echo "teacher:12345678" | sudo chpasswd
sudo usermod -aG sudo teacher
sudo chage -d 0 teacher

# operator - управління сервісами
sudo useradd --shell /bin/bash -m operator
echo "operator:12345678" | sudo chpasswd
sudo chage -d 0 operator
```

### 3. Налаштуйте sudo для operator

```bash
sudo tee /etc/sudoers.d/operator > /dev/null <<EOF
operator ALL=(ALL) NOPASSWD: /bin/systemctl start mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl stop mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl restart mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl status mywebapp
operator ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
EOF

sudo chmod 440 /etc/sudoers.d/operator
```

### 4. Встановіть застосунок

```bash
cd /tmp
git clone <repo-url>
cd software-deployment-labs

# Встановіть залежності
python3 -m pip install -r requirements.txt
```

### 5. Налаштуйте БД

```bash
# Запустіть MySQL
sudo systemctl start mysql
sudo systemctl enable mysql

# Створіть БД та користувача
sudo mysql -u root << EOF
CREATE DATABASE software_labs CHARACTER SET utf8mb4;
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'app_password_123';
GRANT ALL ON software_labs.* TO 'app_user'@'localhost';
FLUSH PRIVILEGES;
EOF
```

### 6. Встановіть systemd сервіс

```bash
sudo cp deployment/configs/mywebapp.service /etc/systemd/system/
sudo cp deployment/configs/mywebapp.socket /etc/systemd/system/
sudo sed -i 's|/opt/software-deployment-labs|/opt/software-deployment-labs|g' \
    /etc/systemd/system/mywebapp.service

# Запустіть міграції
python3 -m alembic upgrade head

# Лізволіть сервіс
sudo systemctl daemon-reload
sudo systemctl enable mywebapp
sudo systemctl start mywebapp
```

### 7. Налаштуйте Nginx

```bash
sudo cp deployment/configs/nginx.conf /etc/nginx/sites-available/mywebapp
sudo ln -s /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Перевірте конфіг
sudo nginx -t

# Запустіть
sudo systemctl enable nginx
sudo systemctl start nginx
```

## Управління сервісом

### Stateful управління

```bash
# Переглянути статус
sudo systemctl status mywebapp

# Запустити
sudo systemctl start mywebapp

# Зупинити
sudo systemctl stop mywebapp

# Перезапустити
sudo systemctl restart mywebapp

# Переглянути логи
sudo journalctl -u mywebapp
sudo journalctl -u mywebapp -f  # Follow logs
sudo journalctl -u mywebapp -n 100  # Last 100 lines
```

### Socket Activation (опціонально)

Якщо налаштовано socket activation:

```bash
# Перевірте socket
sudo systemctl status mywebapp.socket

# Сокет автоматично активує сервіс при першому запиту
```

## Тестування розгортання

### На VM

```bash
# 1. Перевірте, що сервіси запущені
sudo systemctl status mywebapp nginx

# 2. Тестуйте health endpoints
curl http://localhost/health/alive
curl http://localhost/health/ready

# 3. Тестуйте API
curl -H "Accept: application/json" http://localhost/tasks/

# 4. Тестуйте веб-інтерфейс
# Відкрийте браузер: http://<vm-ip>/

# 5. Перевірте логи
sudo journalctl -u mywebapp -n 50
sudo tail -f /var/log/nginx/mywebapp_access.log
```

### З іншої машини

```bash
# Тестуйте з з'ясування мережі
curl http://<vm-ip>/health/alive
curl -H "Accept: application/json" http://<vm-ip>/tasks/
```

## Адміністування

### Переглянути логи

```bash
# Логи застосунку
sudo journalctl -u mywebapp -f

# Логи Nginx
sudo tail -f /var/log/nginx/mywebapp_access.log
sudo tail -f /var/log/nginx/mywebapp_error.log

# Системні логи
sudo journalctl -f
```

### Перезавантажити конфіг

```bash
# Nginx (без перезавантаження)
sudo systemctl reload nginx

# Застосунок (потрібен перезапуск)
sudo systemctl restart mywebapp
```

### Резервне копіювання БД

```bash
# Експортувати БД
sudo mysqldump -u app_user -p software_labs > backup.sql

# Імпортувати БД
sudo mysql -u app_user -p software_labs < backup.sql
```

## Усунення несправностей

### Сервіс не запускається

```bash
# Перевірте статус
sudo systemctl status mywebapp

# Перевірте логи
sudo journalctl -u mywebapp -n 50

# Перевірте конфіг
ls -la /etc/systemd/system/mywebapp.service
```

### БД не підключується

```bash
# Перевірте MySQL
sudo systemctl status mysql

# Перевірте конфіг БД
cat /opt/software-deployment-labs/src/config.ini

# Спробуйте підключитися
mysql -u app_user -p -h 127.0.0.1 software_labs
```

### Nginx повертає 502

```bash
# Перевірте, чи запущений застосунок
sudo systemctl status mywebapp

# Перевірте Nginx конфіг
sudo nginx -t

# Перевірте логи Nginx
sudo tail -f /var/log/nginx/mywebapp_error.log

# Перевірте, що застосунок слухає на 127.0.0.1:8000
sudo ss -tlnp | grep 8000
```

### Сервіс часто перезавантажується

```bash
# Перевірте логи для помилок
sudo journalctl -u mywebapp -n 100

# Перевірте конфіг міграцій
python3 -m alembic current
```

## Безпека

1. **Змініть паролі** за-замовчуванням:
   ```bash
   passwd  # Для студента/вчителя
   ```

2. **Налаштуйте SSH ключі**:
   ```bash
   ssh-keygen -t ed25519 -C "user@host"
   ssh-copy-id user@<vm-ip>
   ```

3. **Відключіть root SSH**:
   ```bash
   sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

4. **Налаштуйте firewall** (якщо потрібен):
   ```bash
   sudo ufw enable
   sudo ufw allow ssh
   sudo ufw allow http
   sudo ufw allow https
   ```

## Документація

- [API.md](API.md) — Описання API ендпоінтів
- [DATABASE.md](DATABASE.md) — Схема БД та міграції
- [../README.md](../README.md) — Основна документація

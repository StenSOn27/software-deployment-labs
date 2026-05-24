# Software Deployment Labs

Веб-застосунок для управління завданнями (To-Do List) з дотриманням вимог software deployment.

## Варіант завдання

Варіант розраховується з залікової книжки: студент **28** (Sten SOn27)
- **v2**: 2 (28 % 2 + 1)
- **v3**: 2 (28 % 3 + 1)
- **v4**: 4 (28 % 5 + 1)

## Призначення застосунку

Веб-застосунок для управління списком завдань з наступним функціоналом:
- Перегляд всіх завдань
- Додавання нових завдань
- Позначення завдання як виконаного
- Доступ через веб-інтерфейс та JSON API
- Перевірка стану сервісу (health checks)

## Технологічний стек

- **Backend**: Python 3, FastAPI, Uvicorn
- **Database**: MySQL 8.0+
- **ORM**: SQLAlchemy 2.0+ з асинхронною підтримкою
- **Migrations**: Alembic
- **Reverse Proxy**: Nginx
- **Process Management**: systemd

## Встановлення для розроблення

### Вимоги

- Python 3.11+
- MySQL 8.0+ (для продакшену)
- pip, virtualenv

### Кроки встановлення

```bash
# Клонуйте репозиторій
git clone <repo-url>
cd software-deployment-labs

# Створіть віртуальне середовище
python -m venv venv

# Активуйте venv
# On Linux/Mac:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Встановіть залежності
pip install -r requirements.txt

# Налаштуйте конфіг
cp src/config.ini.example src/config.ini
# Відредагуйте src/config.ini зі своїми параметрами БД

#創jте .env файл
echo "CONFIG_FILE_PATH=src/config.ini" > .env
```

### Запуск локально

#### Варіант 1: Із автоматичною міграцією

```bash
python run.py
```

#### Варіант 2: Запуск вручну

```bash
# Запустіть міграції
alembic upgrade head

# Запустіть застосунок
uvicorn src.main:app --reload --host 127.0.0.1 --port 8000
```

Застосунок буде доступний за адресою: **http://localhost:8000**

## API Ендпоінти

### Перевірка стану

- **GET** `/health/alive` — Завжди повертає HTTP 200 з текстом "OK"
  ```bash
  curl http://localhost:8000/health/alive
  ```

- **GET** `/health/ready` — Перевіряє підключення до БД
  - HTTP 200 з "OK" — сервіс готовий
  - HTTP 500 з опису помилки — проблема з БД

### Управління завданнями

#### Отримати всі завдання

- **GET** `/tasks/`
  - `Accept: text/html` → HTML сторінка таблиці завдань
  - `Accept: application/json` → JSON масив завдань
  ```bash
  curl -H "Accept: application/json" http://localhost:8000/tasks/
  ```

#### Додати нове завдання

- **POST** `/tasks/new`
  - Форма: `title` (обов'язково)
  - `Accept: text/html` → HTML форма + редірект після збереження
  - `Accept: application/json` → JSON з новим завданням
  ```bash
  curl -X POST -H "Accept: application/json" \
    -d "title=My Task" http://localhost:8000/tasks/new
  ```

#### Позначити завдання як виконане

- **POST** `/tasks/done`
  - Форма: `task_id` (обов'язково)
  - `Accept: text/html` → HTML форма + редірект після оновлення
  - `Accept: application/json` → JSON з оновленим завданням
  ```bash
  curl -X POST -H "Accept: application/json" \
    -d "task_id=1" http://localhost:8000/tasks/done
  ```

### Корневий ендпоінт

- **GET** `/`
  - Повертає HTML сторінку зі списком всіх доступних ендпоінтів

## Структура проекту

```
.
├── src/
│   ├── main.py                 # FastAPI приложение
│   ├── config.py               # Конфігурація із config.ini
│   ├── config.ini              # Параметри БД та сервісу
│   ├── alembic/
│   │   ├── env.py              # Конфіг Alembic для асинхронних міграцій
│   │   └── versions/           # Файли міграцій
│   ├── database/
│   │   ├── models.py           # ORM моделі (Task)
│   │   └── engine.py           # DatabaseHelper та сесії SQLAlchemy
│   ├── routes/
│   │   ├── health.py           # GET /health/*
│   │   ├── task_routes.py      # GET/POST /tasks/*
│   │   └── dependencies.py     # Dependency injection
│   ├── services/
│   │   └── task_service.py     # Бізнес-логіка для завдань
│   ├── repositories/
│   │   └── task_repository.py  # Дані доступу до завдань
│   └── templates/              # Jinja2 HTML шаблони
├── alembic.ini                 # Alembic конфіг
├── run.py                       # Скрипт запуску з міграціями
├── requirements.txt            # Python залежності
├── .env                        # Шлях до config.ini
└── deployment/                 # Скрипти розгортання
```

## Розгортання на Linux VM

### Вимоги до VM

- **OS**: Ubuntu 22.04 LTS або CentOS 9
- **CPU**: 2+ ядра
- **RAM**: 2 GB+
- **Disk**: 20 GB+
- **Network**: SSH доступ

### Базовий образ

Завантажте:
- **Ubuntu**: [ubuntu.com/download/server](https://ubuntu.com/download/server) — Ubuntu 22.04 LTS
- **CentOS**: [centos.org](https://www.centos.org/) — CentOS Stream 9

При встановленні:
- Використовуйте LVM для гнучкості розбивки диску
- Увімкніть OpenSSH Server
- Налаштуйте часовий пояс

### Автоматизовано розгортання

#### 1. Підготовка VM

```bash
# Завантажте базовий образ і встановіть OS
# SSH доступ: ssh root@<ip> з паролем встановленого користувача

# Клонуйте репозиторій
git clone <repo-url> /opt/software-deployment-labs
cd /opt/software-deployment-labs
```

#### 2. Запустіть скрипт розгортання

```bash
sudo bash deployment/setup.sh
```

Скрипт автоматично:
- Встановлює пакети (Python, MySQL, Nginx)
- Створює користувачів (student, teacher, operator, app)
- Налаштовує файлові права
- Запускає міграції БД
- Встановлює systemd unit (`mywebapp.service`)
- Налаштовує Nginx reverse proxy
- Запускає сервіси

#### 3. Увійдіть та змініть паролі

```bash
# Від користувача student (пароль за-замовчуванням: 12345678)
ssh student@<ip>
passwd  # Змініть пароль

# Від користувача teacher
ssh teacher@<ip>
passwd
```

### Управління сервісом

#### systemd unit

Файл розташований за `/etc/systemd/system/mywebapp.service`

```bash
# Переглянути статус
sudo systemctl status mywebapp

# Запустити
sudo systemctl start mywebapp

# Зупинити
sudo systemctl stop mywebapp

# Перезапустити
sudo systemctl restart mywebapp

# Логи
sudo journalctl -u mywebapp -f
```

**Користувач `operator`** може виконати ці команди через `sudo`:

```bash
# Як operator
sudo systemctl start mywebapp
sudo systemctl stop mywebapp
sudo systemctl restart mywebapp
sudo systemctl status mywebapp
sudo systemctl reload nginx
```

### Перевірка розгортання

```bash
# Перевіра живості (завжди 200)
curl http://<ip>/health/alive

# Перевіра готовності (200 якщо БД підключена)
curl http://<ip>/health/ready

# Отримати HTML сторінку з ендпоінтами
curl http://<ip>/

# Отримати JSON список завдань
curl -H "Accept: application/json" http://<ip>/tasks/
```

## Тестування

### Локальне тестування

```bash
# 1. Запустіть застосунок
python run.py

# 2. У іншому терміналі, перевірте ендпоінти
curl http://localhost:8000/health/alive
curl http://localhost:8000/health/ready
curl -H "Accept: application/json" http://localhost:8000/tasks/

# 3. Протестуйте веб-інтерфейс
# Відкрийте браузер: http://localhost:8000/
```

### На VM

```bash
# SSH на VM
ssh student@<ip>

# Перевірте статус сервісу
sudo systemctl status mywebapp

# Перевірте логи
sudo journalctl -u mywebapp -f

# Тестуйте ендпоінти
curl http://localhost/health/alive
curl http://localhost/health/ready

# Протестуйте веб-інтерфейс
# Відкрийте браузер: http://<ip>/
```

## Користувачі в системі

| Користувач | Призначення | Права | Пароль за-замовчуванням |
|-----------|-----------|-------|----------------------|
| student | Розробник / адміністратор | sudo | 12345678 |
| teacher | Перевірка роботи | sudo | 12345678 |
| operator | Управління сервісами | обмежена sudo | 12345678 |
| app | Системний користувач (застосунок) | мінімальні | - |

## Виправлення типових проблем

### Сервіс не запускається

```bash
sudo journalctl -u mywebapp -f  # Перевірте логи
sudo systemctl status mywebapp  # Перевірте статус
```

### БД не підключується

```bash
# Перевірте параметри в src/config.ini
# Перевірте, чи запущений MySQL
sudo systemctl status mysql
```

### Nginx повертає 502

```bash
# Перевірте, чи запущений застосунок
sudo systemctl status mywebapp

# Перевірте логи Nginx
sudo tail -f /var/log/nginx/error.log
```

## Розгортання з Docker Compose

### Вимоги

- Docker 20.10+
- Docker Compose 2.0+

### Запуск усіх сервісів

```bash
# Створіть та запустіть контейнери
docker-compose up -d

# Перевірте статус
docker-compose ps
```

Застосунок буде доступний за адресом: **http://localhost**

### Сервіси

Docker Compose запускає три сервіси:

- **db** (MySQL 8.0): База даних на порті 3306
- **web** (FastAPI): Веб-застосунок на порті 8000
- **nginx** (Nginx): Reverse proxy на порті 80

### Управління сервісами

```bash
# Перегляд логів
docker-compose logs -f web
docker-compose logs -f db
docker-compose logs -f nginx

# Запуск тільки конкретного сервісу
docker-compose up -d web

# Зупинка сервісів
docker-compose down

# Видалення з очищенням томів (УВАГА: видалить БД!)
docker-compose down -v

# Перебудова образу
docker-compose build --no-cache
```

### Тестування через Docker

```bash
# Перевіра живості
curl http://localhost/health/alive

# Перевіра готовності
curl http://localhost/health/ready

# Отримати JSON список завдань
curl -H "Accept: application/json" http://localhost/tasks/

# Додати нове завдання
curl -X POST http://localhost/tasks/new -d "title=Test Task"
```

### Обʼєм дані

База даних MySQL автоматично створює том `db_data` для персистентності. Дані будуть збережені навіть після видалення контейнера.

```bash
# Переглянути томи
docker volume ls

# Видалити том (УВАГА: видалить дані!)
docker volume rm software-deployment-labs_db_data
```

### Мережа

Всі сервіси работают в окремій мережі `app_network`, що забезпечує безпечну комунікацію між ними.

## Документація розробника

Додаткові файли документації:
- `docs/API.md` — Детальне описання API
- `docs/DEPLOYMENT.md` — Деталі розгортання та адміністрування
- `docs/DATABASE.md` — Схема БД та міграції

## Ліцензія

Освітній проект для курсу Software Deployment Labs.

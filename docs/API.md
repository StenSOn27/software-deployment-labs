# API Документація

## Огляд

Software Deployment Labs надає REST API для управління завданнями. API підтримує два формати відповідей:

- **HTML** (`Accept: text/html`) — для веб-браузера
- **JSON** (`Accept: application/json`) — для клієнтів та скриптів

## Базова URL

```
http://<hostname>/
```

Приклади:
- Локально: `http://localhost:8000/`
- На VM: `http://<vm-ip>/` або `http://<hostname>/`

## Аутентифікація

API не вимагає аутентифікації. Усі ендпоінти доступні без логіну.

## Формати даних

### Завдання (Task)

```json
{
  "id": 1,
  "title": "Купити молоко",
  "status": false,
  "created_at": "2024-05-24T10:30:00+00:00"
}
```

**Поля:**
- `id` (int) — унікальний ідентифікатор завдання
- `title` (str) — назва завдання (max 30 символів, унікальне)
- `status` (bool) — false = невиконане, true = виконане
- `created_at` (datetime) — коли було створено

## Ендпоінти

### 1. Список усіх ендпоінтів

**Запит:**
```
GET /
```

**Параметри:**
- Немає

**Відповіді:**
- `text/html` — HTML сторінка зі списком ендпоінтів

**Приклад:**
```bash
curl http://localhost:8000/
```

---

### 2. Перевірка живості

**Запит:**
```
GET /health/alive
```

**Параметри:**
- Немає

**Відповідь:**
- **HTTP 200** — сервіс живий
  ```
  OK
  ```

**Приклад:**
```bash
curl http://localhost:8000/health/alive
# OK
```

**Використання:** Для load balancers та health checks. Завжди повертає 200.

---

### 3. Перевірка готовності

**Запит:**
```
GET /health/ready
```

**Параметри:**
- Немає

**Відповідь:**
- **HTTP 200** — сервіс готовий (БД підключена)
  ```
  OK
  ```
- **HTTP 500** — сервіс не готовий
  ```
  Database connection error: <details>
  ```

**Приклад:**
```bash
curl http://localhost:8000/health/ready
# OK

# або
curl -i http://localhost:8000/health/ready
# HTTP/1.1 500 Internal Server Error
# Database connection error: (2003, "Can't connect to MySQL server on '127.0.0.1' (111)")
```

**Використання:** Для перевірки, чи готовий сервіс обробляти запити.

---

### 4. Отримати всі завдання

**Запит:**
```
GET /tasks/
```

**Параметри:**
- `Accept` (header) — тип відповіді
  - `text/html` — HTML таблиця
  - `application/json` — JSON масив

**Відповідь (JSON):**
```json
[
  {
    "id": 1,
    "title": "Купити молоко",
    "status": false,
    "created_at": "2024-05-24T10:30:00+00:00"
  },
  {
    "id": 2,
    "title": "Прочитати книгу",
    "status": true,
    "created_at": "2024-05-24T11:00:00+00:00"
  }
]
```

**Приклади:**

JSON:
```bash
curl -H "Accept: application/json" http://localhost:8000/tasks/
```

HTML (браузер):
```
http://localhost:8000/tasks/
```

Curl з HTML:
```bash
curl -H "Accept: text/html" http://localhost:8000/tasks/
```

---

### 5. Додати нове завдання

**Запит:**
```
GET /tasks/new
POST /tasks/new
```

**Параметри:**

GET — показати форму
```
Accept: text/html  # Показати HTML форму
```

POST — створити завдання
```
title=<назва>      # Обов'язково, max 30 символів, унікальне
Accept: <тип>      # text/html або application/json
```

**Відповідь (JSON):**
```json
{
  "id": 3,
  "title": "Нове завдання",
  "status": false,
  "created_at": "2024-05-24T12:00:00+00:00"
}
```

**Помилки:**

- **400 Bad Request** — порожня назва або відсутня назва
- **409 Conflict** — завдання з такою назвою вже існує

**Приклади:**

Форма (HTML):
```bash
curl -H "Accept: text/html" http://localhost:8000/tasks/new
```

Додати (JSON):
```bash
curl -X POST \
  -H "Accept: application/json" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "title=Купити сніданок" \
  http://localhost:8000/tasks/new
```

Додати (форма):
```bash
curl -X POST \
  -H "Accept: text/html" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "title=Позвонити другу" \
  http://localhost:8000/tasks/new
# Редірект на /tasks/ (HTTP 303)
```

---

### 6. Позначити завдання як виконане

**Запит:**
```
GET /tasks/done
POST /tasks/done
```

**Параметри:**

GET — показати форму
```
Accept: text/html  # Показати HTML форму
```

POST — позначити виконане
```
task_id=<id>       # Обов'язково, числове ID завдання
Accept: <тип>      # text/html або application/json
```

**Відповідь (JSON):**
```json
{
  "id": 1,
  "title": "Купити молоко",
  "status": true,
  "created_at": "2024-05-24T10:30:00+00:00"
}
```

**Помилки:**

- **400 Bad Request** — відсутня task_id або не число
- **404 Not Found** — завдання з таким ID не існує

**Приклади:**

Форма (HTML):
```bash
curl -H "Accept: text/html" http://localhost:8000/tasks/done
```

Позначити (JSON):
```bash
curl -X POST \
  -H "Accept: application/json" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "task_id=1" \
  http://localhost:8000/tasks/done
```

Позначити (форма):
```bash
curl -X POST \
  -H "Accept: text/html" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "task_id=1" \
  http://localhost:8000/tasks/done
# Редірект на /tasks/ (HTTP 303)
```

---

## Коди помилок

| Код | Опис | Приклад |
|-----|------|---------|
| 200 | OK — запит успішно оброблений | Успішно отримані завдання |
| 303 | See Other — редірект після POST у HTML | После додавання завдання |
| 400 | Bad Request — неправильні параметри | Відсутня обов'язкова поле |
| 404 | Not Found — ресурс не існує | Завдання з ID 999 не знайдено |
| 409 | Conflict — конфлікт даних | Завдання з такою назвою існує |
| 500 | Server Error — помилка сервера | БД недоступна |

## Примітки

1. **Content-Type:** Щоб передати дані в POST, використовуйте `application/x-www-form-urlencoded` або веб-форму
2. **Accept header:** Завжди вказуйте бажаний тип відповіді
3. **Унікальність назв:** Не можна створити два завдання з однаковою назвою
4. **Довжина назви:** Максимум 30 символів
5. **Часова зона:** Відповіді використовують UTC часовий пояс

## Приклади скриптів

### Bash

```bash
#!/bin/bash
API_URL="http://localhost:8000"

# Перевірити готовність
echo "Перевіка готовності..."
curl -s "$API_URL/health/ready"

# Отримати всі завдання
echo "Завдання:"
curl -s -H "Accept: application/json" "$API_URL/tasks/" | jq '.'

# Додати нове завдання
echo "Додаємо нове завдання..."
curl -s -X POST \
  -H "Accept: application/json" \
  -d "title=Нове завдання" \
  "$API_URL/tasks/new" | jq '.'

# Позначити як виконане
echo "Позначаємо завдання 1 як виконане..."
curl -s -X POST \
  -H "Accept: application/json" \
  -d "task_id=1" \
  "$API_URL/tasks/done" | jq '.'
```

### Python

```python
import requests
import json

API_URL = "http://localhost:8000"

# Перевірити готовність
response = requests.get(f"{API_URL}/health/ready")
print(f"Ready: {response.status_code == 200}")

# Отримати всі завдання
response = requests.get(
    f"{API_URL}/tasks/",
    headers={"Accept": "application/json"}
)
tasks = response.json()
print("Tasks:", json.dumps(tasks, indent=2))

# Додати нове завдання
response = requests.post(
    f"{API_URL}/tasks/new",
    data={"title": "Нове завдання"},
    headers={"Accept": "application/json"}
)
new_task = response.json()
print("New task:", json.dumps(new_task, indent=2))

# Позначити як виконане
response = requests.post(
    f"{API_URL}/tasks/done",
    data={"task_id": 1},
    headers={"Accept": "application/json"}
)
done_task = response.json()
print("Done task:", json.dumps(done_task, indent=2))
```

### JavaScript/Fetch API

```javascript
const API_URL = "http://localhost:8000";

// Перевірити готовність
fetch(`${API_URL}/health/ready`)
  .then(r => console.log(`Ready: ${r.status === 200}`));

// Отримати всі завдання
fetch(`${API_URL}/tasks/`, {
  headers: {"Accept": "application/json"}
})
  .then(r => r.json())
  .then(tasks => console.log("Tasks:", tasks));

// Додати нове завдання
fetch(`${API_URL}/tasks/new`, {
  method: "POST",
  headers: {"Accept": "application/json"},
  body: new URLSearchParams({title: "Нове завдання"})
})
  .then(r => r.json())
  .then(task => console.log("New task:", task));

// Позначити як виконане
fetch(`${API_URL}/tasks/done`, {
  method: "POST",
  headers: {"Accept": "application/json"},
  body: new URLSearchParams({task_id: 1})
})
  .then(r => r.json())
  .then(task => console.log("Done:", task));
```

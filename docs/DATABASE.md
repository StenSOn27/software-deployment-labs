# Схема БД та Міграції

## Огляд

Software Deployment Labs використовує MySQL 8.0+ як основне сховище даних. Схема керується за допомогою Alembic, що дозволяє версіонувати та відтворювати зміни структури БД.

## Схема БД

### Таблиця: tasks

Таблиця для зберігання завдань.

```sql
CREATE TABLE tasks (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(30) NOT NULL UNIQUE,
    status BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    
    INDEX idx_status (status),
    INDEX ix_tasks_title_status (title, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Поля:**

| Поле | Тип | Обмеження | Опис |
|------|-----|----------|------|
| `id` | INT | PRIMARY KEY, AUTO_INCREMENT | Унікальний ідентифікатор |
| `title` | VARCHAR(30) | NOT NULL, UNIQUE | Назва завдання |
| `status` | BOOLEAN | NOT NULL, DEFAULT FALSE | Статус (false = невиконане, true = виконане) |
| `created_at` | DATETIME(6) | NOT NULL, DEFAULT CURRENT_TIMESTAMP(6) | Час створення |

**Індекси:**

- `PRIMARY KEY (id)` — для швидкого пошуку по ID
- `INDEX idx_status (status)` — для фільтрації по статусу
- `INDEX ix_tasks_title_status (title, status)` — складний індекс для запитів, що фільтрують по названию та статусу

**Комбіновано:**

```mysql
SELECT id, title, status, created_at FROM tasks WHERE status = false;
```

## Міграції

Міграції керуються Alembic і дозволяють відслідковувати зміни схеми БД. Кожна міграція має унікальний ID (revision) та опис.

### Структура файлів міграцій

```
src/alembic/
├── env.py              # Конфіг Alembic для асинхронної роботи
├── script.py.mako      # Template для нових міграцій
└── versions/           # Каталог із міграціями
    └── 8da5ef45e102_create_task_table.py
```

### Поточні міграції

#### 1. Базова міграція (8da5ef45e102)

**Опис:** Створення таблиці tasks та індексів

**Файл:** `src/alembic/versions/8da5ef45e102_create_task_table.py`

**Операції:**
- CREATE TABLE tasks
- CREATE INDEX idx_status
- CREATE INDEX ix_tasks_title_status

## Запуск міграцій

### Автоматично (через run.py)

```bash
python3 run.py  # Запустить міграції перед стартом
```

### Вручну (через Alembic)

```bash
# Подивити поточну версію
alembic current

# Подивити історію міграцій
alembic history

# Запустити всі нові міграції
alembic upgrade head

# Запустити конкретну кількість міграцій
alembic upgrade +1  # Один крок вперед
alembic upgrade +2  # Два кроки вперед

# Відкотити міграції
alembic downgrade -1  # Один крок назад
alembic downgrade base  # До базову версії (без таблиць)

# Перейти на конкретну версію
alembic upgrade 8da5ef45e102
```

### На VM (через systemd)

Міграції запускаються автоматично перед стартом застосунку:

```bash
# systemd виконує ExecStartPre
ExecStartPre=/usr/bin/python3 /opt/software-deployment-labs/run.py migrate-only
```

Якщо потрібне ручне виконання:

```bash
cd /opt/software-deployment-labs
python3 -m alembic upgrade head
```

## Розробка нових міграцій

### Створення нової міграції

```bash
# Автоматична генерація на основі ORM моделей
alembic revision --autogenerate -m "Описання змін"

# Наприклад:
alembic revision --autogenerate -m "Add priority column to tasks"
```

Алембік проаналізує ваші ORM моделі (в `src/database/models.py`) та створить файл міграції із змінами.

### Редагування файлу міграції

Файл міграції матиме вигляд:

```python
"""Описание.

Revision ID: abc123def456
Revises: 8da5ef45e102
Create Date: 2024-05-24 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = 'abc123def456'
down_revision = '8da5ef45e102'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Операції для升级
    op.add_column('tasks', sa.Column('priority', sa.Integer(), nullable=True))
    op.create_index('ix_priority', 'tasks', ['priority'], unique=False)

def downgrade() -> None:
    # Операції для降级
    op.drop_index('ix_priority', table_name='tasks')
    op.drop_column('tasks', 'priority')
```

### Перевірка міграції

```bash
# Перевірити синтаксис
python3 -m py_compile src/alembic/versions/abc123def456_*.py

# Запустити на тестовій БД (рекомендується)
alembic upgrade +1
```

## Резервне копіювання та відновлення

### Резервна копія БД

```bash
# Повна експортація схеми та даних
mysqldump -u app_user -p software_labs > backup.sql

# Лише схема (без даних)
mysqldump -u app_user -p --no-data software_labs > schema.sql

# Лише дані (без схеми)
mysqldump -u app_user -p --no-create-info software_labs > data.sql

# Сжата резервна копія
mysqldump -u app_user -p software_labs | gzip > backup.sql.gz
```

### Відновлення з резервної копії

```bash
# Відновити усе
mysql -u app_user -p software_labs < backup.sql

# Відновити з arquіву
gunzip < backup.sql.gz | mysql -u app_user -p software_labs

# Відновити в нову БД
mysql -u root -p -e "CREATE DATABASE software_labs_restored;"
mysql -u app_user -p software_labs_restored < backup.sql
```

## Запитання для адміністрування

### Отримати статистику задач

```sql
SELECT COUNT(*) as total, 
       SUM(status = 1) as completed,
       SUM(status = 0) as pending
FROM tasks;
```

### Знайти найстарішії завдання

```sql
SELECT id, title, created_at 
FROM tasks 
ORDER BY created_at ASC 
LIMIT 10;
```

### Видалити завершені завдання

```sql
DELETE FROM tasks WHERE status = 1 AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);
```

### Перейменувати завдання

```sql
UPDATE tasks SET title = 'Нова назва' WHERE id = 1;
```

### Очистити таблицю

```sql
TRUNCATE TABLE tasks;
```

## Проблеми та рішення

### Міграція не запускається

```bash
# Перевірте версію
alembic current

# Переглянути логи
alembic upgrade head -v

# Ручне переналаштування версії (обережно!)
alembic stamp head  # Позначити як поточну версію без виконання
```

### БД не синхронізована з моделями

```bash
# Запустіть автогенерацію
alembic revision --autogenerate -m "Sync with models"

# Перевірте згенеровану міграцію
cat src/alembic/versions/<new_revision>_*.py

# Запустіть
alembic upgrade head
```

### Неправильна міграція

```bash
# Отримайте інформацію про стан
alembic history

# Відкотіть до попередньої версії
alembic downgrade -1

# Видаліть неправильний файл
rm src/alembic/versions/<bad_revision>_*.py

# Створіть нову правильну міграцію
alembic revision --autogenerate -m "Fix..."
alembic upgrade head
```

## Посилання

- [Alembic Documentation](https://alembic.sqlalchemy.org/)
- [SQLAlchemy ORM](https://docs.sqlalchemy.org/en/20/orm/)
- [MySQL Documentation](https://dev.mysql.com/doc/)

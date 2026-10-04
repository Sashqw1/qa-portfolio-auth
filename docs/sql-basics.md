# SQL для проверки данных: базовые запросы

Учебный материал, базовый уровень. Запросы написаны на схеме, которая следует из
контрактов данных ROBOCALC (`contracts/*.md` в репозитории продукта). Базы у
сервиса пока нет, поэтому схема приведена как есть — она показывает, какие
проверки понадобятся, когда появится хранилище.

## Схема

```sql
-- Пользователи
CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    name        VARCHAR(255) NOT NULL,
    role        VARCHAR(20)  NOT NULL,   -- user | admin
    blocked     BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Проекты расчёта
CREATE TABLE projects (
    id            SERIAL PRIMARY KEY,
    owner_user_id INTEGER     NOT NULL REFERENCES users(id),
    name          VARCHAR(255) NOT NULL,
    object_type   VARCHAR(20)  NOT NULL,  -- warehouse | airport | medical
    status        VARCHAR(20)  NOT NULL,  -- draft | calculated | archived
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Результаты расчёта по сценариям финансирования
CREATE TABLE scenarios (
    id            SERIAL PRIMARY KEY,
    project_id    INTEGER     NOT NULL REFERENCES projects(id),
    kind          VARCHAR(20) NOT NULL,   -- baseline | purchase | raas | custom
    capex_total   NUMERIC(14,2) NOT NULL,
    opex_annual   NUMERIC(14,2) NOT NULL,
    annual_effect NUMERIC(14,2) NOT NULL,
    payback_years NUMERIC(6,2),           -- NULL, если сценарий не окупается
    roi_pct       NUMERIC(8,2)
);
```

## Выборка данных

```sql
-- Все проекты одного пользователя, новые сверху
SELECT id, name, object_type, status, updated_at
FROM projects
WHERE owner_user_id = 1
ORDER BY updated_at DESC;
```

```sql
-- Только рассчитанные проекты по складам
SELECT id, name, updated_at
FROM projects
WHERE object_type = 'warehouse'
  AND status = 'calculated';
```

```sql
-- Проекты, которые не трогали больше 30 дней
SELECT id, name, updated_at
FROM projects
WHERE updated_at < NOW() - INTERVAL '30 days'
ORDER BY updated_at;
```

## Объединение таблиц

```sql
-- Проекты вместе с владельцем
SELECT p.name AS project, u.email, u.role
FROM projects p
JOIN users u ON u.id = p.owner_user_id
ORDER BY p.created_at DESC;
```

```sql
-- Проекты, по которым ещё нет ни одного расчёта.
-- LEFT JOIN + IS NULL — показывает строки, для которых пары не нашлось
SELECT p.id, p.name, p.status
FROM projects p
LEFT JOIN scenarios s ON s.project_id = p.id
WHERE s.id IS NULL;
```

## Группировка и подсчёт

```sql
-- Сколько проектов у каждого пользователя
SELECT u.email, COUNT(p.id) AS projects
FROM users u
LEFT JOIN projects p ON p.owner_user_id = u.id
GROUP BY u.email
ORDER BY projects DESC;
```

```sql
-- Распределение проектов по типам объектов и статусам
SELECT object_type, status, COUNT(*) AS cnt
FROM projects
GROUP BY object_type, status
ORDER BY object_type, status;
```

```sql
-- Средний срок окупаемости по типам объектов,
-- только там, где окупаемость вообще достигается
SELECT p.object_type,
       ROUND(AVG(s.payback_years), 2) AS avg_payback_years,
       COUNT(*) AS scenarios
FROM scenarios s
JOIN projects p ON p.id = s.project_id
WHERE s.payback_years IS NOT NULL
GROUP BY p.object_type;
```

## Запросы для поиска дефектов в данных

Это то, ради чего тестировщику нужен SQL: интерфейс может показывать
правдоподобную картинку, а в базе лежать мусор.

```sql
-- Проект помечен как рассчитанный, но расчётов нет.
-- Расхождение статуса и фактических данных
SELECT p.id, p.name, p.status
FROM projects p
LEFT JOIN scenarios s ON s.project_id = p.id
WHERE p.status = 'calculated' AND s.id IS NULL;
```

```sql
-- Отрицательные затраты — такого быть не должно
SELECT id, project_id, capex_total, opex_annual
FROM scenarios
WHERE capex_total < 0 OR opex_annual < 0;
```

```sql
-- Сценарий окупается, хотя годового эффекта нет.
-- Ровно та ошибка, что найдена на фронтенде (BUG-001)
SELECT id, project_id, annual_effect, payback_years
FROM scenarios
WHERE payback_years IS NOT NULL AND annual_effect <= 0;
```

```sql
-- Базовый сценарий с вложениями: по определению их быть не должно
SELECT id, project_id, capex_total
FROM scenarios
WHERE kind = 'baseline' AND capex_total <> 0;
```

```sql
-- Проекты-сироты: владелец удалён, а записи остались
SELECT p.id, p.name, p.owner_user_id
FROM projects p
LEFT JOIN users u ON u.id = p.owner_user_id
WHERE u.id IS NULL;
```

```sql
-- Дубли писем: поле объявлено уникальным, но проверить стоит —
-- ограничение могли добавить позже, чем появились данные
SELECT email, COUNT(*) AS cnt
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

```sql
-- Дата изменения раньше даты создания
SELECT id, name, created_at, updated_at
FROM projects
WHERE updated_at < created_at;
```

## Памятка

| Задача | Конструкция |
|---|---|
| Отобрать строки по условию | `WHERE` |
| Отсортировать | `ORDER BY ... DESC` |
| Соединить таблицы по ключу | `JOIN ... ON` |
| Найти строки без пары | `LEFT JOIN` + `WHERE ... IS NULL` |
| Посчитать по группам | `GROUP BY` + `COUNT`, `SUM`, `AVG` |
| Условие на результат группировки | `HAVING` |
| Ограничить количество строк | `LIMIT` |
| Проверить пустое значение | `IS NULL`, `IS NOT NULL` — не `= NULL` |

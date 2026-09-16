# Домашнее задание №2 — Писанко Михаил Геннадьевич, группа 16-25

Вариант: **EdTech (онлайн-курсы)**, на основе схемы из ДЗ №1.

## Файлы

- [`schema_1.sql`](./schema_1.sql) — полная схема из ДЗ №1 (нужна как база: остальные скрипты предполагают, что она уже применена).
- [`schema_2.sql`](./schema_2.sql) — Часть 1: две новые таблицы (`categories`, `course_categories`) и дополнительные индексы.
- [`violations_demo.sql`](./violations_demo.sql) — Часть 2: скрипт с 5 демонстрациями нарушений ограничений.
- этот файл — Часть 3: таблица нарушений и выводы.

## Как запустить

Через Docker + PostgreSQL 16 (аналогично инструкции в `студентам/README.md`):

```bash
docker start pg16_check 2>/dev/null || \
  docker run -d --name pg16_check -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

MSYS_NO_PATHCONV=1 docker cp schema_1.sql pg16_check:/tmp/schema_1.sql
MSYS_NO_PATHCONV=1 docker cp schema_2.sql pg16_check:/tmp/schema_2.sql
MSYS_NO_PATHCONV=1 docker cp violations_demo.sql pg16_check:/tmp/violations_demo.sql

MSYS_NO_PATHCONV=1 docker exec -i pg16_check psql -U postgres -d postgres -f /tmp/schema_1.sql
MSYS_NO_PATHCONV=1 docker exec -i pg16_check psql -U postgres -d postgres -f /tmp/schema_2.sql
MSYS_NO_PATHCONV=1 docker exec -i pg16_check psql -U postgres -d postgres -f /tmp/violations_demo.sql
```

Последняя команда должна вывести 5 `NOTICE`-сообщений — по одному на каждую демонстрацию нарушения.

---

## Часть 1. Кратко о дополнении схемы

Добавлены таблицы `categories` (справочник категорий курсов) и `course_categories`
(таблица-посредник для связи courses ↔ categories, отношение «многие-ко-многим»).

**Как реализовано M:N.** Прямо хранить связь M:N в реляционной таблице нельзя —
пришлось бы держать список значений в одном поле, что нарушает 1НФ. Поэтому
заведена отдельная таблица `course_categories` с одной строкой на каждую пару
(курс, категория) и составным первичным ключом `(course_id, category_id)`,
который одновременно:
- не даёт добавить одну и ту же пару дважды (работает как UNIQUE для пары полей);
- ускоряет запрос «все категории курса X» (course_id — первая часть ключа).

Для обратного запроса «все курсы категории Y» добавлен отдельный индекс
`idx_course_categories_category_id`.

**Что будет при DROP CASCADE.** У обоих FK в `course_categories` стоит
`ON DELETE CASCADE`:
- удаление курса (или `DROP TABLE courses CASCADE`) каскадно удаляет только
  связи этого курса в `course_categories`; сам справочник категорий не трогается;
- удаление категории каскадно удаляет только связи с этой категорией; курсы
  как сущности остаются, у них просто становится на одну категорию меньше.

Таким образом каскад затрагивает только таблицу-посредник — это ожидаемое и
безопасное поведение для M:N-связи.

---

## Часть 3. Таблица нарушений

| № | Ограничение | Выполняемый запрос (SQL) | Сообщение СУБД (SQLERRM) | Понятное сообщение для пользователя | Как исправить |
|---|---|---|---|---|---|
| 1 | CHECK | `INSERT INTO courses (title, description, teacher_id, price) VALUES ('Курс с отрицательной ценой', 'test', <teacher_id>, -500.00);` | `new row for relation "courses" violates check constraint "courses_price_check"` | «Стоимость курса не может быть отрицательной — курс нельзя продавать "в минус"» | Указать цену `>= 0`, для бесплатного курса — `0` |
| 2 | FOREIGN KEY | `INSERT INTO enrollments (student_id, course_id) VALUES (<student_id>, 999999);` | `insert or update on table "enrollments" violates foreign key constraint "enrollments_course_id_fkey"` | «Нельзя записать студента на несуществующий курс — курс должен реально существовать в каталоге» | Использовать `course_id` существующего курса (проверить его наличие в `courses` перед вставкой) |
| 3 | UNIQUE | `INSERT INTO users (full_name, email, password_hash) VALUES ('Дубликат Почтова', 'teacher_demo@example.com', 'hash_dup');` | `duplicate key value violates unique constraint "users_email_key"` | «Пользователь с такой почтой уже зарегистрирован — почта используется как логин и должна быть уникальной» | Использовать другую почту или пройти сценарий восстановления/входа в существующий аккаунт |
| 4 | NOT NULL | `INSERT INTO courses (title, description, teacher_id, price) VALUES (NULL, 'Курс без названия', <teacher_id>, 100.00);` | `null value in column "title" of relation "courses" violates not-null constraint` | «У курса обязательно должно быть название — иначе студенты не найдут его в каталоге» | Указать непустое название курса |
| 5 | PRIMARY KEY (составной) | `INSERT INTO course_categories (course_id, category_id) VALUES (<course_id>, <category_id>);` — при уже существующей паре | `duplicate key value violates unique constraint "course_categories_pkey"` | «Этот курс уже привязан к данной категории — повторная привязка не имеет смысла» | Перед вставкой проверить, есть ли уже такая связь (`SELECT ... WHERE course_id=... AND category_id=...`), либо использовать `ON CONFLICT DO NOTHING` |

---

## Краткие выводы

- Ограничения целостности (`CHECK`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, `PRIMARY KEY`)
  надёжно защищают базу от некорректных данных ещё до того, как они попадут в
  бизнес-логику приложения — ошибка возникает на уровне СУБД, а не где-то в коде.
- Технический текст ошибки СУБД (`SQLERRM`) полезен разработчику для отладки,
  но непригоден для показа пользователю — поэтому в приложении такие ошибки
  нужно перехватывать (как в блоках `DO $$ ... EXCEPTION ... END $$`) и
  превращать в понятные бизнес-сообщения.
- Составной первичный ключ в таблице-посреднике (`course_categories`) — удобный
  и дешёвый способ одновременно запретить дубли M:N-связи и ускорить выборку
  по одной из сторон связи, без создания дополнительного `UNIQUE`-ограничения.
- `ON DELETE CASCADE` на таблице-посреднике безопасен: он чистит только сами
  связи, а не сущности по обе стороны отношения (курсы и категории остаются
  на месте).

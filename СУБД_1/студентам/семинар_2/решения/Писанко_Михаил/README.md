# ДЗ №2 — Писанко Михаил Геннадьевич, группа 16-25

Вариант EdTech (онлайн-курсы), продолжение схемы из ДЗ №1

## Файлы

- `schema_1.sql` — схема из ДЗ №1, нужна как база, остальные скрипты без неё не запустятся
- `schema_2.sql` — часть 1, две новые таблицы + индексы
- `violations_demo.sql` — часть 2, скрипт с демонстрацией нарушений
- этот файл — часть 3, таблица нарушений и выводы

## Как запустить

Поднимаю Postgres 16 в докере (как в инструкции для семинара) и прогоняю файлы по очереди

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

Последний файл должен напечатать 5 NOTICE — по одному на каждое нарушение

---

## Часть 1. Что добавил в схему

Добавил две таблицы: `categories` (справочник категорий курсов, типа "Программирование", "Дизайн") и `course_categories` — таблица-посредник, которая связывает курсы и категории

Тут как раз получается связь многие-ко-многим: у курса может быть несколько категорий, у категории — много курсов. Напрямую такое в таблице не хранится (пришлось бы пихать список значений в одну колонку, а это уже не первая нормальная форма), поэтому делаю отдельную таблицу с одной строкой на каждую пару курс-категория. Первичный ключ составной, (course_id, category_id) — он же не даёт добавить одну и ту же пару дважды, и заодно ускоряет поиск "все категории курса X", потому что course_id стоит первым в ключе. Для обратного запроса, "все курсы категории Y", добавил ещё отдельный индекс по category_id, иначе он бы искал по всей таблице

По поводу DROP CASCADE — у обоих внешних ключей в course_categories стоит ON DELETE CASCADE. Если удалить курс, каскадом удалятся только связи этого курса в course_categories, сам справочник категорий останется целым. Если удалить категорию — то же самое, но в обратную сторону: пропадут только связи с этой категорией, а курсы никуда не денутся, просто у них будет на одну категорию меньше. То есть каскад бьёт только по таблице-посреднику, а не по самим сущностям — это и нужно для M:N

---

## Часть 3. Таблица нарушений

| № | Ограничение | Запрос | Сообщение СУБД | Сообщение для пользователя | Как исправить |
|---|---|---|---|---|---|
| 1 | CHECK | `INSERT INTO courses (title, description, teacher_id, price) VALUES ('Курс с отрицательной ценой', 'test', <teacher_id>, -500.00);` | `new row for relation "courses" violates check constraint "courses_price_check"` | Стоимость курса не может быть отрицательной, курс нельзя продавать "в минус" | Указать цену >= 0, для бесплатного курса — 0 |
| 2 | FOREIGN KEY | `INSERT INTO enrollments (student_id, course_id) VALUES (<student_id>, 999999);` | `insert or update on table "enrollments" violates foreign key constraint "enrollments_course_id_fkey"` | Нельзя записать студента на несуществующий курс | Указать course_id реального курса из каталога |
| 3 | UNIQUE | `INSERT INTO users (full_name, email, password_hash) VALUES ('Дубликат Почтова', 'teacher_demo@example.com', 'hash_dup');` | `duplicate key value violates unique constraint "users_email_key"` | Пользователь с такой почтой уже зарегистрирован | Ввести другую почту или войти в существующий аккаунт |
| 4 | NOT NULL | `INSERT INTO courses (title, description, teacher_id, price) VALUES (NULL, 'Курс без названия', <teacher_id>, 100.00);` | `null value in column "title" of relation "courses" violates not-null constraint` | У курса должно быть название, иначе его не найти в каталоге | Указать непустое название |
| 5 | PRIMARY KEY (составной) | `INSERT INTO course_categories (course_id, category_id) VALUES (<course_id>, <category_id>);` — пара уже есть | `duplicate key value violates unique constraint "course_categories_pkey"` | Этот курс уже привязан к этой категории | Проверить перед вставкой, есть ли уже такая связь, или использовать ON CONFLICT DO NOTHING |

---

## Выводы

Ограничения целостности ловят некорректные данные ещё на уровне СУБД, до того как они долетят до логики приложения — это удобно, потому что не надо дублировать эти же проверки в коде

Текст ошибки от Postgres (SQLERRM) — штука техническая, пользователю её показывать бессмысленно, но для логов и отладки полезна, поэтому в демо-скрипте вывожу оба варианта сразу: и понятное сообщение, и SQLERRM

Составной PK в таблице-посреднике — простой способ убить сразу двух зайцев: не пускает дубли связи и работает как индекс для поиска по первой колонке, отдельный UNIQUE для этого заводить не пришлось

ON DELETE CASCADE на посреднике безопасный, потому что чистит только сами связи, а курсы с категориями как сущности не трогает

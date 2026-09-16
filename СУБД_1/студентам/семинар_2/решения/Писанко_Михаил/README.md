# ДЗ №2, Писанко Михаил Геннадьевич, 16-25

EdTech, продолжение ДЗ №1.

Файлы:
- schema_1.sql - схема из ДЗ №1, без неё остальное не запустится
- schema_2.sql - часть 1, новые таблицы и индексы
- violations_demo.sql - часть 2, нарушения ограничений
- README.md (этот файл) - часть 3

Запуск через докер, postgres 16, так же как в семинаре:

```bash
docker start pg16_check 2>/dev/null || docker run -d --name pg16_check -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

docker cp schema_1.sql pg16_check:/tmp/schema_1.sql
docker cp schema_2.sql pg16_check:/tmp/schema_2.sql
docker cp violations_demo.sql pg16_check:/tmp/violations_demo.sql

docker exec -i pg16_check psql -U postgres -d postgres -f /tmp/schema_1.sql
docker exec -i pg16_check psql -U postgres -d postgres -f /tmp/schema_2.sql
docker exec -i pg16_check psql -U postgres -d postgres -f /tmp/violations_demo.sql
```

на винде перед docker cp/exec нужно ставить MSYS_NO_PATHCONV=1, иначе git bash ломает пути

в конце должно вывестись 5 NOTICE, по одной на каждое нарушение

## часть 1

добавил две таблицы. categories - просто справочник категорий курса (программирование, дизайн и тд), и course_categories - таблица которая связывает курсы и категории.

тут м:н получается, курс может быть в нескольких категориях и в категории много курсов. напрямую так в базе не хранят, нормально это только через отдельную таблицу-посредник, где одна строка = одна связь курс-категория. pk сделал составной, (course_id, category_id), он и дубли не даёт вставлять и поиск по course_id ускоряет. для обратного поиска (все курсы категории) добавил ещё индекс по category_id отдельно.

по касkаду - у обеих fk в course_categories on delete cascade. то есть если удалить курс - удалятся только связи этого курса в посреднике, категории как были так и останутся. если удалить категорию - то же самое, просто у курсов будет на одну категорию меньше, сами курсы никуда не денутся. короче каскад только по таблице-посреднику идет, не по основным сущностям.

## часть 3

таблица нарушений:

| № | ограничение | запрос | ошибка СУБД | сообщение юзеру | как исправить |
|---|---|---|---|---|---|
| 1 | CHECK | INSERT INTO courses (title, description, teacher_id, price) VALUES ('Курс с отрицательной ценой', 'test', <teacher_id>, -500.00); | new row for relation "courses" violates check constraint "courses_price_check" | цена курса не может быть отрицательной | цена >= 0, для бесплатного 0 |
| 2 | FOREIGN KEY | INSERT INTO enrollments (student_id, course_id) VALUES (<student_id>, 999999); | insert or update on table "enrollments" violates foreign key constraint "enrollments_course_id_fkey" | нельзя записать на несуществующий курс | указать реальный course_id |
| 3 | UNIQUE | INSERT INTO users (full_name, email, password_hash) VALUES ('Дубликат Почтова', 'teacher_demo@example.com', 'hash_dup'); | duplicate key value violates unique constraint "users_email_key" | такая почта уже зарегана | ввести другую почту |
| 4 | NOT NULL | INSERT INTO courses (title, description, teacher_id, price) VALUES (NULL, 'Курс без названия', <teacher_id>, 100.00); | null value in column "title" of relation "courses" violates not-null constraint | у курса должно быть название | заполнить название |
| 5 | PRIMARY KEY | INSERT INTO course_categories (course_id, category_id) VALUES (...); повторно | duplicate key value violates unique constraint "course_categories_pkey" | курс уже привязан к этой категории | проверять перед вставкой или ON CONFLICT DO NOTHING |

выводы: ограничения ловят кривые данные прямо в базе, ещё до того как они дойдут до кода приложения, поэтому эти же проверки не приходится дублировать в бэкенде. SQLERRM для пользователя показывать не надо, это для логов, а нормальный текст ошибки пишем сами. составной pk в course_categories удобен тем что сразу и от дублей защищает и индекс дает бесплатно. cascade delete в таблице-посреднике не страшный, он чистит только связи а не сами курсы/категории.

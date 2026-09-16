-- ДЗ №2, часть 1 — дополнение схемы (EdTech, вариант 1)
--
-- Добавляю две таблицы: categories (справочник категорий курсов) и
-- course_categories (таблица-посредник для связи courses <-> categories)
--
-- Тут связь многие-ко-многим: у курса может быть несколько категорий,
-- у категории много курсов. Напрямую в реляционке так не хранят, поэтому
-- завожу отдельную таблицу с одной строкой на пару (курс, категория).
-- Составной PK (course_id, category_id) не даёт добавить одну и ту же
-- пару дважды и заодно ускоряет поиск "все категории курса X" (course_id
-- первый в ключе). Для обратного поиска "все курсы категории Y" нужен
-- отдельный индекс по category_id, иначе будет скан всей таблицы.
--
-- DROP CASCADE: у обоих FK в course_categories стоит ON DELETE CASCADE.
-- Удаление курса каскадом чистит только его связи в course_categories,
-- сам справочник категорий не трогается. Удаление категории — так же,
-- но в обратную сторону: курсы остаются, просто у них становится на
-- одну категорию меньше. Каскад бьёт только по таблице-посреднику.

DROP TABLE IF EXISTS course_categories CASCADE;
DROP TABLE IF EXISTS categories CASCADE;


-- Таблица 1 (новая): справочник категорий курсов
CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);


-- Таблица 2 (новая): посредник для M:N courses <-> categories.
-- Составной PK = и запрет дублей, и индекс по course_id заодно.
CREATE TABLE course_categories (
    course_id   INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (course_id, category_id)
);

-- индекс для обратного поиска "все курсы категории"
CREATE INDEX idx_course_categories_category_id ON course_categories(category_id);


-- Дополнительные индексы для старых таблиц из ДЗ №1, под частые запросы:
--   уроки курса по порядку           -> lessons(course_id, order_number)
--   отзывы + средний рейтинг курса   -> reviews(course_id, rating)
--   выплаты преподавателю за месяц   -> payouts(teacher_id, pay_month)
--   невыплаченные выплаты            -> payouts(paid_at), частичный индекс
--   завершённые записи на курс       -> enrollments(course_id, status)
-- индексов на FK из schema_1.sql для этих запросов недостаточно, базе
-- всё равно пришлось бы досортировывать/дофильтровывать вручную

CREATE INDEX idx_lessons_course_order ON lessons(course_id, order_number);
CREATE INDEX idx_reviews_course_rating ON reviews(course_id, rating);
CREATE INDEX idx_payouts_teacher_month ON payouts(teacher_id, pay_month);
CREATE INDEX idx_payouts_unpaid ON payouts(teacher_id) WHERE paid_at IS NULL;
CREATE INDEX idx_enrollments_course_status ON enrollments(course_id, status);
